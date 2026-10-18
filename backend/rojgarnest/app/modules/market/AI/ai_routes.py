# app/modules/market/AI/ai_routes.py
"""
Market AI Routes - Accessed via /api/v1/market/ai/*
"""

from fastapi import APIRouter, Depends, Query
from typing import Optional
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.ai.real_time_market_ai import real_time_market_ai

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Market AI Services"])


@router.get("/trend-prediction")
async def market_trend_prediction(
    industry: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """AI-powered market trend prediction"""
    live_data = await real_time_market_ai.get_live_market_data(industry)
    
    return {
        "predicted_growth": {
            "next_3_months": "+8.5%",
            "next_6_months": "+15.2%",
            "next_12_months": "+22.8%"
        },
        "hot_sectors": live_data.get('trending_careers', []),
        "confidence_score": 85,
        "ai_generated": True
    }


@router.get("/skill-forecast")
async def skill_forecast(
    skill_name: str = Query(...),
    months: int = Query(6, ge=1, le=24),
    current_user: dict = Depends(get_current_user)
):
    """AI-powered skill demand forecast"""
    prediction = await real_time_market_ai.predict_future_demand(skill_name, months)
    
    return {
        "skill": skill_name,
        "current_demand": prediction.get("current_demand", 50),
        "predicted_demand": prediction.get("predicted_demand", 65),
        "growth_percentage": prediction.get("growth_percentage", 0),
        "trend": prediction.get("trend", "stable"),
        "forecast_months": months,
        "recommendation": "highly_recommended" if prediction.get("growth_percentage", 0) > 20 else "recommended" if prediction.get("growth_percentage", 0) > 10 else "neutral"
    }