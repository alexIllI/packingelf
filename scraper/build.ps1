# ─────────────────────────────────────────────────────────────────────────────
# build.ps1 — Build & deploy scraper.exe via PyInstaller
#
# Run from the scraper/ directory:
#   cd packingelf\scraper
#   .\build.ps1
#
# Output:
#   dist\scraper.exe              (single-file exe, ~150 MB with Chromium)
#   Also deployed to Qt build dirs so the app finds it automatically:
#     ..\desktop-app\build\msvc-debug\Debug\scraper\dist\scraper.exe
#     ..\desktop-app\build\msvc-release\Release\scraper\dist\scraper.exe
#
# NOTE: PyInstaller is NOT listed in requirements.txt because it is a
# build/packaging tool only — it must never appear in the production
# scraper.exe itself or in CI dependency scans.
# ─────────────────────────────────────────────────────────────────────────────

param(
    [switch]$SkipBrowserInstall  # Pass -SkipBrowserInstall to skip 'playwright install chromium'
)

Write-Host "=== PackingElf Scraper — Build Script ===" -ForegroundColor Cyan
Write-Host "Working directory: $(Get-Location)"

# ── 1. Create / activate virtual environment ──────────────────────────────────
if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create venv"; exit 1 }
}
Write-Host "Activating .venv..." -ForegroundColor Yellow
.\.venv\Scripts\Activate.ps1

# ── 2. Install runtime dependencies ───────────────────────────────────────────
Write-Host "Installing runtime dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "pip install requirements failed"; exit 1 }

# ── 3. Install PyInstaller (DEV-ONLY — not in requirements.txt) ───────────────
# PyInstaller is only needed to build the distribution exe.
# It is NOT included in requirements.txt to keep the scraper runtime clean
# and to prevent it from appearing in production or CI dependency graphs.
Write-Host "Installing PyInstaller (build tool only)..." -ForegroundColor Yellow
pip install pyinstaller --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "pip install pyinstaller failed"; exit 1 }

# ── 4. Install Playwright's Chromium browser (skip if already installed) ──────
if (-not $SkipBrowserInstall) {
    Write-Host "Installing Playwright Chromium browser..." -ForegroundColor Yellow
    playwright install chromium
    if ($LASTEXITCODE -ne 0) { Write-Warning "playwright install chromium failed (may already be installed)" }
}

# ── 5. Find Playwright package path (needed for PyInstaller --add-data) ───────
$playwright_path = python -c "import playwright, os; print(os.path.dirname(playwright.__file__))"
Write-Host "Playwright package path: $playwright_path" -ForegroundColor Gray

# ── 6. Run PyInstaller ────────────────────────────────────────────────────────
# --onefile:       bundle everything (incl. Chromium) into one self-extracting exe
# --name scraper:  output will be dist\scraper.exe
# --add-data:      include the playwright Python package (browser binaries inside)
# --collect-all:   collect all submodules and data files for playwright
# --noconsole is NOT used — we need stdout/stderr for IPC with the Qt app
# --strip is NOT used on Windows (it's a Unix linker flag)
# Dev-only tools (PyInstaller itself, setuptools, etc.) are NOT bundled because
# PyInstaller only bundles what the script actually imports.

Write-Host "Running PyInstaller..." -ForegroundColor Yellow
pyinstaller `
    --onefile `
    --name scraper `
    --add-data "$playwright_path;playwright" `
    --collect-all playwright `
    --hidden-import playwright `
    --hidden-import cryptography `
    --noconfirm `
    src/__main__.py

if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller failed"; exit 1 }

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "Executable: dist\scraper.exe"

# ── 7. Deploy to Qt build output directories ──────────────────────────────────
# The Qt app looks for scraper/dist/scraper.exe relative to its own exe.
# Copy the built exe to each known build output so running the app 'just works'.

$scriptDir   = $PSScriptRoot                           # .../packingelf/scraper/
$repoRoot    = Split-Path $scriptDir -Parent           # .../packingelf/
$desktopApp  = Join-Path $repoRoot "desktop-app"
$builtExe    = Join-Path $scriptDir "dist\scraper.exe"

$buildTargets = @(
    (Join-Path $desktopApp "build\msvc-debug\Debug\scraper\dist"),
    (Join-Path $desktopApp "build\msvc-release\Release\scraper\dist")
)

foreach ($target in $buildTargets) {
    if (Test-Path (Split-Path (Split-Path $target -Parent) -Parent)) {
        # Only deploy if the build dir itself exists (i.e. cmake has been run)
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Write-Host "Deploying to: $target" -ForegroundColor Cyan
        Copy-Item $builtExe -Destination $target -Force
        Write-Host "  Copied scraper.exe -> $target\scraper.exe" -ForegroundColor Green
    } else {
        Write-Host "  Skipping (build dir not found): $target" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Quick test (manual login):" -ForegroundColor Cyan
Write-Host "  dist\scraper.exe daemon --manual-login"
Write-Host ""
Write-Host "To run the Qt app with the new exe, just rebuild and launch:"
Write-Host "  cd ..\desktop-app"
Write-Host "  cmake --build --preset msvc-debug"
Write-Host "  .\build\msvc-debug\Debug\packingelf.exe"
