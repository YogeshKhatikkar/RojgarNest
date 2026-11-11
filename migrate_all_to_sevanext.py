#!/usr/bin/env python3
"""
============================================================
🚀 SEVANEXT — ONE-SHOT MIGRATION SCRIPT
============================================================
Ye ek hi script sab kuch karti hai:

  1. Backup      — automatic .bak copy of every file it touches
  2. Rewrite     — rojgarnext/rojgarnest → sevanext in ALL text files
  3. Rename      — file/folder names containing rojgarnext → sevanext
  4. Docker Fix  — docker-compose*.yml ki DB names + network + container names
  5. .env Fix    — .env, .env.* files me MONGO_URI + DATABASE_NAME
  6. Sanitize    — export_backend_code.py ki ENV_SANITIZATION_RULES
  7. Verify      — akhir me scan karke report deti hai

KAISE CHALAYE:
    cd E:\\YOGESH\\website\\SevaNext
    python migrate_all_to_sevanext.py                # LIVE (apply all)
    python migrate_all_to_sevanext.py --dry-run      # preview only
    python migrate_all_to_sevanext.py --no-backup    # skip .bak copies
    python migrate_all_to_sevanext.py --no-rename    # skip path renames

KAUNSE PATHS KEEP karna hai (protected):
  - rojgarnest.com / www.rojgarnest.com   (domain)
  - com.rojgarnext.app                    (Android app ID)
  - rojgarnext-release-key.jks            (keystore)
  - RojgarNest_uploads                    (Cloudinary folder)
============================================================
"""

import argparse
import os
import re
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Tuple

# ============================================================
# CONFIG
# ============================================================

ROOT_PATH = Path(__file__).parent.resolve()

# Folders that are NEVER touched
HARD_SKIP_DIRS = {
    '.git', '.vscode', '.idea', 'node_modules', '__pycache__',
    '.pytest_cache', '.mypy_cache', '.ruff_cache', '.dart_tool',
    '.gradle', 'build', 'dist', 'coverage', 'htmlcov', '.next',
    '.cache', '.turbo', '.venv', 'venv', 'env',
}

# Binary extensions — never rewrite content
BINARY_EXTENSIONS = {
    '.zip', '.tar', '.tgz', '.rar', '.7z', '.gz', '.bz2', '.xz',
    '.pyc', '.pyo', '.class', '.o', '.obj', '.so', '.dll', '.exe',
    '.dylib', '.wasm', '.jpg', '.jpeg', '.png', '.gif', '.bmp',
    '.ico', '.webp', '.svg', '.mp4', '.mov', '.avi', '.mkv', '.webm',
    '.flv', '.m4v', '.3gp', '.mp3', '.wav', '.ogg', '.flac', '.aac',
    '.m4a', '.woff', '.woff2', '.ttf', '.otf', '.eot', '.pdf', '.doc',
    '.docx', '.pptx', '.xlsx', '.xls', '.db', '.sqlite', '.sqlite3',
    '.rdb', '.dump', '.pem', '.key', '.crt', '.cer', '.p12', '.pfx',
    '.jks', '.keystore', '.bin', '.lz4',
}

# Output/backup files — never rewrite
SKIP_FILE_NAMES = {
    'full_project_export.txt',
    'backend_complete_export.txt',
    'frontend_export.txt',
    'migrate_all_to_sevanext.py',
    'migrate_to_sevanext.py',
    'post_migration_verify.py',
    '.DS_Store',
    'Thumbs.db',
    'desktop.ini',
}

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

# ============================================================
# PROTECTED PATTERNS
# ------------------------------------------------------------
# These strings are replaced with a placeholder FIRST so generic
# replacement doesn't break them, then restored at the end.
# ============================================================

PROTECTED_PATTERNS = [
    # domain (used everywhere) — keep exact
    'www.rojgarnest.com',
    'rojgarnest.com',
    # android app id (Play Store — immutable)
    'com.rojgarnext.app',
    # keystore file (Android signing)
    'rojgarnext-release-key.jks',
    # cloudinary folder (existing assets)
    'RojgarNest_uploads',
    # android package folders in Flutter
    '/com/rojgarnext/',
    'com/rojgarnext',
    # gradle applicationId
    'applicationId "com.rojgarnext.app"',
    'applicationId = "com.rojgarnext.app"',
]

