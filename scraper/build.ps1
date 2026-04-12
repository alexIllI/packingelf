param(
    [switch]$SkipBrowserInstall
)

$ErrorActionPreference = "Stop"

Write-Host "=== PackingElf Scraper Build Script ===" -ForegroundColor Cyan
Write-Host "Working directory: $(Get-Location)"

if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create venv"; exit 1 }
}

Write-Host "Activating .venv..." -ForegroundColor Yellow
.\.venv\Scripts\Activate.ps1

Write-Host "Installing runtime dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "pip install requirements failed"; exit 1 }

Write-Host "Installing PyInstaller (build tool only)..." -ForegroundColor Yellow
pip install pyinstaller --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "pip install pyinstaller failed"; exit 1 }

# Force Playwright to place browser binaries inside its package directory so
# PyInstaller can bundle Chromium into scraper.exe.
$env:PLAYWRIGHT_BROWSERS_PATH = "0"

$playwrightPath = python -c "import playwright, os; print(os.path.dirname(playwright.__file__))"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($playwrightPath)) {
    Write-Error "Failed to resolve Playwright package path"; exit 1
}
Write-Host "Playwright package path: $playwrightPath" -ForegroundColor Gray

$embeddedBrowserDir = Join-Path $playwrightPath "driver\package\.local-browsers"
if (-not $SkipBrowserInstall -or -not (Test-Path $embeddedBrowserDir)) {
    Write-Host "Installing Playwright Chromium browser into package..." -ForegroundColor Yellow
    python -m playwright install chromium
    if ($LASTEXITCODE -ne 0) { Write-Error "playwright install chromium failed"; exit 1 }
}

if (-not (Test-Path $embeddedBrowserDir)) {
    Write-Error "Embedded Playwright browser directory was not created at $embeddedBrowserDir"; exit 1
}

Write-Host "Running PyInstaller..." -ForegroundColor Yellow
pyinstaller `
    --onefile `
    --name scraper `
    --add-data "$playwrightPath;playwright" `
    --collect-all playwright `
    --hidden-import playwright `
    --hidden-import cryptography `
    --noconfirm `
    src/__main__.py

if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller failed"; exit 1 }

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "Executable: dist\scraper.exe"

$scriptDir = $PSScriptRoot
$repoRoot = Split-Path $scriptDir -Parent
$desktopApp = Join-Path $repoRoot "desktop-app"
$builtExe = Join-Path $scriptDir "dist\scraper.exe"

$buildTargets = @(
    (Join-Path $desktopApp "build\msvc-debug\Debug\scraper\dist"),
    (Join-Path $desktopApp "build\msvc-release\Release\scraper\dist")
)

foreach ($target in $buildTargets) {
    if (Test-Path (Split-Path (Split-Path $target -Parent) -Parent)) {
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
