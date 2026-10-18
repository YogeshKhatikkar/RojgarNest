# scripts/export_frontend.py
"""
Frontend Code Exporter for RojgarNext
Exports all Flutter frontend code to a single text file
Run: python scripts/export_frontend.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Tuple, Set

# ==================== CONFIGURATION ====================
# Frontend path - Update this to your actual frontend location
FRONTEND_PATH = r"E:\yogesh\website\rojgarnest\frontend"

# Output file
OUTPUT_FILE = "frontend_export.txt"

# Extensions to include
EXTENSIONS = [
    '.dart', '.yaml', '.yml', '.json', '.md', '.html', '.css', '.js',
    '.xml', '.gradle', '.properties', '.sh', '.bat', '.ps1',
    '.dockerfile', '.conf', '.ini', '.toml'
]

# Folders to exclude
EXCLUDE_FOLDERS = {
    '.dart_tool', '.github', '.idea', '.vscode', 'build', 'node_modules',
    '.git', '__pycache__', 'venv', '.venv', 'env', '.env',
    'android', 'ios', 'linux', 'macos', 'windows', 'test',
    '.flutter-plugins', '.gradle', 'gradle', '.settings'
}

# Files to exclude
EXCLUDE_FILES = {
    'pubspec.lock', '.flutter-plugins', '.flutter-plugins-dependencies',
    'gradle.properties', 'local.properties', 'flutter_export_environment.sh',
    'Podfile.lock', '.gitignore', '.metadata', '*.log', '*.tmp',
    '*.lock', '*.pid', '*.old', '*.symbols'
}

# Specific files to always include (even if in excluded patterns)
FORCE_INCLUDE = {
    'pubspec.yaml', 'analysis_options.yaml', 'Dockerfile', 'README.md',
    'index.html', 'manifest.json', 'favicon.ico'
}

# File size limit (50 MB)
MAX_FILE_SIZE = 50 * 1024 * 1024

# ==================== UTILITY FUNCTIONS ====================

def should_include_file(file_path: Path) -> bool:
    """Check if file should be included in export"""
    file_name = file_path.name
    
    # Force include specific files
    if file_name in FORCE_INCLUDE:
        return True
    
    # Check file size
    try:
        if file_path.stat().st_size > MAX_FILE_SIZE:
            return False
    except:
        pass
    
    # Check extension
    if file_path.suffix not in EXTENSIONS:
        return False
    
    # Check exclude list (with pattern matching)
    for pattern in EXCLUDE_FILES:
        if '*' in pattern:
            import fnmatch
            if fnmatch.fnmatch(file_name, pattern):
                return False
        elif file_name == pattern:
            return False
    
    # Skip empty files
    try:
        if file_path.stat().st_size == 0:
            return False
    except:
        pass
    
    return True


def should_include_folder(folder_path: Path) -> bool:
    """Check if folder should be traversed"""
    folder_name = folder_path.name
    
    # Check exclude list
    if folder_name in EXCLUDE_FOLDERS:
        return False
    
    # Skip hidden folders (starting with .)
    if folder_name.startswith('.') and folder_name not in FORCE_INCLUDE:
        return False
    
    return True


def get_all_files(root_path: Path) -> List[Path]:
    """Get all files to export recursively"""
    all_files = []
    
    try:
        for item in root_path.iterdir():
            if item.is_dir():
                if should_include_folder(item):
                    all_files.extend(get_all_files(item))
            else:
                if should_include_file(item):
                    all_files.append(item)
    except PermissionError:
        pass
    
    return all_files


def read_file_content(file_path: Path) -> Tuple[str, str]:
    """Read file content with proper encoding"""
    # Try different encodings
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1']
    
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
            return content, encoding
        except UnicodeDecodeError:
            continue
        except Exception as e:
            continue
    
    # If all encodings fail, try with replacement
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
        return content, 'utf-8 (with replacements)'
    except Exception as e:
        return f"[ERROR: Could not read file - {str(e)}]", 'error'


def get_file_type_icon(extension: str) -> str:
    """Get icon for file type"""
    icons = {
        '.dart': '🎯',
        '.yaml': '⚙️',
        '.yml': '⚙️',
        '.json': '📋',
        '.md': '📝',
        '.html': '🌐',
        '.css': '🎨',
        '.js': '💛',
        '.txt': '📄',
        '.xml': '📄',
        '.gradle': '📦',
        '.properties': '⚙️',
        '.sh': '📜',
        '.bat': '🪟',
        '.ps1': '💻',
        '.dockerfile': '🐳',
        '.conf': '🔧',
        '.ini': '⚙️',
        '.toml': '📋',
    }
    return icons.get(extension, '📄')


def get_relative_path(file_path: Path, base_path: Path) -> str:
    """Get relative path with forward slashes"""
    try:
        rel = file_path.relative_to(base_path)
        return str(rel).replace('\\', '/')
    except ValueError:
        return str(file_path).replace('\\', '/')


def generate_tree_structure(root_path: Path, prefix: str = "", is_root: bool = True) -> List[str]:
    """Generate directory tree structure"""
    lines = []
    
    if is_root:
        lines.append(f"📁 {root_path.name}/")
        current_prefix = ""
    else:
        current_prefix = prefix
    
    try:
        items = []
        for item in sorted(root_path.iterdir()):
            if item.is_dir():
                if should_include_folder(item):
                    items.append(item)
            else:
                if should_include_file(item):
                    items.append(item)
        
        for i, item in enumerate(items):
            is_last = (i == len(items) - 1)
            connector = "└── " if is_last else "├── "
            
            if item.is_dir():
                icon = "📁"
                lines.append(f"{current_prefix}{connector}{icon} {item.name}/")
                extension = "    " if is_last else "│   "
                lines.extend(generate_tree_structure(item, current_prefix + extension, False))
            else:
                icon = get_file_type_icon(item.suffix)
                lines.append(f"{current_prefix}{connector}{icon} {item.name}")
    except Exception as e:
        lines.append(f"{current_prefix}[Error: {e}]")
    
    return lines


def get_file_summary(all_files: List[Path]) -> dict:
    """Get summary of file types"""
    summary = {}
    for f in all_files:
        ext = f.suffix if f.suffix else '(no extension)'
        if ext not in summary:
            summary[ext] = {'count': 0, 'size': 0}
        summary[ext]['count'] += 1
        try:
            summary[ext]['size'] += f.stat().st_size
        except:
            pass
    return summary


def format_size(size_bytes: int) -> str:
    """Format file size in human readable format"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"


