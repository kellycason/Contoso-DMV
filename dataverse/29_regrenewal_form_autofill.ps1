###############################################################################
# 29_regrenewal_form_autofill.ps1
# Creates JS web resource for registration renewal form autofill:
#   - When status = Approved, auto-fills Approved Date + New Expiration (1 year)
# Updates form with event handlers and "Review and Decision" tab.
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
# 1. Create (or update) the JS web resource
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Create JS web resource ===" -ForegroundColor Cyan

$jsCode = @'
// dmv_registrationrenewal_form.js
// Auto-fills Approved Date and New Expiration Date when status = Approved
"use strict";
var DMV = DMV || {};
DMV.RegistrationRenewal = {
    onStatusChange: function (executionContext) {
        var formContext = executionContext.getFormContext();
        var status = formContext.getAttribute("dmv_renewalstatus");
        if (!status) return;
        var val = status.getValue();
        // 100000002 = Approved
        if (val === 100000002) {
            var now = new Date();
            var approvedAttr = formContext.getAttribute("dmv_approveddate");
            if (approvedAttr && !approvedAttr.getValue()) {
                approvedAttr.setValue(now);
                approvedAttr.setSubmitMode("always");
            }
            var expiryAttr = formContext.getAttribute("dmv_newexpirationdate");
            if (expiryAttr && !expiryAttr.getValue()) {
                var expiry = new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());
                expiryAttr.setValue(expiry);
                expiryAttr.setSubmitMode("always");
            }
        }
    },
    onLoad: function (executionContext) {
        var formContext = executionContext.getFormContext();
        var status = formContext.getAttribute("dmv_renewalstatus");
        if (status) {
            status.addOnChange(DMV.RegistrationRenewal.onStatusChange);
        }
    }
};
'@

$jsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jsCode))
$wrName = "dmv_/scripts/registrationrenewal_form.js"

# Check if it exists
$existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/webresourceset?`$filter=name eq '$wrName'&`$select=webresourceid" -Headers $readH
if ($existing.value.Count -gt 0) {
    $wrId = $existing.value[0].webresourceid
    Write-Host "  Updating existing: $wrId"
    $body = @{ content = $jsBase64 } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/webresourceset($wrId)" -Method Patch -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
} else {
    Write-Host "  Creating new web resource"
    $body = @{
        name = $wrName
        displayname = "Registration Renewal Form Script"
        webresourcetype = 3  # JS
        content = $jsBase64
    } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/webresourceset" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
    $wrId = ($resp.Headers["OData-EntityId"] -replace '.*\(','') -replace '\)',''
    Write-Host "  Created: $wrId"
}
Write-Host "  Web resource ready: $wrName"

# ────────────────────────────────────────────────
# 2. Update the form with event handlers
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Update form with event handlers ===" -ForegroundColor Cyan

# Get the main form ID
$tbl = "dmv_registrationrenewal"
$forms = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq '$tbl' and type eq 2 and formactivationstate eq 1&`$select=formid,name" -Headers $readH
$mainForm = $forms.value[0]
$formId = $mainForm.formid
Write-Host "  Using form: $($mainForm.name) ($formId)"

$txt   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
$dt    = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
$pick  = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
$email = "{ADA2203E-B4CD-49be-9DDF-234642B43B52}"
$money = "{533B9E00-756B-4312-95A0-DC888637AC78}"
$lkp   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
$phone = "{8C10015A-B339-4982-9474-A95FE05631A5}"

function Make-Row($id,$lbl,$cid,$fld) {
    return "<row><cell id=`"$id`" showlabel=`"true`"><labels><label description=`"$lbl`" languagecode=`"1033`" /></labels><control id=`"$fld`" classid=`"$cid`" datafieldname=`"$fld`" disabled=`"false`" /></cell></row>"
}

# Tab 1: Review and Decision (Action section)
$secAction = (Make-Row "{g1010001-0001-0001-0001-000000000001}" "Renewal Status" $pick "dmv_renewalstatus") +
             (Make-Row "{g1010001-0001-0001-0001-000000000002}" "Approved Date" $dt "dmv_approveddate") +
             (Make-Row "{g1010001-0001-0001-0001-000000000003}" "New Expiration Date" $dt "dmv_newexpirationdate") +
             (Make-Row "{g1010001-0001-0001-0001-000000000004}" "Vehicle" $lkp "dmv_vehicleid") +
             (Make-Row "{g1010001-0001-0001-0001-000000000005}" "Registration" $lkp "dmv_registrationid")

# Tab 2: Request Info
$sec1 = (Make-Row "{g1010001-0001-0001-0001-000000000006}" "Renewal ID" $txt "dmv_renewalid") +
        (Make-Row "{g1010001-0001-0001-0001-000000000007}" "Contact" $lkp "dmv_contactid") +
        (Make-Row "{g1010001-0001-0001-0001-000000000008}" "Submitted" $dt "dmv_submitteddate") +
        (Make-Row "{g1010001-0001-0001-0001-000000000009}" "Channel" $pick "dmv_channel")

# Vehicle section
$sec2 = (Make-Row "{g1010001-0001-0001-0001-00000000000a}" "Plate Number" $txt "dmv_platenumber") +
        (Make-Row "{g1010001-0001-0001-0001-00000000000b}" "VIN" $txt "dmv_vin") +
        (Make-Row "{g1010001-0001-0001-0001-00000000000c}" "Year" $txt "dmv_vehicleyear") +
        (Make-Row "{g1010001-0001-0001-0001-00000000000d}" "Make" $txt "dmv_vehiclemake") +
        (Make-Row "{g1010001-0001-0001-0001-00000000000e}" "Model" $txt "dmv_vehiclemodel") +
        (Make-Row "{g1010001-0001-0001-0001-00000000000f}" "Color" $txt "dmv_vehiclecolor")

