# app/modules/jobs/AI/__init__.py
from .ai_routes import router as ai_router
from .fake_job_detector import fake_job_detector
from .job_parser import JobParserAI
from .salary_predictor import SalaryPredictorAI

__all__ = [
    'ai_router',
    'fake_job_detector',
    'JobParserAI',
    'SalaryPredictorAI'
]