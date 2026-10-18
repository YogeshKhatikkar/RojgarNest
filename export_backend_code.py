#!/usr/bin/env python3
"""
Export Backend Code to a Single Text File - WITH ENV SANITIZATION
This script scans the entire backend/rojgarnext/ folder and exports ALL code files
to a single txt file, BUT it sanitizes the .env file by replacing ALL actual values
with dummy/placeholder values.

This ensures you can safely share the code without exposing your secrets.

Usage: python export_backend_code.py
"""

import os
import re
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple

# ================= CONFIGURATION =================
BACKEND_ROOT = Path(__file__).parent / "backend" / "rojgarnest"

if not BACKEND_ROOT.exists():
    if Path.cwd().name == "rojgarnext" and (Path.cwd() / "app").exists():
        BACKEND_ROOT = Path.cwd()
    else:
        for path in Path.cwd().parents:
            if (path / "backend" / "rojgarnext").exists():
                BACKEND_ROOT = path / "backend" / "rojgarnext"
                break

OUTPUT_FILE = "backend_complete_export.txt"

# Skip only these
SKIP_DIRS = {'.venv', '__pycache__', '.git', '.pytest_cache', 'node_modules', '.idea', '.vscode'}
SKIP_FILES = {'.DS_Store', '*.pyc', '*.pyo', '*.pyd', '*.so', '*.dll', '*.exe', OUTPUT_FILE, 'backend.txt', 'service-account-key.json'}

# Include extensions
INCLUDE_EXTENSIONS = {
    '.py', '.yaml', '.yml', '.json', '.txt', '.md', '.sql', '.sh', '.bat',
    '.ps1', '.dockerfile', '.conf', '.ini', '.toml', '.xml', '.html', '.css', '.js'
}

MAX_FILE_SIZE = 10 * 1024 * 1024


# ================= ENV SANITIZATION MAPPING =================
# KEY ke according dummy value map karo
ENV_SANITIZATION_RULES = {
    # Database
    'MONGO_URI': 'mongodb://localhost:27017/rojgarnext',
    'DATABASE_NAME': 'rojgarnext',
    'ENVIRONMENT': 'development',
    
    # Security
    'SECRET_KEY': 'your-secret-key-change-in-production-minimum-32-chars',
    'JWT_SECRET_KEY': 'your-jwt-secret-key-change-in-production',
    'SESSION_SECRET_KEY': 'your-session-secret-key-change-in-production',
    'ENCRYPTION_KEY': 'your-encryption-key-change-in-production',
    
    # Redis
    'REDIS_URL': 'redis://localhost:6379',
    
    # SMTP / Email
    'SMTP_HOST': 'smtp.gmail.com',
    'SMTP_PORT': '587',
    'SMTP_USER': 'your-email@gmail.com',
    'SMTP_PASSWORD': 'your-app-password-here',
    'SMTP_FROM': 'your-email@gmail.com',
    
    # SMS / Twilio
    'TWILIO_ACCOUNT_SID': 'your_twilio_account_sid',
    'TWILIO_AUTH_TOKEN': 'your_twilio_auth_token',
    'TWILIO_PHONE': '+1234567890',
    'MOBILE_OTP_BYPASS': 'true',
    
    # App
    'APP_BASE_URL': 'http://localhost:8000',
    'SECURE_FOLDER_PATH': './secure',
    'SECRET_TOKEN': 'your-secret-token-here',
    
    # APIs
    'OPENAI_API_KEY': 'your_openai_api_key_here',
    'OPENAI_MODEL': 'gpt-4o-mini',
    'PROXY_POOL': '["proxy1:port","proxy2:port"]',
    'CAPTCHA_API_KEY': 'your_captcha_api_key',
    'DISABLE_AUTH': 'false',
    'FAST2SMS_API_KEY': 'your_fast2sms_api_key',
    
    # Job APIs
    'ADZUNA_APP_ID': 'your_adzuna_app_id',
    'ADZUNA_API_KEY': 'your_adzuna_api_key',
    'FREE_JOB_SEARCH_API_KEY': 'your_free_job_search_api_key',
    'INFOTRIE_API_KEY': 'your_infotrie_api_key',
    'CORESIGNAL_API_KEY': 'your_coresignal_api_key',
    
    # Cloudinary
    'CLOUDINARY_CLOUD_NAME': 'your_cloud_name',
    'CLOUDINARY_API_KEY': 'your_api_key',
    'CLOUDINARY_API_SECRET': 'your_api_secret',
    
    # Google Drive
    'GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL': 'your-service-account@project.iam.gserviceaccount.com',
    'GOOGLE_DRIVE_PRIVATE_KEY': '-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----',
    'GOOGLE_DRIVE_FOLDER_ID': 'your_google_drive_folder_id_here',
    'GOOGLE_DRIVE_FOLDER_NAME': 'rojgarnext_advertisements',
    
    # Blockchain
    'WEB3_PROVIDER_URL': 'https://mainnet.infura.io/v3/YOUR_PROJECT_ID',
    'CONTRACT_ADDRESS': '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
    'ISSUER_ADDRESS': '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B',
    
    # Stripe
    'STRIPE_SECRET_KEY': 'sk_test_your_stripe_secret_key',
    'STRIPE_PUBLISHABLE_KEY': 'pk_test_your_stripe_publishable_key',
    
    # AI / ML
    'ML_MODELS_PATH': './models',
    'AI_LEARNING_RATE': '0.01',
    'AUTO_RETRAIN_INTERVAL_HOURS': '24',
    'ENABLE_AUTO_APPLY': 'true',
    'ENABLE_AUTO_SHORTLIST': 'true',
    'AUTO_SHORTLIST_THRESHOLD': '85',
    'ENABLE_SMART_NOTIFICATIONS': 'true',
    
    # CORS
    'CORS_ORIGINS': '["http://localhost:3000","http://localhost:8000"]',
    
    # Fake Job Detection
    'FAKE_JOB_DETECTION_ENABLED': 'true',
    'FAKE_JOB_CONFIDENCE_THRESHOLD': '60',
    'DUPLICATE_JOB_DAYS_THRESHOLD': '30',
    'MAX_JOBS_PER_FETCH': '50',
    
    # Access Tokens
    'ACCESS_TOKEN_EXPIRE_MINUTES': '1440',
    'REFRESH_TOKEN_EXPIRE_DAYS': '7',
}


