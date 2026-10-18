# app/modules/notification/watcher.py
import asyncio
from app.db.connection import get_db
from app.modules.notification.service import send_new_job_notification
from app.core.utils.logger import logger

async def start_job_watcher():
    """MongoDB Change Stream se real-time new job detect karega"""
    db = get_db()
    pipeline = [{"$match": {"operationType": "insert"}}]

    try:
        async with db.job.watch(pipeline, full_document="updateLookup") as stream:
            async for change in stream:
                job_doc = change.get("fullDocument")
                if job_doc:
                    logger.info(f"🔴 New Job Detected via Change Stream: {job_doc.get('post_name')}")
                    # Background task ke through notification bhejo
                    # Note: yahan background_tasks nahi hai, isliye simple call
                    # Production mein better queue (Celery/Redis) use karo
                    await send_new_job_notification(job_doc, None)   # adjust if needed
    except asyncio.CancelledError:
        logger.info("Job Watcher cancelled")
    except Exception as e:
        logger.error(f"Job Watcher Error: {e}")