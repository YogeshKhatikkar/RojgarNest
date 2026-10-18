# scripts/remove_ttl_indexes.py
"""
One-time migration script to remove all TTL indexes from MongoDB.
Run: python scripts/remove_ttl_indexes.py
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config.settings import settings


async def remove_all_ttl_indexes():
    """Remove ALL TTL indexes from all collections"""
    
    print("=" * 70)
    print("🔧 REMOVING ALL TTL INDEXES FROM MONGODB")
    print("=" * 70)
    
    client = AsyncIOMotorClient(settings.SAFE_MONGO_URI, **settings.MONGO_OPTIONS)
    db = client[settings.DATABASE_NAME]
    
    # Get all collections
    collections = await db.list_collection_names()
    
    removed_count = 0
    
    for coll_name in collections:
        print(f"\n📋 Checking collection: {coll_name}")
        
        try:
            # Get all indexes for this collection
            indexes = await db[coll_name].index_information()
            
            for index_name, index_info in indexes.items():
                if index_name == '_id_':
                    continue
                
                # Check if this is a TTL index
                if 'expireAfterSeconds' in index_info:
                    print(f"   ⚠️ Found TTL index: {index_name}")
                    print(f"      Keys: {index_info.get('key')}")
                    print(f"      TTL: {index_info.get('expireAfterSeconds')} seconds")
                    
                    try:
                        # Drop the TTL index
                        await db[coll_name].drop_index(index_name)
                        print(f"   ✅ REMOVED TTL index: {index_name}")
                        removed_count += 1
                    except Exception as e:
                        print(f"   ❌ Failed to remove: {e}")
            
        except Exception as e:
            print(f"   ⚠️ Error checking {coll_name}: {e}")
    
    print("\n" + "=" * 70)
    print(f"✅ MIGRATION COMPLETE")
    print(f"   Removed {removed_count} TTL indexes")
    print(f"   ALL DATA IS NOW PERMANENT")
    print("=" * 70)
    
    client.close()


if __name__ == "__main__":
    asyncio.run(remove_all_ttl_indexes())
