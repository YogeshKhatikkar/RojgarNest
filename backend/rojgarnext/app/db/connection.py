# app/db/connection.py - COMPLETE FIXED VERSION
# ✅ CRITICAL: NO TTL INDEXES - DATA NEVER AUTO-DELETED
# ✅ All indexes are non-expiring
# ✅ No drop_collection calls
# ✅ User data is PERMANENT

from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config.settings import settings
import logging
import asyncio

logger = logging.getLogger(__name__)


async def create_index_safely(collection, keys, **kwargs):
    """
    Create index safely - ignore if already exists.

    ⚠️ CRITICAL: We BLOCK expireAfterSeconds to prevent auto-deletion!
    Any attempt to create a TTL index will be intercepted and stripped.
    """
    # ✅ STRIP expireAfterSeconds to prevent auto-deletion
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
            logger.warning(f"Index creation warning for {keys}: {e}")
            return False


async def drop_unused_collections():
    """
    ✅ DISABLED - This function NO LONGER drops any collections.
    User data must NEVER be automatically removed.
    """
    logger.info("✅ drop_unused_collections() DISABLED - No collections will be dropped")
    return []


async def connect_db():
    """Connect to MongoDB (supports both local and Atlas)"""
    global client, db

    try:
        mongo_uri = settings.SAFE_MONGO_URI

        print("=" * 60)
        print(f"🔗 Connecting to MongoDB...")
        print(f"   Environment: {settings.ENVIRONMENT}")
        db_type = 'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'
        print(f"   Database Type: {db_type}")
        print("=" * 60)

        options = settings.MONGO_OPTIONS.copy()

        max_retries = 3
        last_error = None

        for attempt in range(max_retries):
            try:
                client = AsyncIOMotorClient(mongo_uri, **options)
                await asyncio.wait_for(client.admin.command("ping"), timeout=15.0)
                print(f"✅ MongoDB ping successful! (attempt {attempt + 1})")
                break
            except asyncio.TimeoutError:
                print(f"⚠️ Attempt {attempt + 1} timed out")
                last_error = "Connection timeout"
                if attempt < max_retries - 1:
                    await asyncio.sleep(3)
            except Exception as e:
                print(f"⚠️ Attempt {attempt + 1} failed: {e}")
                last_error = str(e)
                if attempt < max_retries - 1:
                    await asyncio.sleep(3)
        else:
            raise Exception(
                f"All {max_retries} connection attempts failed. Last error: {last_error}"
            )

        db = client[settings.DATABASE_NAME]
        print(f"✅ Connected to database: {settings.DATABASE_NAME}")

        # ✅ Create collections if they don't exist
        collections = await db.list_collection_names()

        required_collections = [
            "auth", "profile", "job",
            "applications",
            "resumes", "sessions", "notifications", "ai_insights",
            "reports", "security"
        ]

        for coll_name in required_collections:
            if coll_name not in collections:
                await db.create_collection(coll_name)
                print(f"📁 Created collection: {coll_name}")

        # ✅ Setup SAFE indexes (NO TTL)
        await create_all_indexes(db)
        await verify_and_show_data(db)

        return True

    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        print("\n📌 Troubleshooting:")
        print("   1. Check your internet connection")
        print("   2. Verify MongoDB Atlas credentials")
        print("   3. Check IP whitelist in MongoDB Atlas Network Access")
        print("   4. Try: pip install --upgrade motor")
        raise


