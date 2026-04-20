###############################################################################
# 23_add_renewal_to_mda.ps1
# Adds the dmv_licenserenewal entity to the Copilot Service Workspace app
# with a custom view, updated form, sitemap entry, and publish.
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

$csAppId   = "a2e5b03e-948b-f011-b4cb-001dd8040727"
$csSitemapId = "360aa480-8c3a-f111-88b3-001dd801f94a"
$cswSitemapId = "9fe5b03e-948b-f011-b4cb-001dd8040727"
$tbl = "dmv_licenserenewal"

function Add-CSComponent([int]$type, [string]$id) {
    $body = @{ componenttype = $type; objectid = $id } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules($csAppId)/appmodule_appmodulecomponent" `
            -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
        return "OK"
    } catch { return "EXISTS" }
}

# ────────────────────────────────────────────────
# 1. Get entity metadata ID
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Get entity metadata ===" -ForegroundColor Cyan
$meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$tbl')?`$select=MetadataId,ObjectTypeCode" -Headers $readH
$entityMetaId = $meta.MetadataId
$otc = $meta.ObjectTypeCode
Write-Host "  MetadataId: $entityMetaId"
Write-Host "  ObjectTypeCode: $otc"

# ────────────────────────────────────────────────
# 2. Add entity to app (type=1)
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Add entity to app ===" -ForegroundColor Cyan
$r = Add-CSComponent -type 1 -id $entityMetaId
Write-Host "  $tbl -> $r"

# ────────────────────────────────────────────────
# 3. Update the default view
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Update default view ===" -ForegroundColor Cyan
$views = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries?`$filter=returnedtypecode eq '$tbl' and statecode eq 0 and querytype eq 0&`$select=savedqueryid,name&`$orderby=name" -Headers $readH
Write-Host "  Found $($views.value.Count) views"
$defaultView = $views.value | Where-Object { $_.name -match "Active" } | Select-Object -First 1
if (-not $defaultView) { $defaultView = $views.value[0] }
Write-Host "  Using: $($defaultView.name) ($($defaultView.savedqueryid))"

$fetch = @"
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_licenserenewal">
    <attribute name="dmv_renewalid" />
    <attribute name="dmv_renewalstatus" />
    <attribute name="dmv_licensenumber" />
    <attribute name="dmv_firstname" />
    <attribute name="dmv_lastname" />
    <attribute name="dmv_email" />
    <attribute name="dmv_submitteddate" />
    <attribute name="dmv_approveddate" />
    <attribute name="dmv_renewalfee" />
    <attribute name="dmv_channel" />
    <attribute name="dmv_contactid" />
    <attribute name="dmv_licenserenewalid" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
    <order attribute="dmv_submitteddate" descending="true" />
  </entity>
</fetch>
"@.Trim()

$layout = @"
<grid name="resultset" object="$otc" jump="dmv_renewalid" select="1" icon="1" preview="1">
  <row name="result" id="dmv_licenserenewalid">
    <cell name="dmv_renewalid" width="140" />
    <cell name="dmv_renewalstatus" width="120" />
    <cell name="dmv_firstname" width="100" />
    <cell name="dmv_lastname" width="100" />
    <cell name="dmv_licensenumber" width="120" />
    <cell name="dmv_email" width="160" />
    <cell name="dmv_submitteddate" width="130" />
    <cell name="dmv_approveddate" width="130" />
    <cell name="dmv_renewalfee" width="90" />
    <cell name="dmv_channel" width="100" />
  </row>
</grid>
"@.Trim()

$viewBody = @{
    name = "Active License Renewals"
    fetchxml = $fetch
    layoutxml = $layout
} | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($($defaultView.savedqueryid))" `
    -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($viewBody)) -UseBasicParsing | Out-Null
Write-Host "  View updated: Active License Renewals"

# Add all views to app
foreach ($v in $views.value) {
    $r = Add-CSComponent -type 26 -id $v.savedqueryid
    Write-Host "  View $($v.name) -> $r"
}

