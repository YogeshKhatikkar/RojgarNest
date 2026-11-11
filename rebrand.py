#!/usr/bin/env python3
# rebrand.py
# ============================================================
# SEVANEXT REBRAND SCRIPT
# ============================================================
# Usage:
#   python rebrand.py              → Dry run (preview only)
#   python rebrand.py --apply      → Apply changes
#   python rebrand.py --rollback   → Restore from backup
# ============================================================

import os
import sys
import shutil
import re
import argparse
from datetime import datetime
from pathlib import Path

# ============================================================
# CONFIG — Yahan apne project ka path set karo
# ============================================================
PROJECT_ROOT = Path(__file__).parent.resolve()

BACKEND_DIR = PROJECT_ROOT / "backend" / "sevanext"
FRONTEND_DIR = PROJECT_ROOT / "frontend" / "sevanext"

# Backup folder
BACKUP_ROOT = PROJECT_ROOT / f"_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

# ============================================================
# REPLACEMENT RULES — Order matters! Specific → generic
# ============================================================
REPLACEMENTS = [
    # Cloudinary folder path (MOST SPECIFIC FIRST)
    ("RojgarNest_uploads", "sevanext_uploads"),
    ("rojgarnest_uploads", "sevanext_uploads"),

    # Email domains — specific first
    ("admin@rojgarnest.com",      "admin@sevanext.com"),
    ("customadmin@rojgarnest.com","customadmin@sevanext.com"),
    ("support@rojgarnest.com",    "support@sevanext.com"),
    ("noreply@rojgarnest.com",    "noreply@sevanext.com"),

    # URLs — with www
    ("www.rojgarnest.com", "www.sevanext.com"),

    # URLs — without www (standalone)
    ("rojgarnest.com", "sevanext.com"),

    # Catch-all (lowercase — for any remaining like loggers, variables)
    ("rojgarnest", "sevanext"),

    # Capital R variants (safety)
    ("RojgarNest", "SevaNext"),
    ("Rojgarnest", "SevaNext"),
    ("ROJGARNEST", "SEVANEXT"),
]

# ============================================================
# FILE EXTENSIONS TO SCAN
# ============================================================
BACKEND_EXTENSIONS = {".py", ".env", ".txt", ".yaml", ".yml", ".json", ".conf"}
FRONTEND_EXTENSIONS = {".dart", ".yaml", ".yml", ".json", ".html", ".conf"}

# Skip these folders
SKIP_DIRS = {
    "__pycache__", ".git", ".venv", "venv", "node_modules",
    "build", ".dart_tool", ".idea", ".vscode", "ios", "android",
    "windows", "macos", "linux", ".pytest_cache", ".mypy_cache",
    "uploads", "logs", "backups", "secure", "models",
}

# Skip these file names
SKIP_FILES = {
    ".DS_Store", "Thumbs.db", "pubspec.lock", "package-lock.json",
    "rebrand.py",  # don't modify self
}

# ============================================================
# HELPERS
# ============================================================

def is_binary(file_path: Path) -> bool:
    """Check if file is binary — skip those."""
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(8192)
            return b"\0" in chunk
    except Exception:
        return True


def should_skip_dir(dir_name: str) -> bool:
    return dir_name in SKIP_DIRS


def should_skip_file(file_name: str) -> bool:
    return file_name in SKIP_FILES


def find_files(root: Path, extensions: set) -> list:
    """Recursively find all matching files, skipping skip-dirs."""
    if not root.exists():
        print(f"   ⚠️  Directory not found: {root}")
        return []

    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune skip dirs in-place
        dirnames[:] = [d for d in dirnames if not should_skip_dir(d)]

        for filename in filenames:
            if should_skip_file(filename):
                continue

            file_path = Path(dirpath) / filename

            # Extension check (allow files with no extension like `.env` or `Dockerfile`)
            if file_path.suffix.lower() in extensions:
                found.append(file_path)
            elif filename in ("Dockerfile", ".env", ".env.example", ".dockerignore", "nginx.conf"):
                found.append(file_path)

    return found


def count_matches(content: str) -> dict:
    """Count how many times each pattern appears."""
    counts = {}
    for old, _ in REPLACEMENTS:
        n = content.count(old)
        if n > 0:
            counts[old] = n
    return counts


