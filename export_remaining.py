# scripts/export_deploy_monitoring.py
"""
RojgarNest - Deploy, Monitoring & .github Exporter (BULLETPROOF)
Extracts ONLY: deploy/, monitoring/, .github/
.github/workflows/ and .github/actions/: EVERY file (no filter, no size limit)

Run: python scripts/export_deploy_monitoring.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Tuple, Dict

# ==================== CONFIGURATION ====================

ROOT_PATH = r"E:\YOGESH\website\RojgarNest"
OUTPUT_FILE = "deploy_monitoring_export.txt"

TARGET_FOLDERS = ['deploy', 'monitoring', '.github']

# ✅ .github ke andar bypass subfolders (case-insensitive)
GITHUB_BYPASS_SUBFOLDERS = {'workflows', 'actions'}

# Normal files ke liye size limit
MAX_FILE_SIZE = 5 * 1024 * 1024

# ✅ .github/workflows/actions ke liye NO size limit
# (kyunki wahan koi bhi file ho sakti hai)
GITHUB_BYPASS_MAX_SIZE = 100 * 1024 * 1024  # 100 MB

# ==================== SKIP FOLDERS ====================

SKIP_FOLDERS = {
    '.git', '.gitlab', '.gitlab-ci', '.circleci', '.husky',
    'node_modules', '.venv', 'venv', 'env', 'vendor',
    'build', 'dist', 'out', 'target', 'bin', 'obj', '.cache',
    '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache',
    'coverage', 'htmlcov',
    '.idea', '.vscode', '.fleet', '.history',
    '.terraform', '.serverless',
    'logs', 'tmp', 'temp', '.tmp',
}

# ==================== ALLOWED EXTENSIONS ====================

ALLOWED_EXTENSIONS = {
    '.py', '.js', '.ts', '.sh', '.bash', '.ps1', '.bat', '.cmd',
    '.yaml', '.yml', '.json', '.toml', '.ini', '.conf', '.cfg',
    '.xml', '.properties',
    '.html', '.htm', '.css',
    '.md', '.txt', '.rst',
    '.sql',
    '.tf', '.tfvars', '.hcl', '.nomad',
    '.sample',
}

SKIP_FILE_PATTERNS = [
    'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
    'poetry.lock', 'Pipfile.lock', 'pubspec.lock',
    '.min.js', '.min.css', '.map', '.log',
    '.pyc', '.pyo', '.class', '.o', '.obj',
    '.so', '.dll', '.exe', '.dylib', '.wasm',
    '.zip', '.tar', '.tgz', '.rar', '.7z', '.gz', '.bz2',
    '.csv', '.tsv', '.xlsx', '.xls', '.parquet',
    '.db', '.sqlite', '.sqlite3',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.ico', '.webp', '.svg',
    '.mp4', '.mov', '.avi', '.mkv', '.webm',
    '.mp3', '.wav', '.ogg', '.flac',
    '.woff', '.woff2', '.ttf', '.otf', '.eot',
    '.pdf', '.doc', '.docx', '.pptx',
    '.pem', '.key', '.crt', '.cer', '.p12', '.pfx', '.jks',
]

SKIP_FILES_EXACT = {'.DS_Store', 'Thumbs.db', 'desktop.ini'}

FORCE_INCLUDE_FILENAMES = {
    'Dockerfile', 'Dockerfile.dev', 'Dockerfile.prod',
    'docker-compose.yml', 'docker-compose.yaml',
    'docker-compose.dev.yml', 'docker-compose.prod.yml',
    'Makefile', 'Jenkinsfile',
    '.gitignore', '.dockerignore', '.editorconfig',
    'nginx.conf',
    'CODEOWNERS', 'FUNDING.yml', 'dependabot.yml',
    'PULL_REQUEST_TEMPLATE.md', 'ISSUE_TEMPLATE.md',
}

FORCE_INCLUDE_PATTERNS = ['nginx', 'dockerfile', 'docker-compose', 'makefile']

# ==================== HELPER FUNCTIONS ====================


def normalize_path_parts(file_path: Path) -> List[str]:
    """Path ko lowercase parts mein todo — backslash aur forward slash dono handle"""
    s = str(file_path).replace('\\', '/').lower()
    return [p for p in s.split('/') if p]


def is_under_github_bypass(file_path: Path) -> bool:
    """
    ✅ Check karo file .github/workflows/ ya .github/actions/ ke andar hai (nested bhi).
    Path normalize karke check karta hai — Windows backslash safe.
    """
    parts = normalize_path_parts(file_path)
    for i, part in enumerate(parts):
        if part == '.github':
            # Check karo next part workflows ya actions hai
            for j in range(i + 1, len(parts)):
                if parts[j] in GITHUB_BYPASS_SUBFOLDERS:
                    return True
                # Agar koi aur subfolder mila, continue (nested allowed)
            # Agar .github ke baad koi bhi workflows/actions nahi, still check
            # for nested: .github/some/path/workflows/file.yml
            if any(p in GITHUB_BYPASS_SUBFOLDERS for p in parts[i+1:]):
                return True
            return False
    return False


def get_all_suffixes(file_path: Path) -> List[str]:
    return [s.lower() for s in file_path.suffixes]


def get_last_suffix(file_path: Path) -> str:
    return file_path.suffix.lower()


def matches_force_pattern(filename: str) -> bool:
    fname_lower = filename.lower()
    return any(p.lower() in fname_lower for p in FORCE_INCLUDE_PATTERNS)


def matches_skip_pattern(filename: str) -> Tuple[bool, str]:
    fname_lower = filename.lower()
    for pattern in SKIP_FILE_PATTERNS:
        if pattern.lower() in fname_lower:
            return True, pattern
    return False, ""


def should_include_folder(folder_path: Path, is_top_level_target: bool = False) -> Tuple[bool, str]:
    folder_name = folder_path.name
    name_lower = folder_name.lower()

    if name_lower in {f.lower() for f in SKIP_FOLDERS}:
        return False, "in SKIP_FOLDERS"

    if is_top_level_target:
        return True, "top-level target folder"

    # ✅ .github ke andar workflows/actions allow (even if nested hidden)
    parts = normalize_path_parts(folder_path)
    if '.github' in parts:
        # .github ke andar ka koi bhi subfolder allow karo — kyunki .github target hai
        # (bas SKIP_FOLDERS se bachna hai, jo upar ho gaya)
        return True, ".github subfolder (allowed)"

    if folder_name.startswith('.'):
        return False, "hidden nested folder"

    return True, "regular folder"


def should_include_file(file_path: Path) -> Tuple[bool, str]:
    filename = file_path.name

    # ✅ BYPASS: .github/workflows/ aur .github/actions/ ke andar SAB kuch
    if is_under_github_bypass(file_path):
        if filename in SKIP_FILES_EXACT:
            return False, "system file"
        try:
            size = file_path.stat().st_size
            if size > GITHUB_BYPASS_MAX_SIZE:
                return False, f"too large ({size / (1024*1024):.1f} MB > {GITHUB_BYPASS_MAX_SIZE // (1024*1024)} MB)"
            # ✅ Empty files bhi include karo (.github mein placeholder files hote hain)
        except Exception as e:
            return False, f"stat error: {e}"
        return True, "GitHub workflow/action (BYPASS — all files)"

    # Normal flow
    if filename in SKIP_FILES_EXACT:
        return False, "in SKIP_FILES_EXACT"

    skip_match, matched = matches_skip_pattern(filename)
    if skip_match:
        return False, f"matches skip pattern: '{matched}'"

    if filename in FORCE_INCLUDE_FILENAMES:
        return True, "force-include filename"

    if matches_force_pattern(filename):
        return True, "force-include pattern"

    try:
        size = file_path.stat().st_size
        if size == 0:
            return False, "empty file"
        if size > MAX_FILE_SIZE:
            return False, f"too large ({size / (1024*1024):.1f} MB > {MAX_FILE_SIZE // (1024*1024)} MB)"
    except Exception as e:
        return False, f"stat error: {e}"

    last_suffix = get_last_suffix(file_path)
    if last_suffix in ALLOWED_EXTENSIONS:
        return True, f"extension match: '{last_suffix}'"

    for suf in get_all_suffixes(file_path):
        if suf in ALLOWED_EXTENSIONS:
            return True, f"multi-extension match: '{suf}'"

    return False, f"extension not allowed: {file_path.suffixes}"


def scan_folder(folder_path: Path, root_path: Path) -> Tuple[List[Dict], List[Dict]]:
    included = []
    skipped = []

    def walk(folder: Path):
        try:
            for item in sorted(folder.iterdir()):
                if not item.exists():
                    continue

                try:
                    rel = item.relative_to(root_path)
                except ValueError:
                    rel = item

                # ✅ Symlink handle karo
                is_dir = item.is_dir() and not item.is_symlink()
                is_file = item.is_file() or (item.is_symlink() and item.resolve().is_file())

                if is_dir:
                    inc, reason = should_include_folder(item, is_top_level_target=False)
                    if inc:
                        walk(item)
                    else:
                        skipped.append({
                            'path': item, 'rel_path': rel,
                            'reason': reason, 'is_dir': True
                        })
                elif is_file:
                    inc, reason = should_include_file(item)
                    entry = {
                        'path': item, 'rel_path': rel,
                        'reason': reason, 'is_dir': False
                    }
                    if inc:
                        included.append(entry)
                    else:
                        skipped.append(entry)
        except PermissionError as e:
            print(f"⚠️ Permission denied: {folder} — {e}")
        except Exception as e:
            print(f"⚠️ Error scanning {folder}: {e}")

    walk(folder_path)
    return included, skipped


def read_file_content(file_path: Path) -> Tuple[str, str]:
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1']
    content = None
    used_encoding = 'utf-8'

    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
            used_encoding = encoding
            break
        except UnicodeDecodeError:
            continue
        except Exception:
            continue

    if content is None:
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            used_encoding = 'utf-8 (with replacements)'
        except Exception as e:
            return f"[ERROR: Could not read file - {e}]", 'error'

    return content, used_encoding


def get_file_icon(file_path: Path) -> str:
    path_lower = str(file_path).replace('\\', '/').lower()
    name_lower = file_path.name.lower()
    suffix = file_path.suffix.lower()

    if '.github/workflows' in path_lower:
        return '🔄'
    if '.github/actions' in path_lower:
        return '⚡'
    if '.github' in path_lower:
        return '🔧'
    if 'nginx' in name_lower:
        return '🌐'
    if 'docker' in name_lower:
        return '🐳'
    if 'prometheus' in name_lower:
        return '📊'
    if 'grafana' in name_lower:
        return '📈'

    icons = {
        '.py': '🐍', '.js': '💛', '.ts': '💙',
        '.json': '📋', '.yaml': '⚙️', '.yml': '⚙️', '.conf': '⚙️',
        '.md': '📝', '.txt': '📄', '.html': '🌐', '.css': '🎨',
        '.sql': '🗄️', '.sh': '📜', '.bat': '🪟', '.ps1': '💻',
        '.tf': '🏗️', '.xml': '📄',
    }
    return icons.get(suffix, '📄')


def get_relative_path(file_path: Path, base_path: Path) -> str:
    try:
        rel = file_path.relative_to(base_path)
        return str(rel).replace('\\', '/')
    except ValueError:
        return str(file_path).replace('\\', '/')


def format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


def generate_tree_structure(root_path: Path, base_path: Path, prefix: str = "") -> List[str]:
    lines = []
    try:
        items = []
        for item in sorted(root_path.iterdir()):
            try:
                if item.is_dir() and not item.is_symlink():
                    inc, _ = should_include_folder(item, is_top_level_target=False)
                    if inc:
                        items.append(item)
                elif item.is_file():
                    inc, _ = should_include_file(item)
                    if inc:
                        items.append(item)
            except Exception:
                continue

        for i, item in enumerate(items):
            is_last = (i == len(items) - 1)
            connector = "└── " if is_last else "├── "
            if item.is_dir():
                lines.append(f"{prefix}{connector}📁 {item.name}/")
                ext = "    " if is_last else "│   "
                lines.extend(generate_tree_structure(item, base_path, prefix + ext))
            else:
                icon = get_file_icon(item)
                lines.append(f"{prefix}{connector}{icon} {item.name}")
    except Exception as e:
        lines.append(f"{prefix}[Error: {e}]")
    return lines


# ==================== MAIN ====================


def export_deploy_monitoring():
    print("=" * 80)
    print("🚀 ROJGARNEST EXPORTER - deploy/ + monitoring/ + .github/")
    print("   .github/workflows/ and .github/actions/: EVERY file (no filter)")
    print("=" * 80)
    print(f"   ROOT_PATH:   {ROOT_PATH}")
    print(f"   TARGET:      {', '.join(TARGET_FOLDERS)}")
    print(f"   OUTPUT_FILE: {OUTPUT_FILE}")
    print()

    root_path = Path(ROOT_PATH)
    if not root_path.exists():
        print(f"❌ ERROR: Root path not found: {ROOT_PATH}")
        sys.exit(1)

    # Target folders check
    existing_folders = []
    missing_folders = []
    for folder_name in TARGET_FOLDERS:
        folder_path = root_path / folder_name
        if folder_path.exists() and folder_path.is_dir():
            existing_folders.append(folder_path)
        else:
            missing_folders.append(folder_name)

    if missing_folders:
        print(f"⚠️  Missing folders: {', '.join(missing_folders)}")
    if not existing_folders:
        print(f"❌ ERROR: No target folders found!")
        sys.exit(1)

    print(f"✅ Found: {[f.name for f in existing_folders]}")
    print()

    # ✅ PRE-SCAN: Raw filesystem se .github/workflows files count karo
    print("=" * 80)
    print("🔍 PRE-SCAN: Raw filesystem check (.github/workflows/)")
    print("=" * 80)
    workflows_dir = root_path / ".github" / "workflows"
    raw_workflow_files = []
    if workflows_dir.exists():
        print(f"✅ {workflows_dir} EXISTS")
        try:
            for item in sorted(workflows_dir.rglob('*')):
                if item.is_file():
                    raw_workflow_files.append(item)
                    try:
                        sz = item.stat().st_size
                        rel = item.relative_to(root_path)
                        print(f"   📄 {str(rel).replace(chr(92), '/')}  ({sz} bytes)")
                    except Exception:
                        pass
        except Exception as e:
            print(f"   ⚠️ Error reading: {e}")
        print(f"\n📊 RAW COUNT: {len(raw_workflow_files)} files in .github/workflows/")
    else:
        print(f"❌ {workflows_dir} DOES NOT EXIST")
        # Check .github exists
        if (root_path / ".github").exists():
            print(f"   But .github exists. Contents:")
            for item in sorted((root_path / ".github").iterdir()):
                print(f"      {'📁' if item.is_dir() else '📄'} {item.name}")
    print()

    # Scan
    print("📂 Scanning target folders...")
    all_included = []
    all_skipped = []

    for folder_path in existing_folders:
        print(f"   Scanning: {folder_path.name}/")
        inc, skip = scan_folder(folder_path, root_path)
        all_included.extend(inc)
        all_skipped.extend(skip)
        print(f"      → {len(inc)} included, {len(skip)} skipped")

    included = all_included
    skipped = all_skipped

    included.sort(key=lambda x: str(x['rel_path']).lower())
    skipped.sort(key=lambda x: str(x['rel_path']).lower())

    # ✅ POST-SCAN: Compare raw vs included
    print()
    print("=" * 80)
    print("🔍 POST-SCAN: .github/workflows/ verification")
    print("=" * 80)
    included_workflows = [
        e for e in included
        if '.github/workflows' in str(e['rel_path']).replace('\\', '/').lower()
    ]
    print(f"   Raw filesystem:   {len(raw_workflow_files)}")
    print(f"   Included in scan: {len(included_workflows)}")

    if len(raw_workflow_files) != len(included_workflows):
        print(f"   ⚠️  MISMATCH! Some files were skipped.")
        raw_paths = {str(p.relative_to(root_path)).replace('\\', '/').lower() for p in raw_workflow_files}
        inc_paths = {str(e['rel_path']).replace('\\', '/').lower() for e in included_workflows}
        missing = raw_paths - inc_paths
        if missing:
            print(f"   ❌ MISSING files ({len(missing)}):")
            for m in sorted(missing):
                print(f"      - {m}")
            # Find reason
            for entry in skipped:
                rel = str(entry['rel_path']).replace('\\', '/').lower()
                if rel in missing:
                    print(f"      Reason for {rel}: {entry['reason']}")
    else:
        print(f"   ✅ All workflow files included!")
    print()

    # Summary
    total_size = 0
    type_summary = {}
    folder_summary = {}

    for entry in included:
        try:
            sz = entry['path'].stat().st_size
            total_size += sz
            suf = entry['path'].suffix.lower() or '(no ext)'
            if suf not in type_summary:
                type_summary[suf] = {'count': 0, 'size': 0}
            type_summary[suf]['count'] += 1
            type_summary[suf]['size'] += sz

            rel_str = str(entry['rel_path']).replace('\\', '/')
            top_folder = rel_str.split('/')[0] if '/' in rel_str else '(root)'
            if top_folder not in folder_summary:
                folder_summary[top_folder] = {'count': 0, 'size': 0}
            folder_summary[top_folder]['count'] += 1
            folder_summary[top_folder]['size'] += sz
        except Exception:
            pass

    print(f"✅ Included: {len(included)} files, {format_size(total_size)}")
    print(f"⏭️  Skipped:  {len(skipped)} items")
    print()

    if folder_summary:
        print("📁 Folder breakdown:")
        for folder, info in sorted(folder_summary.items()):
            print(f"   {folder}/: {info['count']} files ({format_size(info['size'])})")
        print()

    # Write output
    print(f"✍️  Writing {OUTPUT_FILE}...")
    try:
        out_handle = open(OUTPUT_FILE, 'w', encoding='utf-8')
    except Exception as e:
        print(f"❌ Cannot open: {e}")
        sys.exit(1)

    with out_handle as out:
        out.write("=" * 80 + "\n")
        out.write("ROJGARNEST - DEPLOY, MONITORING & .GITHUB EXPORT\n")
        out.write("=" * 80 + "\n")
        out.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out.write(f"Source: {ROOT_PATH}\n")
        out.write(f"Target Folders: {', '.join(TARGET_FOLDERS)}\n")
        out.write(f"NOTE: .github/workflows/ and .github/actions/ = ALL files (no filter)\n")
        out.write(f"Total Files Included: {len(included)}\n")
        out.write(f"Total Skipped: {len(skipped)}\n")
        out.write(f"Total Size: {format_size(total_size)}\n")
        out.write("=" * 80 + "\n\n")

        # Verification section
        out.write("=" * 80 + "\n")
        out.write("🔍 .GITHUB/WORKFLOWS VERIFICATION\n")
        out.write("=" * 80 + "\n\n")
        out.write(f"Raw filesystem count:  {len(raw_workflow_files)}\n")
        out.write(f"Included in export:    {len(included_workflows)}\n")
        if len(raw_workflow_files) == len(included_workflows):
            out.write("✅ All workflow files included\n")
        else:
            out.write(f"⚠️  MISMATCH: {len(raw_workflow_files) - len(included_workflows)} file(s) missing\n")
        out.write("\nWorkflow files:\n")
        for e in included_workflows:
            out.write(f"  ✅ {e['rel_path']}\n")
        out.write("\n\n")

        # Folder breakdown
        if folder_summary:
            out.write("=" * 80 + "\n")
            out.write("📁 FOLDER BREAKDOWN\n")
            out.write("=" * 80 + "\n\n")
            for folder, info in sorted(folder_summary.items()):
                out.write(f"  {folder}/: {info['count']} files ({format_size(info['size'])})\n")
            out.write("\n\n")

        # Skipped
        out.write("=" * 80 + "\n")
        out.write("⏭️  SKIPPED (Detailed Reason)\n")
        out.write("=" * 80 + "\n\n")
        if skipped:
            for e in skipped:
                tag = "📁" if e['is_dir'] else get_file_icon(e['path'])
                out.write(f"  {tag} {e['rel_path']}  →  {e['reason']}\n")
        else:
            out.write("  (none)\n")
        out.write("\n\n")

        # Tree
        out.write("=" * 80 + "\n")
        out.write("📁 DIRECTORY STRUCTURE\n")
        out.write("=" * 80 + "\n\n")
        for folder_path in existing_folders:
            out.write(f"📁 {folder_path.name}/\n")
            for line in generate_tree_structure(folder_path, folder_path):
                out.write(line + "\n")
            out.write("\n")
        out.write("\n")

        # Summary
        out.write("=" * 80 + "\n")
        out.write("📊 FILE SUMMARY\n")
        out.write("=" * 80 + "\n\n")
        out.write(f"Total Files: {len(included)}\n")
        out.write(f"Total Size: {format_size(total_size)}\n\n")
        out.write("By extension:\n")
        for suf, info in sorted(type_summary.items(), key=lambda x: x[1]['count'], reverse=True):
            out.write(f"  {suf}: {info['count']} files ({format_size(info['size'])})\n")
        out.write("\n\n")

        # File contents
        out.write("=" * 80 + "\n")
        out.write("📄 ALL FILE CONTENTS\n")
        out.write("=" * 80 + "\n\n")

        total = len(included)
        i = 0
        for folder_path in existing_folders:
            folder_name = folder_path.name
            folder_files = [
                e for e in included
                if str(e['rel_path']).replace('\\', '/').split('/')[0] == folder_name
            ]

            out.write("\n" + "█" * 80 + "\n")
            out.write(f"█ FOLDER: {folder_name}/  ({len(folder_files)} files)\n")
            out.write("█" * 80 + "\n\n")

            for entry in folder_files:
                i += 1
                file_path = entry['path']
                rel_path = get_relative_path(file_path, root_path)
                icon = get_file_icon(file_path)

                try:
                    size = file_path.stat().st_size
                    mtime = datetime.fromtimestamp(file_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                except Exception:
                    size = 0
                    mtime = 'unknown'

                content, encoding = read_file_content(file_path)

                pct = (i / total) * 100 if total > 0 else 0
                print(f"  [{i:4d}/{total}] ({pct:5.1f}%) {rel_path}")

                out.write("=" * 80 + "\n")
                out.write(f"[{i:4d}/{total:4d}] {icon} {rel_path}\n")
                out.write(f"📏 SIZE: {format_size(size)}\n")
                out.write(f"🕐 MODIFIED: {mtime}\n")
                out.write(f"✅ INCLUDE REASON: {entry['reason']}\n")
                if encoding != 'utf-8':
                    out.write(f"📝 ENCODING: {encoding}\n")
                out.write("=" * 80 + "\n\n")
                out.write(content)
                out.write("\n\n")

        out.write("=" * 80 + "\n")
        out.write("🎉 EXPORT COMPLETED!\n")
        out.write("=" * 80 + "\n")
        out.write(f"Total Files: {total}\n")
        out.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out.write("=" * 80 + "\n")

    try:
        output_size = os.path.getsize(OUTPUT_FILE)
    except Exception:
        output_size = 0

    print()
    print("=" * 80)
    print("🎉 EXPORT COMPLETED!")
    print("=" * 80)
    print(f"📄 Output: {OUTPUT_FILE}")
    print(f"📊 Included: {len(included)} files")
    print(f"⏭️  Skipped: {len(skipped)} items")
    print(f"💾 Size: {format_size(output_size)}")
    print(f"📁 Path: {os.path.abspath(OUTPUT_FILE)}")
    print("=" * 80)


if __name__ == "__main__":
    try:
        export_deploy_monitoring()
    except KeyboardInterrupt:
        print("\n\n❌ Cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
