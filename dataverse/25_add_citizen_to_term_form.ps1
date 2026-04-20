###############################################################################
# 25_add_citizen_to_term_form.ps1
# Adds a "Citizen Information" section to the Registration Term form using a
# Quick View form on Vehicle Registration that shows the contact lookup.
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
$termFormId = "08509d60-d139-f111-88b4-001dd80340cd"

# ────────────────────────────────────────────────
# STEP 1: Create Quick View form on dmv_vehicleregistration
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Create Quick View form on Vehicle Registration ===" -ForegroundColor Cyan

$qvFormId = "a2000001-0001-0001-0001-000000000006"

$qvXml = @'
<form><tabs><tab verticallayout="true" id="{a2000001-0001-0001-0001-000000000001}" IsUserDefined="1"><labels><label description="" languagecode="1033" /></labels><columns><column width="100%"><sections><section showlabel="false" showbar="false" IsUserDefined="0" id="{b2000001-0001-0001-0001-000000000001}"><labels><label description="Citizen" languagecode="1033" /></labels><rows><row><cell id="{c2000001-0001-0001-0001-000000000001}"><labels><label description="Citizen (Contact)" languagecode="1033" /></labels><control id="dmv_regcontactid" classid="{270BD3DB-D9AF-4782-9025-509E298DEC0A}" datafieldname="dmv_regcontactid" /></cell></row><row><cell id="{c2000001-0001-0001-0001-000000000002}"><labels><label description="Registration ID" languagecode="1033" /></labels><control id="dmv_registrationid" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="dmv_registrationid" /></cell></row><row><cell id="{c2000001-0001-0001-0001-000000000003}"><labels><label description="Registration Status" languagecode="1033" /></labels><control id="dmv_regstatus" classid="{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}" datafieldname="dmv_regstatus" /></cell></row></rows></section></sections></column></columns></tab></tabs></form>
'@

# Check if it already exists
$qvExists = $false
try {
    $existingQv = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($qvFormId)?`$select=formid" -Headers $readH
    if ($existingQv.formid) { $qvExists = $true }
} catch {
    $qvExists = $false
}

if ($qvExists) {
    Write-Host "  Quick View form already exists, updating..."
    $patchBody = @{
        formxml = $qvXml
        name = "Citizen Quick View"
    } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($qvFormId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody)) -UseBasicParsing | Out-Null
} else {
    Write-Host "  Creating new Quick View form..."
    $createBody = @{
        formid = $qvFormId
        objecttypecode = "dmv_vehicleregistration"
        type = 6
        name = "Citizen Quick View"
        description = "Shows the citizen contact for the vehicle registration"
        formxml = $qvXml
    } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($createBody)) -UseBasicParsing | Out-Null
    Write-Host "  Created Quick View form: $qvFormId"
}
Write-Host "  Done" -ForegroundColor Green

# ────────────────────────────────────────────────
# STEP 2: Add Quick View control to Registration Term form
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Add Quick View control to Registration Term form ===" -ForegroundColor Cyan

$termResp = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms($termFormId)?`$select=formxml" -Headers $readH
$termXml = $termResp.formxml

# Check if we already added it
if ($termXml -match "SEC_CITIZEN") {
    Write-Host "  Citizen section already present, skipping"
} else {
    # New section XML to insert after the existing Payment Details section (SEC1)
    $citizenSection = @"
<section name="SEC_CITIZEN" showlabel="true" showbar="false" id="{b1000001-0001-0001-0001-000000000003}" columns="1" labelwidth="115" celllabelposition="Left"><labels><label description="Citizen Information" languagecode="1033" /></labels><rows><row><cell id="{c3010001-0001-0001-0001-000000000009}" showlabel="false" auto="false" colspan="1" rowspan="4"><labels><label description="Citizen" languagecode="1033" /></labels><control id="qvCitizen" classid="{5C5600E0-1D6E-4205-A272-BE80DA87FD42}" datafieldname="dmv_vehicleregistrationid" disabled="false"><parameters><QuickForms>&lt;QuickFormIds&gt;&lt;QuickFormId entityname="dmv_vehicleregistration"&gt;$qvFormId&lt;/QuickFormId&gt;&lt;/QuickFormIds&gt;</QuickForms></parameters></control></cell></row></rows></section>
"@

    # Insert after the closing </section> of SEC1 (the first section in the left column)
    # Find the end of the first section (SEC1) and insert the citizen section after it
    $insertPoint = '</section></sections></column><column width="50%">'
    $replacement = "</section>$citizenSection</sections></column><column width=`"50%`">"
    $termXml = $termXml.Replace($insertPoint, $replacement)

    # Validate
    try {
        [xml]$t = $termXml
        Write-Host "  XML valid"
    } catch {
        Write-Host "  XML ERROR: $_" -ForegroundColor Red
        Write-Host "  Dumping XML for debug..."
        Write-Host $termXml
        throw
    }

    $patchBody = @{ formxml = $termXml } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($termFormId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody)) -UseBasicParsing | Out-Null
    Write-Host "  Patched Registration Term form" -ForegroundColor Green
}

# ────────────────────────────────────────────────
# STEP 3: Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><entities><entity>dmv_vehicleregistration</entity><entity>dmv_registrationterm</entity></entities></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`n==========================================="
Write-Host " CITIZEN INFO ADDED TO TERM FORM" -ForegroundColor Green
Write-Host "==========================================="
Write-Host "  Quick View: Citizen Quick View (on dmv_vehicleregistration)"
Write-Host "  Shows: Contact lookup, Registration ID, Registration Status"
Write-Host "  Location: Below 'Payment Details' section on the General tab"
Write-Host ""