# ==================== MAIN EXPORT FUNCTION ====================

def export_frontend():
    """Main export function"""
    
    print("=" * 80)
    print("🚀 FRONTEND CODE EXPORTER - RojgarNext")
    print("=" * 80)
    print()
    
    # Check if frontend path exists
    frontend_path = Path(FRONTEND_PATH)
    if not frontend_path.exists():
        print(f"❌ ERROR: Frontend path not found!")
        print(f"   Path: {FRONTEND_PATH}")
        print()
        print("Please update FRONTEND_PATH in the script to your actual frontend location.")
        sys.exit(1)
    
    print(f"📁 Source: {frontend_path}")
    print(f"📄 Output: {OUTPUT_FILE}")
    print()
    
    # Get all files
    print("📂 Scanning files...")
    all_files = get_all_files(frontend_path)
    
    # Sort files by path
    all_files.sort(key=lambda x: str(x))
    
    # Get summary
    summary = get_file_summary(all_files)
    total_size = sum(info['size'] for info in summary.values())
    
    print(f"✅ Found {len(all_files)} files to export")
    print(f"💾 Total size: {format_size(total_size)}")
    print()
    print("📊 File type breakdown:")
    for ext, info in sorted(summary.items(), key=lambda x: x[1]['count'], reverse=True):
        icon = get_file_type_icon(ext)
        print(f"   {icon} {ext}: {info['count']} files ({format_size(info['size'])})")
    print()
    
    # Create export content
    print("✍️ Writing export file...")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out_file:
        # Write header
        out_file.write("=" * 80 + "\n")
        out_file.write("ROJGARNEXT FRONTEND - COMPLETE CODE EXPORT\n")
        out_file.write("=" * 80 + "\n")
        out_file.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out_file.write(f"Source: {FRONTEND_PATH}\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write(f"Total Size: {format_size(total_size)}\n")
        out_file.write("=" * 80 + "\n\n")
        
        # Write directory structure
        out_file.write("=" * 80 + "\n")
        out_file.write("📁 COMPLETE DIRECTORY STRUCTURE\n")
        out_file.write("=" * 80 + "\n\n")
        
        tree_lines = generate_tree_structure(frontend_path)
        for line in tree_lines:
            out_file.write(line + "\n")
        out_file.write("\n\n")
        
        # Write file summary
        out_file.write("=" * 80 + "\n")
        out_file.write("📊 FILE SUMMARY\n")
        out_file.write("=" * 80 + "\n\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write(f"Total Size: {format_size(total_size)}\n\n")
        out_file.write("File Types:\n")
        for ext, info in sorted(summary.items(), key=lambda x: x[1]['count'], reverse=True):
            out_file.write(f"  {ext}: {info['count']} files ({format_size(info['size'])})\n")
        out_file.write("\n\n")
        
        # Write all file contents
        out_file.write("=" * 80 + "\n")
        out_file.write("📄 ALL FILE CONTENTS\n")
        out_file.write("=" * 80 + "\n\n")
        
        for i, file_path in enumerate(all_files, 1):
            rel_path = get_relative_path(file_path, frontend_path)
            icon = get_file_type_icon(file_path.suffix)
            size = file_path.stat().st_size
            
            # Read file content
            content, encoding = read_file_content(file_path)
            
            # Write file header
            out_file.write("=" * 80 + "\n")
            out_file.write(f"[{i:4d}/{len(all_files):4d}] {icon} {rel_path}\n")
            out_file.write(f"📏 SIZE: {format_size(size)}\n")
            out_file.write(f"🕐 MODIFIED: {datetime.fromtimestamp(file_path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')}\n")
            if encoding != 'utf-8':
                out_file.write(f"📝 ENCODING: {encoding}\n")
            out_file.write("=" * 80 + "\n\n")
            
            # Write content
            out_file.write(content)
            out_file.write("\n\n")
        
        # Write footer
        out_file.write("=" * 80 + "\n")
        out_file.write("🎉 EXPORT COMPLETED!\n")
        out_file.write("=" * 80 + "\n")
        out_file.write(f"Total Files: {len(all_files)}\n")
        out_file.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out_file.write("=" * 80 + "\n")
    
    # Calculate file size
    output_size = os.path.getsize(OUTPUT_FILE)
    
    print()
    print("=" * 80)
    print("🎉 EXPORT COMPLETED SUCCESSFULLY!")
    print("=" * 80)
    print(f"📄 Output file: {OUTPUT_FILE}")
    print(f"📊 Total files exported: {len(all_files)}")
    print(f"💾 File size: {format_size(output_size)}")
    print()
    print("📁 Files exported include:")
    print("   ✅ lib/ (all Dart files)")
    print("   ✅ pubspec.yaml")
    print("   ✅ analysis_options.yaml")
    print("   ✅ README.md")
    print("   ✅ Dockerfile")
    print("   ✅ assets/ (images, icons, JS files)")
    print("   ✅ web/ (HTML, manifest, etc.)")
    print("   ✅ pubspec.yaml")
    print()
    print("⚠️ WARNING: This file contains ALL your frontend code!")
    print("   Do not share it publicly.")
    print("=" * 80)


# ==================== ENTRY POINT ====================

if __name__ == "__main__":
    try:
        export_frontend()
    except KeyboardInterrupt:
        print("\n\n❌ Export cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error during export: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
