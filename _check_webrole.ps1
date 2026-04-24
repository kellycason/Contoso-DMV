$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }
$webRole = "c7500f9c-350c-471b-a6da-e16f0f18009c"

# List all mspp_entitypermissions linked to the authenticated users web role
Write-Host "=== Perms linked to Auth Users web role ===" -ForegroundColor Cyan
$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_webroles($webRole)?`$expand=mspp_entitypermission_webrole"
foreach ($p in $r.mspp_entitypermission_webrole) {
  Write-Host ("  {0,-26} {1}" -f $p.mspp_entityname, $p.mspp_entitypermissionid)
}
Write-Host "Total: $($r.mspp_entitypermission_webrole.Count)"