def apply_replacements(content: str) -> tuple:
    """Apply all replacements in order. Returns (new_content, total_changes)."""
    total = 0
    new = content
    for old, replacement in REPLACEMENTS:
        count = new.count(old)
        if count > 0:
            new = new.replace(old, replacement)
            total += count
    return new, total


def backup_file(file_path: Path) -> Path:
    """Copy file to backup folder preserving relative structure."""
    try:
        rel = file_path.relative_to(PROJECT_ROOT)
    except ValueError:
        rel = Path(file_path.name)

    backup_path = BACKUP_ROOT / rel
    backup_path.parent.mkdir(parents=True, exist_ok=True)

    # Don't overwrite existing backups
    if not backup_path.exists():
        shutil.copy2(file_path, backup_path)

    return backup_path


# ============================================================
# MAIN LOGIC
# ============================================================

def process_root(root: Path, extensions: set, label: str, dry_run: bool):
    """Process one root folder (backend or frontend)."""
    print(f"\n{'='*70}")
    print(f"📂 {label}: {root}")
    print(f"{'='*70}")

    if not root.exists():
        print(f"   ❌ Folder does not exist. Skipping.")
        return {"scanned": 0, "changed": 0, "total_replacements": 0, "files": []}

    files = find_files(root, extensions)
    print(f"   🔍 Found {len(files)} candidate files")

    scanned = 0
    changed_files = []
    total_replacements = 0

    for f in files:
        scanned += 1

        # Skip binary
        if is_binary(f):
            continue

        try:
            original = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            try:
                original = f.read_text(encoding="latin-1")
            except Exception:
                continue
        except Exception as e:
            print(f"   ⚠️  Could not read {f.relative_to(PROJECT_ROOT)}: {e}")
            continue

        # Count matches BEFORE replacing
        matches = count_matches(original)
        if not matches:
            continue

        new_content, n = apply_replacements(original)
        if n == 0:
            continue

        rel_path = f.relative_to(PROJECT_ROOT)
        print(f"\n   📝 {rel_path}")
        for pattern, cnt in matches.items():
            print(f"       • '{pattern}' → {cnt} occurrence(s)")

        changed_files.append({
            "file": str(rel_path),
            "replacements": n,
            "details": matches,
        })
        total_replacements += n

        if not dry_run:
            backup_file(f)
            try:
                f.write_text(new_content, encoding="utf-8")
                print(f"       ✅ Updated (backup saved)")
            except Exception as e:
                print(f"       ❌ Write failed: {e}")

    return {
        "scanned": scanned,
        "changed": len(changed_files),
        "total_replacements": total_replacements,
        "files": changed_files,
    }


def update_docker_names():
    """Detect and print suggested docker commands."""
    print(f"\n{'='*70}")
    print(f"🐳 DOCKER IMAGE NAME SUGGESTIONS")
    print(f"{'='*70}")
    print("\n   Dockerfile mein image name NAHI hota. Yeh commands use karo:\n")
    print("   # Backend")
    print("   docker build -t sevanext-backend ./backend/sevanext")
    print("   docker tag sevanext-backend your-registry/sevanext-backend:latest")
    print("\n   # Frontend")
    print("   docker build -t sevanext-frontend ./frontend/sevanext")
    print("   docker tag sevanext-frontend your-registry/sevanext-frontend:latest")
    print("\n   # Agar docker-compose.yml hai to usme 'image:' line manually badlo:")
    print("   #   image: sevanext-backend:latest")
    print("   #   image: sevanext-frontend:latest")


def print_summary(backend_result, frontend_result, dry_run):
    print(f"\n{'='*70}")
    print(f"📊 SUMMARY")
    print(f"{'='*70}")

    for label, r in [("BACKEND", backend_result), ("FRONTEND", frontend_result)]:
        print(f"\n   {label}:")
        print(f"      Files scanned      : {r['scanned']}")
        print(f"      Files changed      : {r['changed']}")
        print(f"      Total replacements : {r['total_replacements']}")

    grand_total = backend_result["total_replacements"] + frontend_result["total_replacements"]

    print(f"\n   {'='*50}")
    print(f"   🎯 GRAND TOTAL REPLACEMENTS: {grand_total}")
    print(f"   {'='*50}")

    if not dry_run and (backend_result["changed"] > 0 or frontend_result["changed"] > 0):
        print(f"\n   💾 Backup saved to: {BACKUP_ROOT}")
        print(f"   ↩️  Rollback command: python rebrand.py --rollback")

    if dry_run and grand_total > 0:
        print(f"\n   ⚠️  DRY RUN — No files were modified.")
        print(f"   👉 To apply changes, run: python rebrand.py --apply")


