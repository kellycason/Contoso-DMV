###############################################################################
# 11_update_views_forms_sitemap.ps1
# Updates all DMV table views, forms, and sitemap icons
###############################################################################

$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$headers = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

function Update-View($viewId, $name, $entity, $otc, $pkField, $fetchXml, $layoutXml) {
    $body = @{
        name = $name
        fetchxml = $fetchXml
        layoutxml = $layoutXml
    } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
        Write-Host "  VIEW OK: $name"
    } catch {
        Write-Host "  VIEW ERR ($name): $($_.ErrorDetails.Message)"
    }
}

function Update-Form($formId, $formXml) {
    $body = @{ formxml = $formXml } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
        Write-Host "  FORM OK"
    } catch {
        Write-Host "  FORM ERR: $($_.ErrorDetails.Message)"
    }
}

# ClassId constants
$txt   = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
$dt    = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
$bool  = "{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}"
$pick  = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
$email = "{ADA2203E-B4CD-49be-9DDF-234642B43B52}"
$num   = "{C6D124CA-7EDA-4a60-AEA3-7F0A0B76B5B2}"
$money = "{533B9E00-756B-4312-95A0-DC888637AC78}"
$memo  = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
$lkp   = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"

function Make-Row($id,$lbl,$cid,$fld) { return "<row><cell id=`"$id`" showlabel=`"true`"><labels><label description=`"$lbl`" languagecode=`"1033`" /></labels><control id=`"$fld`" classid=`"$cid`" datafieldname=`"$fld`" disabled=`"false`" /></cell></row>" }

function MakeForm($rows1, $sec1Label, $rows2, $sec2Label) {
    return '<form showImage="true"><tabs><tab name="GENERAL" id="{a1000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true"><labels><label description="General" languagecode="1033" /></labels><columns><column width="50%"><sections><section name="SEC1" showlabel="true" showbar="false" id="{b1000001-0001-0001-0001-000000000001}" columns="1" labelwidth="115" celllabelposition="Left"><labels><label description="' + $sec1Label + '" languagecode="1033" /></labels><rows>' + $rows1 + '</rows></section></sections></column><column width="50%"><sections><section name="SEC2" showlabel="true" showbar="false" id="{b1000001-0001-0001-0001-000000000002}" columns="1" labelwidth="115" celllabelposition="Left"><labels><label description="' + $sec2Label + '" languagecode="1033" /></labels><rows>' + $rows2 + '</rows></section></sections></column></columns></tab></tabs></form>'
}

###############################################################################
Write-Host "`n=== 1. DRIVER LICENSES ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_driverlicense"><attribute name="dmv_licensenumber" /><attribute name="dmv_contactid" /><attribute name="dmv_licenseclass" /><attribute name="dmv_licensestatus" /><attribute name="dmv_issuedate" /><attribute name="dmv_expirationdate" /><attribute name="dmv_daystoexpiration" /><attribute name="dmv_realidcompliant" /><attribute name="dmv_onlineeligible" /><attribute name="dmv_driverlicenseid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_licensenumber" descending="false" /></entity></fetch>'
$layout = '<grid name="resultset" object="11393" jump="dmv_licensenumber" select="1" icon="1" preview="1"><row name="result" id="dmv_driverlicenseid"><cell name="dmv_licensenumber" width="140" /><cell name="dmv_contactid" width="160" /><cell name="dmv_licenseclass" width="100" /><cell name="dmv_licensestatus" width="110" /><cell name="dmv_issuedate" width="100" /><cell name="dmv_expirationdate" width="110" /><cell name="dmv_daystoexpiration" width="90" /><cell name="dmv_realidcompliant" width="90" /><cell name="dmv_onlineeligible" width="90" /></row></grid>'
Update-View "8e73e80f-c53b-4752-b748-5a38efe10fb5" "Active Driver Licenses" "dmv_driverlicense" 11393 "dmv_driverlicenseid" $fetch $layout

$r1 = (Make-Row "{c1010001-0001-0001-0001-000000000001}" "License Number" $txt "dmv_licensenumber") +
      (Make-Row "{c1010001-0001-0001-0001-000000000002}" "Citizen (Contact)" $lkp "dmv_contactid") +
      (Make-Row "{c1010001-0001-0001-0001-000000000003}" "License Class" $pick "dmv_licenseclass") +
      (Make-Row "{c1010001-0001-0001-0001-000000000004}" "License Status" $pick "dmv_licensestatus") +
      (Make-Row "{c1010001-0001-0001-0001-000000000005}" "Issue Date" $dt "dmv_issuedate") +
      (Make-Row "{c1010001-0001-0001-0001-000000000006}" "Expiration Date" $dt "dmv_expirationdate") +
      (Make-Row "{c1010001-0001-0001-0001-000000000007}" "Days Until Expiration" $num "dmv_daystoexpiration")
$r2 = (Make-Row "{c1010001-0001-0001-0001-000000000008}" "REAL ID Compliant" $bool "dmv_realidcompliant") +
      (Make-Row "{c1010001-0001-0001-0001-000000000009}" "REAL ID Status" $pick "dmv_realidstatus") +
      (Make-Row "{c1010001-0001-0001-0001-00000000000a}" "Online Renewal Eligible" $bool "dmv_onlineeligible") +
      (Make-Row "{c1010001-0001-0001-0001-00000000000b}" "Renewal Count" $num "dmv_renewalcount") +
      (Make-Row "{c1010001-0001-0001-0001-00000000000c}" "Last Renewal Date" $dt "dmv_lastrenewdate") +
      (Make-Row "{c1010001-0001-0001-0001-00000000000d}" "Last Renewal Method" $pick "dmv_renewalmethod") +
      (Make-Row "{c1010001-0001-0001-0001-00000000000e}" "Notes" $memo "dmv_notes")
Update-Form "3ea38355-b2dd-4920-9896-86bafd36befe" (MakeForm $r1 "License Details" $r2 "Renewal and Compliance")

###############################################################################
Write-Host "`n=== 2. VEHICLES ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_vehicle"><attribute name="dmv_vin" /><attribute name="dmv_year" /><attribute name="dmv_make" /><attribute name="dmv_model" /><attribute name="dmv_color" /><attribute name="dmv_platenumber" /><attribute name="dmv_ownercontactid" /><attribute name="dmv_bodystyle" /><attribute name="dmv_insurancestatus" /><attribute name="dmv_vehicleid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_year" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11394" jump="dmv_vin" select="1" icon="1" preview="1"><row name="result" id="dmv_vehicleid"><cell name="dmv_vin" width="160" /><cell name="dmv_year" width="60" /><cell name="dmv_make" width="100" /><cell name="dmv_model" width="100" /><cell name="dmv_color" width="80" /><cell name="dmv_platenumber" width="100" /><cell name="dmv_ownercontactid" width="150" /><cell name="dmv_bodystyle" width="90" /><cell name="dmv_insurancestatus" width="110" /></row></grid>'
Update-View "8baa7d66-102d-4a34-810c-17440a8751c7" "Active Vehicles" "dmv_vehicle" 11394 "dmv_vehicleid" $fetch $layout

$r1 = (Make-Row "{c1020001-0001-0001-0001-000000000001}" "VIN" $txt "dmv_vin") +
      (Make-Row "{c1020001-0001-0001-0001-000000000002}" "Year" $num "dmv_year") +
      (Make-Row "{c1020001-0001-0001-0001-000000000003}" "Make" $txt "dmv_make") +
      (Make-Row "{c1020001-0001-0001-0001-000000000004}" "Model" $txt "dmv_model") +
      (Make-Row "{c1020001-0001-0001-0001-000000000005}" "Trim" $txt "dmv_trim") +
      (Make-Row "{c1020001-0001-0001-0001-000000000006}" "Color" $txt "dmv_color") +
      (Make-Row "{c1020001-0001-0001-0001-000000000007}" "Body Style" $pick "dmv_bodystyle") +
      (Make-Row "{c1020001-0001-0001-0001-000000000008}" "Owner (Contact)" $lkp "dmv_ownercontactid") +
      (Make-Row "{c1020001-0001-0001-0001-000000000009}" "Owner (Dealer)" $lkp "dmv_owneraccountid")
$r2 = (Make-Row "{c1020001-0001-0001-0001-00000000000a}" "Plate Number" $txt "dmv_platenumber") +
      (Make-Row "{c1020001-0001-0001-0001-00000000000b}" "Plate Type" $pick "dmv_platetype") +
      (Make-Row "{c1020001-0001-0001-0001-00000000000c}" "Odometer (Miles)" $num "dmv_odometer") +
      (Make-Row "{c1020001-0001-0001-0001-00000000000d}" "Fuel Type" $pick "dmv_fueltype") +
      (Make-Row "{c1020001-0001-0001-0001-00000000000e}" "Insurance Carrier" $txt "dmv_insurancecarrier") +
      (Make-Row "{c1020001-0001-0001-0001-00000000000f}" "Insurance Status" $pick "dmv_insurancestatus") +
      (Make-Row "{c1020001-0001-0001-0001-000000000010}" "Insurance Expiration" $dt "dmv_insuranceexp") +
      (Make-Row "{c1020001-0001-0001-0001-000000000011}" "Insurance Policy Number" $txt "dmv_insurancepolicy")
Update-Form "d62a017a-e688-4966-adf1-1ff229b73dbe" (MakeForm $r1 "Vehicle Information" $r2 "Plate and Insurance")

###############################################################################
Write-Host "`n=== 3. VEHICLE REGISTRATIONS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_vehicleregistration"><attribute name="dmv_registrationid" /><attribute name="dmv_regcontactid" /><attribute name="dmv_vehicleid" /><attribute name="dmv_regtype" /><attribute name="dmv_regstatus" /><attribute name="dmv_effectivedate" /><attribute name="dmv_expirationdate" /><attribute name="dmv_totaldue" /><attribute name="dmv_paymentstatus" /><attribute name="dmv_vehicleregistrationid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_expirationdate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11395" jump="dmv_registrationid" select="1" icon="1" preview="1"><row name="result" id="dmv_vehicleregistrationid"><cell name="dmv_registrationid" width="130" /><cell name="dmv_regcontactid" width="150" /><cell name="dmv_vehicleid" width="160" /><cell name="dmv_regtype" width="100" /><cell name="dmv_regstatus" width="110" /><cell name="dmv_effectivedate" width="100" /><cell name="dmv_expirationdate" width="110" /><cell name="dmv_totaldue" width="90" /><cell name="dmv_paymentstatus" width="100" /></row></grid>'
Update-View "26761996-a173-40f5-8a59-ce0d837fdbf1" "Active Vehicle Registrations" "dmv_vehicleregistration" 11395 "dmv_vehicleregistrationid" $fetch $layout

$r1 = (Make-Row "{c1030001-0001-0001-0001-000000000001}" "Registration ID" $txt "dmv_registrationid") +
      (Make-Row "{c1030001-0001-0001-0001-000000000002}" "Registrant (Contact)" $lkp "dmv_regcontactid") +
      (Make-Row "{c1030001-0001-0001-0001-000000000003}" "Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c1030001-0001-0001-0001-000000000004}" "Registration Type" $pick "dmv_regtype") +
      (Make-Row "{c1030001-0001-0001-0001-000000000005}" "Registration Status" $pick "dmv_regstatus") +
      (Make-Row "{c1030001-0001-0001-0001-000000000006}" "Registration Year" $num "dmv_regyear") +
      (Make-Row "{c1030001-0001-0001-0001-000000000007}" "Effective Date" $dt "dmv_effectivedate") +
      (Make-Row "{c1030001-0001-0001-0001-000000000008}" "Expiration Date" $dt "dmv_expirationdate") +
      (Make-Row "{c1030001-0001-0001-0001-000000000009}" "County" $txt "dmv_county")
$r2 = (Make-Row "{c1030001-0001-0001-0001-00000000000a}" "Total Amount Due" $money "dmv_totaldue") +
      (Make-Row "{c1030001-0001-0001-0001-00000000000b}" "Registration Fee" $money "dmv_fee") +
      (Make-Row "{c1030001-0001-0001-0001-00000000000c}" "Late Fee" $money "dmv_latefee") +
      (Make-Row "{c1030001-0001-0001-0001-00000000000d}" "Payment Status" $pick "dmv_paymentstatus") +
      (Make-Row "{c1030001-0001-0001-0001-00000000000e}" "Payment Method" $pick "dmv_paymentmethod") +
      (Make-Row "{c1030001-0001-0001-0001-00000000000f}" "Sticker/Decal Number" $txt "dmv_stickernumber") +
      (Make-Row "{c1030001-0001-0001-0001-000000000010}" "Online Renewal Eligible" $bool "dmv_onlineeligible") +
      (Make-Row "{c1030001-0001-0001-0001-000000000011}" "Notes" $memo "dmv_notes")
Update-Form "65dc8f05-7b9e-4e9f-a3a0-9fc0b5f7b638" (MakeForm $r1 "Registration Details" $r2 "Payment and Fees")

###############################################################################
Write-Host "`n=== 4. APPOINTMENTS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_appointment"><attribute name="dmv_appointmentnumber" /><attribute name="dmv_contactid" /><attribute name="dmv_servicetype" /><attribute name="dmv_status" /><attribute name="dmv_appointmentdate" /><attribute name="dmv_appointmenttime" /><attribute name="dmv_officeid" /><attribute name="dmv_confirmationsent" /><attribute name="dmv_appointmentid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_appointmentdate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11405" jump="dmv_appointmentnumber" select="1" icon="1" preview="1"><row name="result" id="dmv_appointmentid"><cell name="dmv_appointmentnumber" width="120" /><cell name="dmv_contactid" width="150" /><cell name="dmv_servicetype" width="130" /><cell name="dmv_status" width="100" /><cell name="dmv_appointmentdate" width="110" /><cell name="dmv_appointmenttime" width="90" /><cell name="dmv_officeid" width="140" /><cell name="dmv_confirmationsent" width="90" /></row></grid>'
Update-View "feec6b55-6fb9-4b53-a77c-17a7b9413439" "Active DMV Appointments" "dmv_appointment" 11405 "dmv_appointmentid" $fetch $layout

$r1 = (Make-Row "{c1040001-0001-0001-0001-000000000001}" "Appointment ID" $txt "dmv_appointmentnumber") +
      (Make-Row "{c1040001-0001-0001-0001-000000000002}" "Citizen (Contact)" $lkp "dmv_contactid") +
      (Make-Row "{c1040001-0001-0001-0001-000000000003}" "Service Type" $pick "dmv_servicetype") +
      (Make-Row "{c1040001-0001-0001-0001-000000000004}" "Status" $pick "dmv_status") +
      (Make-Row "{c1040001-0001-0001-0001-000000000005}" "Appointment Date" $dt "dmv_appointmentdate") +
      (Make-Row "{c1040001-0001-0001-0001-000000000006}" "Appointment Time" $txt "dmv_appointmenttime") +
      (Make-Row "{c1040001-0001-0001-0001-000000000007}" "DMV Office" $lkp "dmv_officeid") +
      (Make-Row "{c1040001-0001-0001-0001-000000000008}" "Duration (Minutes)" $num "dmv_duration")
$r2 = (Make-Row "{c1040001-0001-0001-0001-000000000009}" "Related License" $lkp "dmv_relatedlicenseid") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000a}" "Related Registration" $lkp "dmv_relatedregid") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000b}" "Confirmation Sent" $bool "dmv_confirmationsent") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000c}" "Reminder Sent" $bool "dmv_remindersent") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000d}" "Check-In Time" $dt "dmv_checkintime") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000e}" "Completion Time" $dt "dmv_completiontime") +
      (Make-Row "{c1040001-0001-0001-0001-00000000000f}" "Cancellation Reason" $txt "dmv_cancelreason") +
      (Make-Row "{c1040001-0001-0001-0001-000000000010}" "Notes" $memo "dmv_notes")
