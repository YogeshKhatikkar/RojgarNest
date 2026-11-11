# migrate_to_atlas_fixed.py
"""
Fixed migration script - no connection close errors
"""

import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def migrate_data():
    print("\n" + "=" * 70)
    print("🔄 MIGRATING DATA FROM LOCAL TO ATLAS")
    print("=" * 70)
    
    # Local MongoDB (source)
    local_uri = "mongodb://localhost:27017"
    local_db_name = "RojgarNest"
    
    # Atlas MongoDB (destination)
    atlas_uri = "mongodb+srv://rojgarnest_db:RojgarNest%40123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority"
    atlas_db_name = "RojgarNest"
    
    print("\n📡 Connecting to databases...")
    
    # Connect to both databases
    local_client = AsyncIOMotorClient(local_uri)
    atlas_client = AsyncIOMotorClient(atlas_uri)
    
    local_db = local_client[local_db_name]
    atlas_db = atlas_client[atlas_db_name]
    
    # Collections to migrate
    collections = [
        "auth", "profile", "job", "applications", "notifications",
        "sessions", "payments", "resumes", "ai_insights", "reports", "security"
    ]
    
    migration_results = {}
    
    for coll_name in collections:
        print(f"\n📋 Migrating {coll_name}...")
        
        try:
            # Get all documents from local
            docs = await local_db[coll_name].find({}).to_list(length=10000)
            
            if docs:
                # Insert into Atlas (handle duplicates)
                for doc in docs:
                    # Remove _id to avoid duplicate key errors
                    if "_id" in doc:
                        del doc["_id"]
                
                if docs:
                    result = await atlas_db[coll_name].insert_many(docs)
                    migration_results[coll_name] = {
                        "status": "success",
                        "count": len(docs),
                        "inserted": len(result.inserted_ids)
                    }
                    print(f"   ✅ Migrated {len(docs)} documents")
                else:
                    migration_results[coll_name] = {"status": "empty", "count": 0}
                    print(f"   ⏭️  No documents found")
            else:
                migration_results[coll_name] = {"status": "empty", "count": 0}
                print(f"   ⏭️  Collection empty or doesn't exist")
                
        except Exception as e:
            migration_results[coll_name] = {"status": "error", "error": str(e)}
            print(f"   ❌ Error: {e}")
    
    # Print summary
    print("\n" + "=" * 70)
    print("📊 MIGRATION SUMMARY")
    print("=" * 70)
    
    total_docs = 0
    for coll, result in migration_results.items():
        if result["status"] == "success":
            total_docs += result["count"]
            print(f"   ✅ {coll}: {result['count']} documents migrated")
        elif result["status"] == "empty":
            print(f"   ⏭️  {coll}: empty")
        else:
            print(f"   ❌ {coll}: {result.get('error', 'failed')}")
    
    print(f"\n📊 Total documents migrated: {total_docs}")
    
    # Verify Atlas data
    print("\n🔍 Verifying Atlas data...")
    for coll_name in ["auth", "profile", "job", "applications", "notifications", "sessions"]:
        count = await atlas_db[coll_name].count_documents({})
        if count > 0:
            print(f"   ✅ {coll_name}: {count} documents in Atlas")
        else:
            print(f"   ⚠️ {coll_name}: {count} documents")
    
    # Close connections properly (no await needed for close)
    local_client.close()
    atlas_client.close()
    
    print("\n" + "=" * 70)
    print("🎉 MIGRATION COMPLETE!")
    print("=" * 70)
    return migration_results

async def verify_atlas_data():
    """Verify all data in Atlas"""
    print("\n" + "=" * 70)
    print("🔍 VERIFYING ATLAS DATABASE")
    print("=" * 70)
    
    atlas_uri = "mongodb+srv://rojgarnest_db:RojgarNest%40123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority"
    client = AsyncIOMotorClient(atlas_uri)
    db = client["RojgarNest"]
    
    collections = await db.list_collection_names()
    print(f"\n📋 Collections in Atlas ({len(collections)}):")
    print("-" * 50)
    
    total = 0
    for coll in sorted(collections):
        count = await db[coll].count_documents({})
        total += count
        print(f"   📄 {coll}: {count:,} documents")
        
        # Show sample from each collection
        sample = await db[coll].find_one({})
        if sample:
            sample_id = str(sample.get("_id", "unknown"))[:8]
            print(f"      Sample ID: {sample_id}...")
    
    print(f"\n📊 TOTAL DOCUMENTS: {total:,}")
    
    # Show user data
    print("\n👥 USERS IN AUTH:")
    users = await db["auth"].find({}).to_list(length=10)
    for user in users:
        print(f"   - {user.get('email')} (Role: {user.get('role', 'user')})")
    
    print("\n💼 JOBS:")
    jobs = await db["job"].find({}).to_list(length=10)
    for job in jobs:
        print(f"   - {job.get('post_name')} at {job.get('organization')}")
    
    client.close()
    print("\n" + "=" * 70)
    print("✅ VERIFICATION COMPLETE!")
    print("=" * 70)

if __name__ == "__main__":
    async def main():
        await migrate_data()
        await verify_atlas_data()
    
    asyncio.run(main())
