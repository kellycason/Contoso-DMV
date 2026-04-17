###############################################################################
# 16_update_mda_for_lifecycle.ps1
# Updates model-driven app for lifecycle-based registration model:
#   - Updates dmv_vehicleregistration view/form (remove deprecated cols, add currenttermid)
#   - Creates dmv_registrationterm form + view
#   - Creates dmv_registrationpayment form + view
#   - Adds new tables/forms/views to app module
#   - Updates sitemap with new nav entries
#   - Publishes
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl  = "https://orga381269e.crm9.dynamics.com"
$token   = az account get-access-token --resource $envUrl --query accessToken -o tsv
$headers = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

$appId = "d6331d8d-a239-f111-88b4-001dd80a6132"
$smId  = "98db46b0-896f-412f-a212-01d534198efb"

# ClassId constants
$txt   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
$dt    = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
$bool  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
$pick  = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
$num   = "{C6D124CA-7EDA-4a60-AEA3-7F0A0B76B5B2}"
$money = "{533B9E00-756B-4312-95A0-DC888637AC78}"
$memo  = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
$lkp   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"

function Make-Row($id,$lbl,$cid,$fld) {
    return "<row><cell id=`"$id`" showlabel=`"true`"><labels><label description=`"$lbl`" languagecode=`"1033`" /></labels><control id=`"$fld`" classid=`"$cid`" datafieldname=`"$fld`" disabled=`"false`" /></cell></row>"
}

function MakeForm($rows1, $sec1Label, $rows2, $sec2Label) {
    return '<form showImage="true"><tabs><tab name="GENERAL" id="{a1000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true"><labels><label description="General" languagecode="1033" /></labels><columns><column width="50%"><sections><section name="SEC1" showlabel="true" showbar="false" id="{b1000001-0001-0001-0001-000000000001}" columns="1" labelwidth="115" celllabelposition="Left"><labels><label description="' + $sec1Label + '" languagecode="1033" /></labels><rows>' + $rows1 + '</rows></section></sections></column><column width="50%"><sections><section name="SEC2" showlabel="true" showbar="false" id="{b1000001-0001-0001-0001-000000000002}" columns="1" labelwidth="115" celllabelposition="Left"><labels><label description="' + $sec2Label + '" languagecode="1033" /></labels><rows>' + $rows2 + '</rows></section></sections></column></columns></tab></tabs></form>'
}

###############################################################################
Write-Host "`n=== 1. UPDATE VEHICLE REGISTRATION VIEW (remove deprecated cols) ==="
###############################################################################
$regViewId = "26761996-a173-40f5-8a59-ce0d837fdbf1"
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_vehicleregistration"><attribute name="dmv_registrationid" /><attribute name="dmv_regcontactid" /><attribute name="dmv_vehicleid" /><attribute name="dmv_regstatus" /><attribute name="dmv_currenttermid" /><attribute name="dmv_county" /><attribute name="dmv_vehicleregistrationid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_registrationid" descending="false" /></entity></fetch>'
$layout = '<grid name="resultset" object="11395" jump="dmv_registrationid" select="1" icon="1" preview="1"><row name="result" id="dmv_vehicleregistrationid"><cell name="dmv_registrationid" width="140" /><cell name="dmv_regcontactid" width="160" /><cell name="dmv_vehicleid" width="160" /><cell name="dmv_regstatus" width="120" /><cell name="dmv_currenttermid" width="160" /><cell name="dmv_county" width="100" /></row></grid>'