async def create_all_indexes(db):
    """
    Create all indexes - NO TTL INDEXES ALLOWED!

    ✅ ALL DATA IS PERMANENT
    ✅ No automatic deletion
    """
    print("\n📊 Creating database indexes (NO TTL - PERMANENT DATA)...")

    # ==================== AUTH INDEXES (NO TTL) ====================
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    await create_index_safely(db.auth, "failed_attempts")
    await create_index_safely(db.auth, "lock_until")
    # ❌ REMOVED: email_otp_expiry TTL - was deleting user records!
    # ❌ REMOVED: mobile_otp_expiry TTL - was deleting user records!

    # ==================== JOB INDEXES ====================
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    await create_index_safely(db.job, "color_type")

    # ==================== PROFILE INDEXES ====================
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    await create_index_safely(db.profile, "category")
    await create_index_safely(db.profile, "disability.is_disabled")
    await create_index_safely(db.profile, "disability.category")
    await create_index_safely(db.profile, [("skills.name", 1)])

    # ==================== UNIFIED APPLICATIONS ====================
    await create_index_safely(db.applications, "application_type")
    await create_index_safely(db.applications, "user_email")
    await create_index_safely(db.applications, "user_id")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "payment_verification_status")
    await create_index_safely(db.applications, "created_at")
    await create_index_safely(db.applications, "updated_at")
    await create_index_safely(db.applications, "job_id", sparse=True)
    await create_index_safely(db.applications, "service_id", sparse=True)
    await create_index_safely(db.applications, "transaction_id", sparse=True)
    await create_index_safely(db.applications, "payment_id", sparse=True)

    # Compound indexes for efficient queries
    await create_index_safely(db.applications, [("user_email", 1), ("application_type", 1)])
    await create_index_safely(db.applications, [("user_email", 1), ("status", 1)])
    await create_index_safely(db.applications, [("application_type", 1), ("status", 1)])
    await create_index_safely(db.applications, [("job_id", 1), ("user_email", 1)])
    await create_index_safely(db.applications, [("service_id", 1), ("sub_type_id", 1), ("user_email", 1)])
    await create_index_safely(db.applications, [("payment_verification_status", 1), ("status", 1)])

    # ❌ REMOVED: expires_at TTL - was deleting applications!

    # ==================== SESSIONS INDEXES (NO TTL) ====================
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at")   # ✅ NO TTL
    await create_index_safely(db.sessions, "ip")
    await create_index_safely(db.sessions, "device")
    await create_index_safely(db.sessions, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.sessions, [("user_id", 1), ("is_active", 1)])
    await create_index_safely(db.sessions, [("user_id", 1), ("is_archived", 1)])

    # ==================== NOTIFICATIONS INDEXES (NO TTL) ====================
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")   # ✅ NO TTL
    await create_index_safely(db.notifications, [("user_id", 1), ("read", 1)])

    # ==================== SECURITY INDEXES (NO TTL) ====================
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    await create_index_safely(db.security, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.security, "severity")
    await create_index_safely(db.security, [("ip_address", 1), ("type", 1)])
    await create_index_safely(db.security, [("user_id", 1), ("type", 1)])

    # ==================== AI INSIGHTS INDEXES (NO TTL) ====================
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    await create_index_safely(db.ai_insights, "analysis_hash", unique=True, sparse=True)
    await create_index_safely(db.ai_insights, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.ai_insights, [("email", 1), ("type", 1), ("is_current", 1)])
    await create_index_safely(db.ai_insights, [("type", 1), ("status", 1), ("progress_percentage", -1)])

    # ==================== RESUMES INDEXES ====================
    await create_index_safely(db.resumes, "user_email")
    await create_index_safely(db.resumes, "created_at")
    await create_index_safely(db.resumes, "is_primary")

    # ==================== BACKUP RECORDS ====================
    await create_index_safely(db.backup_records, "created_at")

    print("✅ All indexes created successfully (NO TTL - DATA IS PERMANENT)")
    print("=" * 60)


async def verify_and_show_data(db):
    """Verify connection and show collection statistics"""
    print("\n📊 DATABASE VERIFICATION")
    print("=" * 60)

    try:
        stats = await db.command("dbStats")
        print(f"📁 Database Name: {settings.DATABASE_NAME}")
        print(f"📊 Total Collections: {stats.get('collections', 0)}")
        print(f"💾 Data Size: {stats.get('dataSize', 0) / (1024 * 1024):.2f} MB")
        print(f"📈 Index Size: {stats.get('indexSize', 0) / (1024 * 1024):.2f} MB")

        print("\n📋 COLLECTION DETAILS:")
        print("-" * 60)

        collections = await db.list_collection_names()
        for coll_name in sorted(collections):
            try:
                count = await db[coll_name].count_documents({})
                print(f"   📄 {coll_name}: {count:,} documents")
            except Exception:
                print(f"   📄 {coll_name}: (error counting)")

        print("\n" + "=" * 60)
        print("✅ DATABASE VERIFICATION COMPLETE")
        print("✅ ALL DATA IS PERMANENT - NO AUTO-DELETION")
        print("=" * 60)

    except Exception as e:
        print(f"⚠️ Could not get database stats: {e}")


async def ensure_connection():
    """Ensure database connection is established"""
    global db, client
    if db is None:
        await connect_db()
    return db


def get_db():
    """Get database instance"""
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
    """Close MongoDB connection"""
    global client
    if client:
        client.close()
        print("✅ MongoDB Connection Closed")


print("=" * 70)
print("✅ Database Connection Module Loaded")
print("   ✅ NO TTL INDEXES - Data is PERMANENT")
print("   ✅ NO AUTO-DELETION of any records")
print("   ✅ Single 'applications' collection for ALL applications")
print("=" * 70)