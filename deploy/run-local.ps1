# ============================================================
# RojgarNest - Local Docker Runner (Windows PowerShell)
# File: deploy/run-local.ps1
# ============================================================
# Usage:
#   cd deploy
#   .\run-local.ps1
#   .\run-local.ps1 --no-cache
#   .\run-local.ps1 --reset      (wipe containers + volumes, then fresh up)
# ============================================================

$ErrorActionPreference = "Continue"   # don't silently kill the script

$noCacheFlag = $false
$resetFlag   = $false
foreach ($a in $args) {
    if ($a -eq "--no-cache") { $noCacheFlag = $true }
    if ($a -eq "--reset")    { $resetFlag   = $true }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  ROJGARNEST - LOCAL DOCKER DEPLOY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Sanity: are we in the deploy folder?
# ------------------------------------------------------------
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "ERROR: docker-compose.yml not found." -ForegroundColor Red
    Write-Host "       Run this script from the 'deploy' folder." -ForegroundColor Gray
    exit 1
}
if (-not (Test-Path ".env.local")) {
    Write-Host "ERROR: .env.local not found in deploy folder." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "..\backend\rojgarnest\.env")) {
    Write-Host "WARNING: ../backend/rojgarnest/.env not found." -ForegroundColor Yellow
    Write-Host "         Backend will start with defaults and may fail." -ForegroundColor Gray
}

$composeArgs = @(
    "-f", "docker-compose.yml",
    "-f", "docker-compose.dev.yml",
    "--env-file", ".env.local"
)

# ------------------------------------------------------------
# [1/6] Reset (optional)
# ------------------------------------------------------------
if ($resetFlag) {
    Write-Host "[1/6] RESET: removing containers + volumes..." -ForegroundColor Yellow
    docker compose @composeArgs down -v --remove-orphans
    Write-Host "      Reset done." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[1/6] Stopping previous containers..." -ForegroundColor Yellow
    docker compose @composeArgs down --remove-orphans 2>$null
    Write-Host "      Cleanup done." -ForegroundColor Green
    Write-Host ""
}

# ------------------------------------------------------------
# [2/6] Build + Start
# ------------------------------------------------------------
Write-Host "[2/6] Building and starting containers..." -ForegroundColor Yellow
Write-Host "      First backend build can take 2 to 5 minutes." -ForegroundColor DarkGray
Write-Host ""

if ($noCacheFlag) {
    Write-Host "      Building with --no-cache ..." -ForegroundColor DarkGray
    docker compose @composeArgs build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: 'docker compose build --no-cache' FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "       Scroll up — the real error is in the build output above." -ForegroundColor Gray
        exit 1
    }
    docker compose @composeArgs up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: 'docker compose up -d' FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "       Run: docker compose @composeArgs logs" -ForegroundColor Gray
        exit 1
    }
} else {
    docker compose @composeArgs up --build -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: 'docker compose up --build -d' FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "       Common causes:" -ForegroundColor Gray
        Write-Host "         - Port 8080 or 8000 already in use (stop the other app)" -ForegroundColor Gray
        Write-Host "         - Backend Dockerfile build error (scroll up)" -ForegroundColor Gray
        Write-Host "         - Flutter web build error (scroll up)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "       Show recent logs with:" -ForegroundColor Gray
        Write-Host "         docker compose @composeArgs logs --tail=80" -ForegroundColor Gray
        exit 1
    }
}

Write-Host ""
Write-Host "      Containers launched." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# [3/6] Wait for Backend health
# ------------------------------------------------------------
Write-Host "[3/6] Waiting for backend healthcheck (max 300s)..." -ForegroundColor Yellow

$maxWait = 300
$elapsed = 0
$backendReady = $false

while ($elapsed -lt $maxWait) {
    $status = docker inspect --format='{{.State.Health.Status}}' rojgarnest-local-backend 2>$null

    if ($status -eq "healthy") {
        $backendReady = $true
        Write-Host ""
        Write-Host "      Backend is HEALTHY after $elapsed seconds." -ForegroundColor Green
        break
    }

    if ($status -eq "unhealthy") {
        Write-Host ""
        Write-Host "ERROR: Backend became UNHEALTHY." -ForegroundColor Red
        Write-Host "Last 60 lines of backend logs:" -ForegroundColor Gray
        docker logs --tail 60 rojgarnest-local-backend
        break
    }

    Write-Host "      [$elapsed s] backend status: $status" -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
    $elapsed = $elapsed + 3
}

