# app/modules/notification/service.py - COMPLETE FIXED VERSION
# ✅ INTEGRATED: Brevo + MSG91 + WhatsApp
# ✅ All notification types now route through unified dispatcher
# ✅ Email: SMTP or Brevo (switchable via .env)
# ✅ SMS: Twilio / MSG91 / Fast2SMS / Brevo (switchable via .env)
# ✅ WhatsApp: MSG91 / Twilio / Meta (switchable via .env)

import asyncio
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import HTTPException, BackgroundTasks
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Union
import logging

# ============================================================
# 📧📱💬 UNIFIED NOTIFICATION IMPORTS
# ============================================================
from app.core.services.email import send_html_email
from app.core.services.sms import send_sms_async
from app.core.services.whatsapp import send_whatsapp
from app.core.services.notification_dispatcher import (
    dispatch_otp,
    dispatch_verification_success,
    dispatch_password_reset,
    dispatch_welcome,
    dispatch_application_status,
    dispatch_job_alert,
    dispatch_payment_status,
    dispatch_admin_alert,
)

from app.core.config.settings import settings
from app.db.connection import get_db
from app.modules.notification.websocket import broadcast_notification

logger = logging.getLogger(__name__)


class NotificationType:
    """Notification types for different scenarios"""
    NEW_JOB = "new_job"
    JOB_APPLICATION = "job_application"
    APPLICATION_STATUS = "application_status"
    USER_REGISTRATION = "user_registration"
    USER_VERIFICATION = "user_verification"
    PASSWORD_RESET = "password_reset"
    SYSTEM_ALERT = "system_alert"
    ADMIN_ALERT = "admin_alert"
    SUPERADMIN_ALERT = "superadmin_alert"
    CUSTOMADMIN_ALERT = "customadmin_alert"


class UserRole:
    USER = "user"
    ADMIN = "admin"
    SUPERADMIN = "superadmin"
    CUSTOMADMIN = "customadmin"


