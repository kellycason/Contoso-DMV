###############################################################################
# 47_dealer_mda_views_and_form.ps1
#
# Adds dealer-submission views and patches the main form on
# dmv_vehicleregistration with a "Dealer Review" tab so CSR/DMV staff can
# triage dealer submissions from the Contact Center Workspace app.
#
# Creates:
#   - Saved query: "Dealer Submissions - Pending Review"
#   - Saved query: "Dealer Submissions - All"
# Patches:
#   - Main form (type=2) on dmv_vehicleregistration: adds Dealer Review tab
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization              = "Bearer $token"
  "Content-Type"             = "application/json; charset=utf-8"
  "OData-MaxVersion"         = "4.0"
  "OData-Version"            = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$hRead = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ──────────────────────────────────────────────────────────────────────────────
# Helper: upsert savedquery by name
# ──────────────────────────────────────────────────────────────────────────────
function Upsert-SavedQuery {
  param([string]$Name, [string]$FetchXml, [string]$LayoutXml, [int]$QueryType = 0)

  $existing = Invoke-RestMethod -Headers $hRead `
    -Uri "$envUrl/api/data/v9.2/savedqueries?`$filter=name eq '$Name' and returnedtypecode eq 'dmv_vehicleregistration'&`$select=savedqueryid"
  $body = @{
    name              = $Name
    returnedtypecode  = "dmv_vehicleregistration"
    fetchxml          = $FetchXml
    layoutxml         = $LayoutXml
    querytype         = $QueryType
    description       = "Dealer submissions for DMV staff review."
  } | ConvertTo-Json -Depth 5
  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

  if ($existing.value.Count -gt 0) {
    $id = $existing.value[0].savedqueryid
    Write-Host "  Updating existing: $Name ($id)" -ForegroundColor Yellow
    Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/savedqueries($id)" -Method Patch -Body $bodyBytes -UseBasicParsing | Out-Null
    return $id
  } else {
    Write-Host "  Creating: $Name" -ForegroundColor Green
    $r = Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/savedqueries" -Method Post -Body $bodyBytes -UseBasicParsing
    $idMatch = [regex]::Match($r.Headers["OData-EntityId"], "\(([^)]+)\)")
    return $idMatch.Groups[1].Value
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. View: Dealer Submissions - Pending Review
#    Filter: submissionchannel = Dealer AND status in (Submitted, Under Review)
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "=== View 1: Dealer Submissions - Pending Review ===" -ForegroundColor Cyan
$fetchPending = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_vehicleregistration">
    <attribute name="dmv_registrationid" />
    <attribute name="dmv_dealeracctid" />
    <attribute name="dmv_vehicleid" />
    <attribute name="dmv_regcontactid" />
    <attribute name="dmv_regstatus" />
    <attribute name="dmv_submissionchannel" />
    <attribute name="dmv_insuranceverified" />
    <attribute name="dmv_submitteddate" />
    <attribute name="dmv_totaldue" />
    <attribute name="dmv_vehicleregistrationid" />
    <order attribute="dmv_submitteddate" descending="false" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="dmv_submissionchannel" operator="eq" value="100000000" />
      <condition attribute="dmv_regstatus" operator="in">
        <value>100000006</value>
        <value>100000007</value>
      </condition>
    </filter>
  </entity>
</fetch>
'@
$layoutPending = @'
<grid name="resultset" object="11395" jump="dmv_registrationid" select="1" icon="1" preview="1">
  <row name="result" id="dmv_vehicleregistrationid">
    <cell name="dmv_registrationid" width="140" />
    <cell name="dmv_dealeracctid" width="160" />
    <cell name="dmv_vehicleid" width="180" />
    <cell name="dmv_regcontactid" width="150" />
    <cell name="dmv_regstatus" width="120" />
    <cell name="dmv_insuranceverified" width="100" />
    <cell name="dmv_submitteddate" width="130" />
    <cell name="dmv_totaldue" width="100" />
  </row>
</grid>
'@
$pendingId = Upsert-SavedQuery -Name "Dealer Submissions - Pending Review" -FetchXml $fetchPending -LayoutXml $layoutPending
Write-Host "  ID: $pendingId"

# ──────────────────────────────────────────────────────────────────────────────
# 2. View: Dealer Submissions - All
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== View 2: Dealer Submissions - All ===" -ForegroundColor Cyan
$fetchAll = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_vehicleregistration">
    <attribute name="dmv_registrationid" />
    <attribute name="dmv_dealeracctid" />
    <attribute name="dmv_vehicleid" />
    <attribute name="dmv_regcontactid" />
    <attribute name="dmv_regstatus" />
    <attribute name="dmv_submitteddate" />
    <attribute name="dmv_totaldue" />
    <attribute name="dmv_rejectionreason" />
    <attribute name="dmv_vehicleregistrationid" />
    <order attribute="dmv_submitteddate" descending="true" />
    <filter type="and">
      <condition attribute="dmv_submissionchannel" operator="eq" value="100000000" />
    </filter>
  </entity>
</fetch>
'@
$layoutAll = @'
<grid name="resultset" object="11395" jump="dmv_registrationid" select="1" icon="1" preview="1">
  <row name="result" id="dmv_vehicleregistrationid">
    <cell name="dmv_registrationid" width="140" />
    <cell name="dmv_dealeracctid" width="160" />
    <cell name="dmv_vehicleid" width="180" />
    <cell name="dmv_regcontactid" width="150" />
    <cell name="dmv_regstatus" width="120" />
    <cell name="dmv_submitteddate" width="130" />
    <cell name="dmv_rejectionreason" width="140" />
    <cell name="dmv_totaldue" width="100" />
  </row>
</grid>
'@
$allId = Upsert-SavedQuery -Name "Dealer Submissions - All" -FetchXml $fetchAll -LayoutXml $layoutAll
Write-Host "  ID: $allId"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Patch main form to add "Dealer Review" tab
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Patch main form ===" -ForegroundColor Cyan
$f = Invoke-RestMethod -Headers $hRead `
  -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq 'dmv_vehicleregistration' and type eq 2&`$select=formid,name,formxml"
$form   = $f.value[0]
$formId = $form.formid
$xml    = $form.formxml
Write-Host "  Main form id: $formId"
Write-Host "  Form xml length before: $($xml.Length)"

# Remove any previous DEALER_TAB so re-runs are idempotent
$xml = [regex]::Replace($xml, '<tab name="DEALER_TAB".+?</tab>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$dealerTab = @'
<tab name="DEALER_TAB" id="{a3000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true"><labels><label description="Dealer Review" languagecode="1033" /></labels><columns><column width="50%"><sections><section name="CHANNEL_SEC" showlabel="true" showbar="false" id="{b3000001-0001-0001-0001-000000000001}" columns="1" labelwidth="140" celllabelposition="Left"><labels><label description="Submission" languagecode="1033" /></labels><rows><row><cell id="{c3030001-0001-0001-0001-000000000001}" showlabel="true"><labels><label description="Submission Channel" languagecode="1033" /></labels><control id="dmv_submissionchannel" classid="{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}" datafieldname="dmv_submissionchannel" disabled="false" /></cell></row><row><cell id="{c3030001-0001-0001-0001-000000000002}" showlabel="true"><labels><label description="Submitted Date" languagecode="1033" /></labels><control id="dmv_submitteddate" classid="{5B773807-9FB2-42DB-97C3-7A91EFF8ADFF}" datafieldname="dmv_submitteddate" disabled="false" /></cell></row><row><cell id="{c3030001-0001-0001-0001-000000000003}" showlabel="true"><labels><label description="Insurance Verified" languagecode="1033" /></labels><control id="dmv_insuranceverified" classid="{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}" datafieldname="dmv_insuranceverified" disabled="false" /></cell></row></rows></section></sections></column><column width="50%"><sections><section name="REJECT_SEC" showlabel="true" showbar="false" id="{b3000001-0001-0001-0001-000000000002}" columns="1" labelwidth="140" celllabelposition="Left"><labels><label description="Rejection (if any)" languagecode="1033" /></labels><rows><row><cell id="{c3030001-0001-0001-0001-000000000004}" showlabel="true"><labels><label description="Rejection Reason" languagecode="1033" /></labels><control id="dmv_rejectionreason" classid="{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}" datafieldname="dmv_rejectionreason" disabled="false" /></cell></row><row><cell id="{c3030001-0001-0001-0001-000000000005}" showlabel="true" rowspan="4"><labels><label description="Rejection Notes" languagecode="1033" /></labels><control id="dmv_rejectionnotes" classid="{E0DECE4B-6FC8-4a8f-A065-082708572369}" datafieldname="dmv_rejectionnotes" disabled="false" /></cell></row></rows></section></sections></column></columns></tab>
'@

# Inject before TERMS_TAB
$xml = $xml -replace '<tab name="TERMS_TAB"', ($dealerTab + '<tab name="TERMS_TAB"')
Write-Host "  Form xml length after:  $($xml.Length)"

$body = @{ formxml = $xml } | ConvertTo-Json -Depth 5
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Body $bodyBytes -UseBasicParsing | Out-Null
Write-Host "  Form patched." -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────
# 4. Publish
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Publish ===" -ForegroundColor Cyan
$publish = @{ ParameterXml = "<importexportxml><entities><entity>dmv_vehicleregistration</entity></entities></importexportxml>" } | ConvertTo-Json
Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Body $publish -UseBasicParsing | Out-Null
Write-Host "  Published." -ForegroundColor Green

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Views: 'Dealer Submissions - Pending Review' and 'Dealer Submissions - All'"
Write-Host "Form: Dealer Review tab added to dmv_vehicleregistration main form"
Write-Host "Open CSW workspace → DMV Operations → Vehicle Services → Registrations"
Write-Host "Switch view to 'Dealer Submissions - Pending Review' to triage."
