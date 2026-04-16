###############################################################################
# 09_create_model_driven_app.ps1
# Creates a model-driven Power App for managing all DMV tables
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

$appName = "DMV Operations Hub"
$appUniqueName = "dmv_DMVOperationsHub"
$appDescription = "Manage DMV citizen records, licenses, vehicles, registrations, appointments, and dealer operations."

# ────────────────────────────────────────────────
# STEP 1: Create the App Module
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Create App Module ==="
$appBody = @{
    name = $appName
    uniquename = $appUniqueName
    description = $appDescription
    clienttype = 4             # Unified Interface
    navigationtype = 0        # Single-page
    formfactor = 3            # Desktop + mobile
    isfeatured = $false
    isdefault = $false
    webresourceid = "00000000-0000-0000-0000-000000000000"
} | ConvertTo-Json -Compress

try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($appBody)) -UseBasicParsing
    $appId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  Created App Module: $appId"
} catch {
    $err = $_.ErrorDetails.Message
    if ($err -match "already exists") {
        Write-Host "  App already exists, finding it..."
        $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/appmodules?`$filter=uniquename eq '$appUniqueName'&`$select=appmoduleid" -Headers $h
        $appId = $existing.value[0].appmoduleid
        Write-Host "  Found existing: $appId"
    } else {
        Write-Host "  ERR: $err"
        exit 1
    }
}
Start-Sleep 3

# ────────────────────────────────────────────────
# STEP 2: Create the SiteMap
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Create SiteMap ==="

$sitemapXml = @'
<SiteMap>
  <Area Id="DMVArea" Title="DMV Operations" Icon="/_imgs/area/18_background.svg" ResourceId="SitemapDesigner.NewArea" DescriptionResourceId="" ShowGroups="true">
    <Group Id="CitizenGroup" Title="Citizen Services" Icon="/_imgs/ico/18_background.svg" ResourceId="SitemapDesigner.NewGroup" DescriptionResourceId="">
      <SubArea Id="nav_contact" Entity="contact" Title="Citizens (Contacts)" Icon="/_imgs/ico/16_contact.svg" />
      <SubArea Id="nav_driverlicense" Entity="dmv_driverlicense" Title="Driver Licenses" />
      <SubArea Id="nav_appointment" Entity="dmv_appointment" Title="Appointments" />
      <SubArea Id="nav_documentupload" Entity="dmv_documentupload" Title="Document Uploads" />
      <SubArea Id="nav_notification" Entity="dmv_notification" Title="Notifications" />
    </Group>
    <Group Id="VehicleGroup" Title="Vehicle Services" Icon="/_imgs/ico/18_background.svg" ResourceId="SitemapDesigner.NewGroup" DescriptionResourceId="">
      <SubArea Id="nav_vehicle" Entity="dmv_vehicle" Title="Vehicles" />
      <SubArea Id="nav_vehiclereg" Entity="dmv_vehicleregistration" Title="Vehicle Registrations" />
      <SubArea Id="nav_vehicletitle" Entity="dmv_vehicletitle" Title="Vehicle Titles" />
      <SubArea Id="nav_lien" Entity="dmv_lien" Title="Liens" />
    </Group>
    <Group Id="DealerGroup" Title="Dealer Operations" Icon="/_imgs/ico/18_background.svg" ResourceId="SitemapDesigner.NewGroup" DescriptionResourceId="">
      <SubArea Id="nav_account" Entity="account" Title="Dealers (Accounts)" />
      <SubArea Id="nav_temporarytag" Entity="dmv_temporarytag" Title="Temporary Tags" />
      <SubArea Id="nav_bulksubmission" Entity="dmv_bulksubmission" Title="Bulk Submissions" />
    </Group>
    <Group Id="AdminGroup" Title="Administration" Icon="/_imgs/ico/18_background.svg" ResourceId="SitemapDesigner.NewGroup" DescriptionResourceId="">
      <SubArea Id="nav_dmvoffice" Entity="dmv_dmvoffice" Title="DMV Offices" />
      <SubArea Id="nav_transactionlog" Entity="dmv_transactionlog" Title="Transaction Log" />
    </Group>
  </Area>
</SiteMap>
'@

