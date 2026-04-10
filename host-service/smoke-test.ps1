param(
    [string]$HostExe = (Join-Path $PSScriptRoot "build-output\jpackage\PackingElf Host\PackingElf Host.exe"),
    [string]$BaseUrl = "http://127.0.0.1:48080",
    [string]$PairingToken = "dev-token",
    [int]$StartupTimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

function Invoke-HostJson {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [hashtable]$Headers,
        [object]$Body
    )

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
    }

    return Invoke-RestMethod `
        -Method $Method `
        -Uri $Uri `
        -Headers $Headers `
        -ContentType "application/json" `
        -Body ($Body | ConvertTo-Json -Depth 8)
}

if (-not (Test-Path $HostExe)) {
    throw "Host executable not found at $HostExe. Run host-service\build.ps1 first."
}

$startedHost = $null

try {
    $startedHost = Start-Process -FilePath $HostExe -PassThru

    $health = $null
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $health = Invoke-HostJson -Method Get -Uri "$BaseUrl/api/v1/health"
            break
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    if ($null -eq $health -or -not $health.ok) {
        throw "Host health check did not succeed within $StartupTimeoutSeconds seconds."
    }

    $clientId = [Guid]::NewGuid().Guid
    $headers = @{
        "X-Pairing-Token" = $PairingToken
        "X-Client-Id" = $clientId
    }

    $pairResponse = Invoke-HostJson `
        -Method Post `
        -Uri "$BaseUrl/api/v1/pair" `
        -Headers $headers `
        -Body @{
            client_id = $clientId
            client_name = "host-smoke-test"
        }

    if (-not $pairResponse.ok) {
        throw "Pairing failed: $($pairResponse.message)"
    }

    $now = (Get-Date).ToUniversalTime().ToString("o")
    $orderNumber = "SMOKE-" + (Get-Date -Format "yyyyMMddHHmmss")
    $mutationId = [Guid]::NewGuid().Guid
    $payload = @{
        id                   = [Guid]::NewGuid().Guid
        order_number         = $orderNumber
        invoice_number       = "INV-" + (Get-Date -Format "HHmmss")
        order_date           = (Get-Date).ToString("yyyy-MM-dd")
        buyer_name           = "Smoke Test Buyer"
        order_status         = "success"
        using_coupon         = $true
        created_by_client_id = $clientId
        updated_by_client_id = $clientId
        created_at           = $now
        updated_at           = $now
        deleted_at           = $null
    }

    $pushResponse = Invoke-HostJson `
        -Method Post `
        -Uri "$BaseUrl/api/v1/mutations/batch" `
        -Headers $headers `
        -Body @{
            client_id = $clientId
            mutations = @(
                @{
                    mutation_id       = $mutationId
                    client_id         = $clientId
                    entity_type       = "order"
                    entity_key        = $orderNumber
                    operation         = "upsert_order"
                    payload           = $payload
                    client_created_at = $now
                }
            )
        }

    if (-not $pushResponse.ok) {
        throw "Mutation push failed: $($pushResponse.message)"
    }

    if ($pushResponse.accepted_mutation_ids -notcontains $mutationId) {
        throw "Host did not acknowledge the smoke-test mutation."
    }

    $changesResponse = Invoke-HostJson `
        -Method Get `
        -Uri "$BaseUrl/api/v1/changes?since_revision=0&limit=20" `
        -Headers $headers

    if (-not $changesResponse.ok) {
        throw "Change fetch failed: $($changesResponse.message)"
    }

    $matchingChange = $changesResponse.changes | Where-Object {
        $_.entity_key -eq $orderNumber -and $_.change_type -eq "upsert_order"
    } | Select-Object -First 1

    if ($null -eq $matchingChange) {
        throw "Host change feed did not contain the smoke-test order."
    }

    Write-Host "Host smoke test passed." -ForegroundColor Green
    Write-Host "Order number: $orderNumber"
    Write-Host "Latest revision: $($pushResponse.latest_revision)"
} finally {
    if ($startedHost -and -not $startedHost.HasExited) {
        Stop-Process -Id $startedHost.Id -Force
    }
}