Update-Form "5a645ec0-c849-4b32-9b17-9f43cc714428" (MakeForm $r1 "Appointment Details" $r2 "Related Records and Status")

###############################################################################
Write-Host "`n=== 5. DOCUMENT UPLOADS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_documentupload"><attribute name="dmv_documentname" /><attribute name="dmv_contactid" /><attribute name="dmv_documenttype" /><attribute name="dmv_verificationstatus" /><attribute name="dmv_uploaddate" /><attribute name="dmv_filetype" /><attribute name="dmv_filesize" /><attribute name="dmv_documentuploadid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_uploaddate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11397" jump="dmv_documentname" select="1" icon="1" preview="1"><row name="result" id="dmv_documentuploadid"><cell name="dmv_documentname" width="180" /><cell name="dmv_contactid" width="150" /><cell name="dmv_documenttype" width="120" /><cell name="dmv_verificationstatus" width="120" /><cell name="dmv_uploaddate" width="110" /><cell name="dmv_filetype" width="80" /><cell name="dmv_filesize" width="80" /></row></grid>'
Update-View "f47426e6-af66-4c5c-a308-ceb5d0e008ca" "Active Document Uploads" "dmv_documentupload" 11397 "dmv_documentuploadid" $fetch $layout

$r1 = (Make-Row "{c1050001-0001-0001-0001-000000000001}" "Document Name" $txt "dmv_documentname") +
      (Make-Row "{c1050001-0001-0001-0001-000000000002}" "Submitted By (Contact)" $lkp "dmv_contactid") +
      (Make-Row "{c1050001-0001-0001-0001-000000000003}" "Submitted By (Dealer)" $lkp "dmv_dealeracctid") +
      (Make-Row "{c1050001-0001-0001-0001-000000000004}" "Document Type" $pick "dmv_documenttype") +
      (Make-Row "{c1050001-0001-0001-0001-000000000005}" "Upload Date" $dt "dmv_uploaddate") +
      (Make-Row "{c1050001-0001-0001-0001-000000000006}" "File Type" $txt "dmv_filetype") +
      (Make-Row "{c1050001-0001-0001-0001-000000000007}" "File Size (KB)" $num "dmv_filesize")
