Write-Host "=== PackingElf Host Build ===" -ForegroundColor Cyan

if (-not $env:JAVA_HOME) {
    Write-Error "JAVA_HOME must point to a JDK 21 installation before building the host application."
    exit 1
}

$mavenCommand = Get-Command mvn -ErrorAction SilentlyContinue
if (-not $mavenCommand) {
    $repoLocalMaven = Join-Path (Split-Path $PSScriptRoot -Parent) ".tools\apache-maven-3.9.9\bin\mvn.cmd"
    if (Test-Path $repoLocalMaven) {
        $mavenCommand = $repoLocalMaven
    } else {
        Write-Error "Maven (mvn) is required on PATH, or provide .tools\apache-maven-3.9.9\bin\mvn.cmd in the repo."
        exit 1
    }
}

Push-Location $PSScriptRoot
try {
    $packagedOutput = Join-Path $PSScriptRoot "build-output\jpackage"
    if (Test-Path $packagedOutput) {
        Remove-Item -LiteralPath $packagedOutput -Recurse -Force
    }

    & $mavenCommand `
        "-Dmaven.repo.local=$(Join-Path (Split-Path $PSScriptRoot -Parent) '.tools\m2')" `
        -DskipTests `
        clean `
        package `
        org.panteleyev:jpackage-maven-plugin:jpackage
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Host build failed."
        exit $LASTEXITCODE
    }

    Write-Host "Host app image created under .\build-output\jpackage" -ForegroundColor Green
} finally {
    Pop-Location
}
