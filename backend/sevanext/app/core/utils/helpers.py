# app/core/utils/helpers.py
import random
from datetime import datetime

def generate_otp() -> str:
    """Generate 6-digit OTP"""
    return str(random.randint(100000, 999999))

def format_date(date_str: str, format: str = "%Y-%m-%d") -> str:
    """Format date string"""
    try:
        dt = datetime.fromisoformat(date_str)
        return dt.strftime(format)
    except:
        return date_str

def clean_text(text: str) -> str:
    """Clean text by removing extra spaces"""
    if not text:
        return ""
    return " ".join(text.split())