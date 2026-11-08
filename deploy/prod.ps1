# ============================================================
# ROJGARNEST — PRODUCTION RUNNER (WINDOWS SERVER)
# ============================================================
param(
    [Parameter(Position=0)]
    [ValidateSet("start","stop","logs","restart","ps","rebuild","clean","seed","shell","mongo","backup","health")]
    [string]$Command = "start"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Log($m)     { Write-Host "▶ $m" -ForegroundColor Cyan }
function Write-Success($m) { Write-Host "✅ $m" -ForegroundColor Green }
function Write-Warn($m)    { Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err($m)     { Write-Host "❌ $m" -ForegroundColor Red; exit 1 }

# ============================================================
# COMPOSE
# ============================================================
$composeArgs = @(
    "compose",
    "-f", "docker-compose.yml",
    "-f", "docker-compose.prod.yml",
    "--env-file", ".env.prod"
)

function Ensure-Env {
    if (-not (Test-Path ".env.prod")) {
        Write-Err ".env.prod not found. Copy from .env.prod.example."
    }
    $content = Get-Content ".env.prod" -Raw
    if ($content -notmatch "MONGO_ROOT_PASSWORD=.+") {
        Write-Err "MONGO_ROOT_PASSWORD not set in .env.prod"
    }
}

function Cmd-Start {
    Ensure-Env
    Write-Log "Starting PRODUCTION stack (server)..."
    docker @composeArgs up --build -d
    Write-Success "Production stack is up!"
    Write-Host ""
    Write-Host "  🌐 Frontend : http://localhost:80"
    Write-Host "  🔌 Backend  : internal (via Nginx)"
    Write-Host ""
}

function Cmd-Stop {
    Write-Log "Stopping..."
    docker @composeArgs down
    Write-Success "Stopped"
}

function Cmd-Logs    { docker @composeArgs logs -f }
function Cmd-Restart {
    Write-Log "Restarting..."
    docker @composeArgs restart
    Write-Success "Restarted"
}
function Cmd-Ps      { docker @composeArgs ps }

function Cmd-Rebuild {
    Ensure-Env
    Write-Log "Full rebuild (no cache)..."
    docker @composeArgs down
    docker @composeArgs build --no-cache
    docker @composeArgs up -d
    Write-Success "Rebuild complete"
}

function Cmd-Clean {
    Write-Warn "⚠️  This will DELETE ALL PRODUCTION DATA."
    $c = Read-Host "Type 'DELETE' to confirm"
    if ($c -ne "DELETE") { Write-Warn "Cancelled"; return }
    docker @composeArgs down -v --rmi local
    Write-Success "Cleaned"
}

function Cmd-Seed {
    docker @composeArgs exec backend python seed_schemes.py
    Write-Success "Seeding complete"
}

function Cmd-Shell { docker @composeArgs exec backend bash }

function Cmd-Mongo {
    $user = (Select-String -Path .env.prod -Pattern "^MONGO_ROOT_USERNAME=(.+)$").Matches.Groups[1].Value
    $pass = (Select-String -Path .env.prod -Pattern "^MONGO_ROOT_PASSWORD=(.+)$").Matches.Groups[1].Value
    docker @composeArgs exec mongo mongosh -u $user -p $pass --authenticationDatabase admin RojgarNest
}

function Cmd-Backup {
    Ensure-Env
    Write-Log "Backing up MongoDB..."
    New-Item -ItemType Directory -Path "backups" -Force | Out-Null
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "backups/mongo_${ts}.gz"
    # Using mongo container's env vars
    docker @composeArgs exec -T mongo sh -c `
        'mongodump --archive --gzip --uri="mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@localhost:27017/RojgarNest?authSource=admin"' `
        | Out-File -FilePath $file -Encoding binary
    Write-Success "Backup saved: $file"
}

function Cmd-Health {
    Write-Log "Checking health..."
    $ok = $true
    try { Invoke-WebRequest -UseBasicParsing -Uri "http://localhost/healthz" -TimeoutSec 5 | Out-Null; Write-Host "  ✅ Frontend : OK" -ForegroundColor Green } catch { Write-Host "  ❌ Frontend : FAIL" -ForegroundColor Red; $ok = $false }
    try { Invoke-WebRequest -UseBasicParsing -Uri "http://localhost/api/v1/health" -TimeoutSec 5 | Out-Null; Write-Host "  ✅ Backend  : OK" -ForegroundColor Green } catch { Write-Host "  ❌ Backend  : FAIL" -ForegroundColor Red; $ok = $false }
    if ($ok) { Write-Success "All healthy" } else { Write-Err "Some unhealthy" }
}

switch ($Command) {
    "start"   { Cmd-Start }
    "stop"    { Cmd-Stop }
    "logs"    { Cmd-Logs }
    "restart" { Cmd-Restart }
    "ps"      { Cmd-Ps }
    "rebuild" { Cmd-Rebuild }
    "clean"   { Cmd-Clean }
    "seed"    { Cmd-Seed }
    "shell"   { Cmd-Shell }
    "mongo"   { Cmd-Mongo }
    "backup"  { Cmd-Backup }
    "health"  { Cmd-Health }
}