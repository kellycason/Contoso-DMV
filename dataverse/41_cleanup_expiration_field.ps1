<#
  41_cleanup_expiration_field.ps1
  - Flow: switch Update_registration_renewal to set dmv_newexpirationdate
    (the semantically correct field) instead of dmv_temptagexpirationdate
  - Email: remove the duplicate/stale "New Reg. Expiration" row; keep a
    single "New Registration Expires" row bound to dmv_newexpirationdate
  - Backfill REGRN-2026-5105 so dmv_newexpirationdate matches
#>
$ErrorActionPreference = "Stop"

$envUrl = "https://orga381269e.crm9.dynamics.com"
$flowId = "9f8e7d6c-5b4a-4321-9876-abcdef012345"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# 1. Patch flow
$wf = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode" -Headers $readH
$cd = $wf.clientdata
$before = $cd.Length

# 1a. Update action: write to dmv_newexpirationdate instead of dmv_temptagexpirationdate
$cd = $cd.Replace(
  '"item/dmv_temptagexpirationdate":"@outputs(''Compose_expiration'')"',
  '"item/dmv_newexpirationdate":"@outputs(''Compose_expiration'')"'
)

# 1b. Remove the duplicate "New Reg. Expiration" row (uses dmv_newexpirationdate)
#     We will keep the "New Registration Expires" row but rebind it to dmv_newexpirationdate.
$dupRow = "              <tr>\r\n                <td style=\""padding:5px 0;color:#5a7a65;font-size:13px;\"">New Reg. Expiration</td>\r\n                <td style=\""padding:5px 0;font-weight:600;\"">@{if(empty(outputs('Get_renewal_row')?['body/dmv_newexpirationdate']), 'N/A', formatDateTime(outputs('Get_renewal_row')?['body/dmv_newexpirationdate'], 'MMMM d, yyyy'))}</td>\r\n              </tr>\r\n"
if ($cd.Contains($dupRow)) {
  $cd = $cd.Replace($dupRow, "")
  Write-Host "Removed duplicate 'New Reg. Expiration' row"
} else {
  Write-Host "WARN: duplicate row not matched verbatim" -ForegroundColor Yellow
}

# 1c. Rebind the kept row from temptagexpirationdate -> newexpirationdate
$cd = $cd.Replace(
  "body/dmv_temptagexpirationdate",
  "body/dmv_newexpirationdate"
)

Write-Host "clientdata: $before -> $($cd.Length) bytes (delta $($cd.Length - $before))"

# Toggle off, patch, toggle back on
Write-Host "Turning flow off..." -ForegroundColor Yellow
$offBody = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($offBody)) -UseBasicParsing | Out-Null

$body = @{ clientdata = $cd } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
Write-Host "clientdata updated"

Write-Host "Turning flow back on..." -ForegroundColor Yellow
$onBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($onBody)) -UseBasicParsing | Out-Null

# 2. Backfill existing approved records: ensure dmv_newexpirationdate = approved + 2 years
Write-Host ""
Write-Host "=== Backfilling dmv_newexpirationdate on approved records ===" -ForegroundColor Cyan
$recs = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_renewalstatus eq 100000002&`$select=dmv_registrationrenewalid,dmv_renewalid,dmv_approveddate,dmv_newexpirationdate" -Headers $readH
foreach ($r in $recs.value) {
  if (-not $r.dmv_approveddate) { continue }
  $want = ([datetime]$r.dmv_approveddate).AddYears(2).ToString("yyyy-MM-dd")
  $have = if ($r.dmv_newexpirationdate) { ([datetime]$r.dmv_newexpirationdate).ToString("yyyy-MM-dd") } else { "" }
  if ($want -ne $have) {
    $b = @{ dmv_newexpirationdate = $want } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($r.dmv_registrationrenewalid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($b)) -UseBasicParsing | Out-Null
    Write-Host "  $($r.dmv_renewalid): $have -> $want"
  } else {
    Write-Host "  $($r.dmv_renewalid): already $want"
  }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