$body = @{ name = "Active Vehicle Registrations"; fetchxml = $fetch; layoutxml = $layout } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($regViewId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  VIEW OK: Active Vehicle Registrations"
} catch { Write-Host "  VIEW ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 2. UPDATE VEHICLE REGISTRATION FORM ==="
###############################################################################
$regFormId = "65dc8f05-7b9e-4e9f-a3a0-9fc0b5f7b638"
$r1 = (Make-Row "{c2030001-0001-0001-0001-000000000001}" "Registration ID" $txt "dmv_registrationid") +
      (Make-Row "{c2030001-0001-0001-0001-000000000002}" "Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c2030001-0001-0001-0001-000000000003}" "Registrant (Contact)" $lkp "dmv_regcontactid") +
      (Make-Row "{c2030001-0001-0001-0001-000000000004}" "Registrant (Dealer)" $lkp "dmv_dealeracctid") +
      (Make-Row "{c2030001-0001-0001-0001-000000000005}" "Registration Status" $pick "dmv_regstatus")
$r2 = (Make-Row "{c2030001-0001-0001-0001-000000000006}" "Current Term" $lkp "dmv_currenttermid") +
      (Make-Row "{c2030001-0001-0001-0001-000000000007}" "County" $txt "dmv_county") +
      (Make-Row "{c2030001-0001-0001-0001-000000000008}" "Notes" $memo "dmv_notes")

$regFormXml = MakeForm $r1 "Registration Details" $r2 "Current Term and Notes"
$body = @{ formxml = $regFormXml } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($regFormId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  FORM OK: Vehicle Registration"
} catch { Write-Host "  FORM ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 3. CREATE REGISTRATION TERM FORM ==="
###############################################################################
$r1 = (Make-Row "{c3010001-0001-0001-0001-000000000001}" "Term Number" $txt "dmv_termnumber") +
      (Make-Row "{c3010001-0001-0001-0001-000000000002}" "Vehicle Registration" $lkp "dmv_vehicleregistrationid") +
      (Make-Row "{c3010001-0001-0001-0001-000000000003}" "Term Type" $pick "dmv_termtype") +
      (Make-Row "{c3010001-0001-0001-0001-000000000004}" "Term Status" $pick "dmv_termstatus")
$r2 = (Make-Row "{c3010001-0001-0001-0001-000000000005}" "Start Date" $dt "dmv_startdate") +
      (Make-Row "{c3010001-0001-0001-0001-000000000006}" "End Date" $dt "dmv_enddate") +
      (Make-Row "{c3010001-0001-0001-0001-000000000007}" "Issue Date" $dt "dmv_issuedate") +
      (Make-Row "{c3010001-0001-0001-0001-000000000008}" "Sticker/Decal Number" $txt "dmv_stickernumber")

$termFormXml = MakeForm $r1 "Term Details" $r2 "Dates and Sticker"
$termFormBody = @{
    name = "Registration Term"
    description = "Main form for registration term records."
    objecttypecode = "dmv_registrationterm"
    type = 2
    formactivationstate = 1
    formxml = $termFormXml
} | ConvertTo-Json -Compress

$termFormId = $null
try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($termFormBody)) -UseBasicParsing
    $termFormId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  FORM CREATED: Registration Term ($termFormId)"
} catch { Write-Host "  FORM ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 4. CREATE REGISTRATION TERM VIEW ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_registrationterm"><attribute name="dmv_termnumber" /><attribute name="dmv_vehicleregistrationid" /><attribute name="dmv_termtype" /><attribute name="dmv_termstatus" /><attribute name="dmv_startdate" /><attribute name="dmv_enddate" /><attribute name="dmv_issuedate" /><attribute name="dmv_stickernumber" /><attribute name="dmv_registrationtermid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_startdate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" jump="dmv_termnumber" select="1" icon="1" preview="1"><row name="result" id="dmv_registrationtermid"><cell name="dmv_termnumber" width="140" /><cell name="dmv_vehicleregistrationid" width="160" /><cell name="dmv_termtype" width="100" /><cell name="dmv_termstatus" width="100" /><cell name="dmv_startdate" width="110" /><cell name="dmv_enddate" width="110" /><cell name="dmv_issuedate" width="110" /><cell name="dmv_stickernumber" width="120" /></row></grid>'

$termViewBody = @{
    name = "Active Registration Terms"
    description = "All active registration terms."
    returnedtypecode = "dmv_registrationterm"
    querytype = 0
    fetchxml = $fetch
    layoutxml = $layout
} | ConvertTo-Json -Compress

$termViewId = $null
try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($termViewBody)) -UseBasicParsing
    $termViewId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  VIEW CREATED: Active Registration Terms ($termViewId)"
} catch { Write-Host "  VIEW ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 5. CREATE REGISTRATION PAYMENT FORM ==="
###############################################################################
$r1 = (Make-Row "{c3020001-0001-0001-0001-000000000001}" "Payment Reference" $txt "dmv_paymentref") +
      (Make-Row "{c3020001-0001-0001-0001-000000000002}" "Registration Term" $lkp "dmv_registrationtermid") +
      (Make-Row "{c3020001-0001-0001-0001-000000000003}" "Payment Status" $pick "dmv_paymentstatus") +
      (Make-Row "{c3020001-0001-0001-0001-000000000004}" "Payment Method" $pick "dmv_paymentmethod")
$r2 = (Make-Row "{c3020001-0001-0001-0001-000000000005}" "Amount" $money "dmv_amount") +
      (Make-Row "{c3020001-0001-0001-0001-000000000006}" "Late Fee" $money "dmv_latefee") +
      (Make-Row "{c3020001-0001-0001-0001-000000000007}" "Total" $money "dmv_total") +
      (Make-Row "{c3020001-0001-0001-0001-000000000008}" "Payment Date" $dt "dmv_paymentdate") +
      (Make-Row "{c3020001-0001-0001-0001-000000000009}" "Transaction ID" $txt "dmv_transactionid")

$payFormXml = MakeForm $r1 "Payment Details" $r2 "Amounts and Transaction"
$payFormBody = @{
    name = "Registration Payment"
    description = "Main form for registration payment records."
    objecttypecode = "dmv_registrationpayment"
    type = 2
    formactivationstate = 1
    formxml = $payFormXml
} | ConvertTo-Json -Compress

$payFormId = $null
try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($payFormBody)) -UseBasicParsing
    $payFormId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  FORM CREATED: Registration Payment ($payFormId)"
} catch { Write-Host "  FORM ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 6. CREATE REGISTRATION PAYMENT VIEW ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_registrationpayment"><attribute name="dmv_paymentref" /><attribute name="dmv_registrationtermid" /><attribute name="dmv_amount" /><attribute name="dmv_latefee" /><attribute name="dmv_total" /><attribute name="dmv_paymentstatus" /><attribute name="dmv_paymentmethod" /><attribute name="dmv_paymentdate" /><attribute name="dmv_transactionid" /><attribute name="dmv_registrationpaymentid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_paymentdate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" jump="dmv_paymentref" select="1" icon="1" preview="1"><row name="result" id="dmv_registrationpaymentid"><cell name="dmv_paymentref" width="130" /><cell name="dmv_registrationtermid" width="150" /><cell name="dmv_amount" width="90" /><cell name="dmv_latefee" width="80" /><cell name="dmv_total" width="90" /><cell name="dmv_paymentstatus" width="110" /><cell name="dmv_paymentmethod" width="110" /><cell name="dmv_paymentdate" width="110" /><cell name="dmv_transactionid" width="120" /></row></grid>'

$payViewBody = @{
    name = "Active Registration Payments"
    description = "All active registration payments."
    returnedtypecode = "dmv_registrationpayment"
    querytype = 0
    fetchxml = $fetch
    layoutxml = $layout
} | ConvertTo-Json -Compress

$payViewId = $null
try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($payViewBody)) -UseBasicParsing
    $payViewId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  VIEW CREATED: Active Registration Payments ($payViewId)"
} catch { Write-Host "  VIEW ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 7. ADD NEW ENTITIES TO APP MODULE ==="
###############################################################################
# Add dmv_registrationterm entity
$entBody = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.appmodulecomponent","rootcomponentbehavior":1,"componenttype":1,"objectid":"00000000-0000-0000-0000-000000000000","rootentityname":"dmv_registrationterm"}]}'
try {
    # Use AddAppComponents with entity logical name approach - first get entity metadata ID
    $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions?`$filter=LogicalName eq 'dmv_registrationterm'&`$select=MetadataId" -Headers @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
    $termEntityId = $meta.value[0].MetadataId
    Write-Host "  dmv_registrationterm MetadataId: $termEntityId"

    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.appmodulecomponent","rootcomponentbehavior":1,"componenttype":1,"objectid":"' + $termEntityId + '"}]}'
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
    Write-Host "  Entity added to app: dmv_registrationterm"
} catch { Write-Host "  Entity add ERR (term): $($_.ErrorDetails.Message)" }

# Add dmv_registrationpayment entity
try {
    $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions?`$filter=LogicalName eq 'dmv_registrationpayment'&`$select=MetadataId" -Headers @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
    $payEntityId = $meta.value[0].MetadataId
    Write-Host "  dmv_registrationpayment MetadataId: $payEntityId"

    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.appmodulecomponent","rootcomponentbehavior":1,"componenttype":1,"objectid":"' + $payEntityId + '"}]}'
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
    Write-Host "  Entity added to app: dmv_registrationpayment"
} catch { Write-Host "  Entity add ERR (pay): $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 8. ADD NEW FORMS TO APP MODULE ==="
###############################################################################
if ($termFormId) {
    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.systemform","formid":"' + $termFormId + '"}]}'
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  Term form added to app"
    } catch { Write-Host "  Term form add ERR: $($_.ErrorDetails.Message)" }
}

if ($payFormId) {
    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.systemform","formid":"' + $payFormId + '"}]}'
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  Payment form added to app"
    } catch { Write-Host "  Payment form add ERR: $($_.ErrorDetails.Message)" }
}