# ────────────────────────────────────────────────
# 4. Update the main form
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Update main form ===" -ForegroundColor Cyan
$forms = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq '$tbl' and type eq 2 and formactivationstate eq 1&`$select=formid,name" -Headers $readH
Write-Host "  Found $($forms.value.Count) main forms"
$mainForm = $forms.value[0]
Write-Host "  Using: $($mainForm.name) ($($mainForm.formid))"

# ClassId constants
$txt   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
$dt    = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
$bool  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
$pick  = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
$email = "{ADA2203E-B4CD-49be-9DDF-234642B43B52}"
$money = "{533B9E00-756B-4312-95A0-DC888637AC78}"
$memo  = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
$lkp   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
$phone = "{8C10015A-B339-4982-9474-A95FE05631A5}"

function Make-Row($id,$lbl,$cid,$fld) {
    return "<row><cell id=`"$id`" showlabel=`"true`"><labels><label description=`"$lbl`" languagecode=`"1033`" /></labels><control id=`"$fld`" classid=`"$cid`" datafieldname=`"$fld`" disabled=`"false`" /></cell></row>"
}

# Section 1: Request Info + Identity
$sec1 = (Make-Row "{d1010001-0001-0001-0001-000000000001}" "Renewal ID" $txt "dmv_renewalid") +
        (Make-Row "{d1010001-0001-0001-0001-000000000002}" "Renewal Status" $pick "dmv_renewalstatus") +
        (Make-Row "{d1010001-0001-0001-0001-000000000003}" "Contact" $lkp "dmv_contactid") +
        (Make-Row "{d1010001-0001-0001-0001-000000000004}" "License Number" $txt "dmv_licensenumber") +
        (Make-Row "{d1010001-0001-0001-0001-000000000005}" "Date of Birth" $dt "dmv_dateofbirth") +
        (Make-Row "{d1010001-0001-0001-0001-000000000006}" "Last 4 SSN" $txt "dmv_ssn4") +
        (Make-Row "{d1010001-0001-0001-0001-000000000007}" "Submitted" $dt "dmv_submitteddate") +
        (Make-Row "{d1010001-0001-0001-0001-000000000008}" "Channel" $pick "dmv_channel")

# Section 2: Personal Details
$sec2 = (Make-Row "{d1010001-0001-0001-0001-000000000009}" "First Name" $txt "dmv_firstname") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000a}" "Last Name" $txt "dmv_lastname") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000b}" "Email" $email "dmv_email") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000c}" "Phone" $phone "dmv_phone") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000d}" "Street Address" $txt "dmv_streetaddress") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000e}" "City" $txt "dmv_city") +
        (Make-Row "{d1010001-0001-0001-0001-00000000000f}" "State" $txt "dmv_state") +
        (Make-Row "{d1010001-0001-0001-0001-000000000010}" "ZIP Code" $txt "dmv_zipcode")

# Section 3: Medical
$sec3 = (Make-Row "{d1010001-0001-0001-0001-000000000011}" "Vision OK" $bool "dmv_visionok") +
        (Make-Row "{d1010001-0001-0001-0001-000000000012}" "Seizure History" $bool "dmv_seizures") +
        (Make-Row "{d1010001-0001-0001-0001-000000000013}" "Loss of Consciousness" $bool "dmv_lossofconsciousness") +
        (Make-Row "{d1010001-0001-0001-0001-000000000014}" "Medical Notes" $memo "dmv_medicalconditions")

# Section 4: Payment & Resolution
$sec4 = (Make-Row "{d1010001-0001-0001-0001-000000000015}" "Renewal Fee" $money "dmv_renewalfee") +
        (Make-Row "{d1010001-0001-0001-0001-000000000016}" "Payment Method" $pick "dmv_paymentmethod") +
        (Make-Row "{d1010001-0001-0001-0001-000000000017}" "Payment Confirmation" $txt "dmv_paymentconfirmation") +
        (Make-Row "{d1010001-0001-0001-0001-000000000018}" "Approved Date" $dt "dmv_approveddate") +
        (Make-Row "{d1010001-0001-0001-0001-000000000019}" "New Expiration Date" $dt "dmv_newexpirationdate") +
        (Make-Row "{d1010001-0001-0001-0001-00000000001a}" "Driver License" $lkp "dmv_licenseid")

