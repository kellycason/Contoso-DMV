$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization="Bearer $token"; "OData-Version"="4.0"; "OData-MaxVersion"="4.0"
  "Content-Type"="application/json"
}
$webRole = "c7500f9c-350c-471b-a6da-e16f0f18009c"

# Permission IDs (same GUID as powerpagecomponent mirror)
$permIds = @(
  "dbf99b41-be39-f111-88b3-001dd801f94a", # dmv_vehicleregistration (unnamed)
  "3c43f726-9839-f111-88b3-001dd801f94a", # dmv_vehicle "DMV - Vehicle Read"
  "a2f99b41-be39-f111-88b3-001dd801f94a", # dmv_temporarytag
  "4fdf2438-563f-f111-88b3-001dd801f94a", # account
  "367ff928-9839-f111-88b4-001dd80340cd", # contact
  "8d7ff928-9839-f111-88b4-001dd80340cd", # dmv_vehicleregistration (Registration Read)
  "83db2143-be39-f111-88b4-001dd80a6132"  # dmv_vehicle
)

foreach ($pid_ in $permIds) {
  Write-Host "`n--- $pid_ ---"
  # Check it exists
  try {
    $p = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($pid_)?`$select=mspp_entityname,mspp_entitypermissionid"
    Write-Host "  entity: $($p.mspp_entityname)"
  } catch {
    Write-Host "  NOT FOUND in mspp_entitypermissions: $($_.Exception.Message)" -ForegroundColor Yellow
    continue
  }

  # Try N:N associate
  $body = @{ "@odata.id" = "$envUrl/api/data/v9.2/mspp_webroles($webRole)" } | ConvertTo-Json
  try {
    Invoke-WebRequest -Headers $h -Method Post `
      -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($pid_)/mspp_entitypermission_webrole/`$ref" `
      -Body $body -UseBasicParsing | Out-Null
    Write-Host "  Associated OK" -ForegroundColor Green
  } catch {
    $m = $_.Exception.Message
    if ($m -match "duplicate|already") { Write-Host "  Already associated" -ForegroundColor DarkGray }
    else { Write-Host "  FAIL: $m" -ForegroundColor Red }
  }
}

Write-Host "`n=== Verify ===" -ForegroundColor Cyan
$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_webroles($webRole)?`$expand=mspp_entitypermission_webrole"
foreach ($p in $r.mspp_entitypermission_webrole) {
  Write-Host ("  {0,-28} {1}" -f $p.mspp_entityname, $p.mspp_entitypermissionid)
}
Write-Host "Total: $($r.mspp_entitypermission_webrole.Count)"
