# app/core/utils/application_number_generator.py
# ============================================================
# APPLICATION NUMBER GENERATOR
# ============================================================
# Format: YYYYMMSSSSS (10 digits total)
# - YYYY = 4-digit year
# - MM   = 2-digit month
# - SSSSS = 5-digit sequence number (starts from 00001)
#
# Example: 2026100001, 2026100002, 2026100003
#
# The sequence resets every month (each YYYYMM combination
# starts from 00001).
#
# Uses atomic MongoDB operations for thread-safety.
# Shared by ALL application types: schemes, jobs, services.
# ============================================================

import logging
from datetime import datetime
from typing import Optional

module_logger = logging.getLogger(__name__)


class ApplicationNumberGenerator:
    """
    Generates unique 10-digit application numbers in format YYYYMMSSSSS.

    - YYYY: 4-digit year
    - MM: 2-digit month
    - SSSSS: 5-digit sequence (00001 to 99999)

    Thread-safe using MongoDB atomic find_one_and_update operation.
    Sequence resets every month.
    Shared across ALL application types (schemes, jobs, services).
    """

    # Collection to store sequence counters
    COUNTER_COLLECTION = "application_counters"

    # Maximum sequence number (5 digits = 99999)
    MAX_SEQUENCE = 99999

    @classmethod
    async def generate_application_number(cls, db) -> str:
        """
        Generate a unique 10-digit application number.

        Args:
            db: MongoDB database instance

        Returns:
            str: 10-digit application number in format YYYYMMSSSSS
                 Example: "2026100001"
        """
        try:
            now = datetime.utcnow()
            year = now.year
            month = now.month

            # Create the prefix: YYYYMM (e.g., "202610")
            prefix = f"{year}{month:02d}"

            # Counter key for this month (shared by ALL app types)
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
                    f"Maximum {cls.MAX_SEQUENCE} applications per month."
                )

            # Format: YYYYMM + 5-digit zero-padded sequence
            application_number = f"{prefix}{sequence:05d}"

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
            now = datetime.utcnow()
            year = now.year
            month = now.month
            prefix = f"{year}{month:02d}"
            counter_key = f"app_seq_{prefix}"

            # Get current counter value (without incrementing)
            counter_doc = await db[cls.COUNTER_COLLECTION].find_one(
                {"_id": counter_key}
            )

            current_sequence = (
                counter_doc.get("sequence", 0) if counter_doc else 0
            )
            next_sequence = current_sequence + 1

            return f"{prefix}{next_sequence:05d}"

        except Exception as e:
            module_logger.error(
                f"❌ Failed to preview application number: {e}"
            )
            return "ERROR"

    @classmethod
    async def get_current_month_count(cls, db) -> int:
        """
        Get the count of applications generated this month.

        Args:
            db: MongoDB database instance

        Returns:
            int: Number of applications generated this month
        """
        try:
            now = datetime.utcnow()
            year = now.year
            month = now.month
            prefix = f"{year}{month:02d}"
            counter_key = f"app_seq_{prefix}"

            counter_doc = await db[cls.COUNTER_COLLECTION].find_one(
                {"_id": counter_key}
            )

            return counter_doc.get("sequence", 0) if counter_doc else 0

        except Exception as e:
            module_logger.error(f"❌ Failed to get month count: {e}")
            return 0

    @classmethod
    async def reset_monthly_counter(
        cls, db, year: int, month: int
    ) -> bool:
        """
        Reset the counter for a specific month.
        ⚠️ USE WITH CAUTION - This will cause duplicate numbers
        if not careful!

        Args:
            db: MongoDB database instance
            year: Year to reset
            month: Month to reset

        Returns:
            bool: True if reset successful
        """
        try:
            prefix = f"{year}{month:02d}"
            counter_key = f"app_seq_{prefix}"

            await db[cls.COUNTER_COLLECTION].update_one(
                {"_id": counter_key},
                {
                    "$set": {
                        "sequence": 0,
                        "reset_at": datetime.utcnow(),
                        "updated_at": datetime.utcnow(),
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
            # Add index on prefix/year/month for quick lookups
            await db[cls.COUNTER_COLLECTION].create_index("prefix")
            await db[cls.COUNTER_COLLECTION].create_index("year")
            await db[cls.COUNTER_COLLECTION].create_index("month")

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
print("   Format: YYYYMMSSSSS (10 digits)")
print("   Example: 2026100001, 2026100002, ...")
print("   Sequence resets every month")
print("   Shared by: schemes, jobs, services")
print("=" * 70)