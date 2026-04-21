<#
  38_renewal_to_confirmation.ps1

  Option A: pivot from "Temporary Decal" metaphor to
  "Registration Renewal Confirmation" (real-world DMV renewal):
    - Number = CONF-YYYY-NNNN (confirmation receipt)
    - Expiration = 2 years from approval (new registration period)
    - Physical sticker arrives by mail; confirmation is digital proof

  Steps:
    1. Update column DisplayNames on dmv_registrationrenewal
    2. Patch flow clientdata (prefix, +30d -> +2y, email body wording)
    3. Re-backfill existing Approved records (DECAL-... -> CONF-...,
       temptagexpirationdate -> approveddate + 2 years)
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
    [string]$AttributeType
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
  -NewDisplayName "Confirmation Number" -AttributeType "String"
Update-AttributeDisplayName -LogicalName "dmv_temptagexpirationdate" `
  -NewDisplayName "New Registration Expiration" -AttributeType "DateTime"

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

# --- 2a. Tag-prefix: DECAL- -> CONF-
$cd = $cd.Replace("'DECAL-'", "'CONF-'")

# --- 2b. Expiration: approved + 30 days -> approved + 2 years
$cd = $cd.Replace(
  "addDays(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 30)",
  "addYears(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 2)"
)

# --- 2c. Email opening line
$cd = $cd.Replace(
  "Your temporary registration tag is now available for download from your Contoso DMV portal account.",
  "Your registration renewal confirmation is now available for download from your Contoso DMV portal account. Your new registration sticker will arrive by mail within 7&ndash;10 business days."
)

# --- 2d. Field labels in email details table
$cd = $cd.Replace(">Registration Decal Number<", ">Confirmation Number<")
$cd = $cd.Replace(">Tag Issued<", ">Renewal Approved<")
$cd = $cd.Replace(">Registration Valid Through<", ">New Registration Expires<")

# --- 2e. Important callout
$cd = $cd.Replace(
  "<strong>Important:</strong> Print this tag and display it in your rear window until your permanent registration sticker arrives in the mail.",
  "<strong>What's next:</strong> Your physical registration sticker will be mailed to the address on file within 7&ndash;10 business days. Apply it to your rear license plate when it arrives. Until then, this confirmation serves as your proof of renewal."
)

# --- 2f. Download button
$cd = $cd.Replace("Download Registration Decal", "Download Renewal Confirmation")

# --- 2g. Closing footer paragraph
$cd = $cd.Replace(
  "Your permanent registration sticker will be mailed to the address on file within 7&ndash;10 business days.`r`n        The registration decal is valid for 30 days from the date of issue.",
  "Keep this confirmation for your records. If your sticker has not arrived after 10 business days, contact us at (555) 123-4567."
)

Write-Host "  Patched clientdata: $($cd.Length) bytes (delta: $($cd.Length - $beforeLen))"

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
# 3. Re-backfill existing approved records
# ============================================================
Write-Host "`n=== Step 3: Re-backfilling Approved records ===" -ForegroundColor Cyan

$records = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_renewalstatus eq 100000002&`$select=dmv_registrationrenewalid,dmv_renewalid,dmv_temptagnumber,dmv_temptagexpirationdate,dmv_approveddate" -Headers $readH

foreach ($rec in $records.value) {
  $currentTag = $rec.dmv_temptagnumber
  if (-not $currentTag) {
    Write-Host "  SKIP (no tag): $($rec.dmv_renewalid)"
    continue
  }

  $updates = @{}

  if ($currentTag -notlike "CONF-*") {
    $newTag = $currentTag -replace '^(TMP|DECAL)-', 'CONF-'
    $updates.dmv_temptagnumber = $newTag
  }

  # Expiration = approved + 2 years
  if ($rec.dmv_approveddate) {
    $approved = [datetime]$rec.dmv_approveddate
    $newExpiry = $approved.AddYears(2).ToString("yyyy-MM-dd")
    $currentExpiry = if ($rec.dmv_temptagexpirationdate) { ([datetime]$rec.dmv_temptagexpirationdate).ToString("yyyy-MM-dd") } else { "" }
    if ($currentExpiry -ne $newExpiry) {
      $updates.dmv_temptagexpirationdate = $newExpiry
    }
  }

  if ($updates.Count -eq 0) {
    Write-Host "  OK (already up to date): $($rec.dmv_renewalid) = $currentTag"
    continue
  }

  $patchBody = $updates | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($rec.dmv_registrationrenewalid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody)) -UseBasicParsing | Out-Null

  $summary = ($updates.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
  Write-Host "  $($rec.dmv_renewalid): $summary"
}

Write-Host "`nDone." -ForegroundColor Green
