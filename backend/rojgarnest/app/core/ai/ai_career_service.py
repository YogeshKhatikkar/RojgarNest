# app/core/ai_career_service.py
import json
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from openai import AsyncOpenAI
from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class AICareerService:
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None

    async def analyze_user_profile(self, profile: Dict[str, Any]) -> Dict[str, Any]:
        """Complete AI analysis of user profile with career guidance"""
        if not self.client:
            return self._get_fallback_analysis(profile)

        try:
            prompt = self._build_analysis_prompt(profile)
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": """You are an expert career counselor and AI career advisor. 
                    Analyze the user profile and provide comprehensive career guidance. Return ONLY valid JSON."""},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=2500
            )
            
            result = json.loads(response.choices[0].message.content.strip())
            return self._enrich_analysis(result, profile)
            
        except Exception as e:
            logger.error(f"AI Career Analysis failed: {e}")
            return self._get_fallback_analysis(profile)

    def _build_analysis_prompt(self, profile: Dict[str, Any]) -> str:
        education = profile.get('academic_records', [])
        experience = profile.get('experience', [])
        skills = [s.get('name') for s in profile.get('skills', [])]
        internships = profile.get('internships', [])
        interests = profile.get('domain_interests', [])
        goals = profile.get('career_goals', [])
        
        education_text = ""
        for edu in education:
            education_text += f"- {edu.get('level', '')}: {edu.get('degree', '')} from {edu.get('institute', '')} ({edu.get('year_of_passing', '')})\n"
        
        experience_text = ""
        for exp in experience:
            experience_text += f"- {exp.get('role', '')} at {exp.get('company', '')} ({exp.get('start_date', '')} - {exp.get('end_date', 'Present')})\n"
        
        skills_text = ", ".join(skills) if skills else "Not specified"
        
        return f"""
        USER PROFILE DATA:
        - Name: {profile.get('full_name', 'User')}
        - Email: {profile.get('email', '')}
        - Age: {self._calculate_age(profile.get('dob'))}
        - Location: {self._get_location(profile)}
        
        EDUCATION:
        {education_text if education_text else "No education records found"}
        
        WORK EXPERIENCE:
        {experience_text if experience_text else "No work experience found"}
        
        INTERNSHIPS: {len(internships)} internships completed
        
        SKILLS: {skills_text}
        
        INTERESTS: {', '.join(interests) if interests else 'Not specified'}
        
        CAREER GOALS: {', '.join(goals) if goals else 'Not specified'}
        
        Generate comprehensive career analysis in JSON format with these exact keys:
        {{
            "career_summary": {{
                "current_level": "entry/mid/senior/executive",
                "overall_score": 0-100,
                "strengths": ["strength1", "strength2", "strength3"],
                "weaknesses": ["weakness1", "weakness2"]
            }},
            "recommended_careers": [
                {{
                    "title": "Job Title",
                    "type": "government/private/remote/internship",
                    "match_percentage": 85,
                    "reason": "Why this career fits",
                    "avg_salary_inr": "Salary range",
                    "growth_potential": "High/Medium/Low",
                    "required_skills": ["skill1", "skill2"]
                }}
            ],
            "skill_gaps": {{
                "missing_skills": ["skill1", "skill2"],
                "improvement_priorities": ["priority1", "priority2"]
            }},
            "learning_path": {{
                "immediate_actions": ["action1", "action2", "action3"],
                "short_term_goals": ["goal1", "goal2"],
                "long_term_goals": ["goal1", "goal2"],
                "recommended_courses": [
                    {{"name": "Course Name", "platform": "Platform", "duration": "X weeks", "url": "optional"}}
                ]
            }},
            "job_market_insights": {{
                "demand_level": "High/Medium/Low",
                "top_industries": ["industry1", "industry2", "industry3"],
                "emerging_roles": ["role1", "role2"],
                "salary_trend": "Increasing/Stable/Decreasing",
                "remote_opportunities": "High/Medium/Low"
            }},
            "growth_projection": {{
                "next_6_months": 0-100,
                "next_1_year": 0-100,
                "next_3_years": 0-100,
                "next_5_years": 0-100,
                "growth_rate": "High/Medium/Low",
                "estimated_salary_progression": [
                    {{"year": 1, "salary": "₹X LPA"}},
                    {{"year": 3, "salary": "₹Y LPA"}},
                    {{"year": 5, "salary": "₹Z LPA"}}
                ]
            }},
            "action_plan": {{
                "next_steps": ["step1", "step2", "step3", "step4", "step5"],
                "timeline": "3/6/12 months",
                "priority_actions": ["action1", "action2"]
            }},
            "ai_recommendations": {{
                "personalized_message": "Motivational message",
                "quick_wins": ["win1", "win2", "win3"],
                "resources": ["resource1", "resource2"],
                "learning_platforms": ["Coursera", "Udemy", "LinkedIn Learning"]
            }}
        }}
        """

    def _calculate_age(self, dob: Optional[str]) -> int:
        if not dob:
            return 25
        try:
            birth = datetime.strptime(dob, "%Y-%m-%d")
            today = datetime.now()
            age = today.year - birth.year
            if today.month < birth.month or (today.month == birth.month and today.day < birth.day):
                age -= 1
            return age
        except:
            return 25

    def _get_location(self, profile: Dict) -> str:
        address = profile.get('current_address', profile.get('address', {}))
        city = address.get('city', '')
        state = address.get('state', '')
        if city and state:
            return f"{city}, {state}"
        elif city:
            return city
        return "Not specified"

    def _enrich_analysis(self, analysis: Dict, profile: Dict) -> Dict:
        # Calculate experience years
        exp_years = 0
        for exp in profile.get('experience', []):
            try:
                start = exp.get('start_date', '')
                if start:
                    exp_years += 1
            except:
                pass
        
        # Skill score calculation
        skills = profile.get('skills', [])
        skill_score = 0
        for skill in skills:
            level = skill.get('level', 'beginner')
            if level == 'expert':
                skill_score += 100
            elif level == 'advanced':
                skill_score += 75
            elif level == 'intermediate':
                skill_score += 50
            else:
                skill_score += 25
        
        skill_score = min(100, skill_score // len(skills)) if skills else 0
        
        # Education score
        education = profile.get('academic_records', [])
        edu_score = min(100, len(education) * 25)
        
        # Overall score
        overall = (skill_score + edu_score + (exp_years * 10)) // 3
        
        analysis['experience_years'] = exp_years
        analysis['skill_score'] = skill_score
        analysis['education_score'] = edu_score
        analysis['overall_score'] = overall
        analysis['profile_completion_percentage'] = self._calculate_completion(profile)
        
        return analysis

    def _calculate_completion(self, profile: Dict) -> int:
        fields = ['full_name', 'email', 'phone', 'address']
        filled = sum(1 for f in fields if profile.get(f))
        sections = ['academic_records', 'experience', 'skills']
        filled += sum(1 for s in sections if profile.get(s))
        total = len(fields) + len(sections)
        return min(100, int((filled / total) * 100)) if total > 0 else 0

    def _get_fallback_analysis(self, profile: Dict) -> Dict:
        completion = self._calculate_completion(profile)
        exp_years = len(profile.get('experience', []))
        skills_count = len(profile.get('skills', []))
        
        return {
            "career_summary": {
                "current_level": "entry" if exp_years < 2 else "mid" if exp_years < 5 else "senior",
                "overall_score": max(30, min(80, completion)),
                "strengths": ["Profile created", "Ready to learn", "Active user"],
                "weaknesses": ["Complete your profile for better insights", "Add more skills"]
            },
            "recommended_careers": [
                {"title": "Complete Your Profile", "type": "general", "match_percentage": completion, 
                 "reason": "Add more details for personalized recommendations", 
                 "avg_salary_inr": "N/A", "growth_potential": "N/A",
                 "required_skills": ["Complete profile first"]}
            ],
            "skill_gaps": {
                "missing_skills": ["Add your skills to see gaps"],
                "improvement_priorities": ["Complete your profile", "Add education", "Add experience"]
            },
            "learning_path": {
                "immediate_actions": ["Add education details", "Add work experience", "List your skills", "Complete your profile", "Explore job opportunities"],
                "short_term_goals": ["Complete profile", "Build 3 key skills", "Apply to 10 jobs"],
                "long_term_goals": ["Get certified", "Advance career", "Reach senior level"],
                "recommended_courses": [
                    {"name": "Career Development", "platform": "Coursera", "duration": "4 weeks", "url": ""}
                ]
            },
            "job_market_insights": {
                "demand_level": "Medium", 
                "top_industries": ["IT/Software", "Banking/Finance", "Government", "Healthcare", "Education"], 
                "emerging_roles": ["AI/ML Engineer", "Data Analyst", "Cloud Architect", "Cybersecurity Expert"], 
                "salary_trend": "Stable",
                "remote_opportunities": "High"
            },
            "growth_projection": {
                "next_6_months": min(100, completion + 15),
                "next_1_year": min(100, completion + 25),
                "next_3_years": min(100, completion + 45),
                "next_5_years": min(100, completion + 60),
                "growth_rate": "Medium" if completion < 70 else "High",
                "estimated_salary_progression": [
                    {"year": 1, "salary": "₹3-6 LPA"},
                    {"year": 3, "salary": "₹6-12 LPA"},
                    {"year": 5, "salary": "₹12-20 LPA"}
                ]
            },
            "action_plan": {
                "next_steps": [
                    "Complete your profile information",
                    "Add your educational qualifications",
                    "List your professional skills",
                    "Add work experience if any",
                    "Explore job opportunities"
                ],
                "timeline": "1-3 months",
                "priority_actions": ["Complete profile", "Add skills"]
            },
            "ai_recommendations": {
                "personalized_message": "Complete your profile to unlock personalized career guidance! Add your education, skills, and experience for better recommendations.",
                "quick_wins": ["Add your education", "List your skills", "Complete your profile"],
                "resources": ["Job listings", "Career articles", "Skill courses"],
                "learning_platforms": ["Coursera", "Udemy", "LinkedIn Learning", "edX"]
            },
            "experience_years": exp_years,
            "skill_score": min(100, skills_count * 10),
            "education_score": min(100, len(profile.get('academic_records', [])) * 25),
            "overall_score": completion,
            "profile_completion_percentage": completion
        }


ai_career_service = AICareerService()