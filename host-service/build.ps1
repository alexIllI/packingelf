Write-Host "=== PackingElf Host Build ===" -ForegroundColor Cyan

if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-Error "Maven (mvn) is required on PATH to build the host application."
    exit 1
}

Push-Location $PSScriptRoot
try {
    mvn -DskipTests clean package javafx:jlink org.panteleyev:jpackage-maven-plugin:jpackage
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Host build failed."
        exit $LASTEXITCODE
    }

    Write-Host "Host app image created under .\target\jpackage" -ForegroundColor Green
} finally {
    Pop-Location
}