$r2 = (Make-Row "{c1050001-0001-0001-0001-000000000008}" "Verification Status" $pick "dmv_verificationstatus") +
      (Make-Row "{c1050001-0001-0001-0001-000000000009}" "Verified Date" $dt "dmv_verifieddate") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000a}" "Expiration Date" $dt "dmv_expirationdate") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000b}" "AI Confidence Score" $num "dmv_aiconfidence") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000c}" "Related License" $lkp "dmv_licenseid") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000d}" "Related Registration" $lkp "dmv_registrationid") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000e}" "Related Title" $lkp "dmv_titleid") +
      (Make-Row "{c1050001-0001-0001-0001-00000000000f}" "Rejection Reason" $memo "dmv_rejectionreason")
Update-Form "ccddbcbf-b314-4f62-ab9f-c4d4a12fd974" (MakeForm $r1 "Document Details" $r2 "Verification and Related Records")

###############################################################################
Write-Host "`n=== 6. VEHICLE TITLES ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_vehicletitle"><attribute name="dmv_titlenumber" /><attribute name="dmv_ownercontactid" /><attribute name="dmv_vehicleid" /><attribute name="dmv_titletype" /><attribute name="dmv_titlestatus" /><attribute name="dmv_processingstatus" /><attribute name="dmv_issuedate" /><attribute name="dmv_saleprice" /><attribute name="dmv_vehicletitleid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_issuedate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11398" jump="dmv_titlenumber" select="1" icon="1" preview="1"><row name="result" id="dmv_vehicletitleid"><cell name="dmv_titlenumber" width="130" /><cell name="dmv_ownercontactid" width="150" /><cell name="dmv_vehicleid" width="160" /><cell name="dmv_titletype" width="100" /><cell name="dmv_titlestatus" width="100" /><cell name="dmv_processingstatus" width="110" /><cell name="dmv_issuedate" width="100" /><cell name="dmv_saleprice" width="90" /></row></grid>'
Update-View "9b4d2135-db38-4e36-91e4-79b43775349f" "Active Vehicle Titles" "dmv_vehicletitle" 11398 "dmv_vehicletitleid" $fetch $layout

