$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18 and _powerpagesiteid_value eq $websiteId&`$select=name,content,powerpagecomponentid"
foreach ($c in $r.value) {
  try {
    $o = $c.content | ConvertFrom-Json
    $el = $o.entitylogicalname; if (-not $el) { $el = $o.EntityLogicalName }
    if ($el -in @("dmv_vehicleregistration","dmv_vehicle","dmv_temporarytag","account","contact")) {
      Write-Host "--- $el ($($c.name)) id=$($c.powerpagecomponentid) ---"
      Write-Host "  R=$($o.read) C=$($o.create) W=$($o.write) A=$($o.append) AT=$($o.appendto) D=$($o.delete)"
      Write-Host "  scope=$($o.scope) webroles=$($o.adx_entitypermission_webrole -join ',')"
    }
  } catch {}
}
