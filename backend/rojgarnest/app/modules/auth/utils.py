# app/modules/auth/utils.py
import random

def generate_otp() -> str:
    """Generate 6-digit OTP"""
    return str(random.randint(100000, 999999))


def get_role_dashboard(role: str) -> str:
    """Get dashboard route based on role"""
    role_dashboards = {
        "user": "/user",
        "admin": "/admin",
        "customadmin": "/customadmin",
        "superadmin": "/superadmin"
    }
    return role_dashboards.get(role, "/user")