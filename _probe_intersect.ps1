$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }
$webRole = "c7500f9c-350c-471b-a6da-e16f0f18009c"

# Different entity set names to try
$candidates = @(
  "mspp_entitypermission_webroleset",
  "mspp_entitypermission_webroles",
  "mspp_entitypermission_webrole"
)
foreach ($ep in $candidates) {
  Write-Host "--- $ep ---"
  try {
    $r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/$ep?`$top=5"
    Write-Host "  rows: $($r.value.Count)"
    $r.value | Select-Object -First 2 | ConvertTo-Json -Compress | Write-Host
  } catch { Write-Host "  FAIL: $($_.Exception.Message)" }
}

Write-Host "`n--- RetrieveAssociated via webrole ---"
try {
  $wr = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_webroles($webRole)/mspp_entitypermission_webrole?`$select=mspp_entitypermissionid"
  Write-Host "  count: $($wr.value.Count)"
  $wr.value | Select -First 5 | ForEach-Object { Write-Host "    $($_.mspp_entitypermissionid)" }
} catch { Write-Host "  FAIL: $($_.Exception.Message)" }

Write-Host "`n--- RetrieveAssociated via entity perm (first id) ---"
try {
  $pid_ = "3c43f726-9839-f111-88b3-001dd801f94a"
  $ep2 = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($pid_)/mspp_entitypermission_webrole?`$select=mspp_webroleid"
  Write-Host "  count: $($ep2.value.Count)"
  $ep2.value | ForEach-Object { Write-Host "    $($_.mspp_webroleid)" }
} catch { Write-Host "  FAIL: $($_.Exception.Message)" }
