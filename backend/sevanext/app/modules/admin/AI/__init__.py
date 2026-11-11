# app/modules/admin/AI/__init__.py
from .ai_routes import router as ai_router
from .candidate_scoring import CandidateScoringAI
from .fraud_detection import FraudDetectionAI
from .hiring_predictions import HiringPredictorAI
from .resume_analyzer import ResumeAnalyzerAI

__all__ = [
    'ai_router',
    'CandidateScoringAI',
    'FraudDetectionAI',
    'HiringPredictorAI',
    'ResumeAnalyzerAI'
]