# demo_mode.ps1
# Resets the environment to a clean baseline for end-to-end demo.
#
# Clears everything created by Sam Smith / Contoso Motors (dealer) and the
# 5 bulk demo customers, then re-runs Maria's "near expiration" setup.
#
# Preserves:
#   * Sam Smith contact + Contoso Motors account
#   * 5 bulk demo customer contacts (Alice Nguyen, Brian Patel, Carmen Ortiz,
#     Derek Johnson, Eliana Rivera)
#   * Maria Jennings + her Tesla vehicle registration record
#
# Run: .\dataverse\demo_mode.ps1

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization   = "Bearer $token"
  "Content-Type"  = "application/json; charset=utf-8"
  "OData-Version" = "4.0"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# --- IDs (from session context) ---
$samId      = "13d0cc9c-523f-f111-88b4-001dd80340cd"  # Sam Smith contact
$dealerId   = "850e5195-523f-f111-88b3-001dd801f94a"  # Contoso Motors account
$bulkContacts = @(
  "46913312-f53f-f111-88b4-001dd80340cd",  # Alice
  "6e913312-f53f-f111-88b4-001dd80340cd",  # Brian
  "8b913312-f53f-f111-88b4-001dd80340cd",  # Carmen
  "a0913312-f53f-f111-88b4-001dd80340cd",  # Derek
  "b1913312-f53f-f111-88b4-001dd80340cd"   # Eliana
)
$contactsToClean = @($samId) + $bulkContacts

Write-Host "=== Contoso DMV — Demo Mode Reset ===" -ForegroundColor Cyan
Write-Host ""

function Invoke-Delete($url, $label) {
  try {
    Invoke-WebRequest -Uri $url -Method Delete -Headers $h -UseBasicParsing | Out-Null
    Write-Host "  Deleted $label" -ForegroundColor DarkGray
  } catch {
    Write-Host "  ERROR deleting $label : $($_.Exception.Message)" -ForegroundColor Red
  }
}

# 1. Collect ALL registrations linked to these contacts or Contoso Motors
Write-Host "[1/6] Collecting registrations..."
$regFilters = @()
$regFilters += "_dmv_dealeracctid_value eq $dealerId"
foreach ($c in $contactsToClean) { $regFilters += "_dmv_regcontactid_value eq $c" }
$regFilter = "(" + ($regFilters -join " or ") + ")"
$regs = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations?`$filter=$regFilter&`$select=dmv_vehicleregistrationid,dmv_registrationid,_dmv_vehicleid_value&`$top=1000" -Headers $readH).value
Write-Host "  Found $($regs.Count) registrations"

# Track vehicle IDs referenced by these registrations
$vehicleIds = @{}
foreach ($r in $regs) { if ($r._dmv_vehicleid_value) { $vehicleIds[$r._dmv_vehicleid_value] = $true } }

# 2. Delete renewals + their payments
Write-Host "[2/6] Deleting registration renewals (+ payments)..."
foreach ($r in $regs) {
  $rid = $r.dmv_vehicleregistrationid
  $renewals = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=_dmv_registrationid_value eq $rid&`$select=dmv_registrationrenewalid" -Headers $readH).value
  foreach ($rn in $renewals) {
    $pays = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments?`$filter=_dmv_renewalid_value eq $($rn.dmv_registrationrenewalid)&`$select=dmv_registrationpaymentid" -Headers $readH).value
    foreach ($p in $pays) { Invoke-Delete "$envUrl/api/data/v9.2/dmv_registrationpayments($($p.dmv_registrationpaymentid))" "payment" }
    Invoke-Delete "$envUrl/api/data/v9.2/dmv_registrationrenewals($($rn.dmv_registrationrenewalid))" "renewal"
  }
}

