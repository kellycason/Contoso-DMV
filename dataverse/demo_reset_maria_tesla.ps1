# demo_reset_maria_tesla.ps1
# Resets Maria Jennings' 2024 Tesla Model S to a clean "nearing expiration"
# state so the Vehicle Registration Renewal demo can be run end-to-end.
#
# Effect:
#   * Vehicle reg REG-2025-00891: effective 2025-05-21, expires 2026-05-21,
#     regyear 2026, status Active, currenttermid → fresh Active term.
#   * Fresh Active / New term TERM-2025-xxxxx created (5/21/2025 → 5/21/2026).
#   * ALL other terms on that vehicle reg marked Expired (100000002).
#   * ALL registration renewals for Maria's Tesla vehicle reg are DELETED
#     (pending, approved, rejected — everything). Payments linked to those
#     renewals are cascaded first.
#
# Run this any time before a fresh demo: `.\demo_reset_maria_tesla.ps1`

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization    = "Bearer $token"
  "Content-Type"   = "application/json; charset=utf-8"
  "OData-Version"  = "4.0"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# Constants — Maria's Tesla Model S
$vrId       = "b3d6565a-1d39-f111-88b3-001dd801f94a"  # dmv_vehicleregistrationid (REG-2025-00891)
$mariaId    = "d2c23913-f238-f111-88b3-001dd801f94a"  # contactid
$effective  = "2025-05-21"
$expiration = "2026-05-21"
$regyear    = 2026

Write-Host "=== Contoso DMV — Maria Tesla demo reset ==="
Write-Host ""

# 1. Delete any Registration Renewal records pointing at this vehicle reg,
#    along with payments that reference them.
$renewals = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=_dmv_registrationid_value eq $vrId or _dmv_contactid_value eq $mariaId&`$select=dmv_registrationrenewalid,dmv_renewalid" -Headers $readH).value
Write-Host "Renewals to delete: $($renewals.Count)"
foreach ($r in $renewals) {
  $linkedPays = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments?`$filter=_dmv_renewalid_value eq $($r.dmv_registrationrenewalid)&`$select=dmv_registrationpaymentid,dmv_paymentref" -Headers $readH).value
  foreach ($p in $linkedPays) {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationpayments($($p.dmv_registrationpaymentid))" -Method Delete -Headers $h -UseBasicParsing | Out-Null
    Write-Host "  Deleted payment $($p.dmv_paymentref)"
  }
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($r.dmv_registrationrenewalid))" -Method Delete -Headers $h -UseBasicParsing | Out-Null
  Write-Host "  Deleted renewal $($r.dmv_renewalid)"
}

# 2. Create a fresh Active / New term (starts $effective, ends $expiration).
$termNum = "TERM-2025-" + ('{0:D5}' -f (Get-Random -Maximum 99999))
$termBody = @{
  dmv_termnumber = $termNum
  dmv_startdate  = $effective
  dmv_issuedate  = $effective
  dmv_enddate    = $expiration
  dmv_termstatus = 100000000   # Active
  dmv_termtype   = 100000000   # New / Original
  "dmv_vehicleregistrationid@odata.bind" = "/dmv_vehicleregistrations($vrId)"
} | ConvertTo-Json
$createH = $h.Clone(); $createH["Prefer"] = "return=representation"
$newTerm   = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms" -Method Post -Headers $createH -Body ([Text.Encoding]::UTF8.GetBytes($termBody))
$newTermId = $newTerm.dmv_registrationtermid
Write-Host "Created new Active term: $termNum ($newTermId)"

# 3. Expire every other term on this vehicle reg.
$others = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms?`$filter=_dmv_vehicleregistrationid_value eq $vrId and dmv_registrationtermid ne $newTermId and dmv_termstatus ne 100000002&`$select=dmv_registrationtermid,dmv_termnumber" -Headers $readH).value
foreach ($o in $others) {
  $body = @{ dmv_termstatus = 100000002 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationterms($($o.dmv_registrationtermid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "  Expired $($o.dmv_termnumber)"
}

# 4. Point vehicle reg at the new term, set dates/status/regyear.
$vrBody = @{
  dmv_effectivedate  = $effective
  dmv_expirationdate = $expiration
  dmv_regyear        = $regyear
  dmv_regstatus      = 100000000
  "dmv_currenttermid@odata.bind" = "/dmv_registrationterms($newTermId)"
} | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($vrId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($vrBody)) -UseBasicParsing | Out-Null
Write-Host "Updated vehicle reg: effective=$effective expires=$expiration regyear=$regyear"

Write-Host ""
Write-Host "=== Verification ==="
(Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($vrId)?`$select=dmv_registrationid,dmv_regstatus,dmv_regyear,dmv_effectivedate,dmv_expirationdate,_dmv_currenttermid_value" -Headers $readH) | Format-List
Write-Host "Renewal count for this vehicle reg: $((Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=_dmv_registrationid_value eq $vrId&`$select=dmv_renewalid" -Headers $readH).value.Count) (should be 0)"
Write-Host ""
Write-Host "Demo ready. Log in as Maria → Vehicle Registration → renew her Tesla."