# ============================================================
# REPLACEMENT ORDER (longest variants first)
# ============================================================

REPLACEMENTS: List[Tuple[str, str]] = [
    # TitleCase variants (mixed, longest first)
    ('RojgarNext', 'SevaNext'),
    ('RojgarNest', 'SevaNext'),
    ('Rojgarnext', 'Sevanext'),
    ('Rojgarnest', 'Sevanext'),
    # lower
    ('rojgarnext', 'sevanext'),
    ('rojgarnest', 'sevanext'),
    # UPPER
    ('ROJGARNEXT', 'SEVANEXT'),
    ('ROJGARNEST', 'SEVANEXT'),
]

# ============================================================
# DIRECT DOCKER / ENV OVERRIDES
# ------------------------------------------------------------
# After generic replacement we additionally FORCE these exact
# key=value pairs in known files so there is zero ambiguity.
# ============================================================

DOCKER_DB_NAME = 'SevaNext'
DOCKER_PROJECT = 'sevanext'
DOCKER_NETWORK = 'sevanext-net'

ENV_TARGETS = {
    'MONGO_URI': {
        'dev': 'mongodb://mongo:27017/SevaNext',
        'prod': 'mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@mongo:27017/SevaNext?authSource=admin',
    },
    'DATABASE_NAME': 'SevaNext',
    'MONGO_INITDB_DATABASE': 'SevaNext',
    'MONGO_DATABASE': 'SevaNext',
}

# ============================================================
# STATS
# ============================================================

class Stats:
    def __init__(self):
        self.files_scanned = 0
        self.files_rewritten = 0
        self.files_skipped = 0
        self.files_failed = 0
        self.total_replacements = 0
        self.paths_renamed = 0
        self.docker_files_fixed = 0
        self.env_files_fixed = 0
        self.backups_created = 0
        self.errors: List[str] = []

    def report(self) -> str:
        lines = [
            '=' * 80,
            '📊 MIGRATION SUMMARY',
            '=' * 80,
            f"  Files scanned:         {self.files_scanned}",
            f"  Files rewritten:       {self.files_rewritten}",
            f"  Files skipped:         {self.files_skipped}",
            f"  Files failed:          {self.files_failed}",
            f"  Total replacements:    {self.total_replacements}",
            f"  Paths renamed:         {self.paths_renamed}",
            f"  Docker files fixed:    {self.docker_files_fixed}",
            f"  Env files fixed:       {self.env_files_fixed}",
            f"  Backups created:       {self.backups_created}",
            '=' * 80,
        ]
        if self.errors:
            lines.append('')
            lines.append('⚠️  ERRORS:')
            for e in self.errors[:30]:
                lines.append(f'    • {e}')
        return '\n'.join(lines)


# ============================================================
# HELPERS
# ============================================================

def is_hard_skipped(dir_name: str) -> bool:
    return dir_name in HARD_SKIP_DIRS


def should_skip_file(path: Path) -> bool:
    if path.name in SKIP_FILE_NAMES:
        return True
    if path.suffix.lower() in BINARY_EXTENSIONS:
        return True
    try:
        s = path.stat().st_size
        if s == 0 or s > MAX_FILE_SIZE:
            return True
    except Exception:
        return True
    return False


def read_text(path: Path) -> Tuple[str | None, str]:
    for enc in ('utf-8', 'utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1'):
        try:
            return path.read_text(encoding=enc), enc
        except UnicodeDecodeError:
            continue
        except Exception:
            return None, 'read-error'
    try:
        return path.read_text(encoding='utf-8', errors='replace'), 'utf-8-replace'
    except Exception as e:
        return None, f'error: {e}'


def write_text(path: Path, content: str, enc: str) -> bool:
    try:
        enc = 'utf-8' if enc in ('utf-8-replace', 'read-error') else enc
        path.write_text(content, encoding=enc)
        return True
    except Exception as e:
        print(f"    ❌ write error: {e}")
        return False


def make_backup(path: Path, backup_root: Path) -> bool:
    try:
        rel = path.relative_to(ROOT_PATH)
        dst = backup_root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)
        return True
    except Exception as e:
        print(f"    ⚠️  backup failed for {path}: {e}")
        return False


