#requires -Version 7.0
# Part 2: continue conversion after hitting view dependency
$envUrl  = "https://orga381269e.crm9.dynamics.com"
$entity  = "dmv_registrationrenewal"
$attr    = "dmv_vehicleyear"
$solution = "DMVDigitalServicesPortal"
$formId  = '8e65687e-9d8d-4ac4-8658-a359b00cfe1e'
$viewId  = '1b6547ed-cb94-4194-8a5c-6a22ae1f5eaf'

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$hJson = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json"
            "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
            "MSCRM.SolutionUniqueName" = $solution }
$hGet = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

function Publish-All { Write-Host "Publishing..." -ForegroundColor Cyan
  Invoke-RestMethod -Method Post -Headers $hJson -Uri "$envUrl/api/data/v9.2/PublishAllXml" | Out-Null }

# --- Strip dmv_vehicleyear from the Active Registration Renewals view ---
Write-Host "[1/9] Loading view..." -ForegroundColor Cyan
$view = Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)?`$select=fetchxml,layoutxml"
$layoutOrig = $view.layoutxml
$fetchOrig  = $view.fetchxml
Write-Host "  layout len=$($layoutOrig.Length), fetch len=$($fetchOrig.Length)"

# Capture the <cell name="dmv_vehicleyear" ... /> and record surrounding context
$cellRx = [regex]'<cell\s+name="dmv_vehicleyear"[^/]*/>'
$layoutMatch = $cellRx.Match($layoutOrig)
$originalLayoutCell = if ($layoutMatch.Success) { $layoutMatch.Value } else { '<cell name="dmv_vehicleyear" width="100" />' }
Write-Host "  Layout cell: $originalLayoutCell"

$fetchRx = [regex]'<attribute\s+name="dmv_vehicleyear"\s*/>'
$fetchMatch = $fetchRx.Match($fetchOrig)
$originalFetchAttr = if ($fetchMatch.Success) { $fetchMatch.Value } else { '<attribute name="dmv_vehicleyear" />' }

# Also check for <order attribute="dmv_vehicleyear" ... />
$orderRx = [regex]'<order\s+attribute="dmv_vehicleyear"[^/]*/>'

$layoutStripped = $cellRx.Replace($layoutOrig, '', 1)
$fetchStripped  = $fetchRx.Replace($fetchOrig, '', 1)
$fetchStripped  = $orderRx.Replace($fetchStripped, '', 1)

Write-Host "[2/9] Saving view without dmv_vehicleyear..." -ForegroundColor Cyan
$body = @{ layoutxml = $layoutStripped; fetchxml = $fetchStripped } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Body $body | Out-Null
Publish-All

# --- Backup data ---
Write-Host "[3/9] Backing up renewal year values..." -ForegroundColor Cyan
$existing = (Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$select=dmv_registrationrenewalid,dmv_vehicleyear&`$top=500").value
$backup = @{}
foreach ($r in $existing) { if ($null -ne $r.dmv_vehicleyear) { $backup[$r.dmv_registrationrenewalid] = "$($r.dmv_vehicleyear)" } }
Write-Host "  Backed up $($backup.Count) values."

# --- Delete Integer attribute ---
Write-Host "[4/9] Deleting Integer attribute..." -ForegroundColor Cyan
Invoke-RestMethod -Method Delete -Headers $hJson -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$entity')/Attributes(LogicalName='$attr')" | Out-Null
Start-Sleep -Seconds 5

# --- Recreate as String ---
Write-Host "[5/9] Creating String attribute..." -ForegroundColor Cyan
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
Start-Sleep -Seconds 25

# --- Backfill ---
Write-Host "[6/9] Backfilling data..." -ForegroundColor Cyan
foreach ($kvp in $backup.GetEnumerator()) {
  $b = @{ $attr = $kvp.Value } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($kvp.Key))" -Body $b | Out-Null
    Write-Host "  $($kvp.Key) = $($kvp.Value)"
  } catch { Write-Host "  Failed $($kvp.Key): $_" -ForegroundColor Yellow }
}

# --- Re-add to view ---
Write-Host "[7/9] Re-adding cell to view..." -ForegroundColor Cyan
$view2 = Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)?`$select=fetchxml,layoutxml"
# Insert layout cell before </row>
$layoutNew = [regex]::Replace($view2.layoutxml, '(</row>)', "$originalLayoutCell`$1", 1)
# Insert fetch attribute before </entity>
$fetchNew  = [regex]::Replace($view2.fetchxml,  '(</entity>)', "$originalFetchAttr`$1", 1)
$body = @{ layoutxml = $layoutNew; fetchxml = $fetchNew } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Body $body | Out-Null

# --- Re-add to form ---
Write-Host "[8/9] Re-adding cell to form..." -ForegroundColor Cyan
$originalCell = '<cell id="{f0000003-0003-0003-0003-000000000003}" showlabel="true"><labels><label description="Vehicle Year" languagecode="1033" /></labels><control id="dmv_vehicleyear" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="dmv_vehicleyear" disabled="false" /></cell>'
$form2 = Invoke-RestMethod -Headers $hGet -Uri "$envUrl/api/data/v9.2/systemforms($formId)?`$select=formxml"
$xml2 = $form2.formxml
$anchorRx = [regex]'(?s)(<cell\b[^>]*>(?:(?!<cell\b).)*?datafieldname="dmv_vehiclemodel"(?:(?!</cell>).)*?</cell>)'
if ($anchorRx.IsMatch($xml2)) {
  $xml3 = $anchorRx.Replace($xml2, { param($m) $m.Groups[1].Value + $originalCell }, 1)
  Write-Host "  Inserted after vehiclemodel cell."
} else {
  $xml3 = [regex]::Replace($xml2, '</row>', "$originalCell</row>", 1)
  Write-Host "  Inserted into first row." -ForegroundColor Yellow
}
$body = @{ formxml = $xml3 } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Patch -Headers $hJson -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Body $body | Out-Null

Write-Host "[9/9] Publishing..." -ForegroundColor Cyan
Publish-All

Write-Host "`n=== DONE ===" -ForegroundColor Green
