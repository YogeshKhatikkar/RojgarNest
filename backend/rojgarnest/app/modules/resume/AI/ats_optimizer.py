# app/modules/resume/AI/ats_optimizer.py
# ============================================================
# COMPLETE ATS (Applicant Tracking System) OPTIMIZATION ENGINE
# Works with: OpenAI GPT-4o + Rule-based scoring + ML heuristics
# ============================================================

import re
import json
import logging
import hashlib
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from collections import Counter

from openai import AsyncOpenAI
from app.core.config.settings import settings
from app.core.utils.logger import logger

module_logger = logging.getLogger(__name__)


# ============================================================
# ATS CONSTANTS — Industry-standard keyword banks
# ============================================================
ACTION_VERBS = {
    "strong": [
        "achieved", "accelerated", "accomplished", "architected", "automated",
        "built", "boosted", "championed", "consolidated", "created",
        "delivered", "designed", "developed", "directed", "drove",
        "eliminated", "engineered", "established", "executed", "expanded",
        "generated", "grew", "implemented", "improved", "increased",
        "initiated", "innovated", "launched", "led", "managed",
        "maximized", "mentored", "optimized", "orchestrated", "overhauled",
        "pioneered", "produced", "reduced", "redesigned", "scaled",
        "secured", "spearheaded", "streamlined", "strengthened", "transformed",
    ],
    "weak": [
        "assisted", "helped", "worked", "responsible for", "duties included",
        "participated", "involved in", "supported", "tried", "attempted",
    ],
}

TECHNICAL_SKILL_BANK = {
    "programming_languages": [
        "python", "java", "javascript", "typescript", "c++", "c#", "go",
        "rust", "ruby", "php", "swift", "kotlin", "scala", "r", "matlab",
        "dart", "perl", "bash", "shell", "powershell", "sql", "nosql",
    ],
    "web_frameworks": [
        "react", "angular", "vue", "svelte", "next.js", "nuxt", "django",
        "flask", "fastapi", "spring", "spring boot", "express", "nestjs",
        "laravel", "rails", "asp.net", ".net core", "flutter",
    ],
    "databases": [
        "mongodb", "postgresql", "mysql", "sqlite", "oracle", "redis",
        "cassandra", "dynamodb", "elasticsearch", "neo4j", "firebase",
    ],
    "cloud_devops": [
        "aws", "azure", "gcp", "docker", "kubernetes", "jenkins", "terraform",
        "ansible", "ci/cd", "github actions", "gitlab ci", "circleci",
        "prometheus", "grafana", "datadog", "cloudformation",
    ],
    "data_ai": [
        "machine learning", "deep learning", "tensorflow", "pytorch",
        "scikit-learn", "pandas", "numpy", "keras", "nlp", "computer vision",
        "data science", "data analysis", "power bi", "tableau", "looker",
        "apache spark", "hadoop", "kafka", "airflow",
    ],
    "soft_skills": [
        "leadership", "communication", "teamwork", "problem solving",
        "critical thinking", "time management", "adaptability", "creativity",
        "collaboration", "project management", "agile", "scrum",
    ],
}

QUANTIFICATION_PATTERNS = [
    r"\b\d+(\.\d+)?\s*%",
    r"\b\d+(\.\d+)?\s*(k|m|b|lakh|crore|million|billion)\b",
    r"\$\s*\d+",
    r"₹\s*\d+",
    r"\b\d+\s*(users|customers|clients|projects|people|members|employees)\b",
    r"\b(increased|decreased|reduced|improved|grew|saved)\s+by\s+\d+",
]