def protect(content: str) -> Tuple[str, dict]:
    """Replace protected patterns with unique tokens."""
    mapping = {}
    for i, pat in enumerate(PROTECTED_PATTERNS):
        token = f"__SEVANEXT_PROTECT_{i}__"
        if pat in content:
            content = content.replace(pat, token)
            mapping[token] = pat
    return content, mapping


def unprotect(content: str, mapping: dict) -> str:
    for token, pat in mapping.items():
        content = content.replace(token, pat)
    return content


def apply_replacements(content: str) -> Tuple[str, int]:
    total = 0
    for old, new in REPLACEMENTS:
        if old in content:
            total += content.count(old)
            content = content.replace(old, new)
    return content, total


# ============================================================
# DOCKER COMPOSE FORCE-FIX
# ------------------------------------------------------------
# Ensures MONGO_URI / DATABASE_NAME / MONGO_INITDB_DATABASE /
# network / container / project names are exactly SevaNext.
# ============================================================

def fix_compose_file(path: Path, kind: str) -> bool:
    content, enc = read_text(path)
    if content is None:
        return False

    original = content
    changed = False

    # 1. MONGO_URI inside compose
    if kind == 'base':
        content = re.sub(
            r'(MONGO_URI:\s*)(mongodb://[^\s]+/[A-Za-z0-9_]+)',
            lambda m: m.group(1) + m.group(2).rsplit('/', 1)[0] + '/' + DOCKER_DB_NAME,
            content,
        )
        content = re.sub(
            r'(DATABASE_NAME:\s*)[A-Za-z0-9_]+',
            rf'\1{DOCKER_DB_NAME}',
            content,
        )
        content = re.sub(
            r'(MONGO_INITDB_DATABASE:\s*)[A-Za-z0-9_]+',
            rf'\1{DOCKER_DB_NAME}',
            content,
        )
        content = re.sub(
            r'(container_name:\s*)rojgarnest-local-(backend|frontend)',
            rf'\1sevanext-local-\2',
            content,
        )
        content = content.replace('rojgarnest-net', DOCKER_NETWORK)

    elif kind == 'prod':
        content = re.sub(
            r'(MONGO_URI:\s*)(mongodb://[^\s]+/[A-Za-z0-9_]+)(\?authSource=admin)',
            lambda m: m.group(1) + m.group(2).rsplit('/', 1)[0] + '/' + DOCKER_DB_NAME + m.group(3),
            content,
        )
        content = re.sub(
            r'(DATABASE_NAME:\s*)[A-Za-z0-9_]+',
            rf'\1{DOCKER_DB_NAME}',
            content,
        )

    if content != original:
        changed = True
        if not write_text(path, content, enc):
            return False
    return changed


def fix_env_file(path: Path) -> bool:
    """Force DB-related keys in .env* files."""
    content, enc = read_text(path)
    if content is None:
        return False

    lines = content.splitlines(keepends=False)
    out: List[str] = []
    seen_keys: set = set()

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            out.append(line)
            continue
        if '=' not in line:
            out.append(line)
            continue

        key, _, val = line.partition('=')
        key_clean = key.strip()
        seen_keys.add(key_clean)

        if key_clean == 'MONGO_URI':
            # decide dev vs prod based on filename
            fname = path.name.lower()
            if 'prod' in fname:
                value = 'mongodb://mongo:27017/SevaNext'  # overridden by compose env anyway
            else:
                value = 'mongodb://localhost:27017/sevanext'
            out.append(f'{key_clean}={value}')
        elif key_clean in ('DATABASE_NAME', 'MONGO_INITDB_DATABASE', 'MONGO_DATABASE'):
            out.append(f'{key_clean}={DOCKER_DB_NAME}')
        elif key_clean == 'COMPOSE_PROJECT_NAME':
            out.append(f'{key_clean}={DOCKER_PROJECT}')
        else:
            out.append(line)

    # Ensure MONGO_URI + DATABASE_NAME exist in backend .env files
    if path.name == '.env' and 'backend' in str(path).lower().replace('\\', '/'):
        if 'MONGO_URI' not in seen_keys:
            out.append('MONGO_URI=mongodb://localhost:27017/sevanext')
        if 'DATABASE_NAME' not in seen_keys:
            out.append('DATABASE_NAME=SevaNext')

    new_content = '\n'.join(out)
    if content.endswith('\n') and not new_content.endswith('\n'):
        new_content += '\n'

    if new_content != content:
        return write_text(path, new_content, enc)
    return False