def sanitize_env_file(content: str) -> str:
    """
    Sanitize .env file content by replacing actual values with dummy values.
    Original values ko hide karta hai, dummy values show karta hai.
    """
    lines = content.split('\n')
    sanitized_lines = []
    
    for line in lines:
        # Remove leading/trailing whitespace
        line = line.rstrip('\n\r')
        
        # Skip empty lines
        if not line.strip():
            sanitized_lines.append(line)
            continue
        
        # Skip comments
        if line.strip().startswith('#'):
            sanitized_lines.append(line)
            continue
        
        # Check if line has KEY=VALUE format
        if '=' in line:
            # Split at first '='
            parts = line.split('=', 1)
            key = parts[0].strip()
            value = parts[1].strip() if len(parts) > 1 else ''
            
            # Apply sanitization if key is in mapping
            if key in ENV_SANITIZATION_RULES:
                dummy_value = ENV_SANITIZATION_RULES[key]
                # Preserve quotes if original had quotes
                if value.startswith('"') and value.endswith('"'):
                    sanitized_lines.append(f'{key}="{dummy_value}"')
                elif value.startswith("'") and value.endswith("'"):
                    sanitized_lines.append(f"{key}='{dummy_value}'")
                else:
                    sanitized_lines.append(f'{key}={dummy_value}')
            else:
                # Unknown key - put placeholder
                sanitized_lines.append(f'{key}=[REDACTED_ADD_TO_ENV_SANITIZATION_RULES]')
        else:
            # Malformed line - keep as is
            sanitized_lines.append(line)
    
    # Add warning header at top of .env content
    warning_header = """# ============================================================
# ⚠️  WARNING: THIS IS A SANITIZED .env FILE
# All original values have been replaced with dummy/placeholder values.
# Add your actual credentials in the original .env file.
# ============================================================

"""
    
    return warning_header + '\n'.join(sanitized_lines)


def should_skip_dir(dir_name: str) -> bool:
    """Check if directory should be skipped"""
    return dir_name in SKIP_DIRS


def should_skip_file(file_path: Path) -> bool:
    """Check if file should be skipped"""
    if file_path.name in SKIP_FILES:
        return True
    if file_path.suffix == '.pyc':
        return True
    if file_path.suffix == '.log':
        return True
    if file_path.name == OUTPUT_FILE:
        return True
    if file_path.stat().st_size == 0:
        return True
    if file_path.stat().st_size > MAX_FILE_SIZE:
        return True
    
    ext = file_path.suffix.lower()
    return ext not in INCLUDE_EXTENSIONS and not file_path.suffix == ''