# Check for existing sitemap
$existingSM = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps?`$filter=_appmoduleid_value eq $appId&`$select=sitemapid" -Headers $h
if ($existingSM.value.Count -gt 0) {
    $smId = $existingSM.value[0].sitemapid
    Write-Host "  Found existing SiteMap: $smId - updating..."
    $smPatch = @{ sitemapxml = $sitemapXml } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
    Write-Host "  SiteMap updated"
} else {
    $smBody = @{
        sitemapname = "DMV Operations Hub SiteMap"
        sitemapxml = $sitemapXml
        "appmoduleid@odata.bind" = "/appmodules($appId)"
    } | ConvertTo-Json -Compress
    try {
        $smResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps" -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($smBody)) -UseBasicParsing
        $smId = ($smResp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
        Write-Host "  Created SiteMap: $smId"
    } catch {
        Write-Host "  SiteMap ERR: $($_.ErrorDetails.Message)"
    }
}
Start-Sleep 3

# ────────────────────────────────────────────────
# STEP 3: Add entity components to the app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Add Entities to App ==="

$entities = @(
    @{ name="contact";                id="608861bc-50a4-4c5f-a02c-21fe1943e2cf" },
    @{ name="account";                id="70816501-edb9-4740-a16c-6a5efbc05d84" },
    @{ name="dmv_dmvoffice";          id="e89098fa-0b39-f111-88b3-001dd801f94a" },
    @{ name="dmv_driverlicense";      id="2c05b033-0c39-f111-88b4-001dd80a6132" },
    @{ name="dmv_vehicle";            id="42e90845-0c39-f111-88b3-001dd801f94a" },
    @{ name="dmv_vehicleregistration";id="efd96951-0c39-f111-88b4-001dd80340cd" },
    @{ name="dmv_appointment";        id="52a3a6c9-0c39-f111-88b4-001dd80340cd" },
    @{ name="dmv_documentupload";     id="765b0263-0c39-f111-88b3-001dd801f94a" },
    @{ name="dmv_vehicletitle";       id="1cdb576f-0c39-f111-88b4-001dd80340cd" },
    @{ name="dmv_lien";               id="a12ffddb-0c39-f111-88b3-001dd801f94a" },
    @{ name="dmv_temporarytag";       id="13694f81-0c39-f111-88b4-001dd80340cd" },
    @{ name="dmv_bulksubmission";     id="3ba6368d-0c39-f111-88b3-001dd801f94a" },
    @{ name="dmv_transactionlog";     id="610a2f93-0c39-f111-88b3-001dd801f94a" },
    @{ name="dmv_notification";       id="2f45bced-0c39-f111-88b4-001dd80340cd" }
)

# Use AddAppComponents action to add entities (type 1 = Entity)
$componentIds = @()
foreach ($e in $entities) { $componentIds += $e.id }

$addBody = @{
    AppId = $appId
    Components = @(
        foreach ($e in $entities) {
            @{ ComponentType = 1; ComponentId = $e.id }
        }
    )
} | ConvertTo-Json -Depth 5 -Compress

try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($addBody)) -UseBasicParsing | Out-Null
    Write-Host "  Added $($entities.Count) entities to app"
} catch {
    Write-Host "  AddAppComponents ERR: $($_.ErrorDetails.Message)"
    # Try one by one as fallback
    Write-Host "  Trying individually..."
    foreach ($e in $entities) {
        $singleBody = @{
            AppId = $appId
            Components = @(
                @{ ComponentType = 1; ComponentId = $e.id }
            )
        } | ConvertTo-Json -Depth 5 -Compress
        try {
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $h `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($singleBody)) -UseBasicParsing | Out-Null
            Write-Host "    $($e.name) -> OK"
        } catch {
            $msg = $_.ErrorDetails.Message
            if ($msg -match "already exists") { Write-Host "    $($e.name) -> EXISTS" }
            else { Write-Host "    $($e.name) -> ERR: $($msg.Substring(0,[Math]::Min(100,$msg.Length)))" }
        }
    }
}
Start-Sleep 3

# ────────────────────────────────────────────────
# STEP 4: Publish the app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Publish App ==="
$pubBody = @{ AppModuleId = $appId } | ConvertTo-Json -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes((@{ ParameterXml = "<importexportxml><appmodules><appmodule>$appId</appmodule></appmodules></importexportxml>" } | ConvertTo-Json -Compress))) -UseBasicParsing | Out-Null
    Write-Host "  Published via PublishXml"
} catch {
    Write-Host "  Publish note: $($_.ErrorDetails.Message)"
    # Fallback: PublishAllXml
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Method Post -Headers $h -Body '{}' -UseBasicParsing | Out-Null
        Write-Host "  Published via PublishAllXml"
    } catch { Write-Host "  Publish ERR: $($_.ErrorDetails.Message)" }
}

Write-Host "`n==========================================="
Write-Host " MODEL-DRIVEN APP CREATED"
Write-Host "==========================================="
Write-Host "  Name: $appName"
Write-Host "  App ID: $appId"
Write-Host "  URL: $envUrl/apps/$appId"
Write-Host ""
Write-Host "  Groups:"
Write-Host "    Citizen Services: Contacts, Licenses, Appointments, Documents, Notifications"
Write-Host "    Vehicle Services: Vehicles, Registrations, Titles, Liens"
Write-Host "    Dealer Operations: Accounts, Temp Tags, Bulk Submissions"
Write-Host "    Administration: DMV Offices, Transaction Log"
Write-Host ""
