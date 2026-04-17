# 20_fix_all_permissions.ps1
# Ensures all DMV tables have entity permissions via enhanced data model (powerpagecomponents type=18).

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$webRoleId = "c7500f9c-350c-471b-a6da-e16f0f18009c"  # Authenticated Users

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization      = "Bearer $token"
    "Content-Type"     = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}
$readH = @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }

# ── STEP 1: Query existing enhanced permissions ──
Write-Host "=== Querying existing enhanced permissions (powerpagecomponents type=18) ===" -ForegroundColor Cyan
$existingPerms = @()
try {
    $result = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18&`$select=name,powerpagecomponentid,content" -Headers $readH
    $existingPerms = $result.value
    Write-Host "Found $($existingPerms.Count) enhanced permissions"
} catch {
    Write-Host "WARN: $($_.Exception.Message)" -ForegroundColor Yellow
}

$existingMap = @{}
foreach ($ep in $existingPerms) {
    try {
        $c = $ep.content | ConvertFrom-Json
        $tbl = $c.EntityLogicalName
        if ($tbl) {
            $existingMap[$tbl] = @{ id = $ep.powerpagecomponentid; content = $c; name = $ep.name }
            Write-Host "  $tbl | R=$($c.read) C=$($c.create) W=$($c.write) | $($ep.name)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  (unparseable) | $($ep.name)" -ForegroundColor Yellow
    }
}

# ── STEP 2: Ensure permissions for all DMV tables ──
Write-Host "`n=== Ensuring permissions for all DMV tables ===" -ForegroundColor Cyan

$tables = @(
    "dmv_driverlicense", "dmv_vehicle", "dmv_vehicleregistration",
    "dmv_registrationterm", "dmv_registrationpayment",
    "dmv_appointment", "dmv_documentupload", "dmv_vehicletitle",
    "dmv_lien", "dmv_temporarytag", "dmv_bulksubmission",
    "dmv_dmvoffice", "dmv_transactionlog", "dmv_notification"
)

foreach ($table in $tables) {
    $existing = $existingMap[$table]

    if ($existing) {
        Write-Host "  EXISTS: $table ($($existing.id))" -ForegroundColor Green
        $c = $existing.content

        # Check if needs update (ensure read/create/write + web role)
        $needsUpdate = $false
        if ($c.read -ne $true) { $needsUpdate = $true }
        if ($c.create -ne $true) { $needsUpdate = $true }
        if ($c.write -ne $true) { $needsUpdate = $true }
        if (-not $c.adx_entitypermission_webrole -or $c.adx_entitypermission_webrole -notcontains $webRoleId) { $needsUpdate = $true }

        if ($needsUpdate) {
            Write-Host "    Updating permissions + web role..." -ForegroundColor Yellow
            $newContent = @{
                EntityLogicalName = $table
                Scope = 756150000
                read = $true
                create = $true
                write = $true
                delete = $false
                append = $true
                appendto = $true
                adx_entitypermission_webrole = @($webRoleId)
            }
            $body = @{ content = ($newContent | ConvertTo-Json -Compress) } | ConvertTo-Json
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            try {
                $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($($existing.id))" `
                    -Method Patch -Headers $h -Body $bytes -UseBasicParsing
                Write-Host "    -> Updated" -ForegroundColor Green
            } catch {
                Write-Host "    WARN: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    -> OK (has R/C/W + web role)" -ForegroundColor Green
        }
    } else {
        Write-Host "  MISSING: $table - creating..." -ForegroundColor Yellow
        $contentObj = @{
            EntityLogicalName = $table
            Scope = 756150000
            read = $true
            create = $true
            write = $true
            delete = $false
            append = $true
            appendto = $true
            adx_entitypermission_webrole = @($webRoleId)
        }
        $body = @{
            name = "DMV - $table (Global RCW)"
            powerpagecomponenttype = 18
            content = ($contentObj | ConvertTo-Json -Compress)
            "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
        } | ConvertTo-Json
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        try {
            $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents" `
                -Method Post -Headers $h -Body $bytes -UseBasicParsing
            Write-Host "    CREATED" -ForegroundColor Green
        } catch {
            Write-Host "    ERR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ── STEP 3: Web API site settings for lifecycle tables ──
Write-Host "`n=== Web API site settings for lifecycle tables ===" -ForegroundColor Cyan

foreach ($t in @("dmv_registrationterm", "dmv_registrationpayment")) {
    foreach ($suffix in @("enabled", "fields")) {
        $settingName = "Webapi/$t/$suffix"
        $settingValue = if ($suffix -eq "enabled") { "true" } else { "*" }
        $bodyObj = @{
            mspp_name  = $settingName
            mspp_value = $settingValue
            "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
        }
        $json = $bodyObj | ConvertTo-Json -Compress
        try {
            $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_sitesettings" `
                -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing
            Write-Host "  OK: $settingName" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -match "already exists|DuplicateRecord") {
                Write-Host "  SKIP: $settingName (exists)" -ForegroundColor Gray
            } else {
                Write-Host "  ERR: $settingName - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host 'Hard-refresh the portal. Check console: window.__DMV_DIAG__'