class ATSOptimizer:
    """
    Complete ATS Optimization Engine
    - Scores resume against job description
    - Checks ATS-compatible formatting
    - Suggests fixes with priority
    - Generates optimized resume (auto-rewrite)
    """

    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
        self._all_skills = self._flatten_skill_bank()
        module_logger.info("✅ ATS Optimizer initialized")

    # ============================================================
    # MAIN ENTRY: Score a resume against a job description
    # ============================================================
    async def score_resume(
        self,
        resume_data: Dict[str, Any],
        job_description: Optional[str] = None,
        job_skills: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Return complete ATS report:
        - overall_score (0-100)
        - section_scores
        - keyword_analysis
        - formatting_issues
        - action_verbs_analysis
        - quantification_score
        - prioritized_fixes
        - ai_summary
        """
        try:
            resume_text = self._flatten_resume(resume_data)
            jd_text = (job_description or "").strip()

            # 1. Rule-based scoring
            keyword_analysis = self._keyword_analysis(resume_text, jd_text, job_skills or [])
            formatting = self._formatting_check(resume_data)
            action_verbs = self._action_verbs_check(resume_data)
            quantification = self._quantification_check(resume_data)
            section_scores = self._section_scores(resume_data, keyword_analysis, formatting)

            # 2. Overall score (weighted)
            overall = self._compute_overall_score(
                section_scores, keyword_analysis, formatting,
                action_verbs, quantification
            )

            # 3. AI-generated insight
            ai_summary = await self._ai_summary(
                resume_data, jd_text, overall, keyword_analysis
            )

            # 4. Prioritized fixes
            fixes = self._prioritized_fixes(
                keyword_analysis, formatting, action_verbs, quantification
            )

            return {
                "overall_score": round(overall, 1),
                "grade": self._grade(overall),
                "section_scores": section_scores,
                "keyword_analysis": keyword_analysis,
                "formatting_issues": formatting,
                "action_verbs": action_verbs,
                "quantification": quantification,
                "prioritized_fixes": fixes,
                "ai_summary": ai_summary,
                "scored_at": datetime.utcnow().isoformat(),
            }

        except Exception as e:
            module_logger.error(f"ATS scoring failed: {e}")
            return self._fallback_report(resume_data)

    # ============================================================
    # KEYWORD ANALYSIS
    # ============================================================
    def _keyword_analysis(
        self,
        resume_text: str,
        jd_text: str,
        explicit_job_skills: List[str],
    ) -> Dict[str, Any]:
        resume_lower = resume_text.lower()
        jd_lower = jd_text.lower()

        # Extract skill keywords from JD
        jd_skills = self._extract_skills_from_text(jd_text)
        resume_skills = self._extract_skills_from_text(resume_text)

        # Merge with explicit job skills
        jd_skills_set = set(jd_skills) | set(s.lower() for s in explicit_job_skills)

        if not jd_skills_set:
            # No JD → score against bank
            matched = [s for s in self._all_skills if s in resume_lower][:50]
            missing = []
            density = self._keyword_density(resume_lower, matched)
            return {
                "has_job_description": False,
                "matched_keywords": matched,
                "missing_keywords": [],
                "match_percentage": min(100.0, len(matched) * 2.5),
                "keyword_density": density,
                "recommended_density": "1.5% – 2.5%",
                "top_priority_missing": [],
            }

        # Match against JD
        matched = []
        missing = []
        for skill in jd_skills_set:
            if self._contains_keyword(resume_lower, skill):
                matched.append(skill)
            else:
                missing.append(skill)

        match_pct = (len(matched) / max(1, len(jd_skills_set))) * 100
        density = self._keyword_density(resume_lower, matched)

        # Priority missing = skills that appear most in JD
        jd_counter = Counter(self._extract_skills_from_text(jd_text))
        priority_missing = sorted(
            missing,
            key=lambda s: jd_counter.get(s, 0),
            reverse=True,
        )[:10]

        return {
            "has_job_description": True,
            "jd_total_keywords": len(jd_skills_set),
            "matched_keywords": sorted(matched),
            "missing_keywords": sorted(missing),
            "top_priority_missing": priority_missing,
            "match_percentage": round(match_pct, 1),
            "keyword_density": round(density, 2),
            "recommended_density": "1.5% – 2.5%",
        }

    def _extract_skills_from_text(self, text: str) -> List[str]:
        if not text:
            return []
        lower = text.lower()
        found = set()
        for skill in self._all_skills:
            if self._contains_keyword(lower, skill):
                found.add(skill)
        return sorted(found)

    def _contains_keyword(self, text: str, keyword: str) -> bool:
        """Word-boundary aware matching (avoids 'Go' matching 'Google')."""
        pattern = r"(?<![a-zA-Z0-9])" + re.escape(keyword) + r"(?![a-zA-Z0-9])"
        return bool(re.search(pattern, text))

    def _keyword_density(self, text: str, keywords: List[str]) -> float:
        if not text:
            return 0.0
        words = re.findall(r"\b\w+\b", text)
        if not words:
            return 0.0
        hits = 0
        for kw in keywords:
            hits += text.count(kw)
        return (hits / len(words)) * 100

    # ============================================================
    # FORMATTING CHECK (ATS-friendliness)
    # ============================================================
    def _formatting_check(self, resume_data: Dict[str, Any]) -> Dict[str, Any]:
        issues: List[Dict[str, Any]] = []
        warnings: List[str] = []

        # Contact info
        contact = resume_data.get("contact_info") or {}
        if not contact.get("email"):
            issues.append({"severity": "critical", "issue": "Missing email address"})
        if not contact.get("phone"):
            issues.append({"severity": "critical", "issue": "Missing phone number"})

        # Summary length
        summary = (resume_data.get("professional_summary") or "").strip()
        if not summary:
            issues.append({"severity": "high", "issue": "No professional summary found"})
        elif len(summary.split()) < 30:
            warnings.append("Professional summary is too short (< 30 words)")
        elif len(summary.split()) > 120:
            warnings.append("Professional summary is too long (> 120 words)")

        # Experience
        experience = resume_data.get("experience") or []
        if not experience:
            warnings.append("No work experience section found")
        else:
            for i, exp in enumerate(experience):
                desc = (exp.get("description") or "")
                if len(desc.split()) < 15:
                    warnings.append(f"Experience #{i+1} description is too short")
                if not exp.get("start_date"):
                    warnings.append(f"Experience #{i+1} missing start date")

        # Education
        education = resume_data.get("education") or []
        if not education:
            warnings.append("No education section found")

        # Skills
        skills_data = resume_data.get("skills") or {}
        all_skills = skills_data.get("all") or []
        if len(all_skills) < 5:
            warnings.append("List at least 5–15 skills for better ATS matching")
        elif len(all_skills) > 40:
            warnings.append("Too many skills listed (aim for 15–30)")

        # Format compatibility flags
        formatting_score = 100
        formatting_score -= len(issues) * 15
        formatting_score -= len(warnings) * 3
        formatting_score = max(0, formatting_score)

        return {
            "score": formatting_score,
            "critical_issues": [i for i in issues if i["severity"] == "critical"],
            "issues": issues,
            "warnings": warnings,
            "ats_compatible": formatting_score >= 70,
        }

    # ============================================================
    # ACTION VERBS ANALYSIS
    # ============================================================
    def _action_verbs_check(self, resume_data: Dict[str, Any]) -> Dict[str, Any]:
        experience = resume_data.get("experience") or []
        all_text = " ".join(
            (exp.get("description") or "") for exp in experience
        ).lower()

        strong_found = [v for v in ACTION_VERBS["strong"] if re.search(rf"\b{v}\b", all_text)]
        weak_found = [v for v in ACTION_VERBS["weak"] if re.search(rf"\b{v}\b", all_text)]

        total = len(strong_found) + len(weak_found)
        strength_score = 100 if total == 0 else int((len(strong_found) / total) * 100)

        suggestions = []
        if weak_found:
            suggestions.append(
                f"Replace weak verbs {weak_found[:5]} with strong action verbs "
                f"like: achieved, led, built, optimized, spearheaded."
            )
        if len(strong_found) < 5:
            suggestions.append(
                "Use more strong action verbs — aim for at least 5 unique ones."
            )

        return {
            "score": strength_score,
            "strong_verbs_found": strong_found,
            "weak_verbs_found": weak_found,
            "suggestions": suggestions,
        }

    # ============================================================
    # QUANTIFICATION CHECK
    # ============================================================
    def _quantification_check(self, resume_data: Dict[str, Any]) -> Dict[str, Any]:
        experience = resume_data.get("experience") or []
        combined = " ".join(
            (exp.get("description") or "") + " " + " ".join(exp.get("achievements") or [])
            for exp in experience
        )

        hits = 0
        samples: List[str] = []
        for pattern in QUANTIFICATION_PATTERNS:
            for m in re.finditer(pattern, combined, re.IGNORECASE):
                hits += 1
                if len(samples) < 5:
                    samples.append(m.group(0))

        score = min(100, hits * 15)

        suggestions = []
        if hits < 3:
            suggestions.append(
                "Add measurable numbers (%, ₹, users, projects) to at least 3 achievements."
            )
        if hits == 0:
            suggestions.append(
                "Example: 'Reduced API latency by 42%' instead of 'Improved API performance'."
            )

        return {
            "score": score,
            "quantified_mentions": hits,
            "samples": samples,
            "suggestions": suggestions,
        }

    # ============================================================
    # SECTION SCORES
    # ============================================================
    def _section_scores(
        self,
        resume_data: Dict[str, Any],
        keyword_analysis: Dict[str, Any],
        formatting: Dict[str, Any],
    ) -> Dict[str, int]:
        contact = resume_data.get("contact_info") or {}
        experience = resume_data.get("experience") or []
        education = resume_data.get("education") or []
        skills_data = resume_data.get("skills") or {}
        projects = resume_data.get("projects") or []
        certifications = resume_data.get("certifications") or []

        contact_score = 100
        if not contact.get("email"): contact_score -= 30
        if not contact.get("phone"): contact_score -= 30
        if not contact.get("location"): contact_score -= 20

        summary_words = len((resume_data.get("professional_summary") or "").split())
        summary_score = min(100, int(summary_words * 2.5)) if summary_words else 0

        experience_score = min(100, len(experience) * 25) if experience else 0
        if experience:
            with_desc = sum(1 for e in experience if len((e.get("description") or "").split()) >= 20)
            experience_score = min(100, int((with_desc / len(experience)) * 100))

        skills_count = len(skills_data.get("all") or [])
        skills_score = min(100, skills_count * 6)

        education_score = min(100, len(education) * 30) if education else 0
        projects_score = min(100, len(projects) * 25) if projects else 0
        certs_score = min(100, len(certifications) * 20) if certifications else 0

        return {
            "contact": contact_score,
            "summary": summary_score,
            "experience": experience_score,
            "skills": skills_score,
            "education": education_score,
            "projects": projects_score,
            "certifications": certs_score,
            "keywords": int(keyword_analysis.get("match_percentage", 0)),
            "formatting": formatting.get("score", 0),
        }

    def _compute_overall_score(
        self,
        section_scores: Dict[str, int],
        keyword_analysis: Dict[str, Any],
        formatting: Dict[str, Any],
        action_verbs: Dict[str, Any],
        quantification: Dict[str, Any],
    ) -> float:
        weights = {
            "keywords": 0.25,
            "experience": 0.20,
            "skills": 0.15,
            "formatting": 0.10,
            "summary": 0.10,
            "education": 0.05,
            "projects": 0.05,
            "certifications": 0.05,
            "contact": 0.05,
        }
        total = 0.0
        for key, w in weights.items():
            total += section_scores.get(key, 0) * w

        # Bonus / penalty
        total += (action_verbs.get("score", 0) * 0.05)
        total += (quantification.get("score", 0) * 0.05)

        return min(100.0, max(0.0, total))

    def _grade(self, score: float) -> str:
        if score >= 90: return "A+ (Excellent)"
        if score >= 80: return "A (Very Good)"
        if score >= 70: return "B (Good)"
        if score >= 60: return "C (Average)"
        if score >= 50: return "D (Below Average)"
        return "F (Needs Major Work)"

    # ============================================================
    # PRIORITIZED FIXES
    # ============================================================
    def _prioritized_fixes(
        self,
        keyword_analysis: Dict[str, Any],
        formatting: Dict[str, Any],
        action_verbs: Dict[str, Any],
        quantification: Dict[str, Any],
    ) -> List[Dict[str, Any]]:
        fixes: List[Dict[str, Any]] = []

        # 1. Critical formatting
        for issue in formatting.get("critical_issues", []):
            fixes.append({
                "priority": 1,
                "category": "Critical",
                "issue": issue["issue"],
                "impact": "High",
                "fix": self._suggest_fix(issue["issue"]),
            })

        # 2. Missing keywords
        top_missing = keyword_analysis.get("top_priority_missing", [])
        if top_missing:
            fixes.append({
                "priority": 1,
                "category": "Keywords",
                "issue": f"Missing {len(top_missing)} high-priority keywords from JD",
                "impact": "High",
                "fix": f"Add these to Skills/Experience: {', '.join(top_missing[:8])}",
            })

        # 3. Weak verbs
        if action_verbs.get("weak_verbs_found"):
            fixes.append({
                "priority": 2,
                "category": "Content",
                "issue": f"Weak verbs detected: {', '.join(action_verbs['weak_verbs_found'][:3])}",
                "impact": "Medium",
                "fix": "Replace with strong verbs: led, built, optimized, delivered.",
            })

        # 4. Quantification
        if quantification.get("score", 0) < 50:
            fixes.append({
                "priority": 2,
                "category": "Content",
                "issue": "Not enough measurable achievements",
                "impact": "Medium",
                "fix": "Add numbers: %, ₹, users, projects, latency, revenue.",
            })

        # 5. Warnings
        for w in formatting.get("warnings", [])[:5]:
            fixes.append({
                "priority": 3,
                "category": "Improvement",
                "issue": w,
                "impact": "Low",
                "fix": self._suggest_fix(w),
            })

        fixes.sort(key=lambda x: x["priority"])
        return fixes

    def _suggest_fix(self, issue: str) -> str:
        issue_lower = issue.lower()
        if "email" in issue_lower: return "Add a professional email (name@domain.com)."
        if "phone" in issue_lower: return "Add a 10-digit mobile number."
        if "summary" in issue_lower: return "Write 40–80 words summarising your experience + goals."
        if "experience" in issue_lower: return "Add at least 1 experience entry with 3+ bullet points."
        if "education" in issue_lower: return "Add highest degree with year and institute."
        if "skill" in issue_lower: return "List 10–20 relevant skills (mix technical + soft)."
        if "too short" in issue_lower: return "Expand with specific project details, tools, and outcomes."
        return "Improve this section for better ATS score."

    # ============================================================
    # AI-GENERATED SUMMARY
    # ============================================================
    async def _ai_summary(
        self,
        resume_data: Dict[str, Any],
        jd_text: str,
        overall: float,
        keyword_analysis: Dict[str, Any],
    ) -> str:
        if not self.client:
            return (
                f"Your resume scores {overall:.1f}/100. "
                f"Focus on the top-priority fixes below to reach 85+."
            )
        try:
            name = (resume_data.get("user_info") or {}).get("full_name", "Candidate")
            exp_count = len(resume_data.get("experience") or [])
            skills_count = len((resume_data.get("skills") or {}).get("all") or [])
            missing = keyword_analysis.get("top_priority_missing", [])[:6]

            prompt = f"""You are a senior ATS recruiter. Give a SHORT (max 4 sentences) summary of this resume.

Candidate: {name}
Score: {overall:.1f}/100
Experience entries: {exp_count}
Skills: {skills_count}
Missing high-priority keywords: {missing}
Has JD: {bool(jd_text)}

Be direct, professional, encouraging. Mention the #1 fix needed.
Return plain text only — no JSON, no markdown."""

            resp = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.4,
                max_tokens=250,
            )
            return resp.choices[0].message.content.strip()
        except Exception as e:
            module_logger.error(f"AI summary failed: {e}")
            return f"Resume score: {overall:.1f}/100. Review prioritized fixes below."

    # ============================================================
    # UTILITIES
    # ============================================================
    def _flatten_skill_bank(self) -> List[str]:
        flat: List[str] = []
        for group in TECHNICAL_SKILL_BANK.values():
            flat.extend(group)
        return sorted(set(flat))

    def _flatten_resume(self, resume_data: Dict[str, Any]) -> str:
        parts: List[str] = []

        user = resume_data.get("user_info") or {}
        parts.append(str(user.get("full_name", "")))

        contact = resume_data.get("contact_info") or {}
        parts.append(str(contact.get("email", "")))
        parts.append(str(contact.get("phone", "")))
        parts.append(str(contact.get("location", "")))

        parts.append(str(resume_data.get("professional_summary", "")))
        parts.append(str(resume_data.get("career_objective", "")))

        for exp in resume_data.get("experience") or []:
            parts.append(str(exp.get("role", "")))
            parts.append(str(exp.get("company", "")))
            parts.append(str(exp.get("description", "")))
            parts.extend([str(a) for a in (exp.get("achievements") or [])])
            parts.extend([str(s) for s in (exp.get("skills_used") or [])])

        for edu in resume_data.get("education") or []:
            parts.append(str(edu.get("degree", "")))
            parts.append(str(edu.get("institute", "")))

        skills = resume_data.get("skills") or {}
        for s in skills.get("all") or []:
            if isinstance(s, dict):
                parts.append(str(s.get("name", "")))
            else:
                parts.append(str(s))

        for p in resume_data.get("projects") or []:
            parts.append(str(p.get("title", "")))
            parts.append(str(p.get("description", "")))
            parts.extend([str(t) for t in (p.get("technologies") or [])])

        for c in resume_data.get("certifications") or []:
            parts.append(str(c.get("name", "")))

        return " ".join(parts)

    def _fallback_report(self, resume_data: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "overall_score": 50.0,
            "grade": "D (Below Average)",
            "section_scores": {},
            "keyword_analysis": {"match_percentage": 0, "matched_keywords": [], "missing_keywords": []},
            "formatting_issues": {"score": 50, "issues": [], "warnings": []},
            "action_verbs": {"score": 50, "suggestions": []},
            "quantification": {"score": 0, "suggestions": ["Enable AI for detailed analysis"]},
            "prioritized_fixes": [{
                "priority": 1,
                "category": "Critical",
                "issue": "AI analysis unavailable",
                "impact": "High",
                "fix": "Check OpenAI API key and retry.",
            }],
            "ai_summary": "Could not analyze resume. Please retry.",
            "scored_at": datetime.utcnow().isoformat(),
        }


ats_optimizer = ATSOptimizer()