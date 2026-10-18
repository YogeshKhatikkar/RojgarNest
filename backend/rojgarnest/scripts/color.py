# scripts/color.py
# One-time script to backfill color_type for existing jobs
# Safe + idempotent: only updates jobs missing color_type

import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.connection import connect_db, get_db, close_db


# ✅ Must match Flutter's JobColorMasterData.colorKeys exactly
VALID_COLORS = {
    "blue", "green", "red", "orange", "purple", "teal",
    "pink", "indigo", "amber", "cyan", "grey", "white",
}

# Map job_type → color_type
DEFAULT_MAP = {
    "government": "green",
    "private":    "blue",
    "remote":     "purple",
    "hybrid":     "orange",
}


async def backfill():
    await connect_db()
    db = get_db()

    total     = await db.job.count_documents({})
    missing   = await db.job.count_documents({"color_type": {"$exists": False}})
    invalid   = await db.job.count_documents({
        "color_type": {"$exists": True, "$nin": list(VALID_COLORS)}
    })

    print(f"📊 Total jobs       : {total}")
    print(f"📊 Missing color    : {missing}")
    print(f"📊 Invalid color    : {invalid}")
    print("-" * 40)

    # ---- 1) Backfill missing ----
    updated_missing = 0
    cursor = db.job.find({"color_type": {"$exists": False}})
    async for doc in cursor:
        jt = (doc.get("job_type") or "private").lower().strip()
        color = DEFAULT_MAP.get(jt, "blue")
        # Safety: never write an invalid value
        if color not in VALID_COLORS:
            color = "blue"
        await db.job.update_one(
            {"_id": doc["_id"]},
            {"$set": {"color_type": color}},
        )
        updated_missing += 1

    # ---- 2) Normalize invalid ----
    updated_invalid = 0
    if invalid > 0:
        cursor2 = db.job.find({
            "color_type": {"$exists": True, "$nin": list(VALID_COLORS)}
        })
        async for doc in cursor2:
            raw = (doc.get("color_type") or "").lower().strip()
            # normalize "gray" → "grey"
            if raw == "gray":
                raw = "grey"
            if raw not in VALID_COLORS:
                raw = "blue"
            await db.job.update_one(
                {"_id": doc["_id"]},
                {"$set": {"color_type": raw}},
            )
            updated_invalid += 1

    print(f"✅ Backfilled (missing)  : {updated_missing}")
    print(f"✅ Normalized (invalid)  : {updated_invalid}")

    # ---- 3) Summary by color ----
    print("-" * 40)
    print("📈 Final distribution:")
    pipeline = [
        {"$group": {"_id": "$color_type", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
    ]
    async for row in db.job.aggregate(pipeline):
        print(f"   {row['_id']:<8} → {row['count']}")

    await close_db()


if __name__ == "__main__":
    asyncio.run(backfill())
