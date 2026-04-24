$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0" }

# What web roles are attached to the Contact permission?
$permId = "367ff928-9839-f111-88b4-001dd80340cd"
Write-Host "=== Contact permission record ===" -ForegroundColor Cyan
$p = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($permId)?`$select=mspp_name,mspp_entitylogicalname,mspp_scope,mspp_read,mspp_create,mspp_write,mspp_append,mspp_appendto"
$p | Format-List

Write-Host "=== Web roles linked (via powerpagecomponent content) ===" -ForegroundColor Cyan
$comp = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents($permId)?`$select=content"
$c = $comp.content | ConvertFrom-Json
$c | Format-List

Write-Host "=== All web roles ===" -ForegroundColor Cyan
$roles = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_webroles?`$select=mspp_webroleid,mspp_name"
$roles.value | Format-Table -AutoSize

Write-Host "=== All entity permissions (summary) ===" -ForegroundColor Cyan
$all = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions?`$select=mspp_entitypermissionid,mspp_name,mspp_entitylogicalname,mspp_scope,mspp_read,mspp_create,mspp_write,mspp_append,mspp_appendto"
$all.value | Format-Table mspp_name,mspp_entitylogicalname,mspp_scope,mspp_read,mspp_create,mspp_write,mspp_append,mspp_appendto -AutoSize