# ============================================================
# MIGRATE ONE FILE
# ============================================================

def migrate_file(
    path: Path,
    dry_run: bool,
    backup_root: Path | None,
    stats: Stats,
) -> None:
    stats.files_scanned += 1

    if should_skip_file(path):
        stats.files_skipped += 1
        return

    content, enc = read_text(path)
    if content is None:
        stats.files_skipped += 1
        print(f"  ⏭️  skip (unreadable): {path.relative_to(ROOT_PATH)} ({enc})")
        return

    # Step 1: protect domain / app-id / keystore / cloudinary
    protected, mapping = protect(content)

    # Step 2: generic replacement
    replaced, changes = apply_replacements(protected)

    # Step 3: restore protected
    new_content = unprotect(replaced, mapping)

    if changes == 0:
        stats.files_skipped += 1
        return

    if dry_run:
        stats.files_rewritten += 1
        stats.total_replacements += changes
        print(f"  [DRY] ✅ {path.relative_to(ROOT_PATH)}  ({changes} replacements)")
        return

    # backup
    if backup_root is not None:
        if make_backup(path, backup_root):
            stats.backups_created += 1

    # write
    if write_text(path, new_content, enc):
        stats.files_rewritten += 1
        stats.total_replacements += changes
        print(f"  ✅ {path.relative_to(ROOT_PATH)}  ({changes} replacements)")
    else:
        stats.files_failed += 1
        stats.errors.append(str(path))


# ============================================================
# PATH RENAME (files & dirs)
# ============================================================

def rename_paths(dry_run: bool, stats: Stats) -> None:
    # Rename dirs deepest-first
    dirs = []
    for current_dir, subdirs, _ in os.walk(ROOT_PATH):
        subdirs[:] = [d for d in subdirs if not is_hard_skipped(d)]
        for d in subdirs:
            dirs.append(Path(current_dir) / d)

    for old in sorted(dirs, key=lambda p: len(p.parts), reverse=True):
        if not old.exists():
            continue
        new_name, ch = apply_replacements(old.name)
        if ch == 0 or new_name == old.name:
            continue
        new_path = old.parent / new_name
        if dry_run:
            print(f"  [DRY] 📁 RENAME  {old.relative_to(ROOT_PATH)}  →  {new_name}")
            stats.paths_renamed += 1
        else:
            try:
                old.rename(new_path)
                print(f"  ✅ 📁 RENAMED  {old.relative_to(ROOT_PATH)}  →  {new_name}")
                stats.paths_renamed += 1
            except Exception as e:
                stats.errors.append(f'rename {old}: {e}')
                print(f"  ❌ rename {old}: {e}")

    # Rename files
    for current_dir, subdirs, files in os.walk(ROOT_PATH):
        subdirs[:] = [d for d in subdirs if not is_hard_skipped(d)]
        for filename in files:
            old = Path(current_dir) / filename
            new_name, ch = apply_replacements(filename)
            if ch == 0 or new_name == filename:
                continue
            new_path = old.parent / new_name
            if dry_run:
                print(f"  [DRY] 📄 RENAME  {old.relative_to(ROOT_PATH)}  →  {new_name}")
                stats.paths_renamed += 1
            else:
                try:
                    old.rename(new_path)
                    print(f"  ✅ 📄 RENAMED  {old.relative_to(ROOT_PATH)}  →  {new_name}")
                    stats.paths_renamed += 1
                except Exception as e:
                    stats.errors.append(f'rename {old}: {e}')
                    print(f"  ❌ rename {old}: {e}")


# ============================================================
# VERIFY
# ============================================================