# 3. Delete registration terms + their payments
Write-Host "[3/6] Deleting registration terms (+ payments)..."
foreach ($r in $regs) {
  $rid = $r.dmv_vehicleregistrationid
  $terms = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms?`$filter=_dmv_vehicleregistrationid_value eq $rid&`$select=dmv_registrationtermid" -Headers $readH).value
  foreach ($tm in $terms) {
    $pays = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments?`$filter=_dmv_registrationtermid_value eq $($tm.dmv_registrationtermid)&`$select=dmv_registrationpaymentid" -Headers $readH).value
    foreach ($p in $pays) { Invoke-Delete "$envUrl/api/data/v9.2/dmv_registrationpayments($($p.dmv_registrationpaymentid))" "term payment" }
    # Null the currenttermid before delete
    $clear = @{ "dmv_currenttermid@odata.bind" = $null } | ConvertTo-Json
    try { Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($rid)/dmv_currenttermid/`$ref" -Method Delete -Headers $h -UseBasicParsing | Out-Null } catch {}
    Invoke-Delete "$envUrl/api/data/v9.2/dmv_registrationterms($($tm.dmv_registrationtermid))" "term"
  }
}

# 4. Delete temp tags linked to these vehicles OR dealer
Write-Host "[4/6] Deleting temporary tags..."
$tagFilters = @("_dmv_dealeracctid_value eq $dealerId")
foreach ($c in $contactsToClean) { $tagFilters += "_dmv_generatedby_value eq $c" }
foreach ($v in $vehicleIds.Keys) { $tagFilters += "_dmv_vehicleid_value eq $v" }
$tagFilter = "(" + ($tagFilters -join " or ") + ")"
$tags = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_temporarytags?`$filter=$tagFilter&`$select=dmv_temporarytagid,dmv_tagnumber&`$top=1000" -Headers $readH).value
Write-Host "  Found $($tags.Count) temp tags"
foreach ($t in $tags) { Invoke-Delete "$envUrl/api/data/v9.2/dmv_temporarytags($($t.dmv_temporarytagid))" "tag $($t.dmv_tagnumber)" }

# 5. Delete registrations, then vehicles
Write-Host "[5/6] Deleting registrations + vehicles..."
foreach ($r in $regs) {
  Invoke-Delete "$envUrl/api/data/v9.2/dmv_vehicleregistrations($($r.dmv_vehicleregistrationid))" "reg $($r.dmv_registrationid)"
}

# Also catch any vehicles owned by these contacts that had no registration
$vehFilters = @()
foreach ($c in $contactsToClean) { $vehFilters += "_dmv_ownercontactid_value eq $c" }
$vehFilters += "_dmv_owneraccountid_value eq $dealerId"
$vehFilter = "(" + ($vehFilters -join " or ") + ")"
$orphanVeh = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicles?`$filter=$vehFilter&`$select=dmv_vehicleid,dmv_vin&`$top=1000" -Headers $readH).value
foreach ($v in $orphanVeh) { $vehicleIds[$v.dmv_vehicleid] = $true }

foreach ($vid in $vehicleIds.Keys) {
  Invoke-Delete "$envUrl/api/data/v9.2/dmv_vehicles($vid)" "vehicle"
}

# 6. Delete bulk submission summary records
Write-Host "[6/6] Deleting bulk submission summaries..."
try {
  $bulks = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_bulksubmissions?`$filter=_dmv_dealeracctid_value eq $dealerId&`$select=dmv_bulksubmissionid&`$top=1000" -Headers $readH).value
  Write-Host "  Found $($bulks.Count) bulk submissions"
  foreach ($b in $bulks) { Invoke-Delete "$envUrl/api/data/v9.2/dmv_bulksubmissions($($b.dmv_bulksubmissionid))" "bulk submission" }
} catch {
  Write-Host "  (skipped — dmv_bulksubmissions entity not present or no dealer lookup)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Resetting Maria's Tesla near-expiration state ===" -ForegroundColor Cyan
& "$PSScriptRoot\demo_reset_maria_tesla.ps1"

Write-Host ""
Write-Host "=== Reseeding appointment calendar demo data ===" -ForegroundColor Cyan
& "$PSScriptRoot\72_seed_appointment_demo_data.ps1"

Write-Host ""
Write-Host "=== DEMO MODE READY ===" -ForegroundColor Green
Write-Host "  Sam Smith: clean slate (no vehicles/regs/tags)"
Write-Host "  Contoso Motors: clean slate (no dealer submissions)"
Write-Host "  Bulk demo customers: clean slate (ready for CSV re-upload)"
Write-Host "  Maria Jennings Tesla: nearing expiration (ready for renewal demo)"