def do_rollback():
    """Find latest backup folder and restore."""
    print(f"\n{'='*70}")
    print(f"↩️  ROLLBACK")
    print(f"{'='*70}")

    # Find all backup folders
    backups = sorted(PROJECT_ROOT.glob("_backup_*"))

    if not backups:
        print("   ❌ No backup folders found.")
        return

    latest = backups[-1]
    print(f"   📁 Using backup: {latest.name}")

    restored = 0
    for root_dir in (BACKEND_DIR, FRONTEND_DIR):
        backup_dir = latest / "backend" / "sevanext" if "backend" in str(root_dir).lower() else latest / "frontend" / "sevanext"

        # Actually reconstruct properly:
        if root_dir == BACKEND_DIR:
            backup_dir = latest / "backend" / "sevanext"
        elif root_dir == FRONTEND_DIR:
            backup_dir = latest / "frontend" / "sevanext"

        if not backup_dir.exists():
            continue

        for backup_file_path in backup_dir.rglob("*"):
            if backup_file_path.is_dir():
                continue

            rel = backup_file_path.relative_to(backup_dir)
            original = root_dir / rel

            original.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup_file_path, original)
            print(f"   ♻️  Restored: {rel}")
            restored += 1

    print(f"\n   ✅ Restored {restored} files")


def confirm(prompt: str) -> bool:
    ans = input(prompt).strip().lower()
    return ans in ("y", "yes")


# ============================================================
# ENTRY POINT
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="RojgarNest → SevaNext rebrand")
    parser.add_argument("--apply", action="store_true", help="Apply changes")
    parser.add_argument("--rollback", action="store_true", help="Restore from latest backup")
    parser.add_argument("--yes", "-y", action="store_true", help="Skip confirmation")
    args = parser.parse_args()

    # ---- ROLLBACK MODE ----
    if args.rollback:
        if not args.yes and not confirm("⚠️  Rollback will overwrite current files. Continue? (y/N): "):
            print("   Cancelled.")
            return
        do_rollback()
        return

    # ---- NORMAL MODE ----
    dry_run = not args.apply

    print(f"\n{'='*70}")
    print(f"🔄 ROJGARNEST → SEVANEXT REBRAND")
    print(f"{'='*70}")
    print(f"   Mode         : {'DRY RUN (preview)' if dry_run else 'APPLY (write files)'}")
    print(f"   Project root : {PROJECT_ROOT}")
    print(f"   Backend      : {BACKEND_DIR}")
    print(f"   Frontend     : {FRONTEND_DIR}")

    # Sanity check
    if not BACKEND_DIR.exists():
        print(f"\n   ❌ Backend folder not found: {BACKEND_DIR}")
        print(f"   👉 Adjust BACKEND_DIR at top of rebrand.py")
        sys.exit(1)

    if not FRONTEND_DIR.exists():
        print(f"\n   ⚠️  Frontend folder not found: {FRONTEND_DIR}")
        print(f"   ⏭️  Will only process backend")

    if not dry_run and not args.yes:
        if not confirm(f"\n⚠️  This will modify files. Backups will be saved to:\n   {BACKUP_ROOT}\n\nContinue? (y/N): "):
            print("   Cancelled.")
            return

    # ---- PROCESS BACKEND ----
    backend_result = process_root(BACKEND_DIR, BACKEND_EXTENSIONS, "BACKEND", dry_run)

    # ---- PROCESS FRONTEND ----
    frontend_result = {"scanned": 0, "changed": 0, "total_replacements": 0, "files": []}
    if FRONTEND_DIR.exists():
        frontend_result = process_root(FRONTEND_DIR, FRONTEND_EXTENSIONS, "FRONTEND", dry_run)

    # ---- SUMMARY ----
    print_summary(backend_result, frontend_result, dry_run)

    # ---- DOCKER SUGGESTIONS ----
    update_docker_names()

    print(f"\n{'='*70}")
    print(f"✅ DONE")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()