def get_file_encoding(file_path: Path) -> str:
    """Detect file encoding"""
    try:
        with open(file_path, 'rb') as f:
            raw = f.read(1000)
            if raw.startswith(b'\xef\xbb\xbf'):
                return 'utf-8-sig'
            if b'\0' in raw:
                return 'utf-16'
    except:
        pass
    return 'utf-8'


def read_file_safely(file_path: Path, is_env_file: bool = False) -> str:
    """
    Read file safely. If it's .env file, sanitize the content.
    """
    encoding = get_file_encoding(file_path)
    try:
        with open(file_path, 'r', encoding=encoding, errors='replace') as f:
            content = f.read()
        
        # ✅ CRITICAL: Sanitize .env file content
        if is_env_file or file_path.name == '.env' or file_path.suffix == '.env':
            content = sanitize_env_file(content)
        
        return content
    except Exception as e:
        return f"ERROR: Could not read file - {str(e)}\n"


def scan_directory(root: Path, base_path: Path, all_files: List[Dict]) -> None:
    """Scan directory recursively and return list of files"""
    try:
        for item in sorted(root.iterdir()):
            if not item.exists():
                continue
            
            if item.is_dir():
                if should_skip_dir(item.name):
                    print(f"⏭️  Skipping directory: {item.relative_to(base_path)}")
                    continue
                scan_directory(item, base_path, all_files)
            
            elif item.is_file():
                if should_skip_file(item):
                    continue
                
                try:
                    rel_path = item.relative_to(base_path)
                    # Check if it's .env file
                    is_env = (item.name == '.env' or item.suffix == '.env')
                    all_files.append({
                        'path': item,
                        'rel_path': rel_path,
                        'size': item.stat().st_size,
                        'is_env': is_env
                    })
                except Exception as e:
                    print(f"⚠️ Error processing {item}: {e}")
                    continue
                    
    except PermissionError:
        print(f"⚠️ Permission denied: {root}")
    except Exception as e:
        print(f"⚠️ Error scanning {root}: {e}")


def format_file_content(path: Path, rel_path: Path, content: str, file_num: int, total: int, is_env: bool = False) -> str:
    """Format file content with header"""
    separator = "=" * 80
    
    if path.suffix == '.py':
        file_type = "🐍 PYTHON FILE"
    elif is_env or path.name == '.env':
        file_type = "🔐 ENV FILE (SANITIZED - Dummy Values Only)"
    else:
        file_type = "📄 TEXT FILE"
    
    env_note = ""
    if is_env or path.name == '.env':
        env_note = "\n⚠️  NOTE: This .env file has been sanitized. All original values replaced with dummy placeholders.\n"
    
    return f"""
{separator}
[{file_num:4d}/{total:4d}] {file_type}: {rel_path}
📏 SIZE: {path.stat().st_size:,} bytes
🕐 MODIFIED: {datetime.fromtimestamp(path.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')}
{env_note}
{separator}

{content}
"""


def generate_tree_structure(root: Path, base_path: Path, prefix: str = "", is_last: bool = True) -> List[str]:
    """Generate complete directory tree structure"""
    lines = []
    
    try:
        items = []
        for item in sorted(root.iterdir()):
            if should_skip_dir(item.name):
                continue
            if item.is_file() and should_skip_file(item):
                continue
            items.append(item)
        
        for i, item in enumerate(items):
            is_last_item = (i == len(items) - 1)
            connector = "└── " if is_last_item else "├── "
            
            if item.is_dir():
                lines.append(f"{prefix}{connector}📁 {item.name}/")
                extension = "    " if is_last_item else "│   "
                lines.extend(generate_tree_structure(item, base_path, prefix + extension))
            else:
                if item.name == '.env':
                    icon = "🔐"
                elif item.suffix == '.py':
                    icon = "🐍"
                elif item.suffix in ['.json', '.yaml', '.yml']:
                    icon = "⚙️"
                elif item.suffix == '.md':
                    icon = "📝"
                else:
                    icon = "📄"
                lines.append(f"{prefix}{connector}{icon} {item.name}")
    except Exception as e:
        lines.append(f"{prefix}[Error reading directory: {e}]")
    
    return lines


