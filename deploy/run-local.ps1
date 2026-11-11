# ============================================================
# SevaNext - Local & Server Docker Runner (Windows PowerShell)
# File: deploy/run-local.ps1
# ============================================================
# WHAT IT DOES:
#   1. NUKES ALL old Docker containers / images / volumes / networks / build cache
#   2. Rebuilds backend + frontend images from scratch
#   3. Starts MongoDB + Redis, waits for healthy
#   4. Starts backend, waits for /api/v1/health
#   5. Starts frontend (nginx), waits for /healthz
#   6. Verifies frontend -> backend proxy works
#   7. Opens browser at http://localhost:8080
#
# USAGE:
#   cd deploy
#   .\run-local.ps1                 # full nuke + rebuild + start
#   .\run-local.ps1 --no-nuke       # keep volumes (only rebuild containers)
#   .\run-local.ps1 --server        # run on PROD server via SSH
# ============================================================

$ErrorActionPreference = "Stop"

# ---- Parse flags ----
$noNukeFlag   = $false
$serverFlag   = $false
foreach ($a in $args) {
    if ($a -eq "--no-nuke") { $noNukeFlag = $true }
    if ($a -eq "--server")  { $serverFlag = $true }
}

function Write-Header($msg) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}
function Write-Step($msg)  { Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $msg" -ForegroundColor Yellow }
function Write-Ok($msg)    { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "  ✘ $msg" -ForegroundColor Red }

Write-Header "SEVANEXT - DOCKER FULL RESET & DEPLOY"

# ---- Sanity ----
if (-not (Test-Path "docker-compose.yml")) {
    Write-Err "docker-compose.yml not found. Run from the 'deploy' folder."
    exit 1
}
if (-not (Test-Path ".env.local")) {
    Write-Err ".env.local not found in deploy folder."
    exit 1
}
if (-not (Test-Path "..\backend\sevanext\.env")) {
    Write-Warn2 "../backend/sevanext/.env not found — backend may fail."
}

$composeArgs = @(
    "-f", "docker-compose.yml",
    "-f", "docker-compose.dev.yml",
    "--env-file", ".env.local"
)
$projectName = "sevanext"

# ============================================================
# SERVER MODE — delegates to run-prod.sh over SSH
# ============================================================
if ($serverFlag) {
    Write-Step "SERVER MODE: reading .env.prod for SSH target..."
    if (-not (Test-Path ".env.prod")) {
        Write-Err ".env.prod not found. Copy .env.prod.example → .env.prod and fill it."
        exit 1
    }
    $cfg = @{}
    Get-Content ".env.prod" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') { $cfg[$Matches[1].Trim()] = $Matches[2].Trim() }
    }
    $host = $cfg["SSH_HOST"]; $user = $cfg["SSH_USER"]; $port = if ($cfg["SSH_PORT"]) { $cfg["SSH_PORT"] } else { "22" }
    if (-not $host -or -not $user) {
        Write-Err "SSH_HOST / SSH_USER must be set in .env.prod"
        exit 1
    }
    Write-Step "Running run-prod.sh on ${user}@${host}:${port} ..."
    ssh -p $port "${user}@${host}" "cd /opt/sevanext/deploy && bash run-prod.sh"
    if ($LASTEXITCODE -ne 0) { Write-Err "Server deploy failed (exit $LASTEXITCODE)"; exit 1 }
    Write-Ok "Server deploy finished."
    exit 0
}

# ============================================================
# STEP 1 — NUKE EVERYTHING (unless --no-nuke)
# ============================================================
if (-not $noNukeFlag) {
    Write-Step "[1/8] FULL NUKE — removing containers, images, volumes, networks, build cache..."

    Write-Host "  -> docker compose down -v --remove-orphans (all compose profiles)"
    docker compose @composeArgs down -v --remove-orphans 2>$null
    docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.prod down -v --remove-orphans 2>$null

    Write-Host "  -> Removing ALL containers"
    $allContainers = docker ps -aq
    if ($allContainers) { docker rm -f $allContainers 2>$null }

    Write-Host "  -> Removing ALL images"
    $allImages = docker images -q
    if ($allImages) { docker rmi -f $allImages 2>$null }

    Write-Host "  -> Removing ALL volumes"
    $allVolumes = docker volume ls -q
    if ($allVolumes) { docker volume rm -f $allVolumes 2>$null }

    Write-Host "  -> Pruning networks"
    docker network prune -f 2>$null

    Write-Host "  -> Pruning build cache"
    docker builder prune -af 2>$null

    Write-Host "  -> Pruning system"
    docker system prune -af --volumes 2>$null

    Write-Ok "FULL NUKE complete."
} else {
    Write-Warn2 "[1/8] --no-nuke: keeping existing volumes & images"
    docker compose @composeArgs down --remove-orphans 2>$null
}

# ============================================================
# STEP 2 — VERIFY DOCKER DAEMON
# ============================================================
Write-Step "[2/8] Verifying Docker daemon..."
$dockerInfo = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker daemon not running. Start Docker Desktop and retry."
    exit 1
}
Write-Ok "Docker daemon running."

# ============================================================
# STEP 3 — BUILD BACKEND + FRONTEND (always no-cache after nuke)
# ============================================================
Write-Step "[3/8] Building backend + frontend images (no-cache)..."

