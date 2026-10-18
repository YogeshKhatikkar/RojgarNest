# app/modules/resume/service.py - COMPLETE VERSION

from fastapi import HTTPException, UploadFile
from typing import Dict, Any, List, Optional
from datetime import datetime
from bson import ObjectId
import logging
import json
import base64
import hashlib
import secrets

from app.core.services.cloudinary import upload_to_cloudinary, upload_user_document
from app.modules.resume.AI import ResumeParserAI, ATSOptimizerAI
from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class ResumeService:
    """Complete Resume Service with Profile Resume View"""
    
    def __init__(self, db):
        self.db = db
        self.resumes = db.resumes
        self.profiles = db.profile
        self.auth = db.auth
        self.applications = db.applications
        self.jobs = db.job
        self.parser = ResumeParserAI()
        self.ats_optimizer = ATSOptimizerAI()
    
    # ==================== PROFILE RESUME VIEW (MAIN) ====================
    
    async def get_profile_resume(self, email: str) -> Dict[str, Any]:
        """
        Get complete user profile in resume format
        Returns ALL user information organized as a resume
        """
        # Get user from auth
        auth_user = await self.auth.find_one({"email": email})
        if not auth_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get profile
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            profile = self._get_empty_profile(email)
        
        # Build complete resume data
        resume = {
            "success": True,
            "generated_at": datetime.utcnow().isoformat(),
            "user_info": self._get_user_info(auth_user, profile),
            "contact_info": self._get_contact_info(auth_user, profile),
            "professional_summary": self._get_professional_summary(profile),
            "career_objective": self._get_career_objective(profile),
            "education": self._get_education(profile),
            "experience": self._get_experience(profile),
            "internships": self._get_internships(profile),
            "skills": self._get_skills(profile),
            "certifications": self._get_certifications(profile),
            "projects": self._get_projects(profile),
            "languages": self._get_languages(profile),
            "achievements": self._get_achievements(profile),
            "social_links": self._get_social_links(profile),
            "additional_info": self._get_additional_info(profile),
            "resume_url": profile.get("resume_url"),
            "statistics": self._get_resume_statistics(auth_user, profile)
        }
        
        return resume
    
    def _get_empty_profile(self, email: str) -> Dict[str, Any]:
        """Return empty profile structure"""
        return {
            "email": email,
            "full_name": "",
            "first_name": "",
            "last_name": "",
            "phone": "",
            "dob": "",
            "gender": "",
            "category": "General/UR",
            "disability": {"is_disabled": False},
            "address": {},
            "current_address": {},
            "summary": "",
            "career_objective": "",
            "academic_records": [],
            "experience": [],
            "internships": [],
            "skills": [],
            "certifications": [],
            "projects": [],
            "languages_known": [],
            "languages": [],
            "social_links": {},
            "additional_details": {}
        }
    
    def _get_user_info(self, auth_user: Dict, profile: Dict) -> Dict[str, Any]:
        """Get user personal information"""
        full_name = profile.get("full_name") or auth_user.get("name", "")
        first_name = profile.get("first_name") or (full_name.split()[0] if full_name else "")
        last_name = profile.get("last_name") or (full_name.split()[-1] if len(full_name.split()) > 1 else "")
        
        # Calculate age from DOB
        age = None
        dob = profile.get("dob")
        if dob:
            try:
                birth = datetime.strptime(dob, "%Y-%m-%d")
                today = datetime.now()
                age = today.year - birth.year
                if today.month < birth.month or (today.month == birth.month and today.day < birth.day):
                    age -= 1
            except:
                pass
        
        return {
            "full_name": full_name,
            "first_name": first_name,
            "last_name": last_name,
            "email": auth_user.get("email", ""),
            "phone": profile.get("phone") or auth_user.get("mobile", ""),
            "date_of_birth": dob,
            "age": age,
            "gender": profile.get("gender", "Not specified"),
            "nationality": profile.get("nationality", "Indian"),
            "category": profile.get("category", "General/UR"),
            "religion": profile.get("religion", ""),
            "blood_group": profile.get("blood_group", ""),
            "marital_status": profile.get("marital_status", ""),
            "disability": self._get_disability_info(profile)
        }
    
    def _get_disability_info(self, profile: Dict) -> Dict[str, Any]:
        """Get disability information from nested object"""
        disability = profile.get("disability", {})
        if isinstance(disability, dict):
            return {
                "is_disabled": disability.get("is_disabled", False),
                "category": disability.get("disability_category", ""),
                "percentage": disability.get("disability_percentage"),
                "details": disability.get("disability_details", "")
            }
        return {"is_disabled": False}
    
    def _get_contact_info(self, auth_user: Dict, profile: Dict) -> Dict[str, Any]:
        """Get contact information"""
        current_address = profile.get("current_address", {})
        
        # Format full address
        address_parts = []
        if current_address.get("village_name"):
            address_parts.append(current_address["village_name"])
        if current_address.get("post_office"):
            address_parts.append(current_address["post_office"])
        if current_address.get("tehsil"):
            address_parts.append(current_address["tehsil"])
        if current_address.get("district"):
            address_parts.append(current_address["district"])
        if current_address.get("state"):
            address_parts.append(current_address["state"])
        if current_address.get("pincode"):
            address_parts.append(current_address["pincode"])
        
        emergency = profile.get("emergency_contact", {})
        
        return {
            "email": auth_user.get("email", ""),
            "phone": profile.get("phone") or auth_user.get("mobile", ""),
            "alternate_mobile": profile.get("alternate_mobile", ""),
            "whatsapp_number": profile.get("whatsapp_number", ""),
            "current_address": {
                "house_number": current_address.get("house_number", ""),
                "village_name": current_address.get("village_name", ""),
                "post_office": current_address.get("post_office", ""),
                "tehsil": current_address.get("tehsil", ""),
                "district": current_address.get("district", ""),
                "state": current_address.get("state", ""),
                "pincode": current_address.get("pincode", ""),
                "landmark": current_address.get("landmark", ""),
                "country": current_address.get("country", "India"),
                "full_address": ", ".join(filter(None, address_parts))
            },
            "emergency_contact": {
                "name": emergency.get("name", ""),
                "relationship": emergency.get("relationship", ""),
                "phone": emergency.get("phone", "")
            }
        }
    
    def _get_professional_summary(self, profile: Dict) -> str:
        """Get professional summary"""
        summary = profile.get("summary", "")
        if not summary:
            # Generate default summary based on profile
            name = profile.get("full_name", "Professional")
            skills_count = len(profile.get("skills", []))
            exp_count = len(profile.get("experience", []))
            edu_count = len(profile.get("academic_records", []))
            
            if exp_count > 0:
                summary = f"{name} is a dedicated professional with {exp_count} years of experience. "
            elif skills_count > 0:
                summary = f"{name} is a motivated professional skilled in multiple areas. "
            else:
                summary = f"{name} is an enthusiastic professional looking for opportunities to grow and contribute. "
            
            if edu_count > 0:
                summary += "Possesses strong educational background. "
            if skills_count > 0:
                summary += f"Proficient in various skills including {', '.join([s.get('name', '') for s in profile.get('skills', [])[:5]])}. "
        
        return summary
    
    def _get_career_objective(self, profile: Dict) -> str:
        """Get career objective"""
        objective = profile.get("career_objective", "")
        if not objective:
            name = profile.get("full_name", "I")
            objective = f"{name} am seeking a challenging position where I can utilize my skills and contribute to organizational growth while continuously learning and developing professionally."
        return objective
    
    def _get_education(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get education records in reverse chronological order"""
        education = profile.get("academic_records", [])
        
        # Sort by year (descending)
        education.sort(key=lambda x: x.get("year_of_passing", 0), reverse=True)
        
        formatted_education = []
        for edu in education:
            formatted_edu = {
                "id": edu.get("_id"),
                "level": edu.get("level", ""),
                "degree": edu.get("degree", ""),
                "stream": edu.get("stream", ""),
                "institute": edu.get("institute", ""),
                "board_university": edu.get("board_university", ""),
                "year_of_passing": edu.get("year_of_passing"),
                "result_type": edu.get("result_type", "Percentage"),
                "result": edu.get("cgpa_percentage"),
                "grade": edu.get("grade", ""),
                "medium": edu.get("medium", ""),
                "subjects": edu.get("subjects", []),
                "backlogs": edu.get("backlogs", 0)
            }
            
            # Format result display
            if formatted_edu["result"]:
                if formatted_edu["result_type"] == "Percentage":
                    formatted_edu["result_display"] = f"{formatted_edu['result']}%"
                elif formatted_edu["result_type"] == "CGPA":
                    formatted_edu["result_display"] = f"{formatted_edu['result']} CGPA"
                else:
                    formatted_edu["result_display"] = str(formatted_edu["result"])
            elif formatted_edu["grade"]:
                formatted_edu["result_display"] = formatted_edu["grade"]
            else:
                formatted_edu["result_display"] = "Completed"
            
            formatted_education.append(formatted_edu)
        
        return formatted_education
    
    def _get_experience(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get work experience in reverse chronological order"""
        experience = profile.get("experience", [])
        
        # Sort by start date (descending)
        experience.sort(key=lambda x: x.get("start_date", ""), reverse=True)
        
        formatted_exp = []
        for exp in experience:
            # Calculate duration
            duration = self._calculate_duration(
                exp.get("start_date"), 
                exp.get("end_date")
            )
            
            formatted_exp.append({
                "id": exp.get("_id"),
                "company": exp.get("company", ""),
                "role": exp.get("role", ""),
                "industry_type": exp.get("industry_type", ""),
                "employment_type": exp.get("employment_type", "Full-time"),
                "location": exp.get("location", ""),
                "start_date": exp.get("start_date", ""),
                "end_date": exp.get("end_date", "Present"),
                "is_current": exp.get("end_date") is None or exp.get("end_date") == "",
                "duration": duration,
                "description": exp.get("description", ""),
                "achievements": exp.get("achievements", []),
                "skills_used": exp.get("skills_used", []),
                "salary": exp.get("salary"),
                "reporting_manager": exp.get("reporting_manager", ""),
                "team_size": exp.get("team_size")
            })
        
        return formatted_exp
    
    def _get_internships(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get internships"""
        internships = profile.get("internships", [])
        
        formatted_internships = []
        for intern in internships:
            duration = self._calculate_duration(
                intern.get("start_date"), 
                intern.get("end_date")
            )
            
            formatted_internships.append({
                "id": intern.get("_id"),
                "company": intern.get("company", ""),
                "role": intern.get("role", ""),
                "start_date": intern.get("start_date", ""),
                "end_date": intern.get("end_date", "Present"),
                "is_current": intern.get("end_date") is None or intern.get("end_date") == "",
                "duration": duration,
                "description": intern.get("description", ""),
                "stipend": intern.get("stipend"),
                "technologies": intern.get("technologies", [])
            })
        
        return formatted_internships
    
    def _get_skills(self, profile: Dict) -> Dict[str, Any]:
        """Get skills categorized by level"""
        skills = profile.get("skills", [])
        
        categorized = {
            "expert": [],
            "advanced": [],
            "intermediate": [],
            "beginner": [],
            "all": [],
            "count": len(skills)
        }
        
        for skill in skills:
            skill_name = skill.get("name", "")
            level = skill.get("level", "beginner").lower()
            skill_data = {
                "name": skill_name,
                "level": level,
                "years_of_experience": skill.get("years_of_experience"),
                "importance": skill.get("importance")
            }
            
            categorized["all"].append(skill_data)
            
            if level == "expert":
                categorized["expert"].append(skill_data)
            elif level == "advanced":
                categorized["advanced"].append(skill_data)
            elif level == "intermediate":
                categorized["intermediate"].append(skill_data)
            else:
                categorized["beginner"].append(skill_data)
        
        return categorized
    
    def _get_certifications(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get certifications"""
        certifications = profile.get("certifications", [])
        
        formatted_certs = []
        for cert in certifications:
            formatted_certs.append({
                "id": cert.get("_id"),
                "name": cert.get("name", ""),
                "issuer": cert.get("issuer", ""),
                "year": cert.get("year"),
                "url": cert.get("url", ""),
                "credential_id": cert.get("credential_id", ""),
                "expiry_date": cert.get("expiry_date")
            })
        
        return formatted_certs
    
    def _get_projects(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get projects"""
        projects = profile.get("projects", [])
        
        formatted_projects = []
        for project in projects:
            formatted_projects.append({
                "id": project.get("_id"),
                "title": project.get("title", ""),
                "description": project.get("description", ""),
                "technologies": project.get("technologies", []),
                "url": project.get("url", ""),
                "github_url": project.get("github_url", ""),
                "start_date": project.get("start_date", ""),
                "end_date": project.get("end_date", ""),
                "is_live": project.get("is_live", False)
            })
        
        return formatted_projects
    
    def _get_languages(self, profile: Dict) -> List[Dict[str, Any]]:
        """Get languages known"""
        languages_known = profile.get("languages_known", [])
        languages = profile.get("languages", [])
        
        formatted_languages = []
        
        # Add from languages_known (simple list)
        for lang in languages_known:
            if isinstance(lang, str) and lang:
                formatted_languages.append({
                    "name": lang,
                    "proficiency": "Professional"
                })
        
        # Add from languages (structured)
        for lang in languages:
            if isinstance(lang, dict):
                formatted_languages.append({
                    "name": lang.get("name", ""),
                    "proficiency": lang.get("proficiency", "Professional"),
                    "can_read": lang.get("can_read", True),
                    "can_write": lang.get("can_write", True),
                    "can_speak": lang.get("can_speak", True)
                })
            elif isinstance(lang, str) and lang:
                formatted_languages.append({
                    "name": lang,
                    "proficiency": "Professional"
                })
        
        return formatted_languages
    
    def _get_achievements(self, profile: Dict) -> List[str]:
        """Get achievements from various sections"""
        achievements = []
        
        # Add from experience achievements
        for exp in profile.get("experience", []):
            achievements.extend(exp.get("achievements", []))
        
        # Add from other achievements if present
        achievements.extend(profile.get("achievements", []))
        
        return achievements[:20]  # Limit to 20
    
    def _get_social_links(self, profile: Dict) -> Dict[str, str]:
        """Get social and professional links"""
        social = profile.get("social_links", {})
        additional = profile.get("additional_details", {})
        
        return {
            "linkedin": social.get("linkedin") or additional.get("linkedin_url", ""),
            "github": social.get("github") or additional.get("github_url", ""),
            "portfolio": social.get("portfolio") or additional.get("portfolio_url", ""),
            "twitter": social.get("twitter", ""),
            "personal_website": social.get("personal_website", "")
        }
    
    def _get_additional_info(self, profile: Dict) -> Dict[str, Any]:
        """Get additional information"""
        return {
            "is_fresher": profile.get("is_fresher", True),
            "is_educated": profile.get("is_educated", True),
            "open_to_relocate": profile.get("open_to_relocate", False),
            "open_to_remote_work": profile.get("open_to_remote_work", False),
            "preferred_job_types": profile.get("preferred_job_types", []),
            "preferred_industries": profile.get("preferred_industries", []),
            "preferred_locations": profile.get("preferred_locations", []),
            "expected_salary_min": profile.get("expected_salary_min"),
            "expected_salary_max": profile.get("expected_salary_max"),
            "notice_period_days": profile.get("notice_period_days"),
            "can_join_immediately": profile.get("can_join_immediately", False),
            "career_goals": profile.get("career_goals", []),
            "domain_interests": profile.get("domain_interests", [])
        }
    
    def _get_resume_statistics(self, auth_user: Dict, profile: Dict) -> Dict[str, Any]:
        """Get resume statistics"""
        exp_years = 0
        for exp in profile.get("experience", []):
            try:
                start = exp.get("start_date", "")
                if start:
                    exp_years += 1
            except:
                pass
        
        return {
            "total_experience_years": exp_years,
            "total_skills": len(profile.get("skills", [])),
            "total_education": len(profile.get("academic_records", [])),
            "total_projects": len(profile.get("projects", [])),
            "total_certifications": len(profile.get("certifications", [])),
            "profile_completion": self._calculate_completion(profile),
            "member_since": auth_user.get("created_at").isoformat() if auth_user.get("created_at") else None
        }
    
    def _calculate_duration(self, start_date: Optional[str], end_date: Optional[str]) -> str:
        """Calculate duration between dates"""
        if not start_date:
            return "N/A"
        
        try:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            end = datetime.now() if not end_date or end_date == "" else datetime.strptime(end_date, "%Y-%m-%d")
            
            years = end.year - start.year
            months = end.month - start.month
            
            if months < 0:
                years -= 1
                months += 12
            
            if years > 0:
                return f"{years} yr{'s' if years > 1 else ''} {months} mon{'s' if months > 1 else ''}" if months > 0 else f"{years} yr{'s' if years > 1 else ''}"
            elif months > 0:
                return f"{months} month{'s' if months > 1 else ''}"
            else:
                days = end.day - start.day
                return f"{days} day{'s' if days > 1 else ''}" if days > 0 else "Less than a month"
        except:
            return "N/A"
    
    def _calculate_completion(self, profile: Dict) -> int:
        """Calculate profile completion percentage"""
        completion = 0
        
        # Personal info (20%)
        if profile.get("full_name"):
            completion += 5
        if profile.get("email"):
            completion += 5
        if profile.get("phone"):
            completion += 5
        if profile.get("dob"):
            completion += 5
        
        # Education (20%)
        edu_count = len(profile.get("academic_records", []))
        completion += min(20, edu_count * 10)
        
        # Experience (20%)
        exp_count = len(profile.get("experience", []))
        completion += min(20, exp_count * 10)
        
        # Skills (20%)
        skill_count = len(profile.get("skills", []))
        completion += min(20, skill_count * 4)
        
        # Projects & Certifications (20%)
        project_count = len(profile.get("projects", []))
        cert_count = len(profile.get("certifications", []))
        completion += min(20, (project_count * 5) + (cert_count * 5))
        
        return min(100, completion)
    
    # ==================== RESUME HTML GENERATION ====================
    
    async def generate_resume_html(self, email: str, resume_data: Dict) -> str:
        """Generate HTML version of resume"""
        user = resume_data.get("user_info", {})
        contact = resume_data.get("contact_info", {})
        summary = resume_data.get("professional_summary", "")
        objective = resume_data.get("career_objective", "")
        education = resume_data.get("education", [])
        experience = resume_data.get("experience", [])
        skills = resume_data.get("skills", {})
        certifications = resume_data.get("certifications", [])
        projects = resume_data.get("projects", [])
        languages = resume_data.get("languages", [])
        social = resume_data.get("social_links", {})
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>{user.get('full_name', 'Resume')} - RojgarNest Resume</title>
            <style>
                * {{
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }}
                body {{
                    font-family: 'Segoe UI', 'Poppins', 'Roboto', Arial, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    padding: 40px 20px;
                    line-height: 1.6;
                }}
                .resume-container {{
                    max-width: 1100px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 20px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    overflow: hidden;
                }}
                .header {{
                    background: linear-gradient(135deg, #1E3A8A 0%, #3B82F6 100%);
                    color: white;
                    padding: 40px;
                    text-align: center;
                }}
                .header h1 {{
                    font-size: 36px;
                    margin-bottom: 10px;
                    letter-spacing: 1px;
                }}
                .header-title {{
                    font-size: 18px;
                    opacity: 0.9;
                    margin-bottom: 20px;
                }}
                .contact-bar {{
                    display: flex;
                    justify-content: center;
                    flex-wrap: wrap;
                    gap: 20px;
                    margin-top: 20px;
                    font-size: 14px;
                }}
                .contact-bar span {{
                    display: inline-flex;
                    align-items: center;
                    gap: 8px;
                }}
                .main-content {{
                    display: flex;
                    flex-wrap: wrap;
                }}
                .sidebar {{
                    flex: 1;
                    min-width: 280px;
                    background: #f8fafc;
                    padding: 30px;
                    border-right: 1px solid #e2e8f0;
                }}
                .main {{
                    flex: 2;
                    min-width: 300px;
                    padding: 30px;
                }}
                .section {{
                    margin-bottom: 25px;
                }}
                .section-title {{
                    font-size: 18px;
                    font-weight: bold;
                    color: #1E3A8A;
                    border-left: 4px solid #3B82F6;
                    padding-left: 12px;
                    margin-bottom: 15px;
                }}
                .skill-tag {{
                    display: inline-block;
                    background: #e0e7ff;
                    color: #1E3A8A;
                    padding: 5px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    margin: 3px;
                }}
                .experience-item, .education-item, .project-item, .cert-item {{
                    margin-bottom: 20px;
                }}
                .item-title {{
                    font-weight: bold;
                    font-size: 16px;
                    color: #1e293b;
                }}
                .item-subtitle {{
                    color: #64748b;
                    font-size: 13px;
                    margin: 5px 0;
                }}
                .item-date {{
                    color: #3B82F6;
                    font-size: 12px;
                    font-weight: 500;
                }}
                .item-description {{
                    font-size: 14px;
                    color: #334155;
                    margin-top: 8px;
                }}
                .achievement-list {{
                    padding-left: 20px;
                    margin-top: 8px;
                }}
                .achievement-list li {{
                    font-size: 13px;
                    margin-bottom: 4px;
                }}
                .divider {{
                    height: 1px;
                    background: #e2e8f0;
                    margin: 15px 0;
                }}
                @media print {{
                    body {{
                        background: white;
                        padding: 0;
                    }}
                    .resume-container {{
                        box-shadow: none;
                        border-radius: 0;
                    }}
                }}
            </style>
        </head>
        <body>
            <div class="resume-container">
                <div class="header">
                    <h1>{user.get('full_name', 'Professional Resume')}</h1>
                    <div class="contact-bar">
                        <span>📧 {contact.get('email', '')}</span>
                        <span>📞 {contact.get('phone', '')}</span>
                        <span>📍 {contact.get('current_address', {}).get('city', 'India')}</span>
                    </div>
                </div>
                <div class="main-content">
                    <div class="sidebar">
                        <div class="section">
                            <div class="section-title">Contact</div>
                            <p>📧 {contact.get('email', '')}</p>
                            <p>📞 {contact.get('phone', '')}</p>
                            <p>📱 {contact.get('alternate_mobile', '')}</p>
                            <p>📍 {contact.get('current_address', {}).get('full_address', 'India')}</p>
                        </div>
        """
        
        # Skills section
        if skills.get("all"):
            html += """
                        <div class="section">
                            <div class="section-title">Skills</div>
            """
            for skill in skills.get("expert", [])[:5]:
                html += f'                            <span class="skill-tag">⭐ {skill.get("name", "")} (Expert)</span>\n'
            for skill in skills.get("advanced", [])[:5]:
                html += f'                            <span class="skill-tag">🔷 {skill.get("name", "")} (Advanced)</span>\n'
            for skill in skills.get("intermediate", [])[:5]:
                html += f'                            <span class="skill-tag">📌 {skill.get("name", "")} (Intermediate)</span>\n'
            html += '                        </div>\n'
        
        # Languages section
        if languages:
            html += """
                        <div class="section">
                            <div class="section-title">Languages</div>
            """
            for lang in languages:
                html += f'                            <p>• {lang.get("name", "")} - {lang.get("proficiency", "Professional")}</p>\n'
            html += '                        </div>\n'
        
        # Certifications section
        if certifications:
            html += """
                        <div class="section">
                            <div class="section-title">Certifications</div>
            """
            for cert in certifications[:5]:
                html += f'                            <p>• {cert.get("name", "")} - {cert.get("issuer", "")} ({cert.get("year", "")})</p>\n'
            html += '                        </div>\n'
        
        # Social Links
        if social.get("linkedin") or social.get("github") or social.get("portfolio"):
            html += """
                        <div class="section">
                            <div class="section-title">Profiles</div>
            """
            if social.get("linkedin"):
                html += f'                            <p>🔗 LinkedIn: {social.get("linkedin", "")}</p>\n'
            if social.get("github"):
                html += f'                            <p>💻 GitHub: {social.get("github", "")}</p>\n'
            if social.get("portfolio"):
                html += f'                            <p>🌐 Portfolio: {social.get("portfolio", "")}</p>\n'
            html += '                        </div>\n'
        
        html += """
                    </div>
                    <div class="main">
        """
        
        # Professional Summary
        if summary:
            html += f"""
                        <div class="section">
                            <div class="section-title">Professional Summary</div>
                            <p>{summary}</p>
                        </div>
            """
        
        # Career Objective
        if objective:
            html += f"""
                        <div class="section">
                            <div class="section-title">Career Objective</div>
                            <p>{objective}</p>
                        </div>
            """
        
        # Experience Section
        if experience:
            html += """
                        <div class="section">
                            <div class="section-title">Work Experience</div>
            """
            for exp in experience[:5]:
                html += f"""
                            <div class="experience-item">
                                <div class="item-title">{exp.get('role', 'Position')}</div>
                                <div class="item-subtitle">{exp.get('company', 'Company')}</div>
                                <div class="item-date">{exp.get('start_date', '')} - {exp.get('end_date', 'Present')} | {exp.get('duration', '')}</div>
                                <div class="item-description">{exp.get('description', '')[:200]}</div>
                """
                if exp.get('achievements'):
                    html += '                                <ul class="achievement-list">\n'
                    for ach in exp.get('achievements', [])[:3]:
                        html += f'                                    <li>✓ {ach}</li>\n'
                    html += '                                </ul>\n'
                html += '                            </div>\n'
            html += '                        </div>\n'
        
        # Education Section
        if education:
            html += """
                        <div class="section">
                            <div class="section-title">Education</div>
            """
            for edu in education[:4]:
                html += f"""
                            <div class="education-item">
                                <div class="item-title">{edu.get('degree', edu.get('level', 'Education'))}</div>
                                <div class="item-subtitle">{edu.get('institute', 'Institute')}</div>
                                <div class="item-date">{edu.get('year_of_passing', '')} | {edu.get('result_display', 'Completed')}</div>
                            </div>
                """
            html += '                        </div>\n'
        
        # Projects Section
        if projects:
            html += """
                        <div class="section">
                            <div class="section-title">Projects</div>
            """
            for proj in projects[:4]:
                html += f"""
                            <div class="project-item">
                                <div class="item-title">{proj.get('title', 'Project')}</div>
                                <div class="item-date">Tech: {', '.join(proj.get('technologies', [])[:3])}</div>
                                <div class="item-description">{proj.get('description', '')[:150]}</div>
                            </div>
                """
            html += '                        </div>\n'
        
        html += """
                    </div>
                </div>
                <div class="divider"></div>
                <div style="text-align: center; padding: 20px; background: #f8fafc; font-size: 12px; color: #64748b;">
                    Resume generated by RojgarNest • AI-Powered Career Platform
                </div>
            </div>
        </body>
        </html>
        """
        
        return html
    
    async def generate_resume_pdf(self, email: str) -> Dict:
        """Generate resume as PDF"""
        # Get resume data
        resume_data = await self.get_profile_resume(email)
        
        # Generate HTML
        html_content = await self.generate_resume_html(email, resume_data)
        
        # In production, use a PDF generation library like weasyprint or reportlab
        # For now, return HTML that can be printed to PDF via browser
        return {
            "success": True,
            "html": html_content,
            "message": "HTML resume generated. Use browser 'Print to PDF' to save as PDF.",
            "print_hint": "Press Ctrl+P (or Cmd+P on Mac) and select 'Save as PDF'"
        }
    
    async def generate_shareable_link(self, email: str) -> Dict:
        """Generate shareable link for resume"""
        # Create a unique token
        token = hashlib.sha256(f"{email}{secrets.token_hex(16)}".encode()).hexdigest()[:32]
        
        # Store in database
        await self.db.shareable_resumes.update_one(
            {"email": email},
            {
                "$set": {
                    "share_token": token,
                    "created_at": datetime.utcnow(),
                    "expires_at": datetime.utcnow().replace(year=datetime.utcnow().year + 1),
                    "view_count": 0
                }
            },
            upsert=True
        )
        
        share_url = f"{settings.APP_BASE_URL}/share/resume/{token}"
        
        return {
            "success": True,
            "share_url": share_url,
            "token": token,
            "expires_in": "1 year",
            "message": "Shareable link generated successfully"
        }
    
    # ==================== RESUME RECORD MANAGEMENT ====================
    
    async def save_resume_record(self, email: str, resume_data: Dict) -> Dict:
        """Save resume record to database"""
        resume_doc = {
            "user_email": email,
            "filename": resume_data.get("filename"),
            "file_url": resume_data.get("file_url"),
            "file_public_id": resume_data.get("file_public_id"),
            "file_size_kb": resume_data.get("file_size_kb", 0),
            "file_type": resume_data.get("file_type", "pdf"),
            "is_primary": resume_data.get("is_primary", False),
            "uploaded_at": resume_data.get("uploaded_at", datetime.utcnow()),
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        result = await self.resumes.insert_one(resume_doc)
        return {"resume_id": str(result.inserted_id), "success": True}
    
    async def get_user_resumes(self, email: str) -> Dict:
        """Get all resumes for a user"""
        resumes = await self.resumes.find({"user_email": email}).sort("uploaded_at", -1).to_list(50)
        
        for resume in resumes:
            resume["_id"] = str(resume["_id"])
        
        return {"resumes": resumes, "total": len(resumes)}
    
    async def get_primary_resume(self, email: str) -> Dict:
        """Get user's primary resume"""
        resume = await self.resumes.find_one({"user_email": email, "is_primary": True})
        
        if not resume:
            # Get the most recent resume
            resume = await self.resumes.find_one({"user_email": email}, sort=[("uploaded_at", -1)])
        
        if resume:
            resume["_id"] = str(resume["_id"])
            return {"success": True, "resume": resume}
        
        return {"success": False, "message": "No resume found"}
    
    async def set_primary_resume(self, email: str, resume_id: str) -> Dict:
        """Set a resume as primary"""
        if not ObjectId.is_valid(resume_id):
            raise HTTPException(status_code=400, detail="Invalid resume ID")
        
        # Remove primary flag from all user's resumes
        await self.resumes.update_many(
            {"user_email": email},
            {"$set": {"is_primary": False}}
        )
        
        # Set this resume as primary
        result = await self.resumes.update_one(
            {"_id": ObjectId(resume_id), "user_email": email},
            {"$set": {"is_primary": True}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Resume not found")
        
        return {"message": "Primary resume updated successfully"}
    
    async def delete_resume(self, email: str, resume_id: str) -> Dict:
        """Delete a resume"""
        if not ObjectId.is_valid(resume_id):
            raise HTTPException(status_code=400, detail="Invalid resume ID")
        
        result = await self.resumes.delete_one({"_id": ObjectId(resume_id), "user_email": email})
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Resume not found")
        
        # If deleted resume was primary, make another resume primary
        remaining = await self.resumes.find_one({"user_email": email})
        if remaining:
            await self.resumes.update_one(
                {"_id": remaining["_id"]},
                {"$set": {"is_primary": True}}
            )
        
        return {"message": "Resume deleted successfully"}
    
    async def get_resume_preview(self, email: str) -> Dict:
        """Get resume preview data for frontend"""
        resume = await self.get_profile_resume(email)
        
        # Extract preview data
        preview = {
            "full_name": resume.get("user_info", {}).get("full_name", ""),
            "email": resume.get("contact_info", {}).get("email", ""),
            "phone": resume.get("contact_info", {}).get("phone", ""),
            "skills_count": resume.get("skills", {}).get("count", 0),
            "experience_count": len(resume.get("experience", [])),
            "education_count": len(resume.get("education", [])),
            "profile_completion": resume.get("statistics", {}).get("profile_completion", 0),
            "has_resume_file": bool(resume.get("resume_url")),
            "last_updated": resume.get("generated_at")
        }
        
        return {"success": True, "preview": preview}
    
    # ==================== AI FEATURES ====================
    
    async def upload_and_parse_resume(self, email: str, file: UploadFile) -> Dict:
        """Upload resume and auto-parse with AI"""
        try:
            allowed_types = ['application/pdf', 'application/msword', 
                            'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
            if file.content_type not in allowed_types:
                raise HTTPException(status_code=400, detail="Only PDF and DOC files are supported")
            
            upload_result = await upload_to_cloudinary(file, folder="resumes")
            
            parsed_data = await self.parser.parse_resume_content(file)
            
            resume_doc = {
                "user_email": email,
                "filename": file.filename,
                "file_url": upload_result.get("url", ""),
                "file_size_kb": upload_result.get("size_kb", 0),
                "parsed_data": parsed_data,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
                "is_primary": False,
                "ats_score": parsed_data.get('ats_score', 50)
            }
            
            result = await self.resumes.insert_one(resume_doc)
            resume_id = str(result.inserted_id)
            
            count = await self.resumes.count_documents({"user_email": email})
            if count == 1:
                await self.resumes.update_one(
                    {"_id": result.inserted_id},
                    {"$set": {"is_primary": True}}
                )
            
            return {
                "resume_id": resume_id,
                "filename": file.filename,
                "parsed_data": parsed_data,
                "ats_score": parsed_data.get('ats_score', 50),
                "message": "Resume uploaded and parsed successfully"
            }
        except Exception as e:
            logger.error(f"Upload failed: {e}")
            raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
    
    async def parse_resume_with_ai(self, email: str, resume_id: str) -> Dict:
        """Parse existing resume with AI"""
        try:
            if not ObjectId.is_valid(resume_id):
                raise HTTPException(status_code=400, detail="Invalid resume ID")
            
            resume = await self.resumes.find_one({"_id": ObjectId(resume_id), "user_email": email})
            if not resume:
                raise HTTPException(status_code=404, detail="Resume not found")
            
            return {
                "resume_id": resume_id,
                "parsed_data": resume.get("parsed_data", {}),
                "ats_score": resume.get("ats_score", 0),
                "filename": resume.get("filename")
            }
        except Exception as e:
            logger.error(f"Parse failed: {e}")
            raise HTTPException(status_code=500, detail=f"Parse failed: {str(e)}")
    
    async def get_ats_optimization(self, email: str, job_id: str) -> Dict:
        """Get ATS optimization suggestions"""
        try:
            resume = await self.resumes.find_one({"user_email": email, "is_primary": True})
            if not resume:
                resume = await self.resumes.find_one({"user_email": email}, sort=[("created_at", -1)])
            
            if not resume:
                raise HTTPException(status_code=404, detail="No resume found. Please upload a resume first.")
            
            if not ObjectId.is_valid(job_id):
                raise HTTPException(status_code=400, detail="Invalid job ID")
            
            job = await self.jobs.find_one({"_id": ObjectId(job_id)})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            
            optimization = await self.ats_optimizer.optimize_for_ats(
                resume.get("parsed_data", {}),
                job
            )
            
            return {
                "current_ats_score": resume.get("ats_score", 50),
                "optimization_suggestions": optimization,
                "job_title": job.get("post_name"),
                "match_percentage": optimization.get("match_percentage", 0),
                "suggestions": optimization.get("recommendations", [])
            }
        except Exception as e:
            logger.error(f"ATS optimization failed: {e}")
            raise HTTPException(status_code=500, detail=f"Optimization failed: {str(e)}")


print("✅ Resume Service Loaded - Complete Profile Resume View Available")