# app/core/utils/application_number_generator.py
# ============================================================
# APPLICATION NUMBER GENERATOR
# ============================================================
# ✅ UPDATED FORMAT: YYYYMMDDSSSS (12 digits total)
#    - YYYY   = 4-digit year
#    - MM     = 2-digit month
#    - DD     = 2-digit day
#    - SSSS   = 4-digit sequence number (starts from 0001)
#
# Example: 202611050001, 202611050002, 202611050003
#
# ✅ The sequence resets EVERY DAY (each YYYYMMDD combination
#    starts from 0001).
#
# ✅ Uses atomic MongoDB operations for thread-safety.
# ✅ Shared by ALL application types: schemes, jobs, services.
# ============================================================

import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

module_logger = logging.getLogger(__name__)


# ============================================================
# ✅ INDIA TIMEZONE (IST = UTC + 5:30)
# ------------------------------------------------------------
# We use IST so that "today's date" is correct for Indian users.
# Without this, the date would be off by up to 5.5 hours
# (e.g. 11:00 PM IST = 5:30 PM UTC = previous day in UTC).
# ============================================================
IST = timezone(timedelta(hours=5, minutes=30))


class ApplicationNumberGenerator:
    """
    Generates unique 12-digit application numbers in format YYYYMMDDSSSS.

    - YYYY: 4-digit year
    - MM:   2-digit month
    - DD:   2-digit day
    - SSSS: 4-digit sequence (0001 to 9999) — resets EVERY DAY

    Thread-safe using MongoDB atomic find_one_and_update operation.
    Sequence resets every day (each YYYYMMDD gets its own counter).
    Shared across ALL application types (schemes, jobs, services).
    """

    # Collection to store sequence counters
    COUNTER_COLLECTION = "application_counters"

    # Maximum sequence number (4 digits = 9999)
    MAX_SEQUENCE = 9999

    @classmethod
    async def generate_application_number(cls, db) -> str:
        """
        Generate a unique 12-digit application number.

        Args:
            db: MongoDB database instance

        Returns:
            str: 12-digit application number in format YYYYMMDDSSSS
                 Example: "202611050001"
        """
        try:
            # ✅ Use IST so the date is correct for Indian users
            now = datetime.now(IST)
            year = now.year
            month = now.month
            day = now.day

            # Create the prefix: YYYYMMDD (e.g. "20261105")
            prefix = f"{year}{month:02d}{day:02d}"

            # Counter key for this specific day
            counter_key = f"app_seq_{prefix}"

            # Atomically increment the counter using find_one_and_update
            # This is thread-safe and prevents duplicate numbers
            result = await db[cls.COUNTER_COLLECTION].find_one_and_update(
                {"_id": counter_key},
                {
                    "$inc": {"sequence": 1},
                    "$setOnInsert": {
                        "prefix": prefix,
                        "year": year,
                        "month": month,
                        "day": day,
                        "created_at": now,
                    },
                    "$set": {"updated_at": now},
                },
                upsert=True,
                return_document=True,  # Return the updated document
            )

            # Get the sequence number
            sequence = result.get("sequence", 1) if result else 1

            # Validate sequence doesn't exceed max
            if sequence > cls.MAX_SEQUENCE:
                module_logger.error(
                    f"❌ Application number sequence exceeded maximum "
                    f"({cls.MAX_SEQUENCE}) for {prefix}"
                )
                raise Exception(
                    f"Application sequence limit reached for {prefix}. "
                    f"Maximum {cls.MAX_SEQUENCE} applications per day."
                )

            # Format: YYYYMMDD + 4-digit zero-padded sequence
            application_number = f"{prefix}{sequence:04d}"

            module_logger.info(
                f"✅ Generated application number: {application_number}"
            )

            return application_number

        except Exception as e:
            module_logger.error(
                f"❌ Failed to generate application number: {e}"
            )
            raise

    @classmethod
    async def get_next_sequence_preview(cls, db) -> str:
        """
        Preview what the next application number would be.
        Does NOT increment the counter.

        Args:
            db: MongoDB database instance

        Returns:
            str: Preview of next application number
        """
        try:
            now = datetime.now(IST)
            year = now.year
            month = now.month
            day = now.day
            prefix = f"{year}{month:02d}{day:02d}"
            counter_key = f"app_seq_{prefix}"

            # Get current counter value (without incrementing)
            counter_doc = await db[cls.COUNTER_COLLECTION].find_one(
                {"_id": counter_key}
            )

            current_sequence = (
                counter_doc.get("sequence", 0) if counter_doc else 0
            )
            next_sequence = current_sequence + 1

            return f"{prefix}{next_sequence:04d}"

        except Exception as e:
            module_logger.error(
                f"❌ Failed to preview application number: {e}"
            )
            return "ERROR"

    @classmethod
    async def get_current_day_count(cls, db) -> int:
        """
        Get the count of applications generated today.

        Args:
            db: MongoDB database instance

        Returns:
            int: Number of applications generated today
        """
        try:
            now = datetime.now(IST)
            year = now.year
            month = now.month
            day = now.day
            prefix = f"{year}{month:02d}{day:02d}"
            counter_key = f"app_seq_{prefix}"

            counter_doc = await db[cls.COUNTER_COLLECTION].find_one(
                {"_id": counter_key}
            )

            return counter_doc.get("sequence", 0) if counter_doc else 0

        except Exception as e:
            module_logger.error(f"❌ Failed to get day count: {e}")
            return 0

    @classmethod
    async def reset_daily_counter(
        cls, db, year: int, month: int, day: int
    ) -> bool:
        """
        Reset the counter for a specific day.
        ⚠️ USE WITH CAUTION - This will cause duplicate numbers
        if not careful!

        Args:
            db: MongoDB database instance
            year: Year to reset
            month: Month to reset
            day: Day to reset

        Returns:
            bool: True if reset successful
        """
        try:
            prefix = f"{year}{month:02d}{day:02d}"
            counter_key = f"app_seq_{prefix}"

            await db[cls.COUNTER_COLLECTION].update_one(
                {"_id": counter_key},
                {
                    "$set": {
                        "sequence": 0,
                        "reset_at": datetime.now(IST),
                        "updated_at": datetime.now(IST),
                    }
                },
                upsert=True,
            )

            module_logger.warning(
                f"⚠️ Reset application counter for {prefix}"
            )
            return True

        except Exception as e:
            module_logger.error(f"❌ Failed to reset counter: {e}")
            return False

    @classmethod
    async def ensure_indexes(cls, db) -> None:
        """
        Ensure required indexes exist on the counter collection.
        Call this once during application startup.
        """
        try:
            # The _id field is already indexed by MongoDB
            # Add index on prefix/year/month/day for quick lookups
            await db[cls.COUNTER_COLLECTION].create_index("prefix")
            await db[cls.COUNTER_COLLECTION].create_index("year")
            await db[cls.COUNTER_COLLECTION].create_index("month")
            await db[cls.COUNTER_COLLECTION].create_index("day")

            module_logger.info(
                "✅ Application counter indexes created"
            )
        except Exception as e:
            module_logger.warning(
                f"⚠️ Counter index creation warning: {e}"
            )


# Global instance
application_number_generator = ApplicationNumberGenerator()


print("=" * 70)
print("✅ Application Number Generator Loaded")
print("   Format: YYYYMMDDSSSS (12 digits)")
print("   Example: 202611050001, 202611050002, ...")
print("   Sequence resets EVERY DAY")
print("   Shared by: schemes, jobs, services")
print("=" * 70)