###############################################################################
Write-Host "`n=== 9. ADD NEW VIEWS TO APP MODULE ==="
###############################################################################
if ($termViewId) {
    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.savedquery","savedqueryid":"' + $termViewId + '"}]}'
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  Term view added to app"
    } catch { Write-Host "  Term view add ERR: $($_.ErrorDetails.Message)" }
}

if ($payViewId) {
    $json = '{"AppId":"' + $appId + '","Components":[{"@odata.type":"Microsoft.Dynamics.CRM.savedquery","savedqueryid":"' + $payViewId + '"}]}'
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  Payment view added to app"
    } catch { Write-Host "  Payment view add ERR: $($_.ErrorDetails.Message)" }
}

###############################################################################
Write-Host "`n=== 10. UPDATE SITEMAP ==="
###############################################################################
$sitemapXml = '<SiteMap IntroducedVersion="7.0.0.0">' +
  '<Area Id="DMVArea" Title="DMV Operations" ShowGroups="true">' +
    '<Group Id="CitizenGroup" Title="Citizen Services">' +
      '<SubArea Id="nav_contact" Entity="contact" Title="Citizens (Contacts)" Icon="$webresource:dmv_/icons/citizen_icon.png" />' +
      '<SubArea Id="nav_driverlicense" Entity="dmv_driverlicense" Title="Driver Licenses" Icon="$webresource:dmv_/icons/license_icon.png" />' +
      '<SubArea Id="nav_appointment" Entity="dmv_appointment" Title="Appointments" Icon="$webresource:dmv_/icons/appointment_icon.png" />' +
      '<SubArea Id="nav_documentupload" Entity="dmv_documentupload" Title="Document Uploads" Icon="$webresource:dmv_/icons/document_icon.png" />' +
      '<SubArea Id="nav_notification" Entity="dmv_notification" Title="Notifications" Icon="$webresource:dmv_/icons/notification_icon.png" />' +
    '</Group>' +
    '<Group Id="VehicleGroup" Title="Vehicle Services">' +
      '<SubArea Id="nav_vehicle" Entity="dmv_vehicle" Title="Vehicles" Icon="$webresource:dmv_/icons/vehicle_icon.png" />' +
      '<SubArea Id="nav_vehiclereg" Entity="dmv_vehicleregistration" Title="Registrations" Icon="$webresource:dmv_/icons/registration_icon.png" />' +
      '<SubArea Id="nav_regterm" Entity="dmv_registrationterm" Title="Registration Terms" Icon="$webresource:dmv_/icons/registration_icon.png" />' +
      '<SubArea Id="nav_regpayment" Entity="dmv_registrationpayment" Title="Registration Payments" Icon="$webresource:dmv_/icons/registration_icon.png" />' +
      '<SubArea Id="nav_vehicletitle" Entity="dmv_vehicletitle" Title="Vehicle Titles" Icon="$webresource:dmv_/icons/title_icon.png" />' +
      '<SubArea Id="nav_lien" Entity="dmv_lien" Title="Liens" Icon="$webresource:dmv_/icons/lien_icon.png" />' +
    '</Group>' +
    '<Group Id="DealerGroup" Title="Dealer Operations">' +
      '<SubArea Id="nav_account" Entity="account" Title="Dealers (Accounts)" Icon="$webresource:dmv_/icons/dealer_icon.png" />' +
      '<SubArea Id="nav_temporarytag" Entity="dmv_temporarytag" Title="Temporary Tags" Icon="$webresource:dmv_/icons/temptag_icon.png" />' +
      '<SubArea Id="nav_bulksubmission" Entity="dmv_bulksubmission" Title="Bulk Submissions" Icon="$webresource:dmv_/icons/bulk_icon.png" />' +
    '</Group>' +
    '<Group Id="AdminGroup" Title="Administration">' +
      '<SubArea Id="nav_dmvoffice" Entity="dmv_dmvoffice" Title="DMV Offices" Icon="$webresource:dmv_/icons/office_icon.png" />' +
      '<SubArea Id="nav_transactionlog" Entity="dmv_transactionlog" Title="Transaction Log" Icon="$webresource:dmv_/icons/transaction_icon.png" />' +
    '</Group>' +
  '</Area>' +
