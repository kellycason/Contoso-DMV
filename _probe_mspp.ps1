$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }

$ids = @(
  "dbf99b41-be39-f111-88b3-001dd801f94a",
  "3c43f726-9839-f111-88b3-001dd801f94a",
  "a2f99b41-be39-f111-88b3-001dd801f94a",
  "4fdf2438-563f-f111-88b3-001dd801f94a",
  "367ff928-9839-f111-88b4-001dd80340cd",
  "8d7ff928-9839-f111-88b4-001dd80340cd",
  "83db2143-be39-f111-88b4-001dd80a6132"
)
foreach ($id in $ids) {
  Write-Host "`n=== $id ===" -ForegroundColor Cyan
  try {
    $r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($id)"
    $r | ConvertTo-Json -Depth 3 | Write-Host
  } catch { Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red }
}
