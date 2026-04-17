###############################################################################
# 21_add_to_cs_workspace.ps1
# Adds all DMV entities, views, forms, sitemap, and dashboard to the
# Copilot Service workspace (Customer Service) app.
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
$csSitemapId = "360aa480-8c3a-f111-88b3-001dd801f94a"

# ────────────────────────────────────────────────
# Helper: add a component to the CS app
# ────────────────────────────────────────────────
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

# ────────────────────────────────────────────────
# STEP 1: Add entities (type=1)
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Add entities ===" -ForegroundColor Cyan
$entities = @(
    @{name="contact";                  id="608861bc-50a4-4c5f-a02c-21fe1943e2cf"},
    @{name="account";                  id="70816501-edb9-4740-a16c-6a5efbc05d84"},
    @{name="dmv_dmvoffice";            id="e89098fa-0b39-f111-88b3-001dd801f94a"},
    @{name="dmv_driverlicense";        id="2c05b033-0c39-f111-88b4-001dd80a6132"},
    @{name="dmv_vehicle";              id="42e90845-0c39-f111-88b3-001dd801f94a"},
    @{name="dmv_vehicleregistration";  id="efd96751-0c39-f111-88b4-001dd80340cd"},
    @{name="dmv_registrationterm";     id="8d7271d5-c839-f111-88b3-001dd801f94a"},
    @{name="dmv_registrationpayment";  id="17afcc1a-c939-f111-88b4-001dd80340cd"},
    @{name="dmv_appointment";          id="52a3a6c9-0c39-f111-88b4-001dd80340cd"},
    @{name="dmv_documentupload";       id="765b0263-0c39-f111-88b3-001dd801f94a"},
    @{name="dmv_vehicletitle";         id="1cdb576f-0c39-f111-88b4-001dd80340cd"},
    @{name="dmv_lien";                 id="a12ffddb-0c39-f111-88b3-001dd801f94a"},
    @{name="dmv_temporarytag";         id="13694f81-0c39-f111-88b4-001dd80340cd"},
    @{name="dmv_bulksubmission";       id="3ba6368d-0c39-f111-88b3-001dd801f94a"},
    @{name="dmv_transactionlog";       id="610a2f93-0c39-f111-88b3-001dd801f94a"},
    @{name="dmv_notification";         id="2f45bced-0c39-f111-88b4-001dd80340cd"}
)

foreach ($e in $entities) {
    $r = Add-CSComponent -type 1 -id $e.id
    Write-Host "  $($e.name) -> $r"
}

# ────────────────────────────────────────────────
# STEP 2: Add views (type=26)
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Add views ===" -ForegroundColor Cyan
$dmvLogical = $entities | Where-Object { $_.name -like "dmv_*" } | ForEach-Object { $_.name }
foreach ($entity in $dmvLogical) {
    $views = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries?`$filter=returnedtypecode eq '$entity' and statecode eq 0&`$select=savedqueryid,name" -Headers $readH
    foreach ($v in $views.value) {
        $r = Add-CSComponent -type 26 -id $v.savedqueryid
        Write-Host "  $entity/$($v.name) -> $r"
    }
}

