# Reset Maria's Tesla Model S to a near-expiration state for demo.
# - Vehicle reg: expires 2026-05-21 (30 days from today), effective 2025-05-21, regyear 2026, Active
# - Creates one fresh Active term matching those dates; expires all prior terms
# - Updates currenttermid to the new active term

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

$vrId = "b3d6565a-1d39-f111-88b3-001dd801f94a"  # Maria's Tesla vehicle registration
$effective  = "2025-05-21"
$expiration = "2026-05-21"
$regyear    = 2026

# 1. Create a fresh Active term aligned with new expiration
$termNum = "TERM-2025-" + ('{0:D5}' -f (Get-Random -Maximum 99999))
$termBody = @{
  dmv_termnumber  = $termNum
  dmv_startdate   = $effective
  dmv_issuedate   = $effective
  dmv_enddate     = $expiration
  dmv_termstatus  = 100000000  # Active
  dmv_termtype    = 100000000  # New / Original
  "dmv_vehicleregistrationid@odata.bind" = "/dmv_vehicleregistrations($vrId)"
} | ConvertTo-Json
$termCreateH = $h.Clone(); $termCreateH["Prefer"] = "return=representation"
$newTerm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms" -Method Post -Headers $termCreateH -Body ([Text.Encoding]::UTF8.GetBytes($termBody))
$newTermId = $newTerm.dmv_registrationtermid
Write-Host "Created new Active term: $termNum ($newTermId)"

# 2. Expire all other terms for this vehicle reg
$others = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms?`$filter=_dmv_vehicleregistrationid_value eq $vrId and dmv_registrationtermid ne $newTermId and dmv_termstatus ne 100000002&`$select=dmv_registrationtermid,dmv_termnumber,dmv_termstatus" -Headers $readH).value
foreach ($o in $others) {
  $expireBody = @{ dmv_termstatus = 100000002 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationterms($($o.dmv_registrationtermid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($expireBody)) -UseBasicParsing | Out-Null
  Write-Host "  Expired $($o.dmv_termnumber)"
}

# 3. Update vehicle registration: dates, regyear, status=Active, currenttermid=new term
$vrBody = @{
  dmv_effectivedate  = $effective
  dmv_expirationdate = $expiration
  dmv_regyear        = $regyear
  dmv_regstatus      = 100000000
  "dmv_currenttermid@odata.bind" = "/dmv_registrationterms($newTermId)"
} | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($vrId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($vrBody)) -UseBasicParsing | Out-Null
Write-Host "Updated vehicle reg: effective=$effective, expires=$expiration, regyear=$regyear, currenttermid=$newTermId"

Write-Host ""
Write-Host "=== Verification ==="
(Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($vrId)?`$select=dmv_registrationid,dmv_regstatus,dmv_regyear,dmv_effectivedate,dmv_expirationdate,_dmv_currenttermid_value" -Headers $readH) | Format-List
Write-Host "=== Terms ==="
(Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms?`$filter=_dmv_vehicleregistrationid_value eq $vrId&`$select=dmv_termnumber,dmv_termstatus,dmv_termtype,dmv_startdate,dmv_enddate&`$orderby=createdon desc" -Headers $readH).value | Format-Table dmv_termnumber,dmv_termstatus,dmv_termtype,dmv_startdate,dmv_enddate -AutoSize
