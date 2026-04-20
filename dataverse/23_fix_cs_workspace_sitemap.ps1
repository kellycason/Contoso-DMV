###############################################################################
# 23_fix_cs_workspace_sitemap.ps1
# Patches the ACTUAL managed CS workspace sitemap (msdyn_CustomerServiceWorkspace)
# to inject DMV Operations navigation area.
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

# ────────────────────────────────────────────────
# STEP 1 — Find the real CS workspace sitemap
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Find real CS workspace sitemap ===" -ForegroundColor Cyan
$smResult = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps?`$filter=sitemapnameunique eq 'msdyn_CustomerServiceWorkspace'&`$select=sitemapid,sitemapnameunique,sitemapxml,ismanaged" -Headers $readH

if ($smResult.value.Count -eq 0) {
    throw "Cannot find msdyn_CustomerServiceWorkspace sitemap"
}

$cswSitemap = $smResult.value[0]
$cswSitemapId = $cswSitemap.sitemapid
$currentXml = $cswSitemap.sitemapxml
Write-Host "  Sitemap ID: $cswSitemapId"
Write-Host "  Managed: $($cswSitemap.ismanaged)"
Write-Host "  Current XML length: $($currentXml.Length)"

# ────────────────────────────────────────────────
# STEP 2 — Build DMV area XML
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Build DMV area ===" -ForegroundColor Cyan
$dmvArea = '<Area Id="DMVArea" ShowGroups="true" Title="DMV Operations" IntroducedVersion="7.0.0.0">' +
  '<Group Id="DashboardGroup" Title="Dashboards" IntroducedVersion="7.0.0.0">' +
    '<SubArea Id="nav_regdashboard" Title="Registration Operations" Url="$webresource:dmv_/dashboard/registration_dashboard.html" IntroducedVersion="7.0.0.0" />' +
  '</Group>' +
  '<Group Id="CitizenGroup" Title="Citizen Services" IntroducedVersion="7.0.0.0">' +
    '<SubArea Id="nav_dmv_contact" Title="Citizens (Contacts)" Entity="contact" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_driverlicense" Title="Driver Licenses" Entity="dmv_driverlicense" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_appointment" Title="Appointments" Entity="dmv_appointment" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_documentupload" Title="Document Uploads" Entity="dmv_documentupload" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_notification" Title="Notifications" Entity="dmv_notification" IntroducedVersion="7.0.0.0" />' +
  '</Group>' +
  '<Group Id="VehicleGroup" Title="Vehicle Services" IntroducedVersion="7.0.0.0">' +
    '<SubArea Id="nav_dmv_vehicle" Title="Vehicles" Entity="dmv_vehicle" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_vehiclereg" Title="Registrations" Entity="dmv_vehicleregistration" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_regterm" Title="Registration Terms" Entity="dmv_registrationterm" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_regpayment" Title="Registration Payments" Entity="dmv_registrationpayment" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_vehicletitle" Title="Vehicle Titles" Entity="dmv_vehicletitle" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_lien" Title="Liens" Entity="dmv_lien" IntroducedVersion="7.0.0.0" />' +
  '</Group>' +
  '<Group Id="DealerGroup" Title="Dealer Operations" IntroducedVersion="7.0.0.0">' +
    '<SubArea Id="nav_dmv_account" Title="Dealers (Accounts)" Entity="account" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_temporarytag" Title="Temporary Tags" Entity="dmv_temporarytag" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_bulksubmission" Title="Bulk Submissions" Entity="dmv_bulksubmission" IntroducedVersion="7.0.0.0" />' +
  '</Group>' +
  '<Group Id="AdminGroup" Title="Administration" IntroducedVersion="7.0.0.0">' +
    '<SubArea Id="nav_dmv_dmvoffice" Title="DMV Offices" Entity="dmv_dmvoffice" IntroducedVersion="7.0.0.0" />' +
    '<SubArea Id="nav_dmv_transactionlog" Title="Transaction Log" Entity="dmv_transactionlog" IntroducedVersion="7.0.0.0" />' +
  '</Group>' +
'</Area>'

# ────────────────────────────────────────────────
# STEP 3 — Inject DMV area into existing sitemap
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Inject DMV area ===" -ForegroundColor Cyan

# Remove any previous DMV area if present
$cleanXml = $currentXml -replace '(?s)<Area\s+Id="DMVArea"[^>]*>.*?</Area>', ''

# Insert the DMV area right before the closing </SiteMap>
$newXml = $cleanXml -replace '</SiteMap>', "$dmvArea</SiteMap>"

Write-Host "  Old XML length: $($currentXml.Length)"
Write-Host "  New XML length: $($newXml.Length)"

# Validate well-formed XML
try {
    [xml]$testXml = $newXml
    Write-Host "  XML is well-formed" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: XML parse error — $($_.Exception.Message)" -ForegroundColor Red
    throw "Sitemap XML is malformed"
}

# Patch the sitemap
$smPatch = @{ sitemapxml = $newXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($cswSitemapId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
Write-Host "  Sitemap patched!" -ForegroundColor Green

# ────────────────────────────────────────────────
# STEP 4 — Publish app + sitemap
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><appmodules><appmodule>$csAppId</appmodule></appmodules><sitemaps><sitemap>{$cswSitemapId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " CS WORKSPACE SITEMAP FIXED" -ForegroundColor Green
Write-Host "==========================================="
Write-Host "  Sitemap: msdyn_CustomerServiceWorkspace ($cswSitemapId)"
Write-Host "  App: $csAppId"
Write-Host "  URL: $envUrl/main.aspx?appid=$csAppId"
Write-Host ""
Write-Host "  Hard-refresh (Ctrl+Shift+R) to see DMV Operations in the left nav."
Write-Host ""
