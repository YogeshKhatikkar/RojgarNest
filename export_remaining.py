# scripts/export_all_except.py
"""
RojgarNest - Full Project Exporter (EXCLUDE MODE)
Exports EVERY file under ROOT_PATH EXCEPT:
  - backend/   (entire folder)
  - frontend/  (entire folder)
  - .git/      (entire folder)
  - *.txt      (all .txt files — prevents self-recursion & log noise)

Run: python scripts/export_all_except.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Tuple, Dict

# ==================== CONFIGURATION ====================

ROOT_PATH = r"E:\YOGESH\website\SevaNext"
OUTPUT_FILE = "full_project_export.txt"

# ❌ Folders to EXCLUDE (case-insensitive, anywhere in tree)
EXCLUDE_FOLDERS = {
    'backend',
    'frontend',
    '.git',
}

# ❌ File extensions to EXCLUDE
EXCLUDE_EXTENSIONS = {
    '.txt',   # output file khud .txt hai — recursion avoid
}

# Hard safety: in folders ko kabhi andar mat jao
HARD_SKIP_FOLDERS = {
    'node_modules', '.venv', 'venv', 'env', '__pycache__',
    '.pytest_cache', '.mypy_cache', '.ruff_cache',
    '.idea', '.vscode', '.next', 'dist', 'build',
    'coverage', 'htmlcov', '.cache', '.turbo',
}

# Exact filenames to skip
SKIP_FILES_EXACT = {
    '.DS_Store', 'Thumbs.db', 'desktop.ini',
    OUTPUT_FILE,  # apna hi output skip karo
}

# Binary / huge file extensions to skip (content can't be read as text)
BINARY_EXTENSIONS = {
    '.zip', '.tar', '.tgz', '.rar', '.7z', '.gz', '.bz2',
    '.pyc', '.pyo', '.class', '.o', '.obj', '.so', '.dll', '.exe', '.dylib', '.wasm',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.ico', '.webp', '.svg',
    '.mp4', '.mov', '.avi', '.mkv', '.webm',
    '.mp3', '.wav', '.ogg', '.flac',
    '.woff', '.woff2', '.ttf', '.otf', '.eot',
    '.pdf', '.doc', '.docx', '.pptx', '.xlsx', '.xls',
    '.db', '.sqlite', '.sqlite3',
    '.pem', '.key', '.crt', '.cer', '.p12', '.pfx', '.jks',
}

# Max size per file (10 MB) — bade files skip (log mein reason aayega)
MAX_FILE_SIZE = 10 * 1024 * 1024

# ==================== HELPERS ====================


def normalize(path: Path) -> str:
    return str(path).replace('\\', '/').lower()


def is_excluded_folder(folder_path: Path) -> Tuple[bool, str]:
    name = folder_path.name.lower()
    if name in EXCLUDE_FOLDERS:
        return True, f"excluded folder '{name}'"
    if name in HARD_SKIP_FOLDERS:
        return True, f"hard-skip folder '{name}'"
    return False, ""


def is_excluded_file(file_path: Path) -> Tuple[bool, str]:
    name = file_path.name
    name_lower = name.lower()
    suffix = file_path.suffix.lower()

    if name in SKIP_FILES_EXACT:
        return True, "system/output file"

    if suffix in EXCLUDE_EXTENSIONS:
        return True, f"excluded extension '{suffix}'"

    if suffix in BINARY_EXTENSIONS:
        return True, f"binary extension '{suffix}'"

    try:
        size = file_path.stat().st_size
        if size > MAX_FILE_SIZE:
            return True, f"too large ({size / (1024*1024):.1f} MB)"
    except Exception as e:
        return True, f"stat error: {e}"

    return False, ""


def read_file_content(file_path: Path) -> Tuple[str, str]:
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1']
    for enc in encodings:
        try:
            with open(file_path, 'r', encoding=enc) as f:
                return f.read(), enc
        except UnicodeDecodeError:
            continue
        except Exception:
            continue
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            return f.read(), 'utf-8 (with replacements)'
    except Exception as e:
        return f"[ERROR: Could not read file - {e}]", 'error'


def format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


def get_file_icon(file_path: Path) -> str:
    suffix = file_path.suffix.lower()
    icons = {
        '.py': '🐍', '.js': '💛', '.ts': '💙', '.jsx': '⚛️', '.tsx': '⚛️',
        '.json': '📋', '.yaml': '⚙️', '.yml': '⚙️', '.conf': '⚙️', '.ini': '⚙️',
        '.md': '📝', '.txt': '📄', '.html': '🌐', '.htm': '🌐',
        '.css': '🎨', '.scss': '🎨', '.sass': '🎨', '.less': '🎨',
        '.sql': '🗄️', '.sh': '📜', '.bat': '🪟', '.ps1': '💻',
        '.tf': '🏗️', '.xml': '📄', '.toml': '⚙️',
        '.env': '🔐', '.lock': '🔒',
        '.java': '☕', '.go': '🐹', '.rs': '🦀', '.rb': '💎', '.php': '🐘',
    }
    return icons.get(suffix, '📄')


def get_rel(file_path: Path, base: Path) -> str:
    try:
        return str(file_path.relative_to(base)).replace('\\', '/')
    except ValueError:
        return str(file_path).replace('\\', '/')


# ==================== SCAN ====================


def scan_folder(folder: Path, root: Path) -> Tuple[List[Dict], List[Dict]]:
    included, skipped = [], []

    def walk(current: Path):
        try:
            for item in sorted(current.iterdir()):
                try:
                    rel = item.relative_to(root)
                except ValueError:
                    rel = item

                if not item.exists():
                    continue

                is_dir = item.is_dir() and not item.is_symlink()
                is_file = item.is_file() or (item.is_symlink() and item.resolve().is_file())

                if is_dir:
                    ex, reason = is_excluded_folder(item)
                    if ex:
                        skipped.append({'path': item, 'rel_path': rel,
                                        'reason': reason, 'is_dir': True})
                    else:
                        walk(item)

                elif is_file:
                    ex, reason = is_excluded_file(item)
                    entry = {'path': item, 'rel_path': rel,
                             'reason': reason, 'is_dir': False}
                    if ex:
                        skipped.append(entry)
                    else:
                        included.append(entry)

        except PermissionError as e:
            print(f"⚠️ Permission denied: {current} — {e}")
        except Exception as e:
            print(f"⚠️ Error scanning {current}: {e}")

    walk(folder)
    return included, skipped


def generate_tree(folder: Path, root: Path, prefix: str = "") -> List[str]:
    lines = []
    try:
        items = []
        for item in sorted(folder.iterdir()):
            if item.is_dir() and not item.is_symlink():
                ex, _ = is_excluded_folder(item)
                if not ex:
                    items.append(item)
            elif item.is_file():
                ex, _ = is_excluded_file(item)
                if not ex:
                    items.append(item)
        for i, item in enumerate(items):
            last = (i == len(items) - 1)
            conn = "└── " if last else "├── "
            if item.is_dir():
                lines.append(f"{prefix}{conn}📁 {item.name}/")
                ext = "    " if last else "│   "
                lines.extend(generate_tree(item, root, prefix + ext))
            else:
                lines.append(f"{prefix}{conn}{get_file_icon(item)} {item.name}")
    except Exception as e:
        lines.append(f"{prefix}[Error: {e}]")
    return lines


# ==================== MAIN ====================


def export_all():
    print("=" * 80)
    print("🚀 ROJGARNEST - FULL PROJECT EXPORTER (EXCLUDE MODE)")
    print("=" * 80)
    print(f"   ROOT_PATH:  {ROOT_PATH}")
    print(f"   OUTPUT_FILE: {OUTPUT_FILE}")
    print(f"   EXCLUDING folders: {', '.join(sorted(EXCLUDE_FOLDERS))}")
    print(f"   EXCLUDING extensions: {', '.join(sorted(EXCLUDE_EXTENSIONS))}")
    print()

    root = Path(ROOT_PATH)
    if not root.exists() or not root.is_dir():
        print(f"❌ Root not found: {ROOT_PATH}")
        sys.exit(1)

    print("📂 Scanning (excluding backend/, frontend/, .git/, *.txt)...")
    included, skipped = scan_folder(root, root)
    included.sort(key=lambda x: str(x['rel_path']).lower())
    skipped.sort(key=lambda x: str(x['rel_path']).lower())

    total_size = 0
    type_summary: Dict[str, Dict] = {}
    folder_summary: Dict[str, Dict] = {}

    for e in included:
        try:
            sz = e['path'].stat().st_size
            total_size += sz
            suf = e['path'].suffix.lower() or '(no ext)'
            type_summary.setdefault(suf, {'count': 0, 'size': 0})
            type_summary[suf]['count'] += 1
            type_summary[suf]['size'] += sz

            rel = str(e['rel_path']).replace('\\', '/')
            top = rel.split('/')[0] if '/' in rel else '(root)'
            folder_summary.setdefault(top, {'count': 0, 'size': 0})
            folder_summary[top]['count'] += 1
            folder_summary[top]['size'] += sz
        except Exception:
            pass

    print(f"✅ Included: {len(included)} files, {format_size(total_size)}")
    print(f"⏭️  Skipped: {len(skipped)} items")
    print()

    print("📁 Folder breakdown:")
    for folder, info in sorted(folder_summary.items()):
        print(f"   {folder}/: {info['count']} files ({format_size(info['size'])})")
    print()

    # ---- Write output ----
    print(f"✍️  Writing {OUTPUT_FILE}...")
    try:
        out = open(OUTPUT_FILE, 'w', encoding='utf-8')
    except Exception as e:
        print(f"❌ Cannot open output: {e}")
        sys.exit(1)

    with out:
        out.write("=" * 80 + "\n")
        out.write("ROJGARNEST - FULL PROJECT EXPORT (EXCLUDE MODE)\n")
        out.write("=" * 80 + "\n")
        out.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out.write(f"Source: {ROOT_PATH}\n")
        out.write(f"Excluded folders: {', '.join(sorted(EXCLUDE_FOLDERS))}\n")
        out.write(f"Excluded extensions: {', '.join(sorted(EXCLUDE_EXTENSIONS))}\n")
        out.write(f"Total Files Included: {len(included)}\n")
        out.write(f"Total Skipped: {len(skipped)}\n")
        out.write(f"Total Size: {format_size(total_size)}\n")
        out.write("=" * 80 + "\n\n")

        # Folder breakdown
        out.write("=" * 80 + "\n📁 FOLDER BREAKDOWN\n" + "=" * 80 + "\n\n")
        for folder, info in sorted(folder_summary.items()):
            out.write(f"  {folder}/: {info['count']} files ({format_size(info['size'])})\n")
        out.write("\n\n")

        # Skipped
        out.write("=" * 80 + "\n⏭️  SKIPPED\n" + "=" * 80 + "\n\n")
        if skipped:
            for e in skipped:
                tag = "📁" if e['is_dir'] else get_file_icon(e['path'])
                out.write(f"  {tag} {e['rel_path']}  →  {e['reason']}\n")
        else:
            out.write("  (none)\n")
        out.write("\n\n")

        # Tree
        out.write("=" * 80 + "\n📁 DIRECTORY STRUCTURE\n" + "=" * 80 + "\n\n")
        out.write(f"📁 RojgarNest/\n")
        for line in generate_tree(root, root):
            out.write(line + "\n")
        out.write("\n\n")

        # Summary
        out.write("=" * 80 + "\n📊 FILE SUMMARY\n" + "=" * 80 + "\n\n")
        out.write(f"Total Files: {len(included)}\n")
        out.write(f"Total Size: {format_size(total_size)}\n\n")
        out.write("By extension:\n")
        for suf, info in sorted(type_summary.items(),
                                key=lambda x: x[1]['count'], reverse=True):
            out.write(f"  {suf}: {info['count']} files ({format_size(info['size'])})\n")
        out.write("\n\n")

        # File contents
        out.write("=" * 80 + "\n📄 ALL FILE CONTENTS\n" + "=" * 80 + "\n\n")

        total = len(included)
        for i, e in enumerate(included, 1):
            fp = e['path']
            rel = get_rel(fp, root)
            icon = get_file_icon(fp)
            try:
                sz = fp.stat().st_size
                mtime = datetime.fromtimestamp(fp.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            except Exception:
                sz, mtime = 0, 'unknown'

            content, enc = read_file_content(fp)
            pct = (i / total) * 100 if total else 0
            print(f"  [{i:4d}/{total}] ({pct:5.1f}%) {rel}")

            out.write("=" * 80 + "\n")
            out.write(f"[{i:4d}/{total:4d}] {icon} {rel}\n")
            out.write(f"📏 SIZE: {format_size(sz)}\n")
            out.write(f"🕐 MODIFIED: {mtime}\n")
            if enc != 'utf-8':
                out.write(f"📝 ENCODING: {enc}\n")
            out.write("=" * 80 + "\n\n")
            out.write(content)
            out.write("\n\n")

        out.write("=" * 80 + "\n🎉 EXPORT COMPLETED!\n" + "=" * 80 + "\n")
        out.write(f"Total Files: {total}\n")
        out.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out.write("=" * 80 + "\n")

    try:
        out_size = os.path.getsize(OUTPUT_FILE)
    except Exception:
        out_size = 0

    print()
    print("=" * 80)
    print("🎉 EXPORT COMPLETED!")
    print("=" * 80)
    print(f"📄 Output: {OUTPUT_FILE}")
    print(f"📊 Included: {len(included)} files")
    print(f"⏭️  Skipped: {len(skipped)} items")
    print(f"💾 Size: {format_size(out_size)}")
    print(f"📁 Path: {os.path.abspath(OUTPUT_FILE)}")
    print("=" * 80)


if __name__ == "__main__":
    try:
        export_all()
    except KeyboardInterrupt:
        print("\n\n❌ Cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
