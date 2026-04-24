$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }

Write-Host "=== mspp_entitypermission N:N relationships ==="
$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='mspp_entitypermission')/ManyToManyRelationships?`$select=SchemaName,Entity1LogicalName,Entity2LogicalName,Entity1NavigationPropertyName,Entity2NavigationPropertyName,IntersectEntityName"
$r.value | ForEach-Object {
  Write-Host ("  Schema={0}" -f $_.SchemaName)
  Write-Host ("    {0} -> {1}  (nav1={2})" -f $_.Entity1LogicalName, $_.Entity2LogicalName, $_.Entity1NavigationPropertyName)
  Write-Host ("    nav2={0}  intersect={1}" -f $_.Entity2NavigationPropertyName, $_.IntersectEntityName)
}

Write-Host "`n=== mspp_webrole N:N relationships ==="
$r2 = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='mspp_webrole')/ManyToManyRelationships?`$select=SchemaName,Entity1LogicalName,Entity2LogicalName,Entity1NavigationPropertyName,Entity2NavigationPropertyName,IntersectEntityName"
$r2.value | ForEach-Object {
  Write-Host ("  Schema={0}" -f $_.SchemaName)
  Write-Host ("    {0} -> {1}  (nav1={2})" -f $_.Entity1LogicalName, $_.Entity2LogicalName, $_.Entity1NavigationPropertyName)
  Write-Host ("    nav2={0}  intersect={1}" -f $_.Entity2NavigationPropertyName, $_.IntersectEntityName)
}
