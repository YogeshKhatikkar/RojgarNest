# app/modules/resume/AI/__init__.py
# ============================================================
# AI Resume Module — Exports + Backward Compatibility Aliases
# Mirrors: app/modules/resume/AI/
# ============================================================

# ---------- NEW AI Classes (from our new files) ----------
from app.modules.resume.AI.ats_optimizer import (
    ATSOptimizer,
    ats_optimizer,
)
from app.modules.resume.AI.resume_generator import (
    ResumeGenerator,
    resume_generator,
)
from app.modules.resume.AI.resume_enhancer import (
    ResumeEnhancer,
    resume_enhancer,
)

# ---------- BACKWARD COMPATIBILITY: ResumeParserAI ----------
# The original resume_parser.py existed before we added the new AI files.
# We must export ResumeParserAI so that service.py (line 14) keeps working.
try:
    from app.modules.resume.AI.resume_parser import ResumeParserAI
except ImportError:
    # Fallback — if resume_parser.py doesn't exist, provide a safe stub
    class ResumeParserAI:
        """
        Backward-compatible stub for ResumeParserAI.
        The new AI pipeline uses resume_generator + ats_optimizer instead.
        This stub exists only to keep old imports from breaking.
        """
        def __init__(self):
            pass

        async def parse(self, *args, **kwargs):
            return {}

        async def extract(self, *args, **kwargs):
            return {}

        async def analyze(self, *args, **kwargs):
            return {}


# ---------- BACKWARD COMPATIBILITY: ATSOptimizerAI ----------
# Old service.py imported 'ATSOptimizerAI'. Our new class is 'ATSOptimizer'.
# Alias them so both names work.
ATSOptimizerAI = ATSOptimizer


# ---------- EXPORTS ----------
__all__ = [
    # New classes (preferred)
    "ATSOptimizer",
    "ats_optimizer",
    "ResumeGenerator",
    "resume_generator",
    "ResumeEnhancer",
    "resume_enhancer",
    # Backward-compatible aliases
    "ATSOptimizerAI",
    "ResumeParserAI",
]