$r1 = (Make-Row "{c1060001-0001-0001-0001-000000000001}" "Title Number" $txt "dmv_titlenumber") +
      (Make-Row "{c1060001-0001-0001-0001-000000000002}" "Owner (Contact)" $lkp "dmv_ownercontactid") +
      (Make-Row "{c1060001-0001-0001-0001-000000000003}" "Owner (Dealer)" $lkp "dmv_owneracctid") +
      (Make-Row "{c1060001-0001-0001-0001-000000000004}" "Co-Owner Name" $txt "dmv_coownername") +
      (Make-Row "{c1060001-0001-0001-0001-000000000005}" "Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c1060001-0001-0001-0001-000000000006}" "Title Type" $pick "dmv_titletype") +
      (Make-Row "{c1060001-0001-0001-0001-000000000007}" "Title Status" $pick "dmv_titlestatus") +
      (Make-Row "{c1060001-0001-0001-0001-000000000008}" "Processing Status" $pick "dmv_processingstatus")
$r2 = (Make-Row "{c1060001-0001-0001-0001-000000000009}" "Issue Date" $dt "dmv_issuedate") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000a}" "Transfer Date" $dt "dmv_transferdate") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000b}" "Odometer at Transfer" $num "dmv_transferodometer") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000c}" "Sale Price" $money "dmv_saleprice") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000d}" "Sales Tax Amount" $money "dmv_salestax") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000e}" "Lienholder Name" $txt "dmv_lienholdername") +
      (Make-Row "{c1060001-0001-0001-0001-00000000000f}" "ELT Enabled" $bool "dmv_eltenabled") +
      (Make-Row "{c1060001-0001-0001-0001-000000000010}" "Notes" $memo "dmv_notes")
