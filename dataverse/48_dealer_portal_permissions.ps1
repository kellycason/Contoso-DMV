###############################################################################
# 48_dealer_portal_permissions.ps1  (v2 — powerpagecomponent type=18 approach)
#
# Fixes: 403 "You don't have permission to associate or disassociate table
# account to dmv_vehicleregistration"
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
  Accept             = "application/json"
}
$hRead = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

function Patch-Perm($compId, $entity, $name, $read, $create, $write, $del, $append, $appendto) {
  $contentObj = [ordered]@{
    entitylogicalname              = $entity
    entityname                     = $name
    scope                          = 756150000  # Global (OptionSet integer — NOT string)
    read                           = [bool]$read
    create                         = [bool]$create
    write                          = [bool]$write
    delete                         = [bool]$del
    append                         = [bool]$append
    appendto                       = [bool]$appendto
    accountrelationship            = $null
    contactrelationship            = $null
    parentrelationship             = $null
    parententitypermission         = $null
    permissionfetchxml             = $null
    childTablePermissions          = @()
    "adx_entitypermission_webrole" = @($webRole)
  }
  $contentJson = $contentObj | ConvertTo-Json -Depth 6 -Compress
  $patchBody   = @{ content = $contentJson } | ConvertTo-Json -Depth 6
  $bytes       = [System.Text.Encoding]::UTF8.GetBytes($patchBody)
  Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents($compId)" -Method Patch -Body $bytes -UseBasicParsing | Out-Null
}

# Associate the mspp_entitypermission with the web role via N:N relationship.
# This is SEPARATE from the content JSON — without this real N:N record the
# portal will still return 403 on Append/AppendTo even though the content
# claims the role is linked.
function Associate-Role($permId) {
  $refBody  = @{ "@odata.id" = "$envUrl/api/data/v9.2/mspp_webroles($webRole)" } | ConvertTo-Json
  $refBytes = [System.Text.Encoding]::UTF8.GetBytes($refBody)
  try {
    Invoke-WebRequest -Headers $h -Method Post `
      -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($permId)/mspp_entitypermission_webrole/`$ref" `
      -Body $refBytes -UseBasicParsing | Out-Null
    Write-Host "  Web role associated (N:N)." -ForegroundColor Green
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match "duplicate" -or $msg -match "already exist") {
      Write-Host "  Web role already associated." -ForegroundColor DarkGray
    } else {
      Write-Host "  Associate error: $msg" -ForegroundColor Red
    }
  }
}

Write-Host "=== Enumerating existing portal table permissions ===" -ForegroundColor Cyan
$all = Invoke-RestMethod -Headers $hRead `
  -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18 and _powerpagesiteid_value eq $websiteId&`$select=powerpagecomponentid,name,content"
Write-Host "  Total type-18 perms: $($all.value.Count)"

function Find-PermByEntity($entity) {
  foreach ($c in $all.value) {
    try {
      $obj = $c.content | ConvertFrom-Json
      $el = $obj.entitylogicalname; if (-not $el) { $el = $obj.EntityLogicalName }
      if ($el -eq $entity) { return $c }
    } catch { }
  }
  return $null
}

$targets = @(
  @{ entity="dmv_vehicleregistration"; name="DMV - Registration Submit"; read=$true;  create=$true;  write=$true;  del=$false; append=$true;  appendto=$true  }
  @{ entity="dmv_vehicle";             name="DMV - Vehicle Submit";      read=$true;  create=$true;  write=$true;  del=$false; append=$true;  appendto=$true  }
  @{ entity="dmv_temporarytag";        name="DMV - Temp Tag Submit";     read=$true;  create=$true;  write=$true;  del=$false; append=$true;  appendto=$true  }
  @{ entity="account";                 name="DMV - Dealer Account Link"; read=$true;  create=$false; write=$false; del=$false; append=$false; appendto=$true  }
)

foreach ($t in $targets) {
  Write-Host "`n=== $($t.entity) ===" -ForegroundColor Cyan
  $existing = Find-PermByEntity $t.entity
  if ($existing) {
    Write-Host "  Found existing: $($existing.name) ($($existing.powerpagecomponentid))"
    Patch-Perm -compId $existing.powerpagecomponentid -entity $t.entity -name $existing.name `
      -read $t.read -create $t.create -write $t.write -del $t.del -append $t.append -appendto $t.appendto
    Write-Host "  Patched flags." -ForegroundColor Green
    Associate-Role $existing.powerpagecomponentid
  } else {
    Write-Host "  Creating new permission..." -ForegroundColor Yellow
    $createBody = @{
      name                       = $t.name
      powerpagecomponenttype     = 18
      content                    = "{}"
      "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
    } | ConvertTo-Json
    $r = Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents" -Method Post -Body $createBody -UseBasicParsing
    $newId = [regex]::Match($r.Headers["OData-EntityId"], "\(([^)]+)\)").Groups[1].Value
    Write-Host "  Created: $newId"
    Patch-Perm -compId $newId -entity $t.entity -name $t.name `
      -read $t.read -create $t.create -write $t.write -del $t.del -append $t.append -appendto $t.appendto
    Write-Host "  Content patched." -ForegroundColor Green
    Associate-Role $newId
  }
}

Write-Host "`n=== Verify ===" -ForegroundColor Cyan
$after = Invoke-RestMethod -Headers $hRead `
  -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18 and _powerpagesiteid_value eq $websiteId&`$select=name,content"
foreach ($c in $after.value) {
  try {
    $o = $c.content | ConvertFrom-Json
    $el = $o.entitylogicalname; if (-not $el) { $el = $o.EntityLogicalName }
    if ($el -in @("dmv_vehicleregistration","dmv_vehicle","dmv_temporarytag","account")) {
      Write-Host ("  {0,-24} R={1} C={2} W={3} A={4} AT={5}  ({6})" -f `
        $el, $o.read, $o.create, $o.write, $o.append, $o.appendto, $c.name)
    }
  } catch { }
}

Write-Host "`n=== PublishAllXml (REQUIRED — portal won't pick up perms otherwise) ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $h -Method Post | Out-Null
  Write-Host "Published." -ForegroundColor Green
} catch {
  Write-Host "Publish warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