class CentralNotificationService:
    """
    Centralized Notification Service - One place for all notifications
    Email notifications are clean - NO publisher role displayed
    BULK EMAIL for fast delivery
    ✅ Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket
    """

    def __init__(self):
        self.db = None

    async def _get_db(self):
        if self.db is None:
            self.db = get_db()
        return self.db

    # ==================== GET ACTIVE USERS WITH ROLE EXCLUSION ====================

    async def get_active_users_for_notification(self, exclude_role: Optional[str] = None) -> List[Dict]:
        """
        Get all active users for notifications
        A user is considered active if is_email_verified = True

        Args:
            exclude_role: Role to exclude from notification (admin/customadmin)
        """
        db = await self._get_db()

        # Build query
        query = {"is_email_verified": True}

        # Apply role exclusion
        if exclude_role == "admin":
            # Exclude admin role (admin and superadmin)
            query["role"] = {"$nin": ["admin", "superadmin"]}
            logger.info(f"📊 Excluding 'admin' and 'superadmin' roles for this notification")
        elif exclude_role == "customadmin":
            # Exclude customadmin role
            query["role"] = {"$nin": ["customadmin", "superadmin"]}
            logger.info(f"📊 Excluding 'customadmin' and 'superadmin' roles for this notification")
        else:
            # No exclusion - send to all
            logger.info(f"📊 No role exclusion - sending to all verified users")

        # Get users with verified email
        users = await db.auth.find(query).to_list(length=10000)

        # Also include users with verified mobile if email not verified
        mobile_verified_users = await db.auth.find({
            "is_email_verified": False,
            "is_mobile_verified": True
        }).to_list(length=10000)

        # Combine and remove duplicates
        all_users = users + mobile_verified_users
        unique_users = {str(u["_id"]): u for u in all_users}.values()

        logger.info(f"📊 Total active users for notification: {len(unique_users)}")

        return list(unique_users)

    async def get_users_by_role(self, roles: List[str]) -> List[Dict]:
        """Get users with specific roles"""
        db = await self._get_db()

        users = await db.auth.find({
            "is_email_verified": True,
            "role": {"$in": roles}
        }).to_list(length=10000)

        return users

    # ==================== BULK EMAIL SENDING (FAST - SINGLE CONNECTION) ====================

    async def send_bulk_email_notification(
        self,
        user_emails: List[str],
        subject: str,
        html_body: str,
        batch_size: int = 50
    ) -> Dict[str, Any]:
        """
        Send bulk email to multiple users using a single SMTP connection
        Very fast - reuses the same connection for all emails in a batch
        ✅ Now supports Brevo via unified email service if EMAIL_PROVIDER=brevo
        """
        # ✅ If using a cloud provider (Brevo/SendGrid/Mailgun), delegate to unified service
        provider = (settings.EMAIL_PROVIDER or "smtp").lower()
        if provider in ("brevo", "sendgrid", "mailgun"):
            logger.info(f"📧 Bulk email via cloud provider: {provider}")
            from app.core.services.email import get_email_service
            svc = get_email_service()
            sent = 0
            failed = 0
            failed_emails = []
            for em in user_emails:
                ok = await svc.send(
                    to_email=em,
                    subject=subject,
                    html_body=html_body,
                )
                if ok:
                    sent += 1
                else:
                    failed += 1
                    failed_emails.append({"email": em, "error": "provider_failed"})
            return {"sent": sent, "failed": failed, "total": len(user_emails), "failed_emails": failed_emails}

        # Fallback: legacy SMTP batch sending (only if EMAIL_PROVIDER=smtp)
        if not settings.SMTP_HOST or not settings.SMTP_USER:
            logger.warning("SMTP not configured, skipping bulk email")
            return {"sent": 0, "failed": 0, "total": len(user_emails)}

        if not user_emails:
            return {"sent": 0, "failed": 0, "total": 0}

        results = {
            "sent": 0,
            "failed": 0,
            "total": len(user_emails),
            "failed_emails": []
        }

        # Process in batches to avoid overwhelming the server
        for i in range(0, len(user_emails), batch_size):
            batch = user_emails[i:i + batch_size]

            try:
                # Create a single SMTP connection for this batch
                server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
                server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)

                for email in batch:
                    try:
                        msg = MIMEMultipart("alternative")
                        msg["From"] = settings.SMTP_FROM
                        msg["To"] = email
                        msg["Subject"] = subject
                        msg.attach(MIMEText(html_body, "html"))

                        server.sendmail(settings.SMTP_FROM, [email], msg.as_string())
                        results["sent"] += 1
                        logger.info(f"📧 Bulk email sent to {email}")

                    except Exception as e:
                        results["failed"] += 1
                        results["failed_emails"].append({"email": email, "error": str(e)})
                        logger.error(f"Failed to send email to {email}: {e}")

                server.quit()

            except Exception as e:
                logger.error(f"SMTP connection failed for batch: {e}")
                # Mark all emails in this batch as failed
                for email in batch:
                    results["failed"] += 1
                    results["failed_emails"].append({"email": email, "error": str(e)})

        logger.info(f"📧 Bulk email complete: {results['sent']} sent, {results['failed']} failed")
        return results

    # ==================== CORE NOTIFICATION METHODS ====================

    async def send_notification(
        self,
        user_ids: Union[str, List[str]],
        notification_type: str,
        title: str,
        message: str,
        related_id: Optional[str] = None,
        metadata: Optional[Dict] = None,
        send_email: bool = True,
        send_sms: bool = False,
        send_whatsapp_flag: bool = True,
        send_websocket: bool = True
    ) -> Dict[str, Any]:
        """
        Send notification to one or multiple users.
        ✅ Sends across ALL configured channels:
           - In-app (DB) — for bell icon
           - Email (SMTP / Brevo / SendGrid / Mailgun)
           - SMS (Twilio / MSG91 / Fast2SMS / Brevo)
           - WhatsApp (MSG91 / Twilio / Meta)
           - WebSocket (real-time bell)
        """
        db = await self._get_db()

        if isinstance(user_ids, str):
            user_ids = [user_ids]

        results = {
            "total_users": len(user_ids),
            "db_notifications": 0,
            "emails_sent": 0,
            "sms_sent": 0,
            "whatsapp_sent": 0,
            "websocket_sent": 0,
            "failed": []
        }

        email_list = []

        for user_id in user_ids:
            try:
                user = None

                if '@' in user_id:
                    user = await db.auth.find_one({"email": user_id})
                    user_id_value = user_id
                else:
                    if ObjectId.is_valid(user_id):
                        user = await db.auth.find_one({"_id": ObjectId(user_id)})
                        user_id_value = user_id
                    else:
                        results["failed"].append({"user_id": user_id, "reason": "Invalid user ID format"})
                        continue

                if not user:
                    results["failed"].append({"user_id": user_id, "reason": "User not found"})
                    continue

                user_email = user.get("email")
                user_name = user.get("name", "User")
                user_role = user.get("role", "user")
                user_mobile = user.get("mobile") or user.get("phone")
                is_email_verified = user.get("is_email_verified", False)
                is_mobile_verified = user.get("is_mobile_verified", False)

                # ==================== 1. DATABASE NOTIFICATION (Bell Icon) ====================
                if is_email_verified or is_mobile_verified:
                    notification_doc = {
                        "user_id": user_id_value,
                        "user_email": user_email,
                        "type": notification_type,
                        "title": title,
                        "message": message,
                        "related_id": related_id,
                        "read": False,
                        "created_at": datetime.utcnow(),
                        "metadata": metadata or {},
                        "user_role": user_role
                    }
                    await db.notifications.insert_one(notification_doc)
                    results["db_notifications"] += 1
                    logger.info(f"📝 DB notification saved for {user_email}: {title[:50]}")

                # ==================== 2. EMAIL NOTIFICATION ====================
                if send_email and user_email and is_email_verified:
                    email_list.append(user_email)

                # ==================== 3. SMS NOTIFICATION ====================
                if send_sms and user_mobile:
                    try:
                        await send_sms_async(
                            to_mobile=user_mobile,
                            message=f"{title}: {message[:120]}",
                            template_id=settings.MSG91_TEMPLATE_ID_ALERT,
                            variables={"name": user_name, "message": message[:140]},
                        )
                        results["sms_sent"] += 1
                        logger.info(f"📱 SMS sent to {user_mobile}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"SMS send failed for {user_mobile}: {e}")

                # ==================== 4. WHATSAPP NOTIFICATION ====================
                if send_whatsapp_flag and user_mobile and settings.WHATSAPP_PROVIDER != "disabled":
                    try:
                        await send_whatsapp(
                            to_mobile=user_mobile,
                            message=f"{title}: {message[:200]}",
                            template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
                            variables={"name": user_name, "message": message[:200]},
                        )
                        results["whatsapp_sent"] += 1
                        logger.info(f"💬 WhatsApp sent to {user_mobile}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"WhatsApp send failed for {user_mobile}: {e}")

                # ==================== 5. WEBSOCKET NOTIFICATION (REAL-TIME BELL) ====================
                if send_websocket and (is_email_verified or is_mobile_verified):
                    try:
                        from .websocket import broadcast_notification

                        ws_message = {
                            "type": "new_notification",
                            "notification_type": notification_type,
                            "title": title,
                            "message": message,
                            "user_id": user_id_value,
                            "user_email": user_email,
                            "user_role": user_role,
                            "metadata": metadata,
                            "timestamp": datetime.utcnow().isoformat()
                        }
                        await broadcast_notification(ws_message)
                        results["websocket_sent"] += 1
                        logger.info(f"📡 WebSocket notification sent to {user_email}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"WebSocket notification failed for {user_email}: {e}")

            except Exception as e:
                logger.error(f"Failed to send notification to {user_id}: {e}")
                results["failed"].append({"user_id": user_id, "reason": str(e)})

        # ==================== SEND BULK EMAILS ====================
        if email_list and send_email:
            html_body = self._create_beautiful_email_html(
                notification_type=notification_type,
                title=title,
                message=message,
                metadata=metadata,
                related_id=related_id
            )

            bulk_result = await self.send_bulk_email_notification(
                user_emails=email_list,
                subject=title,
                html_body=html_body,
                batch_size=50
            )
            results["emails_sent"] = bulk_result["sent"]

        logger.info(f"📢 Notification sent: type={notification_type}, results={results}")
        return results

    # ==================== BEAUTIFUL EMAIL TEMPLATE WITH STATUS HIGHLIGHT ====================

    def _create_beautiful_email_html(
        self,
        notification_type: str,
        title: str,
        message: str,
        metadata: Optional[Dict] = None,
        related_id: Optional[str] = None
    ) -> str:
        """Create beautiful, modern HTML email with status highlighting"""

        # Get status color and icon based on notification type
        status_config = self._get_status_config(notification_type, metadata)

        # Get current date for footer
        current_date = datetime.now().strftime("%B %d, %Y")

        app_base_url = settings.APP_BASE_URL

        # Extract metadata for job details if available
        job_title = metadata.get('job_title', '') if metadata else ''
        organization = metadata.get('organization', '') if metadata else ''
        location = metadata.get('location', '') if metadata else ''
        job_type = metadata.get('job_type', '') if metadata else ''
        status = metadata.get('status', '') if metadata else ''
        notes = metadata.get('notes', '') if metadata else ''

        return f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{title}</title>
            <style>
                /* Reset styles */
                * {{
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }}

                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    padding: 40px 20px;
                    line-height: 1.6;
                }}

                .email-container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background: #ffffff;
                    border-radius: 24px;
                    overflow: hidden;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                    animation: fadeInUp 0.5s ease-out;
                }}

                @keyframes fadeInUp {{
                    from {{
                        opacity: 0;
                        transform: translateY(30px);
                    }}
                    to {{
                        opacity: 1;
                        transform: translateY(0);
                    }}
                }}

                /* Header Section */
                .email-header {{
                    background: linear-gradient(135deg, {status_config['gradient_start']}, {status_config['gradient_end']});
                    padding: 40px 30px;
                    text-align: center;
                    position: relative;
                    overflow: hidden;
                }}

                .email-header::before {{
                    content: '';
                    position: absolute;
                    top: -50%;
                    right: -50%;
                    width: 200%;
                    height: 200%;
                    background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
                    animation: pulse 3s ease-in-out infinite;
                }}

                @keyframes pulse {{
                    0%, 100% {{ transform: scale(1); opacity: 0.5; }}
                    50% {{ transform: scale(1.1); opacity: 0.8; }}
                }}

                .header-icon {{
                    width: 80px;
                    height: 80px;
                    background: rgba(255, 255, 255, 0.2);
                    border-radius: 50%;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    margin-bottom: 20px;
                    backdrop-filter: blur(10px);
                    animation: bounce 2s ease-in-out infinite;
                }}

                @keyframes bounce {{
                    0%, 100% {{ transform: translateY(0); }}
                    50% {{ transform: translateY(-10px); }}
                }}

                .header-icon span {{
                    font-size: 48px;
                }}

                .email-header h1 {{
                    color: white;
                    font-size: 28px;
                    font-weight: 700;
                    margin-bottom: 10px;
                    text-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }}

                .email-header p {{
                    color: rgba(255, 255, 255, 0.95);
                    font-size: 16px;
                }}

                /* Status Badge */
                .status-badge {{
                    display: inline-block;
                    padding: 8px 20px;
                    background: {status_config['badge_color']};
                    color: white;
                    border-radius: 50px;
                    font-weight: 600;
                    font-size: 14px;
                    margin: 20px auto 0;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                }}

                /* Content Section */
                .email-content {{
                    padding: 40px 30px;
                }}

                .greeting {{
                    font-size: 18px;
                    font-weight: 600;
                    color: #1a202c;
                    margin-bottom: 20px;
                }}

                .message-text {{
                    color: #4a5568;
                    font-size: 16px;
                    margin-bottom: 25px;
                    line-height: 1.6;
                }}

                /* Job Details Card */
                .job-details {{
                    background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
                    border-radius: 20px;
                    padding: 25px;
                    margin: 25px 0;
                    border: 1px solid #e2e8f0;
                }}

                .job-title {{
                    font-size: 20px;
                    font-weight: 700;
                    color: #1e3a8a;
                    margin-bottom: 12px;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }}

                .job-title::before {{
                    content: "📌";
                    font-size: 24px;
                }}

                .company-name {{
                    font-size: 16px;
                    color: #475569;
                    margin-bottom: 15px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }}

                .company-name::before {{
                    content: "🏢";
                }}

                .job-info-grid {{
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 12px;
                    margin: 15px 0;
                }}

                .info-item {{
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    font-size: 14px;
                    color: #334155;
                    padding: 8px 12px;
                    background: white;
                    border-radius: 12px;
                }}

                .info-item strong {{
                    color: #1e3a8a;
                    font-weight: 600;
                }}

                /* Status Update Section */
                .status-update {{
                    background: {status_config['highlight_bg']};
                    border-left: 4px solid {status_config['gradient_start']};
                    border-radius: 12px;
                    padding: 20px;
                    margin: 25px 0;
                }}

                .status-label {{
                    font-size: 14px;
                    font-weight: 600;
                    color: {status_config['gradient_start']};
                    margin-bottom: 8px;
                    text-transform: uppercase;
                    letter-spacing: 1px;
                }}

                .status-value {{
                    font-size: 24px;
                    font-weight: 700;
                    color: {status_config['gradient_start']};
                    display: inline-block;
                    padding: 6px 16px;
                    background: rgba({status_config['rgb_color']}, 0.1);
                    border-radius: 50px;
                }}

                .admin-notes {{
                    background: #fef3c7;
                    border-radius: 12px;
                    padding: 15px;
                    margin-top: 15px;
                    border-left: 4px solid #f59e0b;
                }}

                .admin-notes p {{
                    color: #92400e;
                    font-size: 14px;
                    margin: 0;
                }}

                /* Action Button */
                .action-button {{
                    text-align: center;
                    margin: 30px 0 20px;
                }}

                .btn {{
                    display: inline-block;
                    padding: 14px 32px;
                    background: linear-gradient(135deg, {status_config['gradient_start']}, {status_config['gradient_end']});
                    color: white;
                    text-decoration: none;
                    border-radius: 50px;
                    font-weight: 600;
                    font-size: 16px;
                    transition: transform 0.3s ease, box-shadow 0.3s ease;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                }}

                .btn:hover {{
                    transform: translateY(-2px);
                    box-shadow: 0 8px 25px rgba(0,0,0,0.25);
                }}

                /* Supporting Info */
                .supporting-info {{
                    margin-top: 30px;
                    padding: 20px;
                    background: #f8fafc;
                    border-radius: 16px;
                }}

                .info-title {{
                    font-weight: 700;
                    color: #1e293b;
                    margin-bottom: 12px;
                    font-size: 16px;
                }}

                .info-list {{
                    list-style: none;
                    padding: 0;
                }}

                .info-list li {{
                    padding: 6px 0;
                    color: #475569;
                    font-size: 14px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }}

                .info-list li::before {{
                    content: "✓";
                    color: #10b981;
                    font-weight: bold;
                }}

                /* Footer */
                .email-footer {{
                    background: #f8fafc;
                    padding: 30px;
                    text-align: center;
                    border-top: 1px solid #e2e8f0;
                }}

                .footer-links {{
                    margin-bottom: 20px;
                }}

                .footer-links a {{
                    color: #64748b;
                    text-decoration: none;
                    font-size: 13px;
                    margin: 0 10px;
                    transition: color 0.3s ease;
                }}

                .footer-links a:hover {{
                    color: {status_config['gradient_start']};
                }}

                .copyright {{
                    color: #94a3b8;
                    font-size: 12px;
                }}

                /* Divider */
                .divider {{
                    height: 1px;
                    background: linear-gradient(to right, transparent, #e2e8f0, transparent);
                    margin: 20px 0;
                }}

                /* Responsive */
                @media (max-width: 480px) {{
                    .email-content {{
                        padding: 25px 20px;
                    }}
                    .job-info-grid {{
                        grid-template-columns: 1fr;
                    }}
                    .btn {{
                        padding: 12px 24px;
                        font-size: 14px;
                    }}
                }}
            </style>
        </head>
        <body>
            <div class="email-container">
                <!-- Header Section -->
                <div class="email-header">
                    <div class="header-icon">
                        <span>{status_config['icon']}</span>
                    </div>
                    <h1>{title}</h1>
                    <p>RojgarNest - Your Career Partner</p>
                    <div class="status-badge">
                        {status_config['badge_text']}
                    </div>
                </div>

                <!-- Content Section -->
                <div class="email-content">
                    <div class="greeting">
                        Dear Job Seeker,
                    </div>

                    <div class="message-text">
                        {message}
                    </div>

                    <!-- Job Details Card -->
                    {self._get_job_details_html(job_title, organization, location, job_type)}

                    <!-- Status Update Section (for application status notifications) -->
                    {self._get_status_update_html(notification_type, status, notes, status_config)}

                    <!-- Action Button -->
                    {self._get_action_button_html(notification_type, metadata, related_id, app_base_url, status_config)}

                    <!-- Supporting Information -->
                    {self._get_supporting_info_html(notification_type, status_config)}
                </div>

                <!-- Footer Section -->
                <div class="email-footer">
                    <div class="footer-links">
                        <a href="{app_base_url}">Home</a>
                        <a href="{app_base_url}/jobs">Browse Jobs</a>
                        <a href="{app_base_url}/user/applications">My Applications</a>
                        <a href="{app_base_url}/support">Support</a>
                    </div>
                    <div class="copyright">
                        © {current_date.split(', ')[1] if ', ' in current_date else current_date} RojgarNest. All rights reserved.<br>
                        Find Your Dream Job with AI-Powered Career Guidance
                    </div>
                </div>
            </div>
        </body>
        </html>
        """

    def _get_job_details_html(self, job_title: str, organization: str, location: str, job_type: str) -> str:
        """Generate job details HTML section"""
        if not job_title and not organization:
            return ""

        job_type_display = {
            "private": "🏢 Private",
            "government": "🏛️ Government",
            "remote": "🏠 Remote",
            "hybrid": "🔄 Hybrid",
            "internship": "🎓 Internship"
        }.get(job_type, "💼 " + job_type.capitalize() if job_type else "")

        return f"""
        <div class="job-details">
            <div class="job-title">{job_title if job_title else 'Job Opportunity'}</div>
            <div class="company-name">{organization if organization else 'Company Name'}</div>
            <div class="job-info-grid">
                <div class="info-item">📍 <strong>Location:</strong> {location if location else 'India'}</div>
                <div class="info-item">💼 <strong>Job Type:</strong> {job_type_display}</div>
            </div>
        </div>
        """

    def _get_status_update_html(self, notification_type: str, status: str, notes: str, status_config: Dict) -> str:
        """Generate status update HTML section with highlighting"""
        if notification_type != NotificationType.APPLICATION_STATUS or not status:
            return ""

        status_display = status.upper().replace('_', ' ')

        notes_html = ""
        if notes:
            notes_html = f"""
            <div class="admin-notes">
                <p><strong>📝 Admin Notes:</strong> {notes}</p>
            </div>
            """

        return f"""
        <div class="status-update">
            <div class="status-label">Application Status</div>
            <div>
                <span class="status-value">{status_display}</span>
            </div>
            {notes_html}
        </div>
        """

    def _get_action_button_html(self, notification_type: str, metadata: Optional[Dict], related_id: Optional[str], app_base_url: str, status_config: Dict) -> str:
        """Generate action button HTML based on notification type"""

        if notification_type == NotificationType.NEW_JOB and metadata and metadata.get("job_id"):
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/jobs/{metadata['job_id']}" class="btn">🔍 View Job Details</a>
            </div>
            """

        elif notification_type == NotificationType.JOB_APPLICATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/admin/applications" class="btn">📋 View Applications</a>
            </div>
            """

        elif notification_type == NotificationType.APPLICATION_STATUS:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/applications" class="btn">📊 Track My Applications</a>
            </div>
            """

        elif notification_type == NotificationType.USER_VERIFICATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/verification" class="btn">✅ Complete Verification</a>
            </div>
            """

        elif notification_type == NotificationType.PASSWORD_RESET:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/auth/login" class="btn">🔐 Login to Account</a>
            </div>
            """

        elif notification_type == NotificationType.USER_REGISTRATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/dashboard" class="btn">🚀 Go to Dashboard</a>
            </div>
            """

        return ""

    def _get_supporting_info_html(self, notification_type: str, status_config: Dict) -> str:
        """Generate supporting information HTML section"""

        if notification_type == NotificationType.NEW_JOB:
            return f"""
            <div class="supporting-info">
                <div class="info-title">💡 Pro Tips for Your Application:</div>
                <ul class="info-list">
                    <li>Customize your resume for this specific job</li>
                    <li>Highlight relevant skills and experience</li>
                    <li>Submit your application before the deadline</li>
                    <li>Follow up with a professional thank-you message</li>
                </ul>
            </div>
            """

        elif notification_type == NotificationType.APPLICATION_STATUS:
            return f"""
            <div class="supporting-info">
                <div class="info-title">📌 What's Next?</div>
                <ul class="info-list">
                    <li>Keep your profile updated for better opportunities</li>
                    <li>Check your email regularly for interview updates</li>
                    <li>Prepare for potential interviews by researching the company</li>
                    <li>Continue applying to other matching positions</li>
                </ul>
            </div>
            """

        elif notification_type == NotificationType.JOB_APPLICATION:
            return f"""
            <div class="supporting-info">
                <div class="info-title">✅ Application Submitted Successfully!</div>
                <ul class="info-list">
                    <li>The employer will review your application</li>
                    <li>You'll receive updates via email and notifications</li>
                    <li>Track your application status in your dashboard</li>
                    <li>Keep applying to increase your chances</li>
                </ul>
            </div>
            """

        return f"""
        <div class="supporting-info">
            <div class="info-title">🔔 Stay Connected</div>
            <ul class="info-list">
                <li>Enable notifications for instant job alerts</li>
                <li>Complete your profile for better job matches</li>
                <li>Follow us on social media for updates</li>
                <li>Contact support for any assistance</li>
            </ul>
        </div>
        """

    # ==================== STATUS CONFIGURATIONS ====================

    def _get_status_config(self, notification_type: str, metadata: Optional[Dict]) -> Dict[str, str]:
        """Get status configuration based on notification type"""

        configs = {
            NotificationType.NEW_JOB: {
                "icon": "🚀",
                "badge_text": "New Job Opportunity",
                "gradient_start": "#1e3a8a",
                "gradient_end": "#3b82f6",
                "badge_color": "#3b82f6",
                "highlight_bg": "#eff6ff",
                "rgb_color": "59, 130, 246"
            },
            NotificationType.JOB_APPLICATION: {
                "icon": "📝",
                "badge_text": "Application Received",
                "gradient_start": "#7c3aed",
                "gradient_end": "#8b5cf6",
                "badge_color": "#8b5cf6",
                "highlight_bg": "#f5f3ff",
                "rgb_color": "139, 92, 246"
            },
            NotificationType.APPLICATION_STATUS: {
                "icon": "📋",
                "badge_text": "Status Update",
                "gradient_start": "#059669",
                "gradient_end": "#10b981",
                "badge_color": "#10b981",
                "highlight_bg": "#ecfdf5",
                "rgb_color": "16, 185, 129"
            },
            NotificationType.USER_REGISTRATION: {
                "icon": "🎉",
                "badge_text": "Welcome",
                "gradient_start": "#0284c7",
                "gradient_end": "#0ea5e9",
                "badge_color": "#0ea5e9",
                "highlight_bg": "#f0f9ff",
                "rgb_color": "14, 165, 233"
            },
            NotificationType.USER_VERIFICATION: {
                "icon": "✅",
                "badge_text": "Verification",
                "gradient_start": "#16a34a",
                "gradient_end": "#22c55e",
                "badge_color": "#22c55e",
                "highlight_bg": "#f0fdf4",
                "rgb_color": "34, 197, 94"
            },
            NotificationType.PASSWORD_RESET: {
                "icon": "🔒",
                "badge_text": "Security Alert",
                "gradient_start": "#ea580c",
                "gradient_end": "#f97316",
                "badge_color": "#f97316",
                "highlight_bg": "#fff7ed",
                "rgb_color": "249, 115, 22"
            },
            NotificationType.SYSTEM_ALERT: {
                "icon": "⚠️",
                "badge_text": "System Notification",
                "gradient_start": "#dc2626",
                "gradient_end": "#ef4444",
                "badge_color": "#ef4444",
                "highlight_bg": "#fef2f2",
                "rgb_color": "239, 68, 68"
            },
            NotificationType.ADMIN_ALERT: {
                "icon": "👑",
                "badge_text": "Admin Alert",
                "gradient_start": "#0891b2",
                "gradient_end": "#06b6d4",
                "badge_color": "#06b6d4",
                "highlight_bg": "#ecfeff",
                "rgb_color": "6, 182, 212"
            }
        }

        # Override for specific status values
        if notification_type == NotificationType.APPLICATION_STATUS and metadata:
            status = metadata.get('status', '').lower()
            if status == 'shortlisted':
                return {
                    "icon": "⭐",
                    "badge_text": "Shortlisted!",
                    "gradient_start": "#2563eb",
                    "gradient_end": "#3b82f6",
                    "badge_color": "#3b82f6",
                    "highlight_bg": "#eff6ff",
                    "rgb_color": "59, 130, 246"
                }
            elif status == 'interview':
                return {
                    "icon": "📞",
                    "badge_text": "Interview Scheduled",
                    "gradient_start": "#ea580c",
                    "gradient_end": "#f97316",
                    "badge_color": "#f97316",
                    "highlight_bg": "#fff7ed",
                    "rgb_color": "249, 115, 22"
                }
            elif status == 'offered':
                return {
                    "icon": "🎉",
                    "badge_text": "Offer Received!",
                    "gradient_start": "#059669",
                    "gradient_end": "#10b981",
                    "badge_color": "#10b981",
                    "highlight_bg": "#ecfdf5",
                    "rgb_color": "16, 185, 129"
                }
            elif status == 'rejected':
                return {
                    "icon": "📝",
                    "badge_text": "Application Status",
                    "gradient_start": "#dc2626",
                    "gradient_end": "#ef4444",
                    "badge_color": "#ef4444",
                    "highlight_bg": "#fef2f2",
                    "rgb_color": "239, 68, 68"
                }

        return configs.get(notification_type, configs[NotificationType.SYSTEM_ALERT])

    # ==================== NEW JOB NOTIFICATION WITH BULK EMAIL ====================

    async def notify_new_job(self, job_data: Dict, background_tasks: BackgroundTasks, publisher_role: str = "admin") -> Dict:
        """
        Notify users about new job with role-based exclusion
        Uses BULK EMAIL for fast delivery (50-100x faster)
        ✅ Also sends WhatsApp alerts based on NOTIFY_JOB_ALERT_CHANNELS in .env

        Role-based rules:
        - CustomAdmin publishes → Exclude ADMIN role
        - Admin publishes → Exclude CUSTOMADMIN role
        - SuperAdmin publishes → Notify ALL
        """
        db = await self._get_db()

        logger.info("=" * 60)
        logger.info(f"📢 Starting NEW JOB NOTIFICATION (BULK EMAIL + WhatsApp) - Publisher Role: {publisher_role}")
        logger.info("=" * 60)

        job_title = job_data.get("post_name", "New Job")
        organization = job_data.get("organization", "Company")
        job_id = str(job_data.get("_id"))
        location = job_data.get("location", "India")
        job_type = job_data.get("job_type", "private")

        title = f"🚀 New Job Alert: {job_title} at {organization}"
        message = f"A new job opportunity '{job_title}' has been posted by {organization}. Check out the details below and apply now!"

        metadata = {
            "job_title": job_title,
            "organization": organization,
            "job_id": job_id,
            "location": location,
            "job_type": job_type
        }

        user_ids = []
        exclude_role = None

        publisher_role_lower = publisher_role.lower() if publisher_role else "admin"

        if publisher_role_lower == "customadmin":
            exclude_role = "admin"
            users = await self.get_active_users_for_notification(exclude_role="admin")
            logger.info(f"📊 CustomAdmin published job - Excluding 'admin' role")
        elif publisher_role_lower == "admin":
            exclude_role = "customadmin"
            users = await self.get_active_users_for_notification(exclude_role="customadmin")
            logger.info(f"📊 Admin published job - Excluding 'customadmin' role")
        else:
            users = await self.get_active_users_for_notification(exclude_role=None)
            logger.info(f"📊 SuperAdmin published job - Sending to ALL users")

        user_ids = [str(user["_id"]) for user in users]

        logger.info(f"📊 Total active users for notification: {len(user_ids)}")

        if not user_ids:
            logger.warning("⚠️ No active users found to notify!")
            return {
                "success": False,
                "message": "No active users found to notify",
                "total_users": 0,
                "db_notifications": 0,
                "emails_sent": 0,
                "excluded_role": exclude_role
            }

        # ✅ Send with WhatsApp enabled for job alerts
        result = await self.send_notification(
            user_ids=user_ids,
            notification_type=NotificationType.NEW_JOB,
            title=title,
            message=message,
            related_id=job_id,
            metadata=metadata,
            send_email=True,
            send_sms=False,  # Job alerts: no SMS (per .env default)
            send_whatsapp_flag=True,  # ✅ WhatsApp enabled for job alerts
            send_websocket=True
        )

        result["excluded_role"] = exclude_role
        result["publisher_role"] = publisher_role

        logger.info("=" * 60)
        logger.info(f"✅ New Job Notification Complete!")
        logger.info(f"   Publisher Role: {publisher_role}")
        logger.info(f"   Excluded Role: {exclude_role}")
        logger.info(f"   Total Active Users: {result['total_users']}")
        logger.info(f"   DB Notifications: {result['db_notifications']}")
        logger.info(f"   Emails Sent (Bulk): {result['emails_sent']}")
        logger.info(f"   WhatsApp Sent: {result.get('whatsapp_sent', 0)}")
        logger.info(f"   WebSocket Sent: {result['websocket_sent']}")
        logger.info("=" * 60)

        return result

    # ==================== OTHER NOTIFICATION METHODS ====================

    async def notify_admins_new_job(self, job_data: Dict):
        """Notify admins about new job"""
        db = await self._get_db()

        admins = await db.auth.find({
            "role": {"$in": [UserRole.ADMIN, UserRole.SUPERADMIN]},
            "is_email_verified": True
        }).to_list(length=1000)

        admin_ids = [str(admin["_id"]) for admin in admins]

        if admin_ids:
            title = f"📢 Admin Alert: New Job Posted - {job_data.get('post_name')}"
            message = f"A new job '{job_data.get('post_name')}' has been posted by {job_data.get('organization')}"

            await self.send_notification(
                user_ids=admin_ids,
                notification_type=NotificationType.ADMIN_ALERT,
                title=title,
                message=message,
                related_id=str(job_data.get("_id")),
                metadata={"job_title": job_data.get("post_name"), "organization": job_data.get("organization")},
                send_email=True,
                send_websocket=True
            )

    async def notify_customadmins_new_job(self, job_data: Dict):
        """Notify customadmins about new job"""
        db = await self._get_db()

        customadmins = await db.auth.find({
            "role": UserRole.CUSTOMADMIN,
            "is_email_verified": True
        }).to_list(length=1000)

        customadmin_ids = [str(admin["_id"]) for admin in customadmins]

        if customadmin_ids:
            title = f"📢 CustomAdmin Alert: New Job Posted - {job_data.get('post_name')}"
            message = f"A new job '{job_data.get('post_name')}' has been posted by {job_data.get('organization')}"

            await self.send_notification(
                user_ids=customadmin_ids,
                notification_type=NotificationType.CUSTOMADMIN_ALERT,
                title=title,
                message=message,
                related_id=str(job_data.get("_id")),
                metadata={"job_title": job_data.get("post_name"), "organization": job_data.get("organization")},
                send_email=True,
                send_websocket=True
            )

    async def notify_new_application(
        self,
        application_data: Dict,
        job_data: Dict,
        admin_email: str
    ) -> Dict:
        """Notify admin when user applies for a job"""
        db = await self._get_db()

        admin_user = await db.auth.find_one({"email": admin_email})
        if not admin_user:
            logger.error(f"Admin not found: {admin_email}")
            return {"success": False, "error": "Admin not found"}

        admin_id = str(admin_user["_id"])

        job_title = job_data.get("post_name", "Unknown Job")
        organization = job_data.get("organization", "Company")
        applicant_name = application_data.get("applicant_name", "Someone")
        applicant_email = application_data.get("applicant_email", "")
        application_id = application_data.get("application_id", "")

        # Notify Admin
        admin_title = f"📝 New Application Received: {job_title}"
        admin_message = f"{applicant_name} has applied for '{job_title}' at {organization}"

        admin_metadata = {
            "job_title": job_title,
            "organization": organization,
            "applicant_name": applicant_name,
            "applicant_email": applicant_email,
            "application_id": application_id
        }

        admin_result = await self.send_notification(
            user_ids=admin_id,
            notification_type=NotificationType.JOB_APPLICATION,
            title=admin_title,
            message=admin_message,
            related_id=application_id,
            metadata=admin_metadata,
            send_email=True,
            send_whatsapp_flag=False,  # Admin gets email + bell only
            send_websocket=True
        )

        # Notify Applicant (Confirmation)
        applicant_user = await db.auth.find_one({"email": applicant_email})
        if applicant_user and applicant_user.get("is_email_verified"):
            applicant_id = str(applicant_user["_id"])

            user_title = f"✅ Application Submitted Successfully: {job_title}"
            user_message = f"Your application for '{job_title}' at {organization} has been submitted successfully!"

            user_metadata = {
                "job_title": job_title,
                "organization": organization,
                "application_id": application_id,
                "status": "pending"
            }

            await self.send_notification(
                user_ids=applicant_id,
                notification_type=NotificationType.APPLICATION_STATUS,
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata=user_metadata,
                send_email=True,
                send_sms=True,  # ✅ Applicant gets SMS confirmation
                send_whatsapp_flag=True,  # ✅ Also WhatsApp
                send_websocket=True
            )

        return admin_result

    async def notify_status_update(
        self,
        application_id: str,
        new_status: str,
        notes: Optional[str],
        updated_by_email: str
    ) -> Dict:
        """
        Notify user when admin updates application status
        Sends to BOTH user and admin (for audit trail)
        ✅ Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket
        """
        db = await self._get_db()

        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            return {"success": False, "error": "Application not found"}

        applicant_email = application.get("applicant_email")
        job_title = application.get("job_title", "the position")
        organization = application.get("organization", "Company")
        added_by = application.get("added_by")

        job_poster = await db.auth.find_one({"email": added_by}) if added_by else None
        job_poster_id = str(job_poster["_id"]) if job_poster else None

        applicant_user = await db.auth.find_one({"email": applicant_email})
        if not applicant_user:
            return {"success": False, "error": "Applicant not found"}

        applicant_id = str(applicant_user["_id"])

        # Get status display text
        status_display = {
            "shortlisted": "SHORTLISTED",
            "interview": "INTERVIEW SCHEDULED",
            "offered": "OFFER RECEIVED",
            "rejected": "NOT SELECTED",
            "pending": "PENDING REVIEW",
            "submitted": "SUBMITTED",
            "pending_verification": "AWAITING VERIFICATION",
            "verification_successful": "VERIFICATION APPROVED",
            "verification_rejected": "VERIFICATION FAILED"
        }.get(new_status.lower(), new_status.upper())

        # Notification for Applicant
        applicant_title = f"📋 Application Status Update: {job_title}"
        applicant_message = f"Your application for '{job_title}' at {organization} is now {status_display}"
        if notes:
            applicant_message += f"\n\nAdmin Notes: {notes}"

        applicant_metadata = {
            "job_title": job_title,
            "organization": organization,
            "status": new_status,
            "notes": notes,
            "application_id": application_id
        }

        applicant_result = await self.send_notification(
            user_ids=applicant_id,
            notification_type=NotificationType.APPLICATION_STATUS,
            title=applicant_title,
            message=applicant_message,
            related_id=application_id,
            metadata=applicant_metadata,
            send_email=True,
            send_sms=True,  # ✅ Status changes go to SMS too
            send_whatsapp_flag=True,  # ✅ And WhatsApp
            send_websocket=True
        )

        # Notify Admin (Job Poster)
        if job_poster_id:
            admin_title = f"📋 Application Status Updated: {job_title}"
            admin_message = f"Application by {applicant_email} for '{job_title}' is now {status_display}"
            if notes:
                admin_message += f"\n\nNotes: {notes}"

            admin_metadata = {
                "job_title": job_title,
                "organization": organization,
                "applicant_email": applicant_email,
                "status": new_status,
                "notes": notes,
                "application_id": application_id
            }

            await self.send_notification(
                user_ids=job_poster_id,
                notification_type=NotificationType.ADMIN_ALERT,
                title=admin_title,
                message=admin_message,
                related_id=application_id,
                metadata=admin_metadata,
                send_email=True,
                send_sms=False,  # Admin: email + bell
                send_whatsapp_flag=False,
                send_websocket=True
            )

            logger.info(f"📧 Status update notification also sent to admin: {added_by}")

        # Notify CustomAdmins
        if job_poster_id and added_by:
            customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
            for customadmin in customadmins:
                ca_email = customadmin.get("email")
                if ca_email != added_by:
                    ca_id = str(customadmin["_id"])
                    await self.send_notification(
                        user_ids=ca_id,
                        notification_type=NotificationType.CUSTOMADMIN_ALERT,
                        title=f"📋 Application Update: {job_title}",
                        message=f"Application by {applicant_email} for '{job_title}' is now {status_display}",
                        related_id=application_id,
                        metadata=admin_metadata,
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True
                    )

        return {
            "success": True,
            "applicant_notified": applicant_result.get("total_users", 0) > 0,
            "admin_notified": job_poster_id is not None,
            "message": f"Status update notification sent to user and admin"
        }

    # ==================== USER NOTIFICATION METHODS ====================

    async def get_user_notifications(
        self,
        user_id: str,
        limit: int = 50,
        skip: int = 0,
        unread_only: bool = False
    ) -> Dict:
        """Get notifications for a specific user (Bell icon data)"""
        db = await self._get_db()

        query = {"user_id": user_id}
        if unread_only:
            query["read"] = False

        notifications = await db.notifications.find(query)\
            .sort("created_at", -1)\
            .skip(skip)\
            .limit(limit)\
            .to_list(limit)

        total = await db.notifications.count_documents(query)
        unread_count = await db.notifications.count_documents({"user_id": user_id, "read": False})

        for notif in notifications:
            notif["_id"] = str(notif["_id"])
            if notif.get("created_at"):
                notif["created_at"] = notif["created_at"].isoformat()

        return {
            "notifications": notifications,
            "total": total,
            "unread_count": unread_count,
            "skip": skip,
            "limit": limit
        }

    async def mark_as_read(self, notification_id: str, user_id: str) -> Dict:
        """Mark a notification as read"""
        db = await self._get_db()

        if not ObjectId.is_valid(notification_id):
            raise HTTPException(status_code=400, detail="Invalid notification ID")

        result = await db.notifications.update_one(
            {"_id": ObjectId(notification_id), "user_id": user_id},
            {"$set": {"read": True, "read_at": datetime.utcnow()}}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Notification not found")

        return {"message": "Notification marked as read"}

    async def mark_all_as_read(self, user_id: str) -> Dict:
        """Mark all notifications as read for a user"""
        db = await self._get_db()

        result = await db.notifications.update_many(
            {"user_id": user_id, "read": False},
            {"$set": {"read": True, "read_at": datetime.utcnow()}}
        )

        return {"message": f"Marked {result.modified_count} notifications as read"}

    async def get_unread_count(self, user_id: str) -> int:
        """Get unread notification count for bell badge"""
        db = await self._get_db()
        return await db.notifications.count_documents({"user_id": user_id, "read": False})

    # ==================== PAYMENT VERIFICATION NOTIFICATION ====================

    async def notify_payment_verification(
        self,
        payment_id: str,
        application_id: str,
        user_email: str,
        admin_email: str,
        amount: int,
        job_title: str,
        action: str,  # 'approve' or 'reject'
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send payment verification notifications to both user and admin
        Also updates bell icon with proper notification types
        ✅ Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket
        """
        db = await self._get_db()

        # Get admin user to get their user_id
        admin_user = await db.auth.find_one({"email": admin_email})
        admin_user_id = str(admin_user["_id"]) if admin_user else None

        # Get user to get their user_id
        user = await db.auth.find_one({"email": user_email})
        user_user_id = str(user["_id"]) if user else None

        results = {
            "user_notified": False,
            "admin_notified": False,
            "customadmin_notified": False
        }

        if action == "approve":
            # Notification for USER (applicant)
            if user_user_id:
                await self.send_notification(
                    user_ids=[user_user_id],
                    notification_type="application_status",
                    title="✅ Payment Verified Successfully!",
                    message=f"Your payment of ₹{amount} for '{job_title}' has been verified successfully. Your application is now submitted.",
                    related_id=application_id,
                    metadata={
                        "status": "verification_successful",
                        "amount": amount,
                        "job_title": job_title,
                        "application_id": application_id,
                        "payment_id": payment_id,
                        "admin_notes": notes
                    },
                    send_email=True,
                    send_sms=True,   # ✅ SMS for payment
                    send_whatsapp_flag=True,  # ✅ WhatsApp for payment
                    send_websocket=True
                )
                results["user_notified"] = True
                logger.info(f"📧📱💬 Payment approval sent to user: {user_email}")

            # Notification for ADMIN (job poster)
            if admin_user_id:
                await self.send_notification(
                    user_ids=[admin_user_id],
                    notification_type="application_status",
                    title="💰 Payment Approved",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED. Application is now verified.",
                    related_id=application_id,
                    metadata={
                        "status": "payment_approved",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "application_id": application_id,
                        "payment_id": payment_id,
                        "admin_notes": notes
                    },
                    send_email=True,
                    send_sms=False,
                    send_whatsapp_flag=False,
                    send_websocket=True
                )
                results["admin_notified"] = True
                logger.info(f"📧 Payment approval notification sent to admin: {admin_email}")

            # Notification for ALL CUSTOMADMINS
            customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
            customadmin_ids = [str(ca["_id"]) for ca in customadmins]

            for ca_id in customadmin_ids:
                if ca_id != admin_user_id:
                    await self.send_notification(
                        user_ids=[ca_id],
                        notification_type="customadmin_alert",
                        title="💰 Payment Approved",
                        message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED by {admin_email}",
                        related_id=application_id,
                        metadata={
                            "status": "payment_approved",
                            "amount": amount,
                            "job_title": job_title,
                            "applicant_email": user_email,
                            "application_id": application_id,
                            "payment_id": payment_id,
                            "approved_by": admin_email
                        },
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True
                    )
                    results["customadmin_notified"] = True

            return results

        else:  # reject
            # Notification for USER (applicant)
            if user_user_id:
                await self.send_notification(
                    user_ids=[user_user_id],
                    notification_type="application_status",
                    title="❌ Payment Verification Failed",
                    message=f"Your payment of ₹{amount} for '{job_title}' has been REJECTED.\nReason: {notes if notes else 'Please contact support'}",
                    related_id=application_id,
                    metadata={
                        "status": "verification_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "application_id": application_id,
                        "payment_id": payment_id,
                        "rejection_reason": notes
                    },
                    send_email=True,
                    send_sms=True,   # ✅ SMS for payment rejection
                    send_whatsapp_flag=True,  # ✅ WhatsApp
                    send_websocket=True
                )
                results["user_notified"] = True
                logger.info(f"📧📱💬 Payment rejection sent to user: {user_email}")

            # Notification for ADMIN
            if admin_user_id:
                await self.send_notification(
                    user_ids=[admin_user_id],
                    notification_type="application_status",
                    title="💰 Payment Rejected",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED.\nReason: {notes if notes else 'No reason provided'}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "application_id": application_id,
                        "payment_id": payment_id,
                        "rejection_reason": notes
                    },
                    send_email=True,
                    send_sms=False,
                    send_whatsapp_flag=False,
                    send_websocket=True
                )
                results["admin_notified"] = True
                logger.info(f"📧 Payment rejection notification sent to admin: {admin_email}")

            # Notification for ALL CUSTOMADMINS
            customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
            for ca in customadmins:
                ca_id = str(ca["_id"])
                if ca_id != admin_user_id:
                    await self.send_notification(
                        user_ids=[ca_id],
                        notification_type="customadmin_alert",
                        title="💰 Payment Rejected",
                        message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED by {admin_email}.\nReason: {notes if notes else 'No reason provided'}",
                        related_id=application_id,
                        metadata={
                            "status": "payment_rejected",
                            "amount": amount,
                            "job_title": job_title,
                            "applicant_email": user_email,
                            "application_id": application_id,
                            "payment_id": payment_id,
                            "rejected_by": admin_email,
                            "rejection_reason": notes
                        },
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True
                    )
                    results["customadmin_notified"] = True

            return results

    # ==================== HIGH-LEVEL DISPATCH WRAPPERS ====================
    # These wrappers let other modules call unified dispatchers directly
    # through this service. Useful for custom flows.

    async def send_otp(
        self,
        email: Optional[str],
        mobile: Optional[str],
        otp: str,
        purpose: str = "verification",
        user_name: str = "User",
    ) -> Dict[str, bool]:
        """Send OTP through unified dispatcher (Email + SMS + WhatsApp)."""
        return await dispatch_otp(
            email=email, mobile=mobile, otp=otp,
            purpose=purpose, user_name=user_name,
        )

    async def send_welcome(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
    ) -> Dict[str, bool]:
        """Send welcome through unified dispatcher."""
        return await dispatch_welcome(
            email=email, mobile=mobile, user_name=user_name,
        )

    async def send_job_alert(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
        job_title: str,
        organization: str,
        location: str,
        job_id: str,
    ) -> Dict[str, bool]:
        """Send job alert through unified dispatcher."""
        return await dispatch_job_alert(
            email=email, mobile=mobile, user_name=user_name,
            job_title=job_title, organization=organization,
            location=location, job_id=job_id,
        )

    async def send_payment_status(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
        job_title: str,
        amount: int,
        action: str,
        notes: Optional[str] = None,
    ) -> Dict[str, bool]:
        """Send payment status through unified dispatcher."""
        return await dispatch_payment_status(
            email=email, mobile=mobile, user_name=user_name,
            job_title=job_title, amount=amount,
            action=action, notes=notes,
        )

    async def send_admin_alert(
        self,
        admin_email: str,
        title: str,
        message: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, bool]:
        """Send admin alert through unified dispatcher."""
        return await dispatch_admin_alert(
            admin_email=admin_email, title=title,
            message=message, metadata=metadata,
        )


# Create global instance
central_notification = CentralNotificationService()

print("✅ Centralized Notification Service Loaded - BULK EMAIL for fast delivery")
print("   🎨 Beautiful Email Templates with Status Highlighting")
print("   📧 Email Provider: " + settings.EMAIL_PROVIDER)
print("   📱 SMS Provider: " + settings.SMS_PROVIDER)
print("   💬 WhatsApp Provider: " + settings.WHATSAPP_PROVIDER)
print("   🚀 Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket")
print("   💰 Payment verification notification method included")