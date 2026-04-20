###############################################################################
# 22_fix_cs_workspace.ps1
# Fix the Copilot Service workspace: dynamically find the app + sitemap,
# inject DMV area into the existing sitemap XML, re-add entities, publish.
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

# ────────────────────────────────────────────────
# STEP 0 — Find the Copilot Service workspace app
# ────────────────────────────────────────────────
Write-Host "=== Step 0: Find app ===" -ForegroundColor Cyan
$apps = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/appmodules?`$select=appmoduleid,uniquename,name&`$filter=contains(name,'Service')" -Headers $readH
Write-Host "  Matching apps:"
foreach ($a in $apps.value) {
    Write-Host "    $($a.name)  id=$($a.appmoduleid)  unique=$($a.uniquename)"
}

# Pick the Copilot Service / Customer Service workspace app
$csApp = $apps.value | Where-Object {
    $_.uniquename -eq 'msdyn_customerserviceworkspace' -or
    $_.name -like '*Customer Service workspace*' -or
    $_.name -like '*Copilot Service workspace*'
} | Select-Object -First 1

if (-not $csApp) {
    Write-Host "  No Customer Service workspace app found. Listing ALL apps:" -ForegroundColor Yellow
    $allApps = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/appmodules?`$select=appmoduleid,uniquename,name" -Headers $readH
    foreach ($a in $allApps.value) {
        Write-Host "    $($a.name)  id=$($a.appmoduleid)  unique=$($a.uniquename)"
    }
    throw "Cannot find Customer Service workspace app"
}

$csAppId = $csApp.appmoduleid
Write-Host "  Using: $($csApp.name) ($csAppId)" -ForegroundColor Green

# ────────────────────────────────────────────────
# STEP 1 — Find the sitemap linked to this app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 1: Find sitemap ===" -ForegroundColor Cyan

# Query appmodulecomponent for type=62 (sitemap) linked to this app
$smComponents = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/appmodulecomponents?`$filter=_appmoduleidunique_value eq $csAppId and componenttype eq 62&`$select=objectid" -Headers $readH

if ($smComponents.value.Count -gt 0) {
    $csSitemapId = $smComponents.value[0].objectid
    Write-Host "  Found sitemap via appmodulecomponent: $csSitemapId"
} else {
    Write-Host "  No sitemap component found, querying sitemaps directly..." -ForegroundColor Yellow
    $sitemaps = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps?`$select=sitemapid,sitemapname,sitemapnameunique&`$top=20" -Headers $readH
    foreach ($sm in $sitemaps.value) {
        Write-Host "    $($sm.sitemapnameunique)  id=$($sm.sitemapid)"
    }
    # Try to find one associated with the app
    $csSitemapId = $sitemaps.value | Where-Object {
        $_.sitemapnameunique -like '*customerservice*' -or
        $_.sitemapnameunique -like '*csw*' -or
        $_.sitemapnameunique -like '*copilot*'
    } | Select-Object -First 1 -ExpandProperty sitemapid

    if (-not $csSitemapId) {
        throw "Cannot find sitemap for CS workspace. See sitemap list above."
    }
}

# Read current sitemap XML
$smRecord = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($csSitemapId)?`$select=sitemapxml,sitemapnameunique" -Headers $readH
$currentXml = $smRecord.sitemapxml
Write-Host "  Current sitemap: $($smRecord.sitemapnameunique)"
Write-Host "  XML length: $($currentXml.Length) chars"

# ────────────────────────────────────────────────
# STEP 2 — Build DMV area XML
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Build DMV sitemap area ===" -ForegroundColor Cyan
$dmvArea = @'
<Area Id="DMVArea" ShowGroups="true" Title="DMV Operations" Icon="/_imgs/ico_18_256.svg">
  <Group Id="DashboardGroup" Title="Dashboards">
    <SubArea Id="nav_regdashboard" Title="Registration Operations" Url="$webresource:dmv_/dashboard/registration_dashboard.html" />
  </Group>
  <Group Id="CitizenGroup" Title="Citizen Services">
    <SubArea Id="nav_contact" Title="Citizens (Contacts)" Entity="contact" />
    <SubArea Id="nav_driverlicense" Title="Driver Licenses" Entity="dmv_driverlicense" />
    <SubArea Id="nav_appointment" Title="Appointments" Entity="dmv_appointment" />
    <SubArea Id="nav_documentupload" Title="Document Uploads" Entity="dmv_documentupload" />
    <SubArea Id="nav_notification" Title="Notifications" Entity="dmv_notification" />
  </Group>
  <Group Id="VehicleGroup" Title="Vehicle Services">
    <SubArea Id="nav_vehicle" Title="Vehicles" Entity="dmv_vehicle" />
    <SubArea Id="nav_vehiclereg" Title="Registrations" Entity="dmv_vehicleregistration" />
    <SubArea Id="nav_regterm" Title="Registration Terms" Entity="dmv_registrationterm" />
    <SubArea Id="nav_regpayment" Title="Registration Payments" Entity="dmv_registrationpayment" />
    <SubArea Id="nav_vehicletitle" Title="Vehicle Titles" Entity="dmv_vehicletitle" />
    <SubArea Id="nav_lien" Title="Liens" Entity="dmv_lien" />
  </Group>
  <Group Id="DealerGroup" Title="Dealer Operations">
    <SubArea Id="nav_account" Title="Dealers (Accounts)" Entity="account" />
    <SubArea Id="nav_temporarytag" Title="Temporary Tags" Entity="dmv_temporarytag" />
    <SubArea Id="nav_bulksubmission" Title="Bulk Submissions" Entity="dmv_bulksubmission" />
  </Group>
  <Group Id="AdminGroup" Title="Administration">
    <SubArea Id="nav_dmvoffice" Title="DMV Offices" Entity="dmv_dmvoffice" />
    <SubArea Id="nav_transactionlog" Title="Transaction Log" Entity="dmv_transactionlog" />
  </Group>
</Area>
'@

# ────────────────────────────────────────────────
# STEP 3 — Inject DMV area into existing sitemap
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Inject into sitemap ===" -ForegroundColor Cyan

# Remove any previous DMV area if present
$cleanXml = $currentXml -replace '(?s)<Area\s+Id="DMVArea"[^>]*>.*?</Area>', ''

# Insert the DMV area right before the closing </SiteMap>
$newXml = $cleanXml -replace '</SiteMap>', "$dmvArea`n</SiteMap>"

Write-Host "  Old length: $($currentXml.Length)  New length: $($newXml.Length)"

# Validate it's well-formed
try {
    [xml]$testXml = $newXml
    Write-Host "  XML is well-formed" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: XML parse error — $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Dumping first 2000 chars:"
    Write-Host ($newXml.Substring(0, [Math]::Min(2000, $newXml.Length)))
    throw "Sitemap XML is malformed"
}

# Patch the sitemap
$smPatch = @{ sitemapxml = $newXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($csSitemapId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
Write-Host "  Sitemap patched!" -ForegroundColor Green

# ────────────────────────────────────────────────
# STEP 4 — Ensure entities are in the app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Add entities to app ===" -ForegroundColor Cyan

function Add-CSComponent([int]$type, [string]$id) {
    $body = @{ componenttype = $type; objectid = $id } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules($csAppId)/appmodule_appmodulecomponent" `
            -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
        return "OK"
    } catch {
        return "EXISTS"
    }
}

# Look up entity metadata IDs dynamically instead of using hardcoded GUIDs
$dmvEntities = @(
    "dmv_dmvoffice", "dmv_driverlicense", "dmv_vehicle",
    "dmv_vehicleregistration", "dmv_registrationterm", "dmv_registrationpayment",
    "dmv_appointment", "dmv_documentupload", "dmv_vehicletitle",
    "dmv_lien", "dmv_temporarytag", "dmv_bulksubmission",
    "dmv_transactionlog", "dmv_notification"
)

foreach ($entityName in $dmvEntities) {
    $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions?`$filter=LogicalName eq '$entityName'&`$select=MetadataId" -Headers $readH
    if ($meta.value.Count -eq 0) {
        Write-Host "  $entityName — NOT FOUND (skipping)" -ForegroundColor Yellow
        continue
    }
    $metaId = $meta.value[0].MetadataId
    $r = Add-CSComponent -type 1 -id $metaId
    Write-Host "  $entityName ($metaId) -> $r"
}

# Also add contact and account
foreach ($sysEntity in @("contact","account")) {
    $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions?`$filter=LogicalName eq '$sysEntity'&`$select=MetadataId" -Headers $readH
    $metaId = $meta.value[0].MetadataId
    $r = Add-CSComponent -type 1 -id $metaId
    Write-Host "  $sysEntity ($metaId) -> $r"
}

# ────────────────────────────────────────────────
# STEP 5 — Add views + forms for DMV entities
# ────────────────────────────────────────────────
Write-Host "`n=== Step 5: Add views & forms ===" -ForegroundColor Cyan
foreach ($entityName in $dmvEntities) {
    # Views
    $views = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries?`$filter=returnedtypecode eq '$entityName' and statecode eq 0&`$select=savedqueryid,name" -Headers $readH
    foreach ($v in $views.value) {
        $r = Add-CSComponent -type 26 -id $v.savedqueryid
        Write-Host "  view: $entityName/$($v.name) -> $r"
    }
    # Forms
    $forms = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq '$entityName' and formactivationstate eq 1&`$select=formid,name,type" -Headers $readH
    foreach ($f in $forms.value) {
        $r = Add-CSComponent -type 60 -id $f.formid
        Write-Host "  form: $entityName/$($f.name) -> $r"
    }
}

# ────────────────────────────────────────────────
# STEP 6 — Link sitemap to app (idempotent)
# ────────────────────────────────────────────────
Write-Host "`n=== Step 6: Link sitemap ===" -ForegroundColor Cyan
$smComp = @{ componenttype = 62; objectid = $csSitemapId } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules($csAppId)/appmodule_appmodulecomponent" `
        -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($smComp)) -UseBasicParsing | Out-Null
    Write-Host "  Sitemap linked to app"
} catch { Write-Host "  Sitemap already linked" }

# ────────────────────────────────────────────────
# STEP 7 — Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 7: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><appmodules><appmodule>$csAppId</appmodule></appmodules><sitemaps><sitemap>{$csSitemapId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " CS WORKSPACE FIXED" -ForegroundColor Green
Write-Host "==========================================="
Write-Host "  App: $($csApp.name)"
Write-Host "  App ID: $csAppId"
Write-Host "  Sitemap: $csSitemapId"
Write-Host "  URL: $envUrl/main.aspx?appid=$csAppId"
Write-Host ""
Write-Host "  Hard-refresh the browser (Ctrl+Shift+R) to see changes."
Write-Host ""