def verify() -> int:
    """Return number of leftover occurrences."""
    patterns = ['rojgarnext', 'rojgarnest', 'RojgarNext',
                'RojgarNest', 'ROJGARNEXT', 'ROJGARNEST']
    protected_tokens = [p.lower() for p in PROTECTED_PATTERNS]

    hits = 0
    print()
    print("=" * 80)
    print("🔍 POST-MIGRATION VERIFICATION")
    print("=" * 80)

    for current_dir, subdirs, files in os.walk(ROOT_PATH):
        subdirs[:] = [d for d in subdirs if not is_hard_skipped(d)]
        for filename in files:
            path = Path(current_dir) / filename
            if should_skip_file(path):
                continue
            content, _ = read_text(path)
            if content is None:
                continue
            lower = content.lower()
            for pat in patterns:
                if pat.lower() in lower:
                    # ignore if line only contains a protected pattern
                    for line in content.splitlines():
                        l = line.lower()
                        if pat.lower() in l:
                            if any(pt in l for pt in protected_tokens):
                                continue
                            # ignore self-reference to script name
                            if 'migrate_to_sevanext' in l or 'migrate_all_to' in l:
                                continue
                            hits += 1
                            print(f"  ⚠️  {path.relative_to(ROOT_PATH)}  →  '{pat}'")
                            break

    print("=" * 80)
    if hits == 0:
        print("✅ VERIFICATION PASSED — no stray rojgarnest/rojgarnext")
    else:
        print(f"⚠️  {hits} potential leftover(s) — review above")
    print("=" * 80)
    return hits


# ============================================================
# MAIN
# ============================================================