# Owner section
$sec3 = (Make-Row "{g1010001-0001-0001-0001-000000000010}" "First Name" $txt "dmv_firstname") +
        (Make-Row "{g1010001-0001-0001-0001-000000000011}" "Last Name" $txt "dmv_lastname") +
        (Make-Row "{g1010001-0001-0001-0001-000000000012}" "Email" $email "dmv_email") +
        (Make-Row "{g1010001-0001-0001-0001-000000000013}" "Phone" $phone "dmv_phone") +
        (Make-Row "{g1010001-0001-0001-0001-000000000014}" "Street Address" $txt "dmv_streetaddress") +
        (Make-Row "{g1010001-0001-0001-0001-000000000015}" "City" $txt "dmv_city") +
        (Make-Row "{g1010001-0001-0001-0001-000000000016}" "State" $txt "dmv_state") +
        (Make-Row "{g1010001-0001-0001-0001-000000000017}" "ZIP Code" $txt "dmv_zipcode")

# Insurance section
$sec4 = (Make-Row "{g1010001-0001-0001-0001-000000000018}" "Insurance Carrier" $txt "dmv_insurancecarrier") +
        (Make-Row "{g1010001-0001-0001-0001-000000000019}" "Policy Number" $txt "dmv_insurancepolicy") +
        (Make-Row "{g1010001-0001-0001-0001-00000000001a}" "Policy Expiration" $dt "dmv_insuranceexpiration")

# Payment section
$sec5 = (Make-Row "{g1010001-0001-0001-0001-00000000001b}" "Renewal Fee" $money "dmv_renewalfee") +
        (Make-Row "{g1010001-0001-0001-0001-00000000001c}" "Payment Method" $pick "dmv_paymentmethod") +
        (Make-Row "{g1010001-0001-0001-0001-00000000001d}" "Payment Confirmation" $txt "dmv_paymentconfirmation")

$formXml = '<form showImage="true">' +
  '<formLibraries>' +
    '<Library name="dmv_/scripts/registrationrenewal_form.js" libraryUniqueId="{f1000002-0001-0001-0001-000000000001}" />' +
  '</formLibraries>' +
  '<events>' +
    '<event name="onload" application="false" active="true">' +
      '<Handlers>' +
        '<Handler functionName="DMV.RegistrationRenewal.onLoad" libraryName="dmv_/scripts/registrationrenewal_form.js" handlerUniqueId="{f2000002-0001-0001-0001-000000000001}" enabled="true" parameters="" passExecutionContext="true" />' +
      '</Handlers>' +
    '</event>' +
  '</events>' +
  '<tabs>' +
    '<tab name="ACTION" id="{g2000001-0001-0001-0001-000000000000}" showlabel="true" expanded="true">' +
      '<labels><label description="Review and Decision" languagecode="1033" /></labels>' +
      '<columns><column width="100%"><sections>' +
        '<section name="SEC_ACTION" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000000}" columns="2" labelwidth="150" celllabelposition="Left">' +
          '<labels><label description="Approval Action" languagecode="1033" /></labels>' +
          "<rows>$secAction</rows>" +
        '</section>' +
      '</sections></column></columns>' +
    '</tab>' +
    '<tab name="DETAILS" id="{g2000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true">' +
      '<labels><label description="Request Details" languagecode="1033" /></labels>' +
      '<columns>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_REQUEST" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000001}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Request Information" languagecode="1033" /></labels>' +
            "<rows>$sec1</rows>" +
          '</section>' +
          '<section name="SEC_VEHICLE" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000002}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Vehicle Details" languagecode="1033" /></labels>' +
            "<rows>$sec2</rows>" +
          '</section>' +
          '<section name="SEC_INSURANCE" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000005}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Insurance" languagecode="1033" /></labels>' +
            "<rows>$sec4</rows>" +
          '</section>' +
        '</sections></column>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_OWNER" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000003}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Owner Details" languagecode="1033" /></labels>' +
            "<rows>$sec3</rows>" +
          '</section>' +
          '<section name="SEC_PAYMENT" showlabel="true" showbar="false" id="{g3000001-0001-0001-0001-000000000004}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Payment" languagecode="1033" /></labels>' +
            "<rows>$sec5</rows>" +
          '</section>' +
        '</sections></column>' +
      '</columns>' +
    '</tab>' +
  '</tabs></form>'

Write-Host "  Form XML length: $($formXml.Length)"
$formBody = @{ formxml = $formXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($formBody)) -UseBasicParsing | Out-Null
Write-Host "  Form updated with event handlers"

# ────────────────────────────────────────────────
# 3. Add web resource to CS app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Add web resource to app ===" -ForegroundColor Cyan
$csAppId = "a2e5b03e-948b-f011-b4cb-001dd8040727"
$wrComp = @{ componenttype = 61; objectid = $wrId } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/appmodules($csAppId)/appmodule_appmodulecomponent" `
        -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($wrComp)) -UseBasicParsing | Out-Null
    Write-Host "  Web resource added to app"
} catch { Write-Host "  Already in app (or skipped)" }

# ────────────────────────────────────────────────
# 4. Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Publish ===" -ForegroundColor Cyan
$pubXml = "<importexportxml><entities><entity>$tbl</entity></entities><webresources><webresource>{$wrId}</webresource></webresources></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published!" -ForegroundColor Green

Write-Host "`nDone! When you change Renewal Status to 'Approved':"
Write-Host "  - Approved Date auto-fills to today"
Write-Host "  - New Expiration Date auto-fills to 1 year from today"
Write-Host "  - Only fills if the fields are currently empty (won't overwrite)"
