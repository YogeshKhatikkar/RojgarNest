# ============================================================
# ROJGARNEST — DEVELOPMENT RUNNER (WINDOWS LOCAL)
# ============================================================
param(
    [Parameter(Position=0)]
    [ValidateSet("start","stop","logs","restart","ps","rebuild","clean","seed","shell","mongo","health")]
    [string]$Command = "start"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ============================================================
# HELPERS
# ============================================================
function Write-Log     { param([string]$m) Write-Host "> $m" -ForegroundColor Cyan }
function Write-Success { param([string]$m) Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn    { param([string]$m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err     { param([string]$m) Write-Host "[X] $m" -ForegroundColor Red; exit 1 }

# ============================================================
# GUARD
# ============================================================
if ($env:CI -or $env:GITHUB_ACTIONS -or $env:GITLAB_CI) {
    Write-Err "CI environment detected. Use prod.ps1 on server."
}

# ============================================================
# COMPOSE ARGS
# ============================================================
$composeArgs = @(
    "compose",
    "-f", "docker-compose.yml",
    "-f", "docker-compose.dev.yml",
    "--env-file", ".env.dev"
)

# ============================================================
# ENSURE ENV
# ============================================================
function Ensure-Env {
    if (-not (Test-Path ".env.dev")) {
        if (Test-Path ".env.dev.example") {
            Copy-Item ".env.dev.example" ".env.dev"
            Write-Warn "Created .env.dev from template"
        } else {
            Write-Err ".env.dev missing"
        }
    }
}

# ============================================================
# COMMANDS
# ============================================================
function Cmd-Start {
    Ensure-Env
    Write-Log "Starting DEVELOPMENT stack (local)..."
    docker @composeArgs up --build -d
    if ($LASTEXITCODE -ne 0) {
        Write-Err "docker compose up failed"
    }
    Write-Success "Development stack is up!"
    Write-Host ""
    Write-Host "  Frontend : http://localhost:8080"
    Write-Host "  Backend  : http://localhost:8000"
    Write-Host "  API Docs : http://localhost:8000/docs"
    Write-Host "  MongoDB  : mongodb://localhost:27017"
    Write-Host "  Redis    : redis://localhost:6379"
    Write-Host ""
    Write-Host "  Logs: .\dev.ps1 logs"
    Write-Host "  Stop: .\dev.ps1 stop"
    Write-Host ""
}

function Cmd-Stop {
    Write-Log "Stopping DEVELOPMENT stack..."
    docker @composeArgs down
    Write-Success "Stopped"
}

function Cmd-Logs {
    docker @composeArgs logs -f
}

function Cmd-Restart {
    Write-Log "Restarting DEVELOPMENT stack..."
    docker @composeArgs restart
    Write-Success "Restarted"
}

function Cmd-Ps {
    docker @composeArgs ps
}

function Cmd-Rebuild {
    Ensure-Env
    Write-Log "Full rebuild (no cache) - this takes 8-12 minutes..."
    docker @composeArgs down
    docker @composeArgs build --no-cache
    docker @composeArgs up -d
    Write-Success "Rebuild complete"
}

function Cmd-Clean {
    Write-Warn "WARNING: This will DELETE ALL DATA (mongo + redis volumes)."
    Write-Warn "Type DELETE to confirm:"
    $confirm = Read-Host
    if ($confirm -ne "DELETE") {
        Write-Warn "Cancelled"
        return
    }
    docker @composeArgs down -v --rmi local
    Write-Success "Cleaned - all data deleted"
}

function Cmd-Seed {
    Write-Log "Seeding schemes..."
    docker @composeArgs exec backend python seed_schemes.py
    Write-Success "Seeding complete"
}

function Cmd-Shell {
    Write-Log "Opening shell in backend..."
    docker @composeArgs exec backend bash
}

function Cmd-Mongo {
    Write-Log "Opening mongosh..."
    docker @composeArgs exec mongo mongosh RojgarNest
}

function Cmd-Health {
    Write-Log "Checking health..."
    $ok = $true

    try {
        Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/api/v1/health" -TimeoutSec 5 | Out-Null
        Write-Host "  [OK] Backend  : OK" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Backend  : FAIL" -ForegroundColor Red
        $ok = $false
    }

    try {
        Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080/healthz" -TimeoutSec 5 | Out-Null
        Write-Host "  [OK] Frontend : OK" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Frontend : FAIL" -ForegroundColor Red
        $ok = $false
    }

    if ($ok) {
        Write-Success "All healthy"
    } else {
        Write-Err "Some services unhealthy"
    }
}

# ============================================================
# ROUTER
# ============================================================
switch ($Command) {
    "start"   { Cmd-Start   }
    "stop"    { Cmd-Stop    }
    "logs"    { Cmd-Logs    }
    "restart" { Cmd-Restart }
    "ps"      { Cmd-Ps      }
    "rebuild" { Cmd-Rebuild }
    "clean"   { Cmd-Clean   }
    "seed"    { Cmd-Seed    }
    "shell"   { Cmd-Shell   }
    "mongo"   { Cmd-Mongo   }
    "health"  { Cmd-Health  }
    default   {
        Write-Host "Usage: .\dev.ps1 <command>"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start      Start development stack (default)"
        Write-Host "  stop       Stop stack"
        Write-Host "  logs       Follow logs"
        Write-Host "  restart    Restart stack"
        Write-Host "  ps         Show container status"
        Write-Host "  rebuild    Full rebuild (no cache)"
        Write-Host "  clean      Stop + delete volumes (DESTROYS DATA)"
        Write-Host "  seed       Seed schemes"
        Write-Host "  shell      Shell into backend"
        Write-Host "  mongo      Shell into mongo"
        Write-Host "  health     Check endpoints"
        exit 1
    }
}