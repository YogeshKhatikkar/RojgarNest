# test_atlas_connection.py - COMPLETE WORKING VERSION

"""
Test MongoDB Connection (Atlas + Local)
Run: python test_atlas_connection.py
"""

import asyncio
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

def check_and_install_packages():
    """Check and install required packages"""
    required_packages = {
        'motor': 'motor',
        'pymongo': 'pymongo',
        'dotenv': 'python-dotenv'
    }
    
    missing = []
    for module, package in required_packages.items():
        try:
            if module == 'dotenv':
                __import__('dotenv')
            else:
                __import__(module)
            print(f"✅ {package} installed")
        except ImportError:
            print(f"⚠️ {package} not installed")
            missing.append(package)
    
    if missing:
        print(f"\n📦 Installing missing packages: {', '.join(missing)}")
        for package in missing:
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", package])
                print(f"✅ {package} installed successfully")
            except Exception as e:
                print(f"❌ Failed to install {package}: {e}")
                return False
    return True

async def test_local_mongodb():
    """Test local MongoDB connection"""
    print("\n" + "=" * 70)
    print("🔄 TESTING LOCAL MONGODB...")
    print("=" * 70)
    
    try:
        from motor.motor_asyncio import AsyncIOMotorClient
        
        # Connect to local MongoDB
        client = AsyncIOMotorClient(
            "mongodb://localhost:27017",
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=5000,
        )
        
        # Test connection
        await client.admin.command('ping')
        print("✅ Connected to LOCAL MongoDB successfully!")
        
        db = client["RojgarNest"]
        
        # Get collections
        collections = await db.list_collection_names()
        print(f"\n📊 Collections in Local DB ({len(collections)}):")
        print("-" * 50)
        
        if collections:
            for coll_name in sorted(collections):
                try:
                    count = await db[coll_name].count_documents({})
                    print(f"   📄 {coll_name}: {count:,} documents")
                except Exception as e:
                    print(f"   📄 {coll_name}: error - {e}")
        else:
            print("   No collections found in local database")
            print("   Creating initial collections...")
            
            # Create required collections
            required_collections = [
                "auth", "profile", "job", "applications", "payments",
                "resumes", "sessions", "notifications", "ai_insights",
                "reports", "security"
            ]
            
            for coll_name in required_collections:
                try:
                    await db.create_collection(coll_name)
                    print(f"   ✅ Created collection: {coll_name}")
                except Exception as e:
                    if "already exists" in str(e):
                        print(f"   ⏭️ Collection already exists: {coll_name}")
                    else:
                        print(f"   ❌ Error creating {coll_name}: {e}")
            
            print("\n📊 Collections created successfully!")
        
        # Show final collection list
        final_collections = await db.list_collection_names()
        print(f"\n📋 Final collections ({len(final_collections)}):")
        for coll_name in sorted(final_collections):
            try:
                count = await db[coll_name].count_documents({})
                print(f"   📄 {coll_name}: {count:,} documents")
            except:
                print(f"   📄 {coll_name}: (error counting)")
        
        await client.close()
        print("\n✅ Local MongoDB test completed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Local MongoDB failed: {e}")
        print("\n📌 To start local MongoDB:")
        print("   Windows: mongod --dbpath C:\\data\\db")
        print("   Mac/Linux: sudo systemctl start mongod")
        print("   Or download from: https://www.mongodb.com/try/download/community")
        return False