Update-Form "3b0c5f05-02a1-4577-ba82-2d285c3b78ee" (MakeForm $r1 "Title Information" $r2 "Transfer and Financial")

###############################################################################
Write-Host "`n=== 7. LIENS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_lien"><attribute name="dmv_lienreference" /><attribute name="dmv_lienholdername" /><attribute name="dmv_vehicleid" /><attribute name="dmv_titleid" /><attribute name="dmv_lienstatus" /><attribute name="dmv_liendate" /><attribute name="dmv_loanamount" /><attribute name="dmv_loanmaturity" /><attribute name="dmv_lienid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_liendate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11406" jump="dmv_lienreference" select="1" icon="1" preview="1"><row name="result" id="dmv_lienid"><cell name="dmv_lienreference" width="120" /><cell name="dmv_lienholdername" width="160" /><cell name="dmv_vehicleid" width="160" /><cell name="dmv_titleid" width="130" /><cell name="dmv_lienstatus" width="100" /><cell name="dmv_liendate" width="100" /><cell name="dmv_loanamount" width="100" /><cell name="dmv_loanmaturity" width="110" /></row></grid>'
Update-View "b855c293-79a3-41e2-ad4c-9c5730cfc8e6" "Active Liens" "dmv_lien" 11406 "dmv_lienid" $fetch $layout

$r1 = (Make-Row "{c1070001-0001-0001-0001-000000000001}" "Lien ID" $txt "dmv_lienreference") +
      (Make-Row "{c1070001-0001-0001-0001-000000000002}" "Lienholder Name" $txt "dmv_lienholdername") +
      (Make-Row "{c1070001-0001-0001-0001-000000000003}" "Lienholder ELT ID" $txt "dmv_eltid") +
      (Make-Row "{c1070001-0001-0001-0001-000000000004}" "Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c1070001-0001-0001-0001-000000000005}" "Vehicle Title" $lkp "dmv_titleid") +
      (Make-Row "{c1070001-0001-0001-0001-000000000006}" "Lien Status" $pick "dmv_lienstatus") +
      (Make-Row "{c1070001-0001-0001-0001-000000000007}" "Lien Date" $dt "dmv_liendate")
$r2 = (Make-Row "{c1070001-0001-0001-0001-000000000008}" "Loan Amount" $money "dmv_loanamount") +
      (Make-Row "{c1070001-0001-0001-0001-000000000009}" "Loan Term (Months)" $num "dmv_loanterm") +
      (Make-Row "{c1070001-0001-0001-0001-00000000000a}" "Loan Maturity Date" $dt "dmv_loanmaturity") +
      (Make-Row "{c1070001-0001-0001-0001-00000000000b}" "Release Date" $dt "dmv_releasedate") +
      (Make-Row "{c1070001-0001-0001-0001-00000000000c}" "Release Method" $pick "dmv_releasemethod") +
      (Make-Row "{c1070001-0001-0001-0001-00000000000d}" "ELT Notification Sent" $bool "dmv_eltnotification") +
      (Make-Row "{c1070001-0001-0001-0001-00000000000e}" "Notes" $memo "dmv_notes")
Update-Form "1681cecc-152a-4487-84ec-b3f3c27334ea" (MakeForm $r1 "Lien Details" $r2 "Loan and Release")

###############################################################################
Write-Host "`n=== 8. TEMPORARY TAGS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_temporarytag"><attribute name="dmv_tagnumber" /><attribute name="dmv_buyercontactid" /><attribute name="dmv_dealeracctid" /><attribute name="dmv_vehicleid" /><attribute name="dmv_tagstatus" /><attribute name="dmv_issuedate" /><attribute name="dmv_expirationdate" /><attribute name="dmv_saleprice" /><attribute name="dmv_temporarytagid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_issuedate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11400" jump="dmv_tagnumber" select="1" icon="1" preview="1"><row name="result" id="dmv_temporarytagid"><cell name="dmv_tagnumber" width="120" /><cell name="dmv_buyercontactid" width="140" /><cell name="dmv_dealeracctid" width="140" /><cell name="dmv_vehicleid" width="150" /><cell name="dmv_tagstatus" width="100" /><cell name="dmv_issuedate" width="100" /><cell name="dmv_expirationdate" width="110" /><cell name="dmv_saleprice" width="90" /></row></grid>'
Update-View "bef579b2-e078-4fdc-acd4-10b5f609b5e8" "Active Temporary Tags" "dmv_temporarytag" 11400 "dmv_temporarytagid" $fetch $layout

$r1 = (Make-Row "{c1080001-0001-0001-0001-000000000001}" "Tag Number" $txt "dmv_tagnumber") +
      (Make-Row "{c1080001-0001-0001-0001-000000000002}" "Buyer (Contact)" $lkp "dmv_buyercontactid") +
      (Make-Row "{c1080001-0001-0001-0001-000000000003}" "Buyer Name" $txt "dmv_buyername") +
      (Make-Row "{c1080001-0001-0001-0001-000000000004}" "Dealer (Account)" $lkp "dmv_dealeracctid") +
      (Make-Row "{c1080001-0001-0001-0001-000000000005}" "Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c1080001-0001-0001-0001-000000000006}" "Tag Status" $pick "dmv_tagstatus") +
      (Make-Row "{c1080001-0001-0001-0001-000000000007}" "Issue Date" $dt "dmv_issuedate") +
      (Make-Row "{c1080001-0001-0001-0001-000000000008}" "Expiration Date" $dt "dmv_expirationdate")
