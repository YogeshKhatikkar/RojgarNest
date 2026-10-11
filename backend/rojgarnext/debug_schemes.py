# debug_schemes.py
"""
Run this to diagnose why /api/v1/schemes/apply is 404.
    python debug_schemes.py
"""
import sys
import traceback

print("=" * 70)
print("🔍 SCHEMES ROUTE DIAGNOSTIC")
print("=" * 70)

# ----------------------------------------------------------------
# 1. Can we import the schemes router?
# ----------------------------------------------------------------
print("\n[1] Importing app.modules.schemes.routes ...")
try:
    from app.modules.schemes.routes import router as schemes_router
    print(f"    ✅ Imported OK")
    print(f"    Routes on this router: {len(schemes_router.routes)}")
    for r in schemes_router.routes:
        methods = ",".join(r.methods) if hasattr(r, "methods") else "?"
        print(f"       [{methods:12s}] {r.path}")
except Exception as e:
    print(f"    ❌ IMPORT FAILED: {type(e).__name__}: {e}")
    traceback.print_exc()
    sys.exit(1)

# ----------------------------------------------------------------
# 2. Can we import main.app?
# ----------------------------------------------------------------
print("\n[2] Importing app.main ...")
try:
    from app.main import app
    print(f"    ✅ Imported OK")
except Exception as e:
    print(f"    ❌ IMPORT FAILED: {type(e).__name__}: {e}")
    traceback.print_exc()
    sys.exit(1)

# ----------------------------------------------------------------
# 3. Are schemes routes registered in the FastAPI app?
# ----------------------------------------------------------------
print("\n[3] Searching for scheme routes registered in app ...")
scheme_routes = [r for r in app.routes if "/schemes" in getattr(r, "path", "")]
if not scheme_routes:
    print("    ❌ NO /schemes routes found!")
    print("    → You forgot: app.include_router(schemes_router, prefix='/api/v1/schemes')")
    print("      in app/main.py")
    sys.exit(1)

print(f"    ✅ Found {len(scheme_routes)} scheme routes:")
for r in scheme_routes:
    methods = ",".join(r.methods) if hasattr(r, "methods") else "?"
    print(f"       [{methods:12s}] {r.path}")

# ----------------------------------------------------------------
# 4. Exact match test for the failing path
# ----------------------------------------------------------------
print("\n[4] Looking for exact path '/api/v1/schemes/apply' ...")
target = "/api/v1/schemes/apply"
found = [r for r in app.routes if getattr(r, "path", "") == target]
if found:
    print(f"    ✅ FOUND: {target}")
else:
    print(f"    ❌ NOT FOUND: {target}")
    print("    Similar paths that DO exist:")
    for r in scheme_routes:
        p = getattr(r, "path", "")
        if "apply" in p.lower():
            print(f"       → {p}")

print("\n" + "=" * 70)
print("DONE")
print("=" * 70)