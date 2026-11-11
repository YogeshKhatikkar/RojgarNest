# app/modules/support/routes.py
# COMPLETE SUPPORT ROUTES FOR EMAIL SENDING

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
import logging

from app.core.services.email import send_html_email
from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from bson import ObjectId

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/support", tags=["Support"])


class SupportEmailSchema(BaseModel):
    """Schema for support email request"""
    to: str = Field(..., description="Recipient email address")
    from_email: Optional[str] = Field(None, description="Sender email")
    from_name: Optional[str] = Field(None, description="Sender name")
    subject: str = Field(..., description="Email subject")
    message: str = Field(..., description="Email message body")
    user_email: Optional[str] = Field(None, description="User's email")
    user_name: Optional[str] = Field(None, description="User's name")


@router.post("/send-email")
async def send_support_email(
    data: SupportEmailSchema,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Send support email from user to support team
    """
    try:
        # Get user details from current_user if not provided
        user_email = data.user_email or current_user.get("email")
        user_name = data.user_name or current_user.get("name", "User")
        
        # Create beautiful email HTML
        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Support Request</title>
            <style>
                body {{
                    font-family: 'Segoe UI', Arial, sans-serif;
                    background-color: #f4f4f4;
                    margin: 0;
                    padding: 20px;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 16px;
                    overflow: hidden;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
                }}
                .header {{
                    background: linear-gradient(135deg, #1E3A8A, #3B82F6);
                    color: white;
                    padding: 30px 20px;
                    text-align: center;
                }}
                .header h2 {{
                    margin: 0;
                    font-size: 24px;
                }}
                .header p {{
                    margin: 8px 0 0;
                    opacity: 0.9;
                }}
                .content {{
                    padding: 24px;
                }}
                .info-box {{
                    background: #f0f7ff;
                    padding: 16px;
                    border-radius: 12px;
                    margin-bottom: 20px;
                    border-left: 4px solid #3B82F6;
                }}
                .info-item {{
                    margin-bottom: 10px;
                    display: flex;
                }}
                .info-label {{
                    width: 100px;
                    font-weight: 600;
                    color: #1E3A8A;
                }}
                .info-value {{
                    flex: 1;
                    color: #333;
                    word-break: break-word;
                }}
                .message-box {{
                    background: #f9fafb;
                    padding: 20px;
                    border-radius: 12px;
                    border: 1px solid #e5e7eb;
                    margin: 20px 0;
                }}
                .message-box p {{
                    margin: 0;
                    white-space: pre-wrap;
                    line-height: 1.6;
                    color: #374151;
                }}
                .footer {{
                    text-align: center;
                    padding: 20px;
                    background: #f8fafc;
                    border-top: 1px solid #e2e8f0;
                    font-size: 12px;
                    color: #64748b;
                }}
                .badge {{
                    display: inline-block;
                    background: #10B981;
                    color: white;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    margin-top: 8px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>📧 New Support Request</h2>
                    <p>RojgarNest Support System</p>
                </div>
                <div class="content">
                    <div class="info-box">
                        <div class="info-item">
                            <div class="info-label">From:</div>
                            <div class="info-value">{user_name} ({user_email})</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Subject:</div>
                            <div class="info-value">{data.subject[:100]}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Received:</div>
                            <div class="info-value">{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
                        </div>
                    </div>
                    
                    <div class="message-box">
                        <p>{data.message.replace(chr(10), '<br>')}</p>
                    </div>
                    
                    <div style="margin-top: 16px; padding: 12px; background: #fef3c7; border-radius: 8px;">
                        <strong>⚠️ Priority:</strong> Normal
                    </div>
                </div>
                <div class="footer">
                    <p>This is an automated support request from RojgarNest Job Portal</p>
                    <p>© 2025 RojgarNest - Find Your Dream Job</p>
                    <div class="badge">Support Ticket</div>
                </div>
            </div>
        </body>
        </html>
        """
        
        # Send email in background
        background_tasks.add_task(
            send_html_email,
            to_email=data.to,
            subject=f"RojgarNest Support: {data.subject[:50]}",
            html_body=html_body
        )
        
        # Store support message in database
        support_doc = {
            "user_email": user_email,
            "user_name": user_name,
            "subject": data.subject,
            "message": data.message,
            "status": "pending",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        await db.support_messages.insert_one(support_doc)
        
        logger.info(f"✅ Support email sent from {user_email} to {data.to}")
        
        return {
            "success": True,
            "message": "Support request sent successfully",
            "sent_to": data.to
        }
        
    except Exception as e:
        logger.error(f"❌ Support email error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/messages")
async def get_support_messages(
    limit: int = 50,
    skip: int = 0,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get user's support messages (for user dashboard)
    """
    user_email = current_user.get("email")
    
    messages = await db.support_messages.find(
        {"user_email": user_email}
    ).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
    
    for msg in messages:
        msg["_id"] = str(msg["_id"])
        if msg.get("created_at"):
            msg["created_at"] = msg["created_at"].isoformat()
    
    total = await db.support_messages.count_documents({"user_email": user_email})
    
    return {
        "success": True,
        "messages": messages,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.get("/admin/messages")
async def get_all_support_messages(
    status: Optional[str] = None,
    limit: int = 100,
    skip: int = 0,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get all support messages (Admin only)
    """
    # Check admin role
    user_role = current_user.get("role", "").lower()
    if user_role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    query = {}
    if status:
        query["status"] = status
    
    messages = await db.support_messages.find(query).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
    
    for msg in messages:
        msg["_id"] = str(msg["_id"])
        if msg.get("created_at"):
            msg["created_at"] = msg["created_at"].isoformat()
    
    total = await db.support_messages.count_documents(query)
    
    return {
        "success": True,
        "messages": messages,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.put("/admin/messages/{message_id}/status")
async def update_support_message_status(
    message_id: str,
    status: str,
    admin_notes: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Update support message status (Admin only)
    """
    # Check admin role
    user_role = current_user.get("role", "").lower()
    if user_role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    if not ObjectId.is_valid(message_id):
        raise HTTPException(status_code=400, detail="Invalid message ID")
    
    result = await db.support_messages.update_one(
        {"_id": ObjectId(message_id)},
        {
            "$set": {
                "status": status,
                "admin_notes": admin_notes,
                "updated_at": datetime.utcnow(),
                "updated_by": current_user.get("email")
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Message not found")
    
    return {
        "success": True,
        "message": f"Status updated to {status}"
    }


print("✅ Support Routes Loaded")