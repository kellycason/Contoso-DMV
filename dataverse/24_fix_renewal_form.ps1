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

$formId = "950f6e67-859e-4e40-910e-67829c661891"
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

$secAction = (Make-Row "{e1010001-0001-0001-0001-000000000001}" "Renewal Status" $pick "dmv_renewalstatus") +
             (Make-Row "{e1010001-0001-0001-0001-000000000002}" "Approved Date" $dt "dmv_approveddate") +
             (Make-Row "{e1010001-0001-0001-0001-000000000003}" "New Expiration Date" $dt "dmv_newexpirationdate") +
             (Make-Row "{e1010001-0001-0001-0001-000000000004}" "Driver License" $lkp "dmv_licenseid")

$sec1 = (Make-Row "{e1010001-0001-0001-0001-000000000005}" "Renewal ID" $txt "dmv_renewalid") +
        (Make-Row "{e1010001-0001-0001-0001-000000000006}" "Contact" $lkp "dmv_contactid") +
        (Make-Row "{e1010001-0001-0001-0001-000000000007}" "License Number" $txt "dmv_licensenumber") +
        (Make-Row "{e1010001-0001-0001-0001-000000000008}" "Date of Birth" $dt "dmv_dateofbirth") +
        (Make-Row "{e1010001-0001-0001-0001-000000000009}" "Last 4 SSN" $txt "dmv_ssn4") +
        (Make-Row "{e1010001-0001-0001-0001-00000000000a}" "Submitted" $dt "dmv_submitteddate") +
        (Make-Row "{e1010001-0001-0001-0001-00000000000b}" "Channel" $pick "dmv_channel")

$sec3 = (Make-Row "{e1010001-0001-0001-0001-000000000011}" "Vision OK" $bool "dmv_visionok") +
        (Make-Row "{e1010001-0001-0001-0001-000000000012}" "Seizure History" $bool "dmv_seizures") +
        (Make-Row "{e1010001-0001-0001-0001-000000000013}" "Loss of Consciousness" $bool "dmv_lossofconsciousness") +
        (Make-Row "{e1010001-0001-0001-0001-000000000014}" "Medical Notes" $memo "dmv_medicalconditions")

$sec2 = (Make-Row "{e1010001-0001-0001-0001-00000000000c}" "First Name" $txt "dmv_firstname") +
        (Make-Row "{e1010001-0001-0001-0001-00000000000d}" "Last Name" $txt "dmv_lastname") +
        (Make-Row "{e1010001-0001-0001-0001-00000000000e}" "Email" $email "dmv_email") +
        (Make-Row "{e1010001-0001-0001-0001-00000000000f}" "Phone" $phone "dmv_phone") +
        (Make-Row "{e1010001-0001-0001-0001-000000000010}" "Street Address" $txt "dmv_streetaddress") +
        (Make-Row "{e1010001-0001-0001-0001-000000000015}" "City" $txt "dmv_city") +
        (Make-Row "{e1010001-0001-0001-0001-000000000016}" "State" $txt "dmv_state") +
        (Make-Row "{e1010001-0001-0001-0001-000000000017}" "ZIP Code" $txt "dmv_zipcode")

$sec4 = (Make-Row "{e1010001-0001-0001-0001-000000000018}" "Renewal Fee" $money "dmv_renewalfee") +
        (Make-Row "{e1010001-0001-0001-0001-000000000019}" "Payment Method" $pick "dmv_paymentmethod") +
        (Make-Row "{e1010001-0001-0001-0001-00000000001a}" "Payment Confirmation" $txt "dmv_paymentconfirmation")

$formXml = '<form showImage="true"><tabs>' +
    '<tab name="ACTION" id="{e2000001-0001-0001-0001-000000000000}" showlabel="true" expanded="true">' +
      '<labels><label description="Review and Decision" languagecode="1033" /></labels>' +
      '<columns><column width="100%"><sections>' +
        '<section name="SEC_ACTION" showlabel="true" showbar="false" id="{e3000001-0001-0001-0001-000000000000}" columns="2" labelwidth="150" celllabelposition="Left">' +
          '<labels><label description="Approval Action" languagecode="1033" /></labels>' +
          "<rows>$secAction</rows>" +
        '</section>' +
      '</sections></column></columns>' +
    '</tab>' +
    '<tab name="DETAILS" id="{e2000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true">' +
      '<labels><label description="Request Details" languagecode="1033" /></labels>' +
      '<columns>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_REQUEST" showlabel="true" showbar="false" id="{e3000001-0001-0001-0001-000000000001}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Request Information" languagecode="1033" /></labels>' +
            "<rows>$sec1</rows>" +
          '</section>' +
          '<section name="SEC_MEDICAL" showlabel="true" showbar="false" id="{e3000001-0001-0001-0001-000000000003}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Medical Questionnaire" languagecode="1033" /></labels>' +
            "<rows>$sec3</rows>" +
          '</section>' +
        '</sections></column>' +
        '<column width="50%"><sections>' +
          '<section name="SEC_DETAILS" showlabel="true" showbar="false" id="{e3000001-0001-0001-0001-000000000002}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Personal Details" languagecode="1033" /></labels>' +
            "<rows>$sec2</rows>" +
          '</section>' +
          '<section name="SEC_PAYMENT" showlabel="true" showbar="false" id="{e3000001-0001-0001-0001-000000000004}" columns="1" labelwidth="150" celllabelposition="Left">' +
            '<labels><label description="Payment" languagecode="1033" /></labels>' +
            "<rows>$sec4</rows>" +
          '</section>' +
        '</sections></column>' +
      '</columns>' +
    '</tab>' +
  '</tabs></form>'

Write-Host "Form XML length: $($formXml.Length)"
$formBody = @{ formxml = $formXml } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($formBody)) -UseBasicParsing | Out-Null
Write-Host "Form updated!"

$pubXml = "<importexportxml><entities><entity>dmv_licenserenewal</entity></entities></importexportxml>"
$pubBody = @{ ParameterXml = $pubXml } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "Published!"
