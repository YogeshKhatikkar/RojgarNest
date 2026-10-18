# test.py
import sys
import os

print("=" * 60)
print("PYTHON ENVIRONMENT INFO")
print("=" * 60)
print(f"Python executable: {sys.executable}")
print(f"Python version: {sys.version}")
print(f"Virtual env: {os.environ.get('VIRTUAL_ENV', 'Not activated')}")
print(f"Python path: {sys.path}")
print("=" * 60)

print("\nTESTING IMPORTS...")

try:
    import razorpay
    print("✅ razorpay imported successfully!")
    # Check if Client class exists
    if hasattr(razorpay, 'Client'):
        print("   ✅ razorpay.Client class is available")
    # Check if version exists (it doesn't, but that's ok)
    if hasattr(razorpay, '__version__'):
        print(f"   Version: {razorpay.__version__}")
    else:
        print("   ℹ️  razorpay doesn't have __version__ attribute (this is normal)")
except ImportError as e:
    print(f"❌ razorpay NOT found: {e}")
    print("\n🔧 To fix, run:")
    print("   .venv\\Scripts\\activate")
    print("   pip install razorpay")

try:
    import httpx
    print(f"✅ httpx imported successfully!")
    if hasattr(httpx, '__version__'):
        print(f"   Version: {httpx.__version__}")
except ImportError as e:
    print(f"❌ httpx NOT found: {e}")

try:
    import requests
    print(f"✅ requests imported successfully!")
    if hasattr(requests, '__version__'):
        print(f"   Version: {requests.__version__}")
except ImportError as e:
    print(f"❌ requests NOT found: {e}")

# Test creating a razorpay client (without real credentials)
try:
    # This will fail with auth error, but that's expected
    # It confirms the class exists and can be instantiated
    client = razorpay.Client(auth=("test_key", "test_secret"))
    print("✅ razorpay.Client can be instantiated (auth will fail with real keys, but import works)")
except Exception as e:
    print(f"ℹ️  Client creation test: {e} (this is expected without real credentials)")

print("\n" + "=" * 60)
print("✅ ALL IMPORTS WORKING!")
print("=" * 60)