def main():
    ap = argparse.ArgumentParser(
        description='One-shot rojgarnest → sevanext migration.'
    )
    ap.add_argument('--dry-run', action='store_true',
                    help='Preview only — do not modify files.')
    ap.add_argument('--no-backup', action='store_true',
                    help='Skip .bak copies (faster, riskier).')
    ap.add_argument('--no-rename', action='store_true',
                    help='Skip renaming files/folders.')
    ap.add_argument('--skip-verify', action='store_true',
                    help='Skip post-migration verification.')
    args = ap.parse_args()

    print("=" * 80)
    print("🚀 SEVANEXT — ONE-SHOT MIGRATION")
    print("=" * 80)
    print(f"   ROOT:          {ROOT_PATH}")
    print(f"   DRY RUN:       {args.dry_run}")
    print(f"   BACKUP:        {not args.no_backup}")
    print(f"   RENAME PATHS:  {not args.no_rename}")
    print("=" * 80)

    if not ROOT_PATH.exists():
        print(f"❌ Root not found: {ROOT_PATH}")
        sys.exit(1)

    if not args.dry_run:
        print("⚠️  LIVE MODE — you have 5 seconds to abort (Ctrl+C).")
        try:
            time.sleep(5)
        except KeyboardInterrupt:
            print("\n❌ Aborted.")
            sys.exit(1)

    # ---- Backup dir ----
    backup_root = None
    if not args.no_backup and not args.dry_run:
        backup_root = ROOT_PATH / f'.migration_backup_{datetime.now():%Y%m%d_%H%M%S}'
        backup_root.mkdir(parents=True, exist_ok=True)
        print(f"📦 Backup directory: {backup_root.name}\n")

    stats = Stats()

    # ---- STEP 1: rewrite all file contents ----
    print("📝 STEP 1/4 — Rewriting file contents ...")
    print("-" * 80)
    for current_dir, subdirs, files in os.walk(ROOT_PATH):
        subdirs[:] = [d for d in subdirs if not is_hard_skipped(d)]
        # Also skip the backup directory itself
        if backup_root is not None:
            subdirs[:] = [d for d in subdirs if (Path(current_dir) / d) != backup_root]
        for filename in files:
            migrate_file(Path(current_dir) / filename,
                         args.dry_run, backup_root, stats)
    print()

    # ---- STEP 2: force-fix docker / env / sanitizer ----
    print("🐳 STEP 2/4 — Force-fixing Docker / .env files ...")
    print("-" * 80)

    # 2a. docker-compose files
    for current_dir, subdirs, files in os.walk(ROOT_PATH):
        subdirs[:] = [d for d in subdirs if not is_hard_skipped(d)]
        for filename in files:
            p = Path(current_dir) / filename
            rel = str(p.relative_to(ROOT_PATH)).replace('\\', '/')

            if filename == 'docker-compose.yml':
                if not args.dry_run:
                    if fix_compose_file(p, 'base'):
                        stats.docker_files_fixed += 1
                        print(f"  ✅ fixed: {rel}")
                else:
                    print(f"  [DRY] docker-fix: {rel}")

            elif filename == 'docker-compose.prod.yml':
                if not args.dry_run:
                    if fix_compose_file(p, 'prod'):
                        stats.docker_files_fixed += 1
                        print(f"  ✅ fixed: {rel}")
                else:
                    print(f"  [DRY] docker-prod-fix: {rel}")

            elif filename == '.env' or filename.startswith('.env.'):
                if not args.dry_run:
                    # backup already made in step 1 if modified
                    if fix_env_file(p):
                        stats.env_files_fixed += 1
                        print(f"  ✅ env-fixed: {rel}")
                else:
                    print(f"  [DRY] env-fix: {rel}")

    # 2b. export_backend_code.py — sanitization rules
    exporters = [
        ROOT_PATH / 'export_backend_code.py',
        ROOT_PATH / 'scripts' / 'export_backend_code.py',
    ]
    for exporter in exporters:
        if not exporter.exists():
            continue
        content, enc = read_text(exporter)
        if content is None:
            continue
        new_content = re.sub(
            r"('MONGO_URI'\s*:\s*')[^']*(')",
            rf"\1mongodb://localhost:27017/sevanext\2",
            content,
        )
        new_content = re.sub(
            r"('DATABASE_NAME'\s*:\s*')[^']*(')",
            rf"\1sevanext\2",
            new_content,
        )
        if new_content != content:
            if not args.dry_run:
                write_text(exporter, new_content, enc)
                print(f"  ✅ sanitizer rules fixed: {exporter.name}")
            else:
                print(f"  [DRY] sanitizer-fix: {exporter.name}")
    print()

    # ---- STEP 3: rename paths (optional) ----
    if not args.no_rename:
        print("📁 STEP 3/4 — Renaming files / folders ...")
        print("-" * 80)
        rename_paths(args.dry_run, stats)
        print()
    else:
        print("📁 STEP 3/4 — Rename skipped (--no-rename).\n")

    # ---- STEP 4: verify ----
    if not args.skip_verify:
        print("🔍 STEP 4/4 — Verifying ...")
        leftover = verify()
    else:
        print("🔍 STEP 4/4 — Verify skipped (--skip-verify).\n")
        leftover = 0

    # ---- Final report ----
    print()
    print(stats.report())

    if not args.dry_run:
        print("\n🎉 MIGRATION COMPLETE")
        print("=" * 80)
        print("📋 NEXT STEPS:")
        print("=" * 80)
        print("  1. Review the diff:")
        print("       git diff")
        print()
        print("  2. Migrate MongoDB data:")
        print("       mongodump --db=rojgarnext --archive=old.gz --gzip")
        print("       mongorestore --archive=old.gz --gzip \\")
        print("                    --nsFrom='rojgarnext.*' \\")
        print("                    --nsTo='sevanext.*'")
        print()
        print("  3. Rebuild & restart Docker:")
        print("       cd deploy")
        print("       docker compose -f docker-compose.yml \\")
        print("                      -f docker-compose.dev.yml \\")
        print("                      --env-file .env.local down")
        print("       docker compose -f docker-compose.yml \\")
        print("                      -f docker-compose.dev.yml \\")
        print("                      --env-file .env.local up --build -d")
        print()
        print("  4. Verify backend connected to right DB:")
        print("       docker exec -it sevanext-local-backend sh -c \\")
        print("         \"python -c 'from app.database.mongodb import db; print(db.name)'\"")
        print()
        print("  5. After 1 week of confirmed operation, drop old DB:")
        print("       mongosh --eval \"db.getSiblingDB('rojgarnext').dropDatabase()\"")
        print("=" * 80)

        if backup_root is not None:
            print(f"\n💾 Backup saved at: {backup_root}")
            print("   You can restore a file by copying from that folder.")
            print("   Delete it after verifying migration is OK.")

    if leftover > 0:
        print(f"\n⚠️  {leftover} potential leftover(s) detected — review above.")
        sys.exit(2)

    sys.exit(0)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ Cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)