$formXml = '<form showImage="true">' +
  '<tabs>' +
    '<tab name="GENERAL" id="{d2000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true">' +
      '<labels><label description="General" languagecode="1033" /></labels>' +
      '<columns>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_REQUEST" showlabel="true" showbar="false" id="{d3000001-0001-0001-0001-000000000001}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Request Information" languagecode="1033" /></labels>' +
            "<rows>$sec1</rows>" +
          '</section>' +
          '<section name="SEC_MEDICAL" showlabel="true" showbar="false" id="{d3000001-0001-0001-0001-000000000003}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Medical Questionnaire" languagecode="1033" /></labels>' +
            "<rows>$sec3</rows>" +
          '</section>' +
        '</sections></column>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_DETAILS" showlabel="true" showbar="false" id="{d3000001-0001-0001-0001-000000000002}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Personal Details" languagecode="1033" /></labels>' +
            "<rows>$sec2</rows>" +
          '</section>' +
          '<section name="SEC_PAYMENT" showlabel="true" showbar="false" id="{d3000001-0001-0001-0001-000000000004}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Payment &amp; Resolution" languagecode="1033" /></labels>' +
            "<rows>$sec4</rows>" +
          '</section>' +
        '</sections></column>' +
      '</columns>' +
    '</tab>' +
  '</tabs>' +
'</form>'

$formBody = @{ formxml = $formXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($($mainForm.formid))" `
    -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($formBody)) -UseBasicParsing | Out-Null
Write-Host "  Form updated with 4 sections"

# Add all forms to app
foreach ($f in $forms.value) {
    $r = Add-CSComponent -type 60 -id $f.formid
    Write-Host "  Form $($f.name) -> $r"
}

# ────────────────────────────────────────────────
# 5. Update BOTH sitemaps (CS app + CSW app)
# ────────────────────────────────────────────────
Write-Host "`n=== Step 5: Update sitemaps ===" -ForegroundColor Cyan

$renewalSubArea = '<SubArea Id="nav_licenserenewal" Title="License Renewals" Entity="dmv_licenserenewal" AvailableOffline="true" PassParams="false" />'

foreach ($smId in @($csSitemapId, $cswSitemapId)) {
    $sm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/sitemaps($smId)?`$select=sitemapxml" -Headers $readH
    $xml = $sm.sitemapxml

    if ($xml -match 'nav_licenserenewal') {
        Write-Host "  Sitemap $smId already has renewal entry"
        continue
    }

    # Insert after driver licenses in Citizen Services group
    if ($xml -match 'nav_driverlicense[^/]*/>' ) {
        $xml = $xml -replace '(nav_driverlicense[^/]*/>)', "`$1$renewalSubArea"
    } elseif ($xml -match '(CitizenGroup[^>]*>)') {
        $xml = $xml -replace '(CitizenGroup[^>]*>)', "`$1$renewalSubArea"
    } else {
        Write-Host "  WARNING: Could not find insertion point in sitemap $smId"
        continue
    }

    try { [xml]$test = $xml; Write-Host "  XML valid" } catch { Write-Host "  INVALID XML: $_"; continue }

    $smPatch = @{ sitemapxml = $xml } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($smPatch)) -UseBasicParsing | Out-Null
    Write-Host "  Sitemap $smId updated"
}

# ────────────────────────────────────────────────
# 6. Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 6: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><appmodules><appmodule>$csAppId</appmodule></appmodules><sitemaps><sitemap>{$csSitemapId}</sitemap><sitemap>{$cswSitemapId}</sitemap></sitemaps><entities><entity>$tbl</entity></entities></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " LICENSE RENEWALS ADDED TO CS WORKSPACE"
Write-Host "==========================================="
Write-Host "  Entity: dmv_licenserenewal"
Write-Host "  View: Active License Renewals (sorted by submitted date DESC)"
Write-Host "  Form: 4-section layout (Request Info, Personal, Medical, Payment)"
Write-Host "  Sitemap: Under Citizen Services, after Driver Licenses"
Write-Host "  App URL: $envUrl/main.aspx?appid=$csAppId"
Write-Host ""
