param(
    [switch]$SkipClientBuild,
    [switch]$SkipHostBuild,
    [switch]$SkipScraperBuild,
    [switch]$PortableOnly,
    [switch]$PreferIfw
)

$ErrorActionPreference = "Stop"
$appVersion = "1.0.5"

function Write-Step($message) {
    Write-Host ""
    Write-Host "== $message ==" -ForegroundColor Cyan
}

function Resolve-BinaryCreator {
    $command = Get-Command binarycreator.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $qtRoot = "C:\Qt"
    if (Test-Path $qtRoot) {
        $match = Get-ChildItem -Path $qtRoot -Filter binarycreator.exe -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    return $null
}

function Resolve-Iscc {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $knownPaths = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Antigravity\resources\app\node_modules\innosetup\bin\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $knownPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    $programRoots = @(
        "$env:LOCALAPPDATA\Programs",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "C:\Program Files (x86)",
        "C:\Program Files"
    )
    foreach ($root in $programRoots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $match = Get-ChildItem -Path $root -Filter ISCC.exe -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    return $null
}

function Resolve-ClientOutputDir($repoRoot) {
    $searchRoots = @(
        (Join-Path $repoRoot "desktop-app\build\msvc-release\Release"),
        (Join-Path $repoRoot "desktop-app\build\msvc-release")
    )

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $exe = Get-ChildItem -Path $root -Filter packingelf.exe -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($exe) {
            return $exe.Directory.FullName
        }
    }

    return $null
}

function Ensure-ClientBuild($repoRoot) {
    Write-Step "Building client release"
    Push-Location (Join-Path $repoRoot "desktop-app")
    try {
        cmake --preset msvc-release
        if ($LASTEXITCODE -ne 0) { throw "Client configure failed." }

        cmake --build --preset msvc-release
        if ($LASTEXITCODE -ne 0) { throw "Client release build failed." }
    }
    finally {
        Pop-Location
    }
}

function Ensure-ScraperBuild($repoRoot) {
    Write-Step "Building packaged scraper"
    Push-Location (Join-Path $repoRoot "scraper")
    try {
        & ".\build.ps1"
        if ($LASTEXITCODE -ne 0) { throw "Scraper build failed." }
    }
    finally {
        Pop-Location
    }
}

function Ensure-HostBuild($repoRoot) {
    Write-Step "Building host app"
    & (Join-Path $repoRoot "host-service\build.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Host build failed." }
}

function Copy-DirectoryContents($sourceDir, $destinationDir) {
    Remove-Item -Recurse -Force $destinationDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item (Join-Path $sourceDir "*") -Destination $destinationDir -Recurse -Force
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$ifwRoot = Join-Path $repoRoot "installers\ifw"
$packagesRoot = Join-Path $ifwRoot "packages"
$clientPackageData = Join-Path $packagesRoot "com.meridian.packingelf.client\data\PackingElf Client"
$hostPackageData = Join-Path $packagesRoot "com.meridian.packingelf.host\data\PackingElf Host"
$outputDir = Join-Path $repoRoot "dist"
$portableDir = Join-Path $outputDir "portable"

if (-not $SkipClientBuild) {
    Ensure-ClientBuild $repoRoot
}

if (-not $SkipScraperBuild) {
    Ensure-ScraperBuild $repoRoot
}

if (-not $SkipHostBuild) {
    Ensure-HostBuild $repoRoot
}

$clientOutputDir = Resolve-ClientOutputDir $repoRoot
if (-not $clientOutputDir) {
    throw "Client release output not found. Expected packingelf.exe under desktop-app\build\msvc-release."
}

$hostOutputDir = Join-Path $repoRoot "host-service\build-output\jpackage\PackingElf Host"
if (-not (Test-Path $hostOutputDir)) {
    throw "Host app image not found at $hostOutputDir."
}

$scraperExe = Join-Path $repoRoot "scraper\dist\scraper.exe"
if (-not (Test-Path $scraperExe)) {
    $releaseScraperExe = Join-Path $clientOutputDir "scraper\dist\scraper.exe"
    if (Test-Path $releaseScraperExe) {
        $scraperExe = $releaseScraperExe
    } else {
        throw "Packaged scraper.exe not found. Build scraper\build.ps1 first."
    }
}

Write-Step "Preparing package data"
Copy-DirectoryContents $clientOutputDir $clientPackageData
Copy-DirectoryContents $hostOutputDir $hostPackageData

$clientScraperDir = Join-Path $clientPackageData "scraper\dist"
New-Item -ItemType Directory -Force -Path $clientScraperDir | Out-Null
Copy-Item $scraperExe -Destination (Join-Path $clientScraperDir "scraper.exe") -Force

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

$portableClientDir = Join-Path $portableDir "PackingElf Client"
$portableHostDir = Join-Path $portableDir "PackingElf Host"
Copy-DirectoryContents $clientPackageData $portableClientDir
Copy-DirectoryContents $hostPackageData $portableHostDir

Write-Host "Portable client output: $portableClientDir" -ForegroundColor Green
Write-Host "Portable host output:   $portableHostDir" -ForegroundColor Green

if ($PortableOnly) {
    Write-Host ""
    Write-Host "Portable packages prepared. Skipping installer creation because -PortableOnly was used." -ForegroundColor Yellow
    exit 0
}

$installerPath = Join-Path $outputDir "PackingElf-Setup-$appVersion.exe"

$iscc = if (-not $PreferIfw) { Resolve-Iscc } else { $null }
if ($iscc) {
    Write-Step "Creating installer with Inno Setup"
    & $iscc `
        "/DRepoRoot=$repoRoot" `
        "/DMyAppVersion=$appVersion" `
        (Join-Path $repoRoot "installers\inno\packingelf.iss")

    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed."
    }

    Write-Host ""
    Write-Host "Installer created at $installerPath" -ForegroundColor Green
    exit 0
}

$binaryCreator = Resolve-BinaryCreator
if (-not $binaryCreator) {
    throw @"
No supported installer compiler was found.

Preferred option:
  Install Inno Setup (ISCC.exe), then rerun:
    .\scripts\build-installer.ps1

Alternative option:
  Install Qt Installer Framework (binarycreator.exe), then rerun:
    .\scripts\build-installer.ps1 -PreferIfw
"@
}

Write-Step "Creating installer with Qt Installer Framework"
& $binaryCreator `
    --config (Join-Path $ifwRoot "config\config.xml") `
    --packages $packagesRoot `
    $installerPath

if ($LASTEXITCODE -ne 0) {
    throw "binarycreator failed."
}

Write-Host ""
Write-Host "Installer created at $installerPath" -ForegroundColor Green