$r2 = (Make-Row "{c1080001-0001-0001-0001-000000000009}" "Sale Price" $money "dmv_saleprice") +
      (Make-Row "{c1080001-0001-0001-0001-00000000000a}" "Print Count" $num "dmv_printcount") +
      (Make-Row "{c1080001-0001-0001-0001-00000000000b}" "Generated By" $lkp "dmv_generatedby") +
      (Make-Row "{c1080001-0001-0001-0001-00000000000c}" "Voided Reason" $txt "dmv_voidedreason")
Update-Form "445699df-f6a9-4943-a1c5-6fca09ae573e" (MakeForm $r1 "Tag Details" $r2 "Sale and Printing")

###############################################################################
Write-Host "`n=== 9. BULK SUBMISSIONS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_bulksubmission"><attribute name="dmv_batchid" /><attribute name="dmv_dealeracctid" /><attribute name="dmv_batchstatus" /><attribute name="dmv_submissiondate" /><attribute name="dmv_totalrecords" /><attribute name="dmv_processedrecords" /><attribute name="dmv_failedrecords" /><attribute name="dmv_totalfees" /><attribute name="dmv_paymentstatus" /><attribute name="dmv_bulksubmissionid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_submissiondate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11401" jump="dmv_batchid" select="1" icon="1" preview="1"><row name="result" id="dmv_bulksubmissionid"><cell name="dmv_batchid" width="120" /><cell name="dmv_dealeracctid" width="150" /><cell name="dmv_batchstatus" width="100" /><cell name="dmv_submissiondate" width="110" /><cell name="dmv_totalrecords" width="80" /><cell name="dmv_processedrecords" width="80" /><cell name="dmv_failedrecords" width="80" /><cell name="dmv_totalfees" width="90" /><cell name="dmv_paymentstatus" width="100" /></row></grid>'
Update-View "8d9abb73-82dd-40ba-844e-9d9e7d59ae1f" "Active Bulk Registration Submissions" "dmv_bulksubmission" 11401 "dmv_bulksubmissionid" $fetch $layout

$r1 = (Make-Row "{c1090001-0001-0001-0001-000000000001}" "Batch ID" $txt "dmv_batchid") +
      (Make-Row "{c1090001-0001-0001-0001-000000000002}" "Dealer (Account)" $lkp "dmv_dealeracctid") +
      (Make-Row "{c1090001-0001-0001-0001-000000000003}" "Batch Status" $pick "dmv_batchstatus") +
      (Make-Row "{c1090001-0001-0001-0001-000000000004}" "Submission Date" $dt "dmv_submissiondate") +
      (Make-Row "{c1090001-0001-0001-0001-000000000005}" "Submitted By" $lkp "dmv_submittedby")
$r2 = (Make-Row "{c1090001-0001-0001-0001-000000000006}" "Total Records" $num "dmv_totalrecords") +
      (Make-Row "{c1090001-0001-0001-0001-000000000007}" "Processed Records" $num "dmv_processedrecords") +
      (Make-Row "{c1090001-0001-0001-0001-000000000008}" "Failed Records" $num "dmv_failedrecords") +
      (Make-Row "{c1090001-0001-0001-0001-000000000009}" "Total Fees" $money "dmv_totalfees") +
      (Make-Row "{c1090001-0001-0001-0001-00000000000a}" "Payment Status" $pick "dmv_paymentstatus") +
      (Make-Row "{c1090001-0001-0001-0001-00000000000b}" "Notes" $memo "dmv_notes")
Update-Form "a1c59194-0504-48b3-8f8d-7eb9e1bf96bd" (MakeForm $r1 "Submission Details" $r2 "Processing and Payment")

###############################################################################
Write-Host "`n=== 10. TRANSACTION LOG ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_transactionlog"><attribute name="dmv_transactionid" /><attribute name="dmv_transactiontype" /><attribute name="dmv_contactid" /><attribute name="dmv_transactiondate" /><attribute name="dmv_amount" /><attribute name="dmv_status" /><attribute name="dmv_channel" /><attribute name="dmv_vehicleid" /><attribute name="dmv_transactionlogid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_transactiondate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11402" jump="dmv_transactionid" select="1" icon="1" preview="1"><row name="result" id="dmv_transactionlogid"><cell name="dmv_transactionid" width="130" /><cell name="dmv_transactiontype" width="120" /><cell name="dmv_contactid" width="150" /><cell name="dmv_transactiondate" width="110" /><cell name="dmv_amount" width="90" /><cell name="dmv_status" width="100" /><cell name="dmv_channel" width="90" /><cell name="dmv_vehicleid" width="150" /></row></grid>'
Update-View "86234468-3bab-48b4-a824-c7b7a587a4e2" "Active DMV Transaction Logs" "dmv_transactionlog" 11402 "dmv_transactionlogid" $fetch $layout

$r1 = (Make-Row "{c10a0001-0001-0001-0001-000000000001}" "Transaction ID" $txt "dmv_transactionid") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000002}" "Transaction Type" $pick "dmv_transactiontype") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000003}" "Citizen (Contact)" $lkp "dmv_contactid") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000004}" "Dealer (Account)" $lkp "dmv_dealeracctid") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000005}" "Transaction Date" $dt "dmv_transactiondate") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000006}" "Amount" $money "dmv_amount") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000007}" "Status" $pick "dmv_status") +
      (Make-Row "{c10a0001-0001-0001-0001-000000000008}" "Channel" $pick "dmv_channel")
