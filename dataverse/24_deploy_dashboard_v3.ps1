###############################################################################
# 24_deploy_dashboard_v3.ps1
# Deploys the redesigned dashboard v3 webresource and updates the CS workspace
# sitemap to rename the entry to "DMV Dashboard" with a new icon.
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{
    Authorization  = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

$csAppId = "a2e5b03e-948b-f011-b4cb-001dd8040727"
$cswSitemapId = "9fe5b03e-948b-f011-b4cb-001dd8040727"

# ────────────────────────────────────────────────
# STEP 1: Upload dashboard webresource
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Upload dashboard ===" -ForegroundColor Cyan

# Find the existing webresource
$wr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq 'dmv_/dashboard/registration_dashboard.html'&`$select=webresourceid,name" -Headers $readH
if ($wr.value.Count -eq 0) {
    Write-Host "  Dashboard webresource not found, creating new..."
    $htmlBytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot\..\webresources\dashboard\registration_dashboard.html")
    $b64 = [Convert]::ToBase64String($htmlBytes)
    $body = @{
        name = "dmv_/dashboard/registration_dashboard.html"
        displayname = "DMV Dashboard"
        webresourcetype = 1
        content = $b64
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    Write-Host "  Created: $($resp.webresourceid)"
} else {
    $wrId = $wr.value[0].webresourceid
    Write-Host "  Found webresource: $wrId"
    $htmlBytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot\..\webresources\dashboard\registration_dashboard.html")
    $b64 = [Convert]::ToBase64String($htmlBytes)
    $body = @{ content = $b64 } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/webresourceset($wrId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  Updated webresource content"
}

# ────────────────────────────────────────────────
# STEP 2: Update sitemap — rename to DMV Dashboard
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Update sitemap entry ===" -ForegroundColor Cyan

$sm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($cswSitemapId)?`$select=sitemapxml" -Headers $readH
$xml = $sm.sitemapxml

# Replace the dashboard SubArea title and add a dashboard icon
$xml = $xml -replace 'Id="nav_regdashboard"\s+Title="Registration Operations"', 'Id="nav_regdashboard" Title="DMV Dashboard"'
# Also update the Group title
$xml = $xml -replace 'Id="DashboardGroup"\s+Title="Dashboards"', 'Id="DashboardGroup" Title="DMV Dashboard"'

# Validate
try {
    [xml]$t = $xml
    Write-Host "  XML valid"
} catch {
    Write-Host "  XML ERROR: $_" -ForegroundColor Red
    throw
}

$smPatch = @{ sitemapxml = $xml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($cswSitemapId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
Write-Host "  Sitemap updated"

# ────────────────────────────────────────────────
# STEP 3: Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Publish ===" -ForegroundColor Cyan
# Publish webresources + app + sitemap
$pubXml = "<importexportxml><webresources><webresource>{$($wr.value[0].webresourceid)}</webresource></webresources><appmodules><appmodule>$csAppId</appmodule></appmodules><sitemaps><sitemap>{$cswSitemapId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " DASHBOARD V3 DEPLOYED" -ForegroundColor Green
Write-Host "==========================================="
Write-Host "  Sitemap entry: DMV Dashboard"
Write-Host "  Webresource: dmv_/dashboard/registration_dashboard.html"
Write-Host "  Hard-refresh (Ctrl+Shift+R) to see changes."
Write-Host ""
