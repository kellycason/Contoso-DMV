# 46_update_views.ps1
# Refreshes MDA views to show more relevant columns/info:
#   * Active Registration Terms — adds vehicle reg plate + contact name via linked entities
#   * Active Registration Payments — adds the new Renewal lookup, contact via renewal; removes late fee (unused in demo)
#
# Runs against both duplicate savedqueryids for each view (org has two copies).

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization    = "Bearer $token"
  "Content-Type"   = "application/json; charset=utf-8"
  "OData-Version"  = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ───────────────────────────── Active Registration Terms ─────────────────────────────
$termFetch = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_registrationterm">
    <attribute name="dmv_termnumber" />
    <attribute name="dmv_termtype" />
    <attribute name="dmv_termstatus" />
    <attribute name="dmv_startdate" />
    <attribute name="dmv_enddate" />
    <attribute name="dmv_stickernumber" />
    <attribute name="dmv_vehicleregistrationid" />
    <attribute name="dmv_registrationtermid" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
    <order attribute="dmv_enddate" descending="false" />
    <link-entity name="dmv_vehicleregistration" from="dmv_vehicleregistrationid" to="dmv_vehicleregistrationid" link-type="outer" alias="vr">
      <attribute name="dmv_regcontactid" />
      <attribute name="dmv_vehicleid" />
      <attribute name="dmv_regstatus" />
    </link-entity>
  </entity>
</fetch>
'@

$termLayout = @'
<grid name="resultset" object="11408" jump="dmv_termnumber" select="1" icon="1" preview="1">
  <row name="result" id="dmv_registrationtermid">
    <cell name="dmv_termnumber" width="130" />
    <cell name="dmv_termstatus" width="90" />
    <cell name="dmv_termtype" width="100" />
    <cell name="dmv_startdate" width="110" />
    <cell name="dmv_enddate" width="110" />
    <cell name="dmv_vehicleregistrationid" width="150" />
    <cell name="vr.dmv_regcontactid" width="160" disableSorting="1" />
    <cell name="vr.dmv_vehicleid" width="160" disableSorting="1" />
    <cell name="vr.dmv_regstatus" width="110" disableSorting="1" />
    <cell name="dmv_stickernumber" width="110" />
  </row>
</grid>
'@

# ─────────────────────────── Active Registration Payments ───────────────────────────
$payFetch = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical">
  <entity name="dmv_registrationpayment">
    <attribute name="dmv_paymentref" />
    <attribute name="dmv_renewalid" />
    <attribute name="dmv_amount" />
    <attribute name="dmv_total" />
    <attribute name="dmv_paymentstatus" />
    <attribute name="dmv_paymentmethod" />
    <attribute name="dmv_paymentdate" />
    <attribute name="dmv_registrationtermid" />
    <attribute name="createdon" />
    <attribute name="dmv_registrationpaymentid" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
    <order attribute="createdon" descending="true" />
    <link-entity name="dmv_registrationrenewal" from="dmv_registrationrenewalid" to="dmv_renewalid" link-type="outer" alias="rn">
      <attribute name="dmv_renewalid" />
      <attribute name="dmv_contactid" />
      <attribute name="dmv_platenumber" />
      <attribute name="dmv_renewalstatus" />
    </link-entity>
  </entity>
</fetch>
'@

$payLayout = @'
<grid name="resultset" object="11409" jump="dmv_paymentref" select="1" icon="1" preview="1">
  <row name="result" id="dmv_registrationpaymentid">
    <cell name="dmv_paymentref" width="130" />
    <cell name="dmv_paymentstatus" width="90" />
    <cell name="dmv_amount" width="90" />
    <cell name="dmv_paymentmethod" width="100" />
    <cell name="dmv_renewalid" width="150" />
    <cell name="rn.dmv_platenumber" width="100" disableSorting="1" />
    <cell name="rn.dmv_renewalstatus" width="110" disableSorting="1" />
    <cell name="rn.dmv_contactid" width="160" disableSorting="1" />
    <cell name="dmv_paymentdate" width="110" />
    <cell name="createdon" width="130" />
  </row>
</grid>
'@

$updates = @(
  @{ id = '1ce8a6a3-d139-f111-88b3-001dd801f94a'; fetch = $termFetch; layout = $termLayout; label = 'Active Registration Terms #1' }
  @{ id = '2227a990-d139-f111-88b4-001dd80340cd'; fetch = $termFetch; layout = $termLayout; label = 'Active Registration Terms #2' }
  @{ id = 'd33b4d72-66ba-4902-b687-7abd8bdad9d0'; fetch = $termFetch; layout = $termLayout; label = 'Active Registration Terms #3' }
  @{ id = 'a916ae90-d139-f111-88b3-001dd801f94a'; fetch = $payFetch;  layout = $payLayout;  label = 'Active Registration Payments #1' }
  @{ id = '1b9aa4a9-d139-f111-88b3-001dd801f94a'; fetch = $payFetch;  layout = $payLayout;  label = 'Active Registration Payments #2' }
  @{ id = 'a46ddddf-d03e-4643-bbe8-d9703183b493'; fetch = $payFetch;  layout = $payLayout;  label = 'Active Registration Payments #3' }
)

foreach ($u in $updates) {
  Write-Host "Patching $($u.label)..."
  $body = @{
    fetchxml  = ($u.fetch  -replace "`r?`n\s*", "")
    layoutxml = ($u.layout -replace "`r?`n\s*", "")
  } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($($u.id))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
}

Write-Host "Publishing..."
$pubBody = @{ ParameterXml = "<importexportxml><entities><entity>dmv_registrationterm</entity><entity>dmv_registrationpayment</entity></entities></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null

Write-Host "Done."