$r2 = (Make-Row "{c10a0001-0001-0001-0001-000000000009}" "Related Vehicle" $lkp "dmv_vehicleid") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000a}" "Related License" $lkp "dmv_licenseid") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000b}" "Related Registration" $lkp "dmv_registrationid") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000c}" "Related Title" $lkp "dmv_titleid") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000d}" "Payment Reference" $txt "dmv_paymentref") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000e}" "Initiated By" $lkp "dmv_initiatedby") +
      (Make-Row "{c10a0001-0001-0001-0001-00000000000f}" "Notes" $memo "dmv_notes")
Update-Form "ce4c0812-ce0f-4e92-bed1-dd92628b963b" (MakeForm $r1 "Transaction Details" $r2 "Related Records")

###############################################################################
Write-Host "`n=== 11. NOTIFICATIONS ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_notification"><attribute name="dmv_notificationref" /><attribute name="dmv_recipientcontactid" /><attribute name="dmv_notificationtype" /><attribute name="dmv_subject" /><attribute name="dmv_channel" /><attribute name="dmv_deliverystatus" /><attribute name="dmv_sentdate" /><attribute name="dmv_notificationid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_sentdate" descending="true" /></entity></fetch>'
$layout = '<grid name="resultset" object="11407" jump="dmv_notificationref" select="1" icon="1" preview="1"><row name="result" id="dmv_notificationid"><cell name="dmv_notificationref" width="120" /><cell name="dmv_recipientcontactid" width="150" /><cell name="dmv_notificationtype" width="120" /><cell name="dmv_subject" width="180" /><cell name="dmv_channel" width="80" /><cell name="dmv_deliverystatus" width="110" /><cell name="dmv_sentdate" width="110" /></row></grid>'
Update-View "e0518773-3326-47cc-b8b9-9c3af456befe" "Active Notifications" "dmv_notification" 11407 "dmv_notificationid" $fetch $layout

$r1 = (Make-Row "{c10b0001-0001-0001-0001-000000000001}" "Notification ID" $txt "dmv_notificationref") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000002}" "Recipient (Contact)" $lkp "dmv_recipientcontactid") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000003}" "Recipient (Dealer)" $lkp "dmv_recipientacctid") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000004}" "Notification Type" $pick "dmv_notificationtype") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000005}" "Subject" $txt "dmv_subject") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000006}" "Preview Text" $txt "dmv_previewtext") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000007}" "Channel" $pick "dmv_channel")
$r2 = (Make-Row "{c10b0001-0001-0001-0001-000000000008}" "Delivery Status" $pick "dmv_deliverystatus") +
      (Make-Row "{c10b0001-0001-0001-0001-000000000009}" "Sent Date" $dt "dmv_sentdate") +
      (Make-Row "{c10b0001-0001-0001-0001-00000000000a}" "Retry Count" $num "dmv_retrycount") +
      (Make-Row "{c10b0001-0001-0001-0001-00000000000b}" "Template Used" $txt "dmv_templatename") +
      (Make-Row "{c10b0001-0001-0001-0001-00000000000c}" "Related Appointment" $lkp "dmv_appointmentid") +
      (Make-Row "{c10b0001-0001-0001-0001-00000000000d}" "Related License" $lkp "dmv_licenseid") +
      (Make-Row "{c10b0001-0001-0001-0001-00000000000e}" "Related Registration" $lkp "dmv_registrationid")
Update-Form "ad9eb40c-e396-42f8-8d6f-79f25264db16" (MakeForm $r1 "Notification Details" $r2 "Delivery and Related Records")

###############################################################################
Write-Host "`n=== 12. DMV OFFICES ==="
###############################################################################
$fetch = '<fetch version="1.0" output-format="xml-platform" mapping="logical"><entity name="dmv_dmvoffice"><attribute name="dmv_officename" /><attribute name="dmv_officecode" /><attribute name="dmv_city" /><attribute name="dmv_county" /><attribute name="dmv_state" /><attribute name="dmv_phone" /><attribute name="dmv_active" /><attribute name="dmv_schedulingenabled" /><attribute name="dmv_dmvofficeid" /><filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter><order attribute="dmv_officename" descending="false" /></entity></fetch>'
$layout = '<grid name="resultset" object="11390" jump="dmv_officename" select="1" icon="1" preview="1"><row name="result" id="dmv_dmvofficeid"><cell name="dmv_officename" width="180" /><cell name="dmv_officecode" width="90" /><cell name="dmv_city" width="110" /><cell name="dmv_county" width="100" /><cell name="dmv_state" width="70" /><cell name="dmv_phone" width="110" /><cell name="dmv_active" width="70" /><cell name="dmv_schedulingenabled" width="100" /></row></grid>'
Update-View "e93f59d4-97dc-4849-9573-3b0732755db5" "Active DMV Offices" "dmv_dmvoffice" 11390 "dmv_dmvofficeid" $fetch $layout

$r1 = (Make-Row "{c10c0001-0001-0001-0001-000000000001}" "Office Name" $txt "dmv_officename") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000002}" "Office Code" $txt "dmv_officecode") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000003}" "Address Line 1" $txt "dmv_address1") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000004}" "City" $txt "dmv_city") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000005}" "County" $txt "dmv_county") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000006}" "State" $txt "dmv_state") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000007}" "ZIP Code" $txt "dmv_zipcode") +
      (Make-Row "{c10c0001-0001-0001-0001-000000000008}" "Phone" $txt "dmv_phone")
