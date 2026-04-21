# 48_create_year_string_and_readd.ps1
# Continuation of 47 — creates dmv_year as String, backfills, re-adds to form + view.
$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization    = "Bearer $token"
  "Content-Type"   = "application/json; charset=utf-8"
  "OData-Version"  = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

Write-Host "Creating dmv_year (String, length 4)..."
$newAttr = @{
  "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
  LogicalName   = "dmv_year"
  SchemaName    = "dmv_Year"
  RequiredLevel = @{ Value = "None" }
  MaxLength     = 4
  FormatName    = @{ Value = "Text" }
  DisplayName   = @{ LocalizedLabels = @(@{ Label = "Year"; LanguageCode = 1033 }) }
  Description   = @{ LocalizedLabels = @(@{ Label = "Model year (text, no grouping)"; LanguageCode = 1033 }) }
} | ConvertTo-Json -Depth 10
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_vehicle')/Attributes" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($newAttr)) -UseBasicParsing | Out-Null

Write-Host "Waiting 6s for metadata cache..."
Start-Sleep -Seconds 6

# Known snapshot from prior run
$snapshot = @{
  '03def455-1d39-f111-88b4-001dd80340cd' = '2023'
  '26def455-1d39-f111-88b4-001dd80340cd' = '2024'
}
Write-Host "Backfilling $($snapshot.Count) vehicles..."
foreach ($kvp in $snapshot.GetEnumerator()) {
  $body = @{ dmv_year = $kvp.Value } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicles($($kvp.Key))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "  $($kvp.Key) -> $($kvp.Value)"
}

# Re-add to main form — append new cell after dmv_model's cell
Write-Host "Re-adding dmv_year to main form..."
$form = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq 'dmv_vehicle' and type eq 2&`$select=formid,formxml&`$top=1" -Headers $readH).value[0]
$formXml = $form.formxml
$yearCell = '<cell id="{f0000000-0000-0000-0000-00000000dmvy}" showlabel="true" locklevel="0"><labels><label description="Year" languagecode="1033" /></labels><control id="dmv_year" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="dmv_year" disabled="false" /></cell>'
$updated = [regex]::Replace(
  $formXml,
  '(<cell[^>]*>\s*<labels>[^<]*<label[^>]*/>\s*</labels>\s*<control[^>]*datafieldname="dmv_model"[^/]*/>\s*</cell>)',
  "`$1$yearCell",
  [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($updated -eq $formXml) {
  Write-Host "  WARN: model anchor not found, trying insertion before first </row>"
  $updated = [regex]::Replace($formXml, '</row>', "$yearCell</row>", 1)
}
$body = @{ formxml = $updated } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($($form.formid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

# Re-add to Active Vehicles view
Write-Host "Re-adding dmv_year to Active Vehicles view..."
$viewId = '8baa7d66-102d-4a34-810c-17440a8751c7'
$v = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)?`$select=fetchxml,layoutxml" -Headers $readH
$fx = $v.fetchxml
$lx = $v.layoutxml
if ($fx -notmatch 'dmv_year') { $fx = $fx -replace '(</entity>)', '<attribute name="dmv_year" />$1' }
if ($lx -notmatch 'name="dmv_year"') { $lx = $lx -replace '(</row>)', '<cell name="dmv_year" width="80" />$1' }
$body = @{ fetchxml = $fx; layoutxml = $lx } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

Write-Host "Publishing..."
$pubBody = @{ ParameterXml = "<importexportxml><entities><entity>dmv_vehicle</entity></entities></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null

Write-Host "Done."
