# app/db/career_data_manager.py - UPDATED to use unified AI insights collection
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from bson import ObjectId
import hashlib
import json
import logging

from app.db.connection import get_db
from app.models.ai_insights_model import AIInsightsModel, AIInsightType

logger = logging.getLogger(__name__)


class CareerDataManager:
    """
    Optimized Career Data Storage using unified AI insights collection
    """
    
    def __init__(self):
        self.max_history_per_user = 10
        self.archive_days = 90
        self.cache_ttl_hours = 24
    
    async def save_career_analysis(self, email: str, user_id: str, analysis: Dict) -> Dict:
        """
        Save career analysis to unified ai_insights collection
        """
        db = get_db()
        
        # Create hash for deduplication
        analysis_hash = hashlib.md5(
            json.dumps(analysis, sort_keys=True, default=str).encode()
        ).hexdigest()
        
        # Check if same analysis exists (avoid duplicates)
        existing = await db.ai_insights.find_one({
            "email": email,
            "type": AIInsightType.CAREER_ANALYSIS,
            "analysis_hash": analysis_hash
        })
        
        if existing:
            return {"message": "Analysis already exists", "cached": True, "analysis_id": str(existing["_id"])}
        
        # Mark previous analyses as not current
        await db.ai_insights.update_many(
            {"email": email, "type": AIInsightType.CAREER_ANALYSIS, "is_current": True},
            {"$set": {"is_current": False}}
        )
        
        # Create new analysis document
        analysis_doc = AIInsightsModel(
            type=AIInsightType.CAREER_ANALYSIS,
            email=email,
            user_id=user_id,
            data=analysis,
            version=analysis.get('version', 1),
            is_current=True,
            analysis_hash=analysis_hash,
            analysis_duration_ms=analysis.get('duration_ms'),
            ai_model_used=analysis.get('model_used', 'gpt-4o-mini')
        )
        
        result = await db.ai_insights.insert_one(analysis_doc.model_dump(by_alias=True))
        analysis_id = str(result.inserted_id)
        
        # Extract cache data from analysis
        career_paths = analysis.get('career_paths', [])
        top_path = career_paths[0] if career_paths else {}
        
        # Update profile with cache (fast access)
        await db.profile.update_one(
            {"email": email},
            {
                "$set": {
                    "career_cache": {
                        "analysis_id": analysis_id,
                        "generated_at": datetime.utcnow().isoformat(),
                        "top_career_match": top_path.get('role', ''),
                        "match_score": top_path.get('match_score', 0),
                        "top_skills": analysis.get('skill_gap_analysis', {}).get('critical_skills', [])[:5],
                        "immediate_actions": analysis.get('personalized_recommendations', {}).get('immediate_actions', [])[:3],
                        "analysis_hash": analysis_hash,
                        "version": analysis.get('version', 1)
                    },
                    "career_cache_updated_at": datetime.utcnow(),
                    "last_ai_update": datetime.utcnow(),
                    "ai_enriched": True
                }
            },
            upsert=True
        )
        
        # Cleanup old analyses
        await self._cleanup_old_analyses(email)
        
        return {
            "analysis_id": analysis_id,
            "stored_in_profile": True,
            "stored_in_ai_insights": True,
            "cache_updated": True
        }
    
    async def get_latest_analysis(self, email: str, include_full: bool = False) -> Optional[Dict]:
        """
        Get latest analysis - fast from profile or full from ai_insights
        """
        db = get_db()
        
        # First try profile cache (fast path - O(1))
        profile = await db.profile.find_one({"email": email})
        
        if profile and profile.get('career_cache'):
            career_cache = profile['career_cache']
            
            if not include_full:
                # Return cached summary (fast path)
                return {
                    "source": "profile_cache",
                    "is_cached": True,
                    "is_full": False,
                    "analysis": career_cache,
                    "generated_at": profile.get('career_cache_updated_at')
                }
            
            # Get full analysis from ai_insights
            analysis_id = career_cache.get('analysis_id')
            if analysis_id and ObjectId.is_valid(analysis_id):
                full_analysis = await db.ai_insights.find_one({
                    "_id": ObjectId(analysis_id),
                    "type": AIInsightType.CAREER_ANALYSIS
                })
                if full_analysis:
                    return {
                        "source": "ai_insights",
                        "is_cached": False,
                        "is_full": True,
                        "analysis_id": analysis_id,
                        "analysis": full_analysis.get('data'),
                        "generated_at": full_analysis.get('created_at')
                    }
        
        # Fallback: get latest from ai_insights
        latest = await db.ai_insights.find_one(
            {"email": email, "type": AIInsightType.CAREER_ANALYSIS, "is_current": True},
            sort=[("created_at", -1)]
        )
        
        if latest:
            return {
                "source": "ai_insights",
                "is_cached": False,
                "is_full": True,
                "analysis_id": str(latest["_id"]),
                "analysis": latest.get('data'),
                "generated_at": latest.get('created_at')
            }
        
        return None
    
    async def get_analysis_history(self, email: str, limit: int = 10, skip: int = 0) -> Dict:
        """
        Get historical analyses for trend analysis
        """
        db = get_db()
        
        total = await db.ai_insights.count_documents({
            "email": email,
            "type": AIInsightType.CAREER_ANALYSIS
        })
        
        history = await db.ai_insights.find(
            {"email": email, "type": AIInsightType.CAREER_ANALYSIS}
        ).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
        
        return {
            "total": total,
            "returned": len(history),
            "skip": skip,
            "limit": limit,
            "history": [
                {
                    "analysis_id": str(h["_id"]),
                    "date": h["created_at"].isoformat(),
                    "version": h.get('version', 1),
                    "summary": {
                        "top_career": h.get('data', {}).get('career_paths', [{}])[0].get('role', ''),
                        "match_score": h.get('data', {}).get('career_paths', [{}])[0].get('match_score', 0)
                    }
                }
                for h in history
            ]
        }
    
    async def save_learning_path(self, user_email: str, user_id: str, 
                                  career_path_id: Optional[str],
                                  learning_plan: Dict) -> Dict:
        """Save learning path to unified ai_insights collection"""
        db = get_db()
        
        # Mark previous learning paths as not current
        await db.ai_insights.update_many(
            {"email": user_email, "type": AIInsightType.LEARNING_PATH, "is_current": True},
            {"$set": {"is_current": False}}
        )
        
        learning_path_doc = AIInsightsModel(
            type=AIInsightType.LEARNING_PATH,
            email=user_email,
            user_id=user_id,
            data=learning_plan,
            career_path_id=career_path_id,
            status="active",
            progress_percentage=0,
            milestones=learning_plan.get('milestones', []),
            total_duration_weeks=learning_plan.get('total_duration_weeks', 0),
            skills_to_learn=learning_plan.get('skills_to_learn', 0),
            resources_count=len(learning_plan.get('resources', [])),
            started_at=datetime.utcnow()
        )
        
        result = await db.ai_insights.insert_one(learning_path_doc.model_dump(by_alias=True))
        learning_path_id = str(result.inserted_id)
        
        # Update profile with cache
        await db.profile.update_one(
            {"email": user_email},
            {
                "$set": {
                    "learning_path_cache": {
                        "learning_path_id": learning_path_id,
                        "status": "active",
                        "progress": 0,
                        "started_at": datetime.utcnow().isoformat()
                    },
                    "learning_path_updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
        
        return {
            "learning_path_id": learning_path_id,
            "stored": True,
            "message": "Learning path saved successfully"
        }
    
    async def update_learning_progress(self, learning_path_id: str, 
                                        progress_percentage: float,
                                        completed_milestone_id: Optional[str] = None) -> Dict:
        """Update learning path progress"""
        db = get_db()
        
        if not ObjectId.is_valid(learning_path_id):
            return {"error": "Invalid learning path ID"}
        
        update_data = {
            "progress_percentage": progress_percentage,
            "last_accessed": datetime.utcnow(),
            "engagement_score": min(100, progress_percentage + 10)
        }
        
        if completed_milestone_id:
            await db.ai_insights.update_one(
                {"_id": ObjectId(learning_path_id)},
                {"$addToSet": {"completed_milestones": completed_milestone_id}}
            )
        
        if progress_percentage >= 100:
            update_data["status"] = "completed"
            update_data["completed_at"] = datetime.utcnow()
        
        result = await db.ai_insights.update_one(
            {"_id": ObjectId(learning_path_id), "type": AIInsightType.LEARNING_PATH},
            {"$set": update_data}
        )
        
        # Update profile cache
        if result.modified_count > 0:
            learning_path = await db.ai_insights.find_one({"_id": ObjectId(learning_path_id)})
            if learning_path:
                await db.profile.update_one(
                    {"email": learning_path["email"]},
                    {
                        "$set": {
                            "learning_path_cache.progress": progress_percentage,
                            "learning_path_cache.status": learning_path.get("status", "active"),
                            "learning_path_updated_at": datetime.utcnow()
                        }
                    }
                )
        
        return {
            "modified": result.modified_count > 0,
            "progress": progress_percentage,
            "is_completed": progress_percentage >= 100
        }
    
    async def store_training_feedback(self, email: str, analysis_type: str, 
                                       feedback: Dict, helpful: bool) -> Dict:
        """Store user feedback for training data"""
        db = get_db()
        
        training_doc = AIInsightsModel(
            type=AIInsightType.TRAINING_DATA,
            email=email,
            data=feedback,
            feedback_score=feedback.get('score', 0.5),
            was_helpful=helpful,
            user_feedback=feedback
        )
        
        result = await db.ai_insights.insert_one(training_doc.model_dump(by_alias=True))
        
        return {
            "feedback_id": str(result.inserted_id),
            "stored": True,
            "message": "Feedback saved for training"
        }
    
    async def _cleanup_old_analyses(self, email: str):
        """Keep only recent analyses, mark older ones as archived"""
        db = get_db()
        
        # Count analyses for user
        count = await db.ai_insights.count_documents({
            "email": email,
            "type": AIInsightType.CAREER_ANALYSIS
        })
        
        if count > self.max_history_per_user:
            # Get oldest analyses beyond limit
            old_analyses = await db.ai_insights.find(
                {"email": email, "type": AIInsightType.CAREER_ANALYSIS}
            ).sort("created_at", 1).limit(count - self.max_history_per_user).to_list(100)
            
            for old in old_analyses:
                # Mark as archived (soft delete)
                await db.ai_insights.update_one(
                    {"_id": old["_id"]},
                    {"$set": {"is_archived": True, "is_current": False}}
                )
    
    async def archive_old_data(self, days_old: int = 90) -> Dict:
        """Archive data older than specified days"""
        db = get_db()
        cutoff_date = datetime.utcnow() - timedelta(days=days_old)
        
        # Mark old career analyses as archived
        result = await db.ai_insights.update_many(
            {
                "type": AIInsightType.CAREER_ANALYSIS,
                "created_at": {"$lt": cutoff_date},
                "is_archived": False
            },
            {"$set": {"is_archived": True, "is_current": False}}
        )
        
        archived_analyses = result.modified_count
        
        # Mark old completed learning paths as archived
        result2 = await db.ai_insights.update_many(
            {
                "type": AIInsightType.LEARNING_PATH,
                "status": "completed",
                "completed_at": {"$lt": cutoff_date},
                "is_archived": False
            },
            {"$set": {"is_archived": True}}
        )
        
        archived_paths = result2.modified_count
        
        return {
            "archived_analyses": archived_analyses,
            "archived_learning_paths": archived_paths,
            "cutoff_days": days_old,
            "message": f"Archived data older than {days_old} days"
        }
    
    async def get_storage_stats(self) -> Dict:
        """Get storage statistics for monitoring"""
        db = get_db()
        
        # Profile analytics
        profile_count = await db.profile.count_documents({})
        profiles_with_cache = await db.profile.count_documents({"career_cache": {"$exists": True}})
        
        # AI insights stats
        career_analyses_count = await db.ai_insights.count_documents({"type": AIInsightType.CAREER_ANALYSIS})
        career_analyses_archived = await db.ai_insights.count_documents({
            "type": AIInsightType.CAREER_ANALYSIS, 
            "is_archived": True
        })
        
        # Learning paths stats
        learning_paths_count = await db.ai_insights.count_documents({"type": AIInsightType.LEARNING_PATH})
        learning_paths_archived = await db.ai_insights.count_documents({
            "type": AIInsightType.LEARNING_PATH,
            "is_archived": True
        })
        
        # Training data stats
        training_data_count = await db.ai_insights.count_documents({"type": AIInsightType.TRAINING_DATA})
        
        # Sessions stats
        active_sessions = await db.sessions.count_documents({"is_active": True})
        archived_sessions = await db.sessions.count_documents({"is_archived": True})
        
        # Get sizes (approximate)
        stats = await db.command("dbStats")
        
        return {
            "collections": {
                "profile": {
                    "total_documents": profile_count,
                    "with_career_cache": profiles_with_cache,
                    "cache_percentage": round((profiles_with_cache / max(1, profile_count)) * 100, 2)
                },
                "ai_insights": {
                    "career_analyses": {
                        "active": career_analyses_count - career_analyses_archived,
                        "archived": career_analyses_archived,
                        "total": career_analyses_count
                    },
                    "learning_paths": {
                        "active": learning_paths_count - learning_paths_archived,
                        "archived": learning_paths_archived,
                        "total": learning_paths_count
                    },
                    "training_data": training_data_count
                },
                "sessions": {
                    "active": active_sessions,
                    "archived": archived_sessions,
                    "total": active_sessions + archived_sessions
                }
            },
            "database_size_mb": round(stats.get("dataSize", 0) / (1024 * 1024), 2),
            "index_size_mb": round(stats.get("indexSize", 0) / (1024 * 1024), 2),
            "total_size_mb": round((stats.get("dataSize", 0) + stats.get("indexSize", 0)) / (1024 * 1024), 2)
        }


# Global instance
career_data_manager = CareerDataManager()