$buildArgs = @()
if (-not $noNukeFlag) { $buildArgs += "--no-cache" }

docker compose @composeArgs build @buildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Err "docker compose build FAILED (exit $LASTEXITCODE). Scroll up for the real error."
    exit 1
}
Write-Ok "Images built."

# ============================================================
# STEP 4 — START STACK
# ============================================================
Write-Step "[4/8] Starting stack (mongo, redis, backend, frontend)..."
docker compose @composeArgs up -d --remove-orphans
if ($LASTEXITCODE -ne 0) {
    Write-Err "docker compose up FAILED (exit $LASTEXITCODE)."
    Write-Host "  Recent logs:" -ForegroundColor Gray
    docker compose @composeArgs logs --tail=80
    exit 1
}
Write-Ok "Containers launched."

# ============================================================
# STEP 5 — WAIT FOR MONGO
# ============================================================
Write-Step "[5/8] Waiting for MongoDB (max 120s)..."
$elapsed = 0
$ok = $false
while ($elapsed -lt 120) {
    $status = docker inspect --format='{{.State.Health.Status}}' sevanext-local-mongo 2>$null
    if ($status -eq "healthy") { $ok = $true; break }
    Start-Sleep -Seconds 3; $elapsed += 3
    Write-Host "      [$elapsed s] mongo: $status" -ForegroundColor DarkGray
}
if (-not $ok) {
    Write-Err "MongoDB not healthy after 120s."
    docker logs --tail 60 sevanext-local-mongo
    exit 1
}
Write-Ok "MongoDB healthy."

# ============================================================
# STEP 6 — WAIT FOR BACKEND HEALTH
# ============================================================
Write-Step "[6/8] Waiting for backend /api/v1/health (max 300s)..."
$elapsed = 0
$ok = $false
while ($elapsed -lt 300) {
    $status = docker inspect --format='{{.State.Health.Status}}' sevanext-local-backend 2>$null
    if ($status -eq "healthy") { $ok = $true; break }
    if ($status -eq "unhealthy") {
        Write-Err "Backend became UNHEALTHY."
        docker logs --tail 100 sevanext-local-backend
        exit 1
    }
    Start-Sleep -Seconds 3; $elapsed += 3
    Write-Host "      [$elapsed s] backend: $status" -ForegroundColor DarkGray
}
if (-not $ok) {
    Write-Warn2 "Backend not healthy after 300s — showing last 100 logs:"
    docker logs --tail 100 sevanext-local-backend
    Write-Warn2 "Common fixes:"
    Write-Host "        - ../backend/sevanext/.env has MONGO_URI, SECRET_KEY, JWT_SECRET_KEY" -ForegroundColor Gray
    Write-Host "        - MongoDB started: docker logs sevanext-local-mongo" -ForegroundColor Gray
    Write-Host "        - Redis started:   docker logs sevanext-local-redis" -ForegroundColor Gray
}

# ============================================================
# STEP 7 — WAIT FOR FRONTEND + VERIFY PROXY
# ============================================================
Write-Step "[7/8] Waiting for frontend + verifying proxy chain..."

try {
    $r = Invoke-WebRequest -Uri "http://localhost:8000/api/v1/health" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { Write-Ok "Backend direct:      http://localhost:8000/api/v1/health  -> 200" }
} catch { Write-Warn2 "Backend direct not reachable yet." }

try {
    $r = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/health" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { Write-Ok "Nginx -> backend:    http://localhost:8080/api/v1/health  -> 200" }
} catch { Write-Warn2 "Nginx proxy not reachable yet." }

try {
    $r = Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { Write-Ok "Frontend:            http://localhost:8080/  -> 200" }
} catch { Write-Warn2 "Frontend not reachable yet." }

# ============================================================
# STEP 8 — SUCCESS + OPEN BROWSER
# ============================================================
Write-Header "✅ DEPLOYMENT COMPLETE"

Write-Host ""
Write-Host "  🌐 Frontend:              http://localhost:8080" -ForegroundColor White
Write-Host "  📘 Swagger (direct):      http://localhost:8000/docs" -ForegroundColor White
Write-Host "  📘 Swagger (via nginx):   http://localhost:8080/docs" -ForegroundColor White
Write-Host "  💚 Backend health:        http://localhost:8000/api/v1/health" -ForegroundColor White
Write-Host "  💚 Nginx proxy health:    http://localhost:8080/api/v1/health" -ForegroundColor White
Write-Host "  🗄️  MongoDB:               mongodb://localhost:27017/SevaNext" -ForegroundColor White
Write-Host "  ⚡ Redis:                  redis://localhost:6379" -ForegroundColor White
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor DarkGray
Write-Host "    docker compose @composeArgs logs -f backend" -ForegroundColor DarkGray
Write-Host "    docker compose @composeArgs logs -f frontend" -ForegroundColor DarkGray
Write-Host "    docker compose @composeArgs ps" -ForegroundColor DarkGray
Write-Host "    docker compose @composeArgs down" -ForegroundColor DarkGray
Write-Host ""

Write-Step "[8/8] Opening browser..."
Start-Sleep -Seconds 1
Start-Process "http://localhost:8080"
Write-Host ""
Write-Host "  🎉 Happy testing!" -ForegroundColor Green
Write-Host ""