'</SiteMap>'

$smBody = @{ sitemapxml = $sitemapXml } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($smBody)) -UseBasicParsing | Out-Null
    Write-Host "  SITEMAP OK"
} catch { Write-Host "  SITEMAP ERR: $($_.ErrorDetails.Message)" }

###############################################################################
Write-Host "`n=== 11. PUBLISH ALL ==="
###############################################################################
$pubXml = "<importexportxml><entities><entity>dmv_vehicleregistration</entity><entity>dmv_registrationterm</entity><entity>dmv_registrationpayment</entity></entities><appmodules><appmodule>$appId</appmodule></appmodules><sitemaps><sitemap>{$smId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
    Write-Host "  PUBLISHED ALL"
} catch { Write-Host "  PUBLISH ERR: $($_.ErrorDetails.Message)" }

Write-Host "`n==========================================="
Write-Host " MODEL-DRIVEN APP UPDATED FOR LIFECYCLE MODEL"
Write-Host "==========================================="
Write-Host "  Updated:"
Write-Host "    - Vehicle Registration view: removed deprecated cols, added Current Term"
Write-Host "    - Vehicle Registration form: simplified to core fields + Current Term lookup"
Write-Host "  Created:"
Write-Host "    - Registration Term form ($termFormId) + view ($termViewId)"
Write-Host "    - Registration Payment form ($payFormId) + view ($payViewId)"
Write-Host "  Sitemap: Added Registration Terms + Registration Payments under Vehicle Services"
Write-Host ""