async def test_atlas_mongodb():
    """Test MongoDB Atlas connection with multiple SSL configs"""
    print("\n" + "=" * 70)
    print("🔄 TESTING MONGODB ATLAS...")
    print("=" * 70)
    
    # Try multiple URIs with different SSL configurations
    test_uris = [
        {
            'uri': "mongodb+srv://rojgarnest_db:RojgarNest123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority&tlsAllowInvalidCertificates=true",
            'name': "Standard + tlsAllowInvalidCertificates"
        },
        {
            'uri': "mongodb+srv://rojgarnest_db:RojgarNest123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority&tls=true&tlsAllowInvalidCertificates=true",
            'name': "tls=true + tlsAllowInvalidCertificates"
        },
        {
            'uri': "mongodb+srv://rojgarnest_db:RojgarNest123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority",
            'name': "No tls params"
        },
        {
            'uri': "mongodb://rojgarnest_db:RojgarNest123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority&ssl=true",
            'name': "mongodb:// protocol with ssl=true"
        },
        {
            'uri': "mongodb+srv://rojgarnest_db:RojgarNest123@cluster0.bmbx8bu.mongodb.net/RojgarNest?retryWrites=true&w=majority&ssl=true&tlsAllowInvalidCertificates=true",
            'name': "ssl=true + tlsAllowInvalidCertificates"
        },
    ]
    
    print(f"\n📋 Testing with {len(test_uris)} different URI configurations...")
    
    for i, config in enumerate(test_uris, 1):
        uri = config['uri']
        name = config['name']
        print(f"\n🔄 Attempt {i}: {name}")
        print(f"   URI: {uri[:80]}...")
        
        try:
            from motor.motor_asyncio import AsyncIOMotorClient
            
            client = AsyncIOMotorClient(
                uri,
                serverSelectionTimeoutMS=30000,
                connectTimeoutMS=30000,
                socketTimeoutMS=30000,
                retryWrites=True,
                retryReads=True,
            )
            
            await client.admin.command('ping')
            print(f"✅ SUCCESS! Connected with URI {i}")
            
            db = client["RojgarNest"]
            collections = await db.list_collection_names()
            print(f"\n📊 Collections in Atlas ({len(collections)}):")
            for coll_name in sorted(collections):
                try:
                    count = await db[coll_name].count_documents({})
                    print(f"   📄 {coll_name}: {count:,} documents")
                except:
                    print(f"   📄 {coll_name}: (count error)")
            
            await client.close()
            return True
            
        except Exception as e:
            error_str = str(e)
            if "SSL" in error_str or "TLS" in error_str:
                print(f"⚠️ SSL/TLS error on attempt {i}")
            elif "getaddrinfo" in error_str:
                print(f"⚠️ DNS resolution error on attempt {i}")
            else:
                print(f"⚠️ Error on attempt {i}: {error_str[:100]}")
            continue
    
    return False

async def main():
    print("\n" + "🚀" * 35)
    print("   MONGODB CONNECTION TEST")
    print("🚀" * 35)
    
    # Check packages
    if not check_and_install_packages():
        print("❌ Package installation failed")
        sys.exit(1)
    
    # Try Local first (since Atlas is failing)
    print("\n📌 Testing Local MongoDB first...")
    local_success = await test_local_mongodb()
    
    if local_success:
        print("\n" + "=" * 70)
        print("✅ LOCAL MONGODB IS WORKING!")
        print("=" * 70)
        print("\n📌 To use local MongoDB:")
        print("   Update .env file:")
        print("   MONGO_URI=mongodb://localhost:27017")
        print("   DATABASE_NAME=RojgarNest")
        print("   ENVIRONMENT=development")
        print("\n🚀 Start the backend:")
        print("   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
        sys.exit(0)
    
    # If Local fails, try Atlas
    print("\n📌 Local failed, trying MongoDB Atlas...")
    atlas_success = await test_atlas_mongodb()
    
    if atlas_success:
        print("\n" + "=" * 70)
        print("✅ MONGODB ATLAS IS WORKING!")
        print("=" * 70)
        sys.exit(0)
    
    # If all fail
    print("\n" + "=" * 70)
    print("❌ NO MONGODB CONNECTION AVAILABLE")
    print("=" * 70)
    print("\n📌 TROUBLESHOOTING:")
    print("   1. Install MongoDB locally: https://www.mongodb.com/try/download/community")
    print("   2. Start MongoDB: mongod --dbpath C:\\data\\db")
    print("   3. Or check Atlas: https://cloud.mongodb.com")
    print("   4. Add IP 0.0.0.0/0 to Atlas Network Access")
    sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
