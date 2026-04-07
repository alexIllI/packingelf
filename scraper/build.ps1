# ─────────────────────────────────────────────────────────────────────────────
# build.ps1 — Build scraper.exe via PyInstaller
#
# Run from the scraper/ directory:
#   cd packingelf\scraper
#   .\build.ps1
#
# Output: dist\scraper.exe  (single-file executable, ~150 MB with Chromium)
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "=== PackingElf Scraper — Build Script ===" -ForegroundColor Cyan

# 1. Create / activate virtual environment
if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
}
.\.venv\Scripts\Activate.ps1

# 2. Install dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt --quiet

# 3. Install Playwright's Chromium browser
Write-Host "Installing Playwright Chromium browser..." -ForegroundColor Yellow
playwright install chromium

# 4. Find Playwright's Chromium installation path (needed for PyInstaller bundle)
$playwright_path = python -c "import playwright; import os; print(os.path.dirname(playwright.__file__))"
Write-Host "Playwright package path: $playwright_path" -ForegroundColor Gray

# 5. Run PyInstaller
Write-Host "Running PyInstaller..." -ForegroundColor Yellow
pyinstaller `
    --onefile `
    --name scraper `
    --add-data "$playwright_path;playwright" `
    --collect-all playwright `
    --hidden-import playwright `
    --hidden-import cryptography `
    src/__main__.py

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "Executable: dist\scraper.exe"
Write-Host ""
Write-Host "Quick test (manual login):"
Write-Host "  dist\scraper.exe scrape --order PG02491384 --manual-login"
