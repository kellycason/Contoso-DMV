###############################################################################
# 73_deploy_appointment_calendar.ps1
#
# Deploys the appointment_calendar.html webresource and rewrites the CSW
# sitemap so that the existing "Appointments" entry (nav_dmv_appointment)
# launches the calendar webresource instead of the dmv_appointment grid.
#
# Run AFTER 72_seed_appointment_demo_data.ps1 if you want demo data.
###############################################################################

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv

$h = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

$csAppId      = "a2e5b03e-948b-f011-b4cb-001dd8040727"
$cswSitemapId = "9fe5b03e-948b-f011-b4cb-001dd8040727"
$wrLogicalName = "dmv_/appointment_calendar/appointment_calendar.html"

# ── Step 1: Upload (or update) the calendar webresource ──────────────────────
Write-Host "=== Step 1: Upload appointment calendar webresource ===" -ForegroundColor Cyan

$htmlBytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot\..\webresources\appointment_calendar\appointment_calendar.html")
$b64 = [Convert]::ToBase64String($htmlBytes)

$existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$wrLogicalName'&`$select=webresourceid" -Headers $readH
if ($existing.value.Count -eq 0) {
    $body = @{
        name            = $wrLogicalName
        displayname     = "Appointment Calendar"
        webresourcetype = 1
        content         = $b64
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    $wrId = $resp.webresourceid
    Write-Host "  Created webresource: $wrId"
} else {
    $wrId = $existing.value[0].webresourceid
    $body = @{ content = $b64 } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/webresourceset($wrId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  Updated webresource: $wrId"
}

# ── Step 2: Rewrite the nav_dmv_appointment SubArea to point at the webresource
Write-Host "`n=== Step 2: Update CSW sitemap ===" -ForegroundColor Cyan
$sm  = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($cswSitemapId)?`$select=sitemapxml" -Headers $readH
$xml = $sm.sitemapxml

# Locate the existing SubArea for nav_dmv_appointment (entity-grid version)
$idx = $xml.IndexOf('nav_dmv_appointment')
if ($idx -lt 0) { throw "Could not find SubArea nav_dmv_appointment in sitemap." }
$start = $xml.LastIndexOf('<SubArea', $idx)
$end   = $xml.IndexOf('/>', $start) + 2
$old   = $xml.Substring($start, $end - $start)
Write-Host "  Found existing entry:`n    $old" -ForegroundColor DarkGray

# New entry: launches the calendar webresource
$new = '<SubArea Id="nav_dmv_appointment" Title="Appointments" IntroducedVersion="7.0.0.0" ' +
       'Url="$webresource:' + $wrLogicalName + '" Icon="$webresource:dmv_/icons/appointment_icon.png" ' +
       'AvailableOffline="true" PassParams="false" />'

$xml = $xml.Replace($old, $new)

# Validate XML
try { [xml]$null = $xml; Write-Host "  XML valid" } catch { Write-Host "  XML ERROR: $_" -ForegroundColor Red; throw }

$smPatch = @{ sitemapxml = $xml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($cswSitemapId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
Write-Host "  Sitemap updated"

# ── Step 3: Publish ──────────────────────────────────────────────────────────
Write-Host "`n=== Step 3: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><webresources><webresource>{$wrId}</webresource></webresources>" +
          "<appmodules><appmodule>$csAppId</appmodule></appmodules>" +
          "<sitemaps><sitemap>{$cswSitemapId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published" -ForegroundColor Green

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host " APPOINTMENT CALENDAR DEPLOYED" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  In CSW app -> Appointments (sidebar) now opens the calendar."
Write-Host "  Webresource: $wrLogicalName"
Write-Host "  Hard-refresh the app (Ctrl+Shift+R) to see the change."
Write-Host ""
