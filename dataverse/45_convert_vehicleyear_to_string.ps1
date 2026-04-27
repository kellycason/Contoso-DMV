#requires -Version 7.0
# Convert dmv_registrationrenewal.dmv_vehicleyear from Integer to String
# so the CSW app doesn't render it as "2,024"

$envUrl  = "https://orga381269e.crm9.dynamics.com"
$entity  = "dmv_registrationrenewal"
$attr    = "dmv_vehicleyear"
$solution = "DMVDigitalServicesPortal"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$hJson = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = $solution
}
$hGet = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

function Publish-All {
  Write-Host "Publishing..." -ForegroundColor Cyan
  Invoke-RestMethod -Method Post -Headers $hJson -Uri "$envUrl/api/data/v9.2/PublishAllXml" | Out-Null
}

# 1. Backup existing data
Write-Host "`n[1/8] Reading existing renewal records..." -ForegroundColor Cyan
$existing = (Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$select=dmv_registrationrenewalid,dmv_vehicleyear&`$top=500").value
Write-Host "  Found $($existing.Count) records."
$backup = @{}
foreach ($r in $existing) {
  if ($null -ne $r.dmv_vehicleyear) { $backup[$r.dmv_registrationrenewalid] = "$($r.dmv_vehicleyear)" }
}
Write-Host "  Backed up $($backup.Count) non-null year values."

# 2. Read main Information form
Write-Host "`n[2/8] Loading main form..." -ForegroundColor Cyan
$formId = '8e65687e-9d8d-4ac4-8658-a359b00cfe1e'
$form = Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/systemforms($formId)?`$select=name,formxml"
$xml  = $form.formxml
Write-Host "  Original form length: $($xml.Length)"

# 3. Capture the <row> or <cell> containing dmv_vehicleyear so we can re-add later
# Cell pattern: <cell ...><labels>...</labels><control ... datafieldname="dmv_vehicleyear" .../></cell>
$cellRegex = [regex]'(?s)<cell\b[^>]*>(?:(?!<cell\b).)*?datafieldname="dmv_vehicleyear"(?:(?!</cell>).)*?</cell>'
$cellMatch = $cellRegex.Match($xml)
if (-not $cellMatch.Success) { throw "Could not find <cell> for dmv_vehicleyear in form XML" }
$originalCell = $cellMatch.Value
Write-Host "  Captured original cell ($($originalCell.Length) chars)"

# 4. Strip the cell from the form and save
Write-Host "`n[3/8] Stripping dmv_vehicleyear from form..." -ForegroundColor Cyan
$xmlStripped = $cellRegex.Replace($xml, '', 1)
$body = @{ formxml = $xmlStripped } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Body $body | Out-Null
Publish-All

# 5. Delete the integer attribute
Write-Host "`n[4/8] Deleting Integer attribute..." -ForegroundColor Cyan
try {
  Invoke-RestMethod -Method Delete -Headers $hJson -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$entity')/Attributes(LogicalName='$attr')" | Out-Null
  Write-Host "  Deleted."
} catch {
  Write-Host "  Delete failed: $_" -ForegroundColor Yellow
  throw
}
Start-Sleep -Seconds 5

# 6. Recreate as String
Write-Host "`n[5/8] Recreating as String..." -ForegroundColor Cyan
$newAttr = @{
  "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
  LogicalName   = $attr
  SchemaName    = "dmv_VehicleYear"
  DisplayName   = @{ LocalizedLabels = @(@{ Label = "Vehicle Year"; LanguageCode = 1033 }) }
  Description   = @{ LocalizedLabels = @(@{ Label = "Model year of the vehicle (e.g. 2024)"; LanguageCode = 1033 }) }
  RequiredLevel = @{ Value = "None" }
  MaxLength     = 10
  FormatName    = @{ Value = "Text" }
} | ConvertTo-Json -Depth 10 -Compress
Invoke-RestMethod -Method Post -Headers $hJson -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$entity')/Attributes" -Body $newAttr | Out-Null
Write-Host "  Created. Waiting for metadata cache..."
Start-Sleep -Seconds 25

# 7. Backfill existing records
Write-Host "`n[6/8] Backfilling $($backup.Count) records..." -ForegroundColor Cyan
foreach ($kvp in $backup.GetEnumerator()) {
  $body = @{ $attr = $kvp.Value } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($kvp.Key))" -Body $body | Out-Null
    Write-Host "  $($kvp.Key) = $($kvp.Value)"
  } catch {
    Write-Host "  Failed $($kvp.Key): $_" -ForegroundColor Yellow
  }
}

# 8. Re-add cell to form and save
Write-Host "`n[7/8] Re-adding dmv_vehicleyear cell to form..." -ForegroundColor Cyan
$form2 = Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/systemforms($formId)?`$select=formxml"
$xml2  = $form2.formxml

# Insert cell after the dmv_vehiclemodel cell (keep it near its peer fields)
$anchorRegex = [regex]'(?s)(<cell\b[^>]*>(?:(?!<cell\b).)*?datafieldname="dmv_vehiclemodel"(?:(?!</cell>).)*?</cell>)'
$anchorMatch = $anchorRegex.Match($xml2)
if ($anchorMatch.Success) {
  $xml3 = $anchorRegex.Replace($xml2, { param($m) $m.Groups[1].Value + $originalCell }, 1)
  Write-Host "  Inserted after dmv_vehiclemodel cell."
} else {
  # Fallback: append before </row> of first row on tab 1
  Write-Host "  Model cell not found; appending after first <row>" -ForegroundColor Yellow
  $xml3 = [regex]::Replace($xml2, '(?s)(</row>)', "$originalCell`$1", 1)
}

$body = @{ formxml = $xml3 } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Body $body | Out-Null

Write-Host "`n[8/8] Publishing final form..." -ForegroundColor Cyan
Publish-All

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "dmv_vehicleyear is now a String. Open a renewal record in CSW and verify no comma."
