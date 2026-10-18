# app/modules/superadmin/AI/__init__.py
from .ai_routes import router as ai_router
from .platform_analytics import PlatformAnalyticsAI
from .anomaly_detection import AnomalyDetectionAI
from .growth_predictor import GrowthPredictorAI
from .sentiment_analysis import SentimentAnalysisAI

__all__ = [
    'ai_router',
    'PlatformAnalyticsAI',
    'AnomalyDetectionAI',
    'GrowthPredictorAI',
    'SentimentAnalysisAI'
]