if (-not $backendReady) {
    Write-Host ""
    Write-Host "WARNING: Backend not healthy after $maxWait seconds." -ForegroundColor Yellow
    Write-Host "         Showing last 60 log lines so you can see WHY:" -ForegroundColor Gray
    docker logs --tail 60 rojgarnest-local-backend
    Write-Host ""
    Write-Host "         Common fixes:" -ForegroundColor Gray
    Write-Host "           - Check ../backend/rojgarnest/.env has MONGO_URI, SECRET_KEY, JWT_SECRET_KEY" -ForegroundColor Gray
    Write-Host "           - Check MongoDB started: docker logs rojgarnest-local-mongo" -ForegroundColor Gray
}

Write-Host ""

# ------------------------------------------------------------
# [4/6] Wait for Frontend health
# ------------------------------------------------------------
Write-Host "[4/6] Waiting for frontend healthcheck (max 90s)..." -ForegroundColor Yellow

$maxWait = 90
$elapsed = 0
$frontendReady = $false

while ($elapsed -lt $maxWait) {
    $status = docker inspect --format='{{.State.Health.Status}}' rojgarnest-local-frontend 2>$null

    if ($status -eq "healthy") {
        $frontendReady = $true
        Write-Host "      Frontend is HEALTHY after $elapsed seconds." -ForegroundColor Green
        break
    }

    Start-Sleep -Seconds 2
    $elapsed = $elapsed + 2
}

if (-not $frontendReady) {
    Write-Host "WARNING: Frontend not healthy after $maxWait seconds, continuing anyway." -ForegroundColor Yellow
    Write-Host "         Showing last 40 frontend log lines:" -ForegroundColor Gray
    docker logs --tail 40 rojgarnest-local-frontend
}

Write-Host ""

# ------------------------------------------------------------
# [5/6] Verify endpoints
# ------------------------------------------------------------
Write-Host "[5/6] Verifying backend endpoint..." -ForegroundColor Yellow

try {
    $resp = Invoke-WebRequest -Uri "http://localhost:8000/api/v1/health" -UseBasicParsing -TimeoutSec 5
    if ($resp.StatusCode -eq 200) {
        Write-Host "      Backend /api/v1/health -> 200 OK" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Backend /api/v1/health not yet reachable." -ForegroundColor Yellow
}

try {
    $resp2 = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/health" -UseBasicParsing -TimeoutSec 5
    if ($resp2.StatusCode -eq 200) {
        Write-Host "      Nginx proxy -> backend -> 200 OK" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Nginx proxy not responding yet." -ForegroundColor Yellow
}

Write-Host ""

$frontendUrl    = "http://localhost:8080"
$backendDocsUrl = "http://localhost:8000/docs"
$backendHealth  = "http://localhost:8000/api/v1/health"
$proxyHealth    = "http://localhost:8080/api/v1/health"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Frontend:              $frontendUrl" -ForegroundColor White
Write-Host "  Swagger (direct):      $backendDocsUrl" -ForegroundColor White
Write-Host "  Swagger (proxy):       http://localhost:8080/docs" -ForegroundColor White
Write-Host "  Backend (direct):      $backendHealth" -ForegroundColor White
Write-Host "  Backend (proxy):       $proxyHealth" -ForegroundColor White
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor DarkGray
Write-Host "    docker logs -f rojgarnest-local-backend" -ForegroundColor DarkGray
Write-Host "    docker logs -f rojgarnest-local-frontend" -ForegroundColor DarkGray
Write-Host "    docker logs -f rojgarnest-local-mongo" -ForegroundColor DarkGray
Write-Host "    docker compose @composeArgs down" -ForegroundColor DarkGray
Write-Host ""

# ------------------------------------------------------------
# [6/6] Open browser
# ------------------------------------------------------------
Write-Host "[6/6] Opening frontend in browser..." -ForegroundColor Cyan
Start-Sleep -Seconds 1
Start-Process $frontendUrl

Write-Host ""
Write-Host "Browser opened. Happy testing." -ForegroundColor Green
Write-Host ""