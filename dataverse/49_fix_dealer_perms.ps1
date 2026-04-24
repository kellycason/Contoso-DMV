###############################################################################
# _fix_dealer_perms.ps1
# Addresses 403 "associate account to dmv_vehicleregistration" by:
#  1. Broadening account perm to full R/W/C/A/AT (was missing append)
#  2. Patching mspp_entitypermission directly (not just powerpagecomponent mirror)
#  3. Ensuring both perms have the web role in content
#  4. PublishAllXml
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl    = "https://orga381269e.crm9.dynamics.com"
$token     = az account get-access-token --resource $envUrl --query accessToken -o tsv
$webRole   = "c7500f9c-350c-471b-a6da-e16f0f18009c"
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"

$h = @{
  Authorization      = "Bearer $token"
  "Content-Type"     = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version"    = "4.0"
}

function Patch-Mspp($permId, $entity, $name, $r, $c, $w, $d, $a, $at) {
  Write-Host "  Patching mspp_entitypermission directly..."
  $body = @{
    mspp_entitylogicalname = $entity
    mspp_entityname        = $name
    mspp_scope             = 756150000
    mspp_read              = [bool]$r
    mspp_create            = [bool]$c
    mspp_write             = [bool]$w
    mspp_delete            = [bool]$d
    mspp_append            = [bool]$a
    mspp_appendto          = [bool]$at
  } | ConvertTo-Json -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  try {
    Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($permId)" -Method Patch -Body $bytes -UseBasicParsing | Out-Null
    Write-Host "    mspp patched" -ForegroundColor Green
  } catch { Write-Host "    mspp WARN: $($_.Exception.Message)" -ForegroundColor Yellow }
}

function Patch-Component($compId, $entity, $name, $r, $c, $w, $d, $a, $at) {
  Write-Host "  Patching powerpagecomponent mirror..."
  $contentObj = [ordered]@{
    entitylogicalname              = $entity
    entityname                     = $name
    scope                          = 756150000
    read                           = [bool]$r
    create                         = [bool]$c
    write                          = [bool]$w
    delete                         = [bool]$d
    append                         = [bool]$a
    appendto                       = [bool]$at
    accountrelationship            = $null
    contactrelationship            = $null
    parentrelationship             = $null
    parententitypermission         = $null
    permissionfetchxml             = $null
    childTablePermissions          = @()
    "adx_entitypermission_webrole" = @($webRole)
  }
  $body = @{ content = ($contentObj | ConvertTo-Json -Depth 6 -Compress) } | ConvertTo-Json -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  try {
    Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents($compId)" -Method Patch -Body $bytes -UseBasicParsing | Out-Null
    Write-Host "    component patched" -ForegroundColor Green
  } catch { Write-Host "    component WARN: $($_.Exception.Message)" -ForegroundColor Yellow }
}

# Perm IDs + target flags. Full R/C/W/A/AT everywhere to eliminate variables.
$targets = @(
  @{ id="dbf99b41-be39-f111-88b3-001dd801f94a"; entity="dmv_vehicleregistration"; name="DMV - Registration Submit"; r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
  @{ id="3c43f726-9839-f111-88b3-001dd801f94a"; entity="dmv_vehicle";             name="DMV - Vehicle (Full)";      r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
  @{ id="a2f99b41-be39-f111-88b3-001dd801f94a"; entity="dmv_temporarytag";        name="DMV - Temp Tag Submit";     r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
  @{ id="4fdf2438-563f-f111-88b3-001dd801f94a"; entity="account";                 name="DMV - Account (Full AT)";   r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
  @{ id="367ff928-9839-f111-88b4-001dd80340cd"; entity="contact";                 name="DMV - Contact (Full)";      r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
  @{ id="8d7ff928-9839-f111-88b4-001dd80340cd"; entity="dmv_vehicleregistration"; name="DMV - Registration Read";   r=$true; c=$true; w=$true; d=$false; a=$true; at=$true }
)

foreach ($t in $targets) {
  Write-Host "`n=== $($t.entity) ($($t.id)) ===" -ForegroundColor Cyan
  Patch-Mspp      -permId $t.id -entity $t.entity -name $t.name -r $t.r -c $t.c -w $t.w -d $t.d -a $t.a -at $t.at
  Patch-Component -compId $t.id -entity $t.entity -name $t.name -r $t.r -c $t.c -w $t.w -d $t.d -a $t.a -at $t.at
}

# Delete the orphaned mspp_entitypermission record (83db...) that has all-null values
Write-Host "`n=== Cleanup orphan ===" -ForegroundColor Cyan
try {
  Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions(83db2143-be39-f111-88b4-001dd80a6132)" -Method Delete -UseBasicParsing | Out-Null
  Write-Host "  Deleted orphan." -ForegroundColor Green
} catch { Write-Host "  Delete WARN: $($_.Exception.Message)" -ForegroundColor Yellow }

Write-Host "`n=== PublishAllXml ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $h -Method Post | Out-Null
  Write-Host "Published." -ForegroundColor Green
} catch { Write-Host "Publish WARN: $($_.Exception.Message)" -ForegroundColor Yellow }

Write-Host "`n=== Verify ===" -ForegroundColor Cyan
foreach ($t in $targets) {
  try {
    $r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($($t.id))?`$select=mspp_entitylogicalname,mspp_read,mspp_create,mspp_write,mspp_append,mspp_appendto"
    Write-Host ("  {0,-26} R={1} C={2} W={3} A={4} AT={5}" -f $r.mspp_entitylogicalname, $r.mspp_read, $r.mspp_create, $r.mspp_write, $r.mspp_append, $r.mspp_appendto)
  } catch { Write-Host "  $($t.id): FAIL" -ForegroundColor Red }
}
Write-Host "`nDONE. Hard-refresh portal and retry dealer submit." -ForegroundColor Green
