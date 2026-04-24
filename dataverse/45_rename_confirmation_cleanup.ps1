<#
  45_rename_confirmation_cleanup.ps1

  Semantic rename on dmv_registrationrenewal:
    dmv_temptagnumber          -> dmv_confirmationnumber   (String 20)
    dmv_temptagexpirationdate  -> (deleted, obsolete; flow writes dmv_newexpirationdate)

  Steps:
    1. Create dmv_confirmationnumber (String 20, DisplayName "Confirmation Number")
    2. Backfill dmv_confirmationnumber from dmv_temptagnumber for all records
    3. Patch flow clientdata:
         triggerOutputs()?['body/dmv_temptagnumber']  -> triggerOutputs()?['body/dmv_confirmationnumber']
         item/dmv_temptagnumber                       -> item/dmv_confirmationnumber
    4. Delete dmv_temptagnumber + dmv_temptagexpirationdate attributes

  No forms/views touch either column, so no strip/re-add is needed.
#>

$ErrorActionPreference = "Stop"

$envUrl    = "https://orga381269e.crm9.dynamics.com"
$solution  = "DMVDigitalServicesPortal"
$flowId    = "9f8e7d6c-5b4a-4321-9876-abcdef012345"
$table     = "dmv_registrationrenewal"
$entitySet = "dmv_registrationrenewals"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

$hSol = @{
  Authorization              = "Bearer $token"
  "Content-Type"             = "application/json; charset=utf-8"
  "OData-MaxVersion"         = "4.0"
  "OData-Version"            = "4.0"
  "MSCRM.SolutionUniqueName" = $solution
}
$hJson = @{
  Authorization      = "Bearer $token"
  "Content-Type"     = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version"    = "4.0"
}
$hRead = @{
  Authorization      = "Bearer $token"
  "OData-MaxVersion" = "4.0"
  "OData-Version"    = "4.0"
}

# ---------- Step 1: Create dmv_confirmationnumber ----------
Write-Host "=== Step 1: Creating dmv_confirmationnumber ===" -ForegroundColor Cyan

$existing = $null
try {
  $existing = Invoke-RestMethod `
    -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='dmv_confirmationnumber')?`$select=LogicalName" `
    -Headers $hRead
} catch { }

if ($existing) {
  Write-Host "  dmv_confirmationnumber already exists; skipping create."
} else {
  $createBody = @{
    "@odata.type"   = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
    AttributeType   = "String"
    AttributeTypeName = @{ Value = "StringType" }
    SchemaName      = "dmv_confirmationnumber"
    MaxLength       = 20
    FormatName      = @{ Value = "Text" }
    RequiredLevel   = @{ Value = "None" }
    DisplayName     = @{ LocalizedLabels = @(@{ Label = "Confirmation Number"; LanguageCode = 1033 }) }
    Description     = @{ LocalizedLabels = @(@{ Label = "Registration renewal confirmation number (e.g. CONF-YYYY-NNNN)"; LanguageCode = 1033 }) }
  } | ConvertTo-Json -Depth 10

  Invoke-WebRequest `
    -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes" `
    -Method Post -Headers $hSol `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($createBody)) -UseBasicParsing | Out-Null
  Write-Host "  Created dmv_confirmationnumber."
}

# Let metadata cache catch up before OData writes
Start-Sleep -Seconds 20

# ---------- Step 2: Backfill from dmv_temptagnumber ----------
Write-Host "`n=== Step 2: Backfilling dmv_confirmationnumber ===" -ForegroundColor Cyan

$recs = Invoke-RestMethod `
  -Uri "$envUrl/api/data/v9.2/$entitySet`?`$select=dmv_registrationrenewalid,dmv_renewalid,dmv_temptagnumber,dmv_confirmationnumber" `
  -Headers $hRead

$copied = 0
foreach ($r in $recs.value) {
  if ($r.dmv_temptagnumber -and -not $r.dmv_confirmationnumber) {
    $body = @{ dmv_confirmationnumber = $r.dmv_temptagnumber } | ConvertTo-Json
    Invoke-WebRequest `
      -Uri "$envUrl/api/data/v9.2/$entitySet($($r.dmv_registrationrenewalid))" `
      -Method Patch -Headers $hJson `
      -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  $($r.dmv_renewalid): $($r.dmv_temptagnumber) -> dmv_confirmationnumber"
    $copied++
  }
}
Write-Host "  Backfilled $copied record(s)."

# ---------- Step 3: Patch flow clientdata ----------
Write-Host "`n=== Step 3: Patching flow clientdata ===" -ForegroundColor Cyan

$wf = Invoke-RestMethod `
  -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode,name" `
  -Headers $hRead
Write-Host "  Flow: $($wf.name)  state=$($wf.statecode) status=$($wf.statuscode)"

$cd = $wf.clientdata
$before = $cd.Length

$cd = $cd.Replace("body/dmv_temptagnumber",  "body/dmv_confirmationnumber")
$cd = $cd.Replace("item/dmv_temptagnumber",  "item/dmv_confirmationnumber")

$after = $cd.Length
Write-Host "  clientdata: $before -> $after bytes"
$remain = ([regex]::Matches($cd, "dmv_temptagnumber|dmv_temptagexpirationdate")).Count
if ($remain -gt 0) {
  Write-Host "  WARNING: $remain residual refs to old names in clientdata" -ForegroundColor Yellow
}

# Disable -> patch -> re-enable (workflow clientdata can't be patched on active flow)
$origState  = $wf.statecode
$origStatus = $wf.statuscode

if ($origState -ne 0) {
  $disable = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $hJson `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($disable)) -UseBasicParsing | Out-Null
  Write-Host "  Flow disabled."
}

$patch = @{ clientdata = $cd } | ConvertTo-Json -Depth 20 -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $hJson `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
Write-Host "  clientdata patched."

if ($origState -ne 0) {
  $enable = @{ statecode = $origState; statuscode = $origStatus } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $hJson `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($enable)) -UseBasicParsing | Out-Null
  Write-Host "  Flow re-enabled (state=$origState status=$origStatus)."
}

# ---------- Step 4: Delete old columns ----------
Write-Host "`n=== Step 4: Deleting old attributes ===" -ForegroundColor Cyan

function Remove-Attribute($logical) {
  try {
    Invoke-WebRequest `
      -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$logical')" `
      -Method Delete -Headers $hSol -UseBasicParsing | Out-Null
    Write-Host "  Deleted $logical"
  } catch {
    Write-Host "  FAILED to delete $logical : $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Remove-Attribute "dmv_temptagnumber"
Remove-Attribute "dmv_temptagexpirationdate"

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "Next: update src/pages/Documents.tsx, rebuild vite, upload bundle."