def main():
    """Main function"""
    print("=" * 80)
    print("📦 ROJARGAR NEXT - COMPLETE BACKEND EXPORTER (with .env Sanitization)")
    print("=" * 80)
    
    if not BACKEND_ROOT.exists():
        print(f"\n❌ Error: Backend directory not found!")
        print(f"   Tried: {BACKEND_ROOT}")
        sys.exit(1)
    
    print(f"\n📁 Scanning directory: {BACKEND_ROOT}")
    print(f"📄 Output file: {OUTPUT_FILE}")
    print(f"🔐 .env file will be SANITIZED (original values replaced with dummies)")
    print("-" * 80)
    
    # Scan all files
    print("\n🔍 Scanning for ALL files...")
    all_files = []
    scan_directory(BACKEND_ROOT, BACKEND_ROOT, all_files)
    
    # Sort files by path
    all_files.sort(key=lambda x: str(x['rel_path']))
    
    total_files = len(all_files)
    py_count = sum(1 for f in all_files if f['path'].suffix == '.py')
    env_count = sum(1 for f in all_files if f['is_env'] or f['path'].name == '.env')
    other_count = total_files - py_count - env_count
    
    print(f"\n✅ Found {total_files} files to export")
    print(f"   🐍 Python files: {py_count}")
    print(f"   🔐 ENV files (will be sanitized): {env_count}")
    print(f"   📄 Other files: {other_count}")
    
    # Generate output lines
    output_lines = []
    
    # Header
    output_lines.append("=" * 80)
    output_lines.append("ROJARGAR NEXT BACKEND - COMPLETE CODE EXPORT (SANITIZED)")
    output_lines.append("=" * 80)
    output_lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    output_lines.append(f"Source: {BACKEND_ROOT.absolute()}")
    output_lines.append(f"Total Files: {total_files}")
    output_lines.append(f"  - Python Files: {py_count}")
    output_lines.append(f"  - ENV Files (Sanitized): {env_count}")
    output_lines.append(f"  - Other Files: {other_count}")
    output_lines.append("=" * 80)
    output_lines.append("")
    output_lines.append("⚠️  IMPORTANT: The .env file in this export has been SANITIZED.")
    output_lines.append("⚠️  All actual credentials, API keys, and secrets have been replaced")
    output_lines.append("⚠️  with dummy/placeholder values for security purposes.")
    output_lines.append("")
    
    # Directory tree
    output_lines.append("=" * 80)
    output_lines.append("📁 COMPLETE DIRECTORY STRUCTURE")
    output_lines.append("=" * 80)
    output_lines.append("")
    output_lines.append(f"📁 backend/rojgarnext/")
    output_lines.extend(generate_tree_structure(BACKEND_ROOT, BACKEND_ROOT))
    output_lines.append("")
    output_lines.append("")
    
    # File contents
    output_lines.append("=" * 80)
    output_lines.append("📄 ALL FILE CONTENTS")
    output_lines.append("=" * 80)
    output_lines.append("")
    
    print("\n📝 Writing file contents...")
    
    for i, file_info in enumerate(all_files, 1):
        path = file_info['path']
        rel_path = file_info['rel_path']
        is_env = file_info.get('is_env', False) or path.name == '.env'
        
        percent = (i / total_files) * 100
        env_marker = "🔐 " if is_env else ""
        print(f"  [{i:4d}/{total_files}] ({percent:5.1f}%) {env_marker}Exporting: {rel_path}")
        
        content = read_file_safely(path, is_env_file=is_env)
        formatted = format_file_content(path, rel_path, content, i, total_files, is_env)
        output_lines.append(formatted)
    
    # Write to output file
    print("\n💾 Writing to output file...")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("\n".join(output_lines))
    
    output_size = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)
    
    print("\n" + "=" * 80)
    print(f"✅ EXPORT COMPLETE!")
    print("=" * 80)
    print(f"📄 Output file: {OUTPUT_FILE}")
    print(f"📊 Total files exported: {total_files}")
    print(f"   🐍 Python files: {py_count}")
    print(f"   🔐 ENV files (sanitized): {env_count}")
    print(f"   📄 Other files: {other_count}")
    print(f"💾 File size: {output_size:.2f} MB")
    print(f"📁 Location: {os.path.abspath(OUTPUT_FILE)}")
    print("=" * 80)
    print("\n🔐 SECURITY NOTE: The .env file has been sanitized.")
    print("   Original credentials, API keys, and secrets are NOT included.")
    print("   You can safely share this file without exposing your sensitive data.")
    print("=" * 80)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Export cancelled by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