# ────────────────────────────────────────────────
# STEP 3: Add forms (type=60)
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Add forms ===" -ForegroundColor Cyan
foreach ($entity in $dmvLogical) {
    $forms = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq '$entity' and formactivationstate eq 1&`$select=formid,name,type" -Headers $readH
    foreach ($f in $forms.value) {
        $r = Add-CSComponent -type 60 -id $f.formid
        Write-Host "  $entity/$($f.name) (type=$($f.type)) -> $r"
    }
}

# ────────────────────────────────────────────────
# STEP 4: Update sitemap
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Update sitemap ===" -ForegroundColor Cyan
$sitemapXml = '<SiteMap IntroducedVersion="7.0.0.0">' +
    '<Area Id="DMVArea" ShowGroups="true" Title="DMV Operations">' +
        '<Group Id="DashboardGroup" Title="Dashboards">' +
            '<SubArea Id="nav_regdashboard" Icon="$webresource:dmv_/icons/dashboard_icon.png" Url="$webresource:dmv_/dashboard/registration_dashboard.html" Title="Registration Operations" AvailableOffline="true" PassParams="false" />' +
        '</Group>' +
        '<Group Id="CitizenGroup" Title="Citizen Services">' +
            '<SubArea Id="nav_contact" VectorIcon="/WebResources/dmv_/icons/citizen.svg" Icon="/WebResources/dmv_/icons/citizen.svg" Title="Citizens (Contacts)" Entity="contact" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_driverlicense" Icon="$webresource:dmv_/icons/license_icon.png" Title="Driver Licenses" Entity="dmv_driverlicense" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_appointment" Icon="$webresource:dmv_/icons/appointment_icon.png" Title="Appointments" Entity="dmv_appointment" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_documentupload" Icon="$webresource:dmv_/icons/document_icon.png" Title="Document Uploads" Entity="dmv_documentupload" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_notification" Icon="$webresource:dmv_/icons/notification_icon.png" Title="Notifications" Entity="dmv_notification" AvailableOffline="true" PassParams="false" />' +
        '</Group>' +
        '<Group Id="VehicleGroup" Title="Vehicle Services">' +
            '<SubArea Id="nav_vehicle" Icon="$webresource:dmv_/icons/vehicle_icon.png" Title="Vehicles" Entity="dmv_vehicle" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_vehiclereg" Icon="$webresource:dmv_/icons/registration_icon.png" Title="Registrations" Entity="dmv_vehicleregistration" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_regterm" VectorIcon="/WebResources/dmv_/icons/term.svg" Icon="/WebResources/dmv_/icons/term.svg" Title="Registration Terms" Entity="dmv_registrationterm" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_regpayment" VectorIcon="/WebResources/dmv_/icons/payment.svg" Icon="/WebResources/dmv_/icons/payment.svg" Title="Registration Payments" Entity="dmv_registrationpayment" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_vehicletitle" Icon="$webresource:dmv_/icons/title_icon.png" Title="Vehicle Titles" Entity="dmv_vehicletitle" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_lien" Icon="$webresource:dmv_/icons/lien_icon.png" Title="Liens" Entity="dmv_lien" AvailableOffline="true" PassParams="false" />' +
        '</Group>' +
        '<Group Id="DealerGroup" Title="Dealer Operations">' +
            '<SubArea Id="nav_account" VectorIcon="/WebResources/dmv_/icons/dealer.svg" Icon="/WebResources/dmv_/icons/dealer.svg" Title="Dealers (Accounts)" Entity="account" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_temporarytag" Icon="$webresource:dmv_/icons/temptag_icon.png" Title="Temporary Tags" Entity="dmv_temporarytag" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_bulksubmission" Icon="$webresource:dmv_/icons/bulk_icon.png" Title="Bulk Submissions" Entity="dmv_bulksubmission" AvailableOffline="true" PassParams="false" />' +
        '</Group>' +
        '<Group Id="AdminGroup" Title="Administration">' +
            '<SubArea Id="nav_dmvoffice" Icon="$webresource:dmv_/icons/office_icon.png" Title="DMV Offices" Entity="dmv_dmvoffice" AvailableOffline="true" PassParams="false" />' +
            '<SubArea Id="nav_transactionlog" Icon="$webresource:dmv_/icons/transaction_icon.png" Title="Transaction Log" Entity="dmv_transactionlog" AvailableOffline="true" PassParams="false" />' +
        '</Group>' +
    '</Area>' +
'</SiteMap>'

$smPatch = @{ sitemapxml = $sitemapXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($csSitemapId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
Write-Host "  Sitemap updated"

# Link sitemap to app (type=62) - idempotent
$smComp = @{ componenttype = 62; objectid = $csSitemapId } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules($csAppId)/appmodule_appmodulecomponent" `
        -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($smComp)) -UseBasicParsing | Out-Null
    Write-Host "  Sitemap linked to app"
} catch { Write-Host "  Sitemap already linked" }

# ────────────────────────────────────────────────
# STEP 5: Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 5: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><appmodules><appmodule>$csAppId</appmodule></appmodules><sitemaps><sitemap>{$csSitemapId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " DMV CONTENT ADDED TO CS WORKSPACE"
Write-Host "==========================================="
Write-Host "  CS App: Copilot Service workspace"
Write-Host "  App ID: $csAppId"
Write-Host "  Sitemap: $csSitemapId"
Write-Host "  URL: $envUrl/main.aspx?appid=$csAppId"
Write-Host ""
Write-Host "  DMV Operations area added with groups:"
Write-Host "    Dashboards, Citizen Services, Vehicle Services,"
Write-Host "    Dealer Operations, Administration"
Write-Host ""
