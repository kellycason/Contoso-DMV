<#
  37_rename_temptag_to_decal.ps1

  Cosmetic rename: "Temporary Tag" -> "Registration Decal" throughout.
  (Column logical names stay the same - Dataverse cannot rename those.)

    1. Update column DisplayNames on dmv_registrationrenewal
    2. Patch flow clientdata (tag format + email body wording)
    3. Re-backfill existing Approved record (TMP-... -> DECAL-...)
#>

$ErrorActionPreference = "Stop"

$envUrl    = "https://orga381269e.crm9.dynamics.com"
$solution  = "DMVDigitalServicesPortal"
$flowId    = "9f8e7d6c-5b4a-4321-9876-abcdef012345"
$table     = "dmv_registrationrenewal"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = $solution
}
$readH = @{
  Authorization = "Bearer $token"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
}

# ============================================================
# 1. Rename column display names
# ============================================================
Write-Host "=== Step 1: Renaming column DisplayNames ===" -ForegroundColor Cyan

function Update-AttributeDisplayName {
  param(
    [string]$LogicalName,
    [string]$NewDisplayName,
    [string]$AttributeType   # "String" or "DateTime"
  )

  $meta = Invoke-RestMethod `
    -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$LogicalName')?`$select=MetadataId,SchemaName" `
    -Headers $readH

  $body = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.$($AttributeType)AttributeMetadata"
    MetadataId    = $meta.MetadataId
    LogicalName   = $LogicalName
    SchemaName    = $meta.SchemaName
    DisplayName   = @{
      LocalizedLabels = @(
        @{ Label = $NewDisplayName; LanguageCode = 1033 }
      )
    }
  } | ConvertTo-Json -Depth 10

  $url = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$LogicalName')"
  Invoke-WebRequest -Uri $url -Method Put -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "  $LogicalName -> '$NewDisplayName'"
}

Update-AttributeDisplayName -LogicalName "dmv_temptagnumber" `
  -NewDisplayName "Registration Decal Number" -AttributeType "String"
Update-AttributeDisplayName -LogicalName "dmv_temptagexpirationdate" `
  -NewDisplayName "Registration Decal Expiration" -AttributeType "DateTime"

# ============================================================
# 2. Patch flow clientdata
# ============================================================
Write-Host "`n=== Step 2: Patching flow clientdata ===" -ForegroundColor Cyan

$wf = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode" -Headers $readH
$cd = $wf.clientdata

$beforeLen = $cd.Length
$origState = $wf.statecode
$origStatus = $wf.statuscode
Write-Host "  Original clientdata: $beforeLen bytes; statecode=$origState statuscode=$origStatus"

# Tag format
$cd = $cd.Replace("'TMP-'", "'DECAL-'")

# Email body wording
$cd = $cd.Replace("Temporary Tag Number", "Registration Decal Number")
$cd = $cd.Replace("Tag Valid Through", "Registration Valid Through")
$cd = $cd.Replace("Download Temporary Tag", "Download Registration Decal")
$cd = $cd.Replace("The temporary tag is valid for 30 days from the date of issue.",
                  "The registration decal is valid for 30 days from the date of issue.")

Write-Host "  Patched clientdata: $($cd.Length) bytes (delta: $($cd.Length - $beforeLen))"

# Flow must be turned off to update clientdata
if ($origStatus -ne 1) {
  Write-Host "  Turning flow off to edit..." -ForegroundColor Yellow
  $offBody = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($offBody)) -UseBasicParsing | Out-Null
}

$body = @{ clientdata = $cd } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
Write-Host "  clientdata updated"

if ($origStatus -eq 2) {
  Write-Host "  Turning flow back on..." -ForegroundColor Yellow
  $onBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($onBody)) -UseBasicParsing | Out-Null
}

# ============================================================
# 3. Re-backfill existing record
# ============================================================
Write-Host "`n=== Step 3: Re-backfilling Approved records ===" -ForegroundColor Cyan

$records = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_renewalstatus eq 100000002&`$select=dmv_registrationrenewalid,dmv_renewalid,dmv_temptagnumber,dmv_approveddate" -Headers $readH

foreach ($rec in $records.value) {
  $currentTag = $rec.dmv_temptagnumber
  if (-not $currentTag) {
    Write-Host "  SKIP (no tag yet): $($rec.dmv_renewalid)"
    continue
  }
  if ($currentTag -like "DECAL-*") {
    Write-Host "  SKIP (already DECAL): $($rec.dmv_renewalid) = $currentTag"
    continue
  }
  $newTag = $currentTag -replace '^TMP-', 'DECAL-'
  $patchBody = @{ dmv_temptagnumber = $newTag } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($rec.dmv_registrationrenewalid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody)) -UseBasicParsing | Out-Null
  Write-Host "  $($rec.dmv_renewalid): $currentTag -> $newTag"
}

Write-Host "`nDone." -ForegroundColor Green
