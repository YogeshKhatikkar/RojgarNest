# app/core/database/connection.py - COMPLETE FIXED VERSION
# ✅ CRITICAL: NO TTL INDEXES - DATA NEVER AUTO-DELETED

from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config.settings import settings
import logging
import asyncio

logger = logging.getLogger(__name__)

client = None
db = None


async def create_index_safely(collection, keys, **kwargs):
    """
    Create index safely - ignore if already exists.

    ⚠️ CRITICAL: We BLOCK expireAfterSeconds to prevent auto-deletion!
    """
    if 'expireAfterSeconds' in kwargs:
        logger.warning(
            f"🚫 BLOCKED TTL index on '{collection.name}' for keys {keys}. "
            f"Data will NOT be auto-deleted."
        )
        kwargs = {k: v for k, v in kwargs.items() if k != 'expireAfterSeconds'}

    try:
        await collection.create_index(keys, **kwargs)
        return True
    except Exception as e:
        error_msg = str(e)
        if (
            "already exists" in error_msg
            or "IndexKeySpecsConflict" in error_msg
            or "IndexOptionsConflict" in error_msg
        ):
            logger.debug(f"Index already exists: {keys}")
            return False
        elif "DuplicateKey" in error_msg or "E11000" in error_msg:
            logger.warning(f"⚠️ Duplicate key found - skipping index: {keys}")
            return False
        else:
            logger.warning(f"Index creation warning: {e}")
            return False


async def drop_unused_collections():
    """✅ DISABLED - No collections will be dropped"""
    logger.info("✅ drop_unused_collections() DISABLED - No collections dropped")
    return []


async def connect_db():
    """Connect to MongoDB - NO AUTO-DELETION"""
    global client, db

    try:
        mongo_uri = settings.SAFE_MONGO_URI

        print("=" * 60)
        print(f"🔗 Connecting to MongoDB...")
        print(f"   Environment: {settings.ENVIRONMENT}")
        print("=" * 60)

        options = settings.MONGO_OPTIONS.copy()

        max_retries = 3
        for attempt in range(max_retries):
            try:
                client = AsyncIOMotorClient(mongo_uri, **options)
                await asyncio.wait_for(client.admin.command("ping"), timeout=10.0)
                print(f"✅ MongoDB ping successful!")
                break
            except Exception as e:
                print(f"⚠️ Attempt {attempt + 1} failed: {e}")
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(3)

        db = client[settings.DATABASE_NAME]
        print(f"✅ Connected to database: {settings.DATABASE_NAME}")

        # Create collections if needed (never drops)
        collections = await db.list_collection_names()
        required_collections = [
            "auth", "profile", "job", "applications", "payments",
            "resumes", "sessions", "notifications", "ai_insights",
            "reports", "security"
        ]

        for coll_name in required_collections:
            if coll_name not in collections:
                await db.create_collection(coll_name)
                print(f"📁 Created collection: {coll_name}")

        # ✅ Create indexes WITHOUT TTL
        await create_all_indexes(db)
        await verify_and_show_data(db)

        return True

    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        raise


async def create_all_indexes(db):
    """Create indexes - NO TTL ALLOWED"""
    print("\n📊 Creating indexes (NO TTL - PERMANENT DATA)...")

    # Auth indexes
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    # ❌ NO TTL for OTP fields

    # Job indexes
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, "organization")

    # Applications indexes
    await create_index_safely(db.applications, "job_id")
    await create_index_safely(db.applications, "applicant_email")
    await create_index_safely(db.applications, "status")
    # ❌ NO TTL for expires_at

    # Sessions indexes
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    # ❌ NO TTL for sessions

    # Notifications indexes
    await create_index_safely(db.notifications, "user_id")
    # ❌ NO TTL for notifications

    # Security indexes
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    # ❌ NO TTL for security

    print("✅ All indexes created (NO TTL - DATA IS PERMANENT)")


async def verify_and_show_data(db):
    """Verify connection and show stats"""
    print("\n📊 DATABASE VERIFICATION")
    print("=" * 60)

    try:
        collections = await db.list_collection_names()
        for coll_name in sorted(collections):
            try:
                count = await db[coll_name].count_documents({})
                print(f"   📄 {coll_name}: {count:,} documents")
            except Exception:
                pass

        print("=" * 60)
        print("✅ DATA IS PERMANENT - NO AUTO-DELETION")
        print("=" * 60)
    except Exception as e:
        print(f"⚠️ Stats error: {e}")


async def ensure_connection():
    global db, client
    if db is None:
        await connect_db()
    return db


def get_db():
    global db
    if db is None:
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(connect_db())
            else:
                loop.run_until_complete(connect_db())
        except RuntimeError:
            import asyncio
            asyncio.run(connect_db())
    return db


async def close_db():
    global client
    if client:
        client.close()
        print("✅ MongoDB Connection Closed")


print("=" * 70)
print("✅ Database Connection Module Loaded")
print("   ✅ NO TTL INDEXES - Data is PERMANENT")
print("=" * 70)