$r2 = (Make-Row "{c10c0001-0001-0001-0001-000000000009}" "Active" $bool "dmv_active") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000a}" "Online Scheduling" $bool "dmv_schedulingenabled") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000b}" "Max Daily Appointments" $num "dmv_maxappointments") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000c}" "Current Wait (Min)" $num "dmv_currentwait") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000d}" "Latitude" $num "dmv_latitude") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000e}" "Longitude" $num "dmv_longitude") +
      (Make-Row "{c10c0001-0001-0001-0001-00000000000f}" "Hours of Operation" $memo "dmv_hours")
Update-Form "e391f71f-88bf-4a97-846f-7994d338e45e" (MakeForm $r1 "Office Information" $r2 "Scheduling and Location")

###############################################################################
Write-Host "`n=== 13. UPDATE SITEMAP WITH ICONS ==="
###############################################################################
# Using Dynamics 365 web resource icon paths (SVG icon names from Dynamics)
$sitemapXml = @'
<SiteMap IntroducedVersion="7.0.0.0">
  <Area Id="DMVArea" Title="DMV Operations" ShowGroups="true" Icon="/WebResources/msdyn_/Icons/DMV_Area.svg">
    <Group Id="CitizenGroup" Title="Citizen Services">
      <SubArea Id="nav_contact" Entity="contact" Title="Citizens (Contacts)" Icon="/_imgs/svg_contact.svg" />
      <SubArea Id="nav_driverlicense" Entity="dmv_driverlicense" Title="Driver Licenses" Icon="/_imgs/ico/16_L_ribbon_card.svg" />
      <SubArea Id="nav_appointment" Entity="dmv_appointment" Title="Appointments" Icon="/_imgs/svg_appointment.svg" />
      <SubArea Id="nav_documentupload" Entity="dmv_documentupload" Title="Document Uploads" Icon="/_imgs/svg_sharepointdocument.svg" />
      <SubArea Id="nav_notification" Entity="dmv_notification" Title="Notifications" Icon="/_imgs/svg_email.svg" />
    </Group>
    <Group Id="VehicleGroup" Title="Vehicle Services">
      <SubArea Id="nav_vehicle" Entity="dmv_vehicle" Title="Vehicles" Icon="/_imgs/svg_product.svg" />
      <SubArea Id="nav_vehiclereg" Entity="dmv_vehicleregistration" Title="Registrations" Icon="/_imgs/svg_invoice.svg" />
      <SubArea Id="nav_vehicletitle" Entity="dmv_vehicletitle" Title="Vehicle Titles" Icon="/_imgs/svg_contract.svg" />
      <SubArea Id="nav_lien" Entity="dmv_lien" Title="Liens" Icon="/_imgs/svg_quote.svg" />
    </Group>
    <Group Id="DealerGroup" Title="Dealer Operations">
      <SubArea Id="nav_account" Entity="account" Title="Dealers (Accounts)" Icon="/_imgs/svg_account.svg" />
      <SubArea Id="nav_temporarytag" Entity="dmv_temporarytag" Title="Temporary Tags" Icon="/_imgs/svg_salesliterature.svg" />
      <SubArea Id="nav_bulksubmission" Entity="dmv_bulksubmission" Title="Bulk Submissions" Icon="/_imgs/svg_importdata.svg" />
    </Group>
    <Group Id="AdminGroup" Title="Administration">
      <SubArea Id="nav_dmvoffice" Entity="dmv_dmvoffice" Title="DMV Offices" Icon="/_imgs/svg_site.svg" />
      <SubArea Id="nav_transactionlog" Entity="dmv_transactionlog" Title="Transaction Log" Icon="/_imgs/svg_audit.svg" />
    </Group>
  </Area>
</SiteMap>
'@

$smId = "98db46b0-896f-412f-a212-01d534198efb"
$smBody = @{ sitemapxml = $sitemapXml } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/sitemaps($smId)" -Method Patch -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($smBody)) -UseBasicParsing | Out-Null
    Write-Host "  SITEMAP OK"
} catch {
    Write-Host "  SITEMAP ERR: $($_.ErrorDetails.Message)"
}

###############################################################################
Write-Host "`n=== 14. PUBLISH ALL ==="
###############################################################################
$appId = "d6331d8d-a239-f111-88b4-001dd80a6132"
$pubXml = "<importexportxml><entities><entity>contact</entity><entity>account</entity><entity>dmv_driverlicense</entity><entity>dmv_vehicle</entity><entity>dmv_vehicleregistration</entity><entity>dmv_appointment</entity><entity>dmv_documentupload</entity><entity>dmv_vehicletitle</entity><entity>dmv_lien</entity><entity>dmv_temporarytag</entity><entity>dmv_bulksubmission</entity><entity>dmv_transactionlog</entity><entity>dmv_notification</entity><entity>dmv_dmvoffice</entity></entities><appmodules><appmodule>$appId</appmodule></appmodules><sitemaps><sitemap>{$smId}</sitemap></sitemaps></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
    Write-Host "  PUBLISHED ALL"
} catch {
    Write-Host "  PUBLISH ERR: $($_.ErrorDetails.Message)"
}

Write-Host "`n==========================================="
Write-Host " ALL VIEWS, FORMS, AND SITEMAP UPDATED"
Write-Host "==========================================="
