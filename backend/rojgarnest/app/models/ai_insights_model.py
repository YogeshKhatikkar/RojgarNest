# app/models/ai_insights_model.py - COMPLETE FIXED VERSION
# ✅ NO TTL INDEXES - AI insights are PERMANENT

from pydantic import BaseModel, Field, EmailStr, model_validator
from typing import Dict, Any, Optional, List
from datetime import datetime
from enum import Enum
import hashlib
import json


class AIInsightType(str, Enum):
    CAREER_ANALYSIS = "career_analysis"
    LEARNING_PATH = "learning_path"
    TRAINING_DATA = "training_data"
    MARKET_INSIGHT = "market_insight"


class AIInsightsModel(BaseModel):
    """
    Single collection for ALL AI-generated insights.
    ✅ NO TTL - Data is PERMANENT
    """

    # Identification
    type: AIInsightType
    email: EmailStr
    user_id: Optional[str] = None

    # Main data
    data: Dict[str, Any]

    # Metadata
    version: int = 1
    is_current: bool = True
    is_archived: bool = False

    # Career analysis specific
    analysis_hash: Optional[str] = None
    analysis_duration_ms: Optional[int] = None
    ai_model_used: str = "gpt-4o-mini"

    # Learning path specific
    progress_percentage: Optional[float] = Field(None, ge=0, le=100)
    status: Optional[str] = Field(
        None,
        pattern="^(active|completed|abandoned|archived)$"
    )
    career_path_id: Optional[str] = None
    milestones: List[Dict[str, Any]] = []
    completed_milestones: List[str] = []
    total_duration_weeks: int = 0
    skills_to_learn: int = 0
    resources_count: int = 0
    engagement_score: float = 0

    # Training data specific
    feedback_score: Optional[float] = Field(None, ge=0, le=1)
    was_helpful: Optional[bool] = None
    user_feedback: Optional[Dict[str, Any]] = None

    # Timestamps
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    last_accessed: datetime = Field(default_factory=datetime.utcnow)
    # ✅ For reference only - NOT a TTL index
    expires_at: Optional[datetime] = None

    @model_validator(mode='after')
    def set_hash(self):
        """Generate hash for career analysis"""
        if self.analysis_hash is None and self.type == AIInsightType.CAREER_ANALYSIS:
            hash_str = json.dumps(self.data, sort_keys=True, default=str)
            self.analysis_hash = hashlib.sha256(hash_str.encode()).hexdigest()
        return self

    model_config = {
        "collection": "ai_insights",
        "json_encoders": {datetime: lambda v: v.isoformat()},
        "indexes": [
            ("email", None),
            ("type", None),
            ("is_current", None),
            ("analysis_hash", {"unique": True, "sparse": True}),
            # ❌ NO TTL - expires_at is NOT indexed with expireAfterSeconds
            [("email", 1), ("type", 1), ("is_current", 1)],
            [("type", 1), ("status", 1), ("progress_percentage", -1)]
        ]
    }


print("✅ AI Insights Model Loaded - NO TTL")