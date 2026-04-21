# 47_change_year_to_string.ps1
# Converts dmv_vehicle.dmv_year from Integer to String (single-line text).
# Required because Integer columns in MDA always display locale grouping (e.g., "2,024").
#
# Steps:
#   1. Snapshot current year values for all vehicles.
#   2. Strip dmv_year references from the Information main form + Active Vehicles view.
#   3. PublishXml so Dataverse releases the column.
#   4. Delete dmv_year column.
#   5. Recreate dmv_year as StringAttributeMetadata (MaxLength=4).
#   6. Backfill values on all vehicles.
#   7. Re-add dmv_year to the main form (after dmv_model) and Active Vehicles view.
#   8. PublishXml.

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

# 1. Snapshot -----------------------------------------------------------------
Write-Host "1. Snapshotting current year values..."
$vehicles = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicles?`$select=dmv_vehicleid,dmv_year" -Headers $readH).value
$snapshot = @{}
foreach ($v in $vehicles) {
  if ($null -ne $v.dmv_year) { $snapshot[$v.dmv_vehicleid] = [string]$v.dmv_year }
}
Write-Host ("   captured {0} vehicle year values" -f $snapshot.Count)

# 2. Strip dmv_year from form + view -----------------------------------------
Write-Host "2. Removing dmv_year references from main form + Active Vehicles view..."

# 2a. Main form (type=2 Information)
$form = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq 'dmv_vehicle' and type eq 2&`$select=formid,formxml&`$top=1" -Headers $readH).value[0]
$formId = $form.formid
$formXml = $form.formxml
# remove any <control ... datafieldname="dmv_year" .../> and wrapping <cell>
$stripped = [regex]::Replace($formXml, '<cell[^>]*>\s*<labels>.*?</labels>\s*<control[^>]*datafieldname="dmv_year"[^/]*/>\s*</cell>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
# fallback: remove just the control if still present
$stripped = [regex]::Replace($stripped, '<control[^>]*datafieldname="dmv_year"[^/]*/>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($stripped -eq $formXml) { Write-Host "   WARN: form XML unchanged" } else { Write-Host "   form XML trimmed" }
$body = @{ formxml = $stripped } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

# 2b. Active Vehicles view
$viewId = '8baa7d66-102d-4a34-810c-17440a8751c7'
$view = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)?`$select=fetchxml,layoutxml" -Headers $readH
$fx = $view.fetchxml -replace '<attribute\s+name="dmv_year"\s*/>', ''
$lx = $view.layoutxml -replace '<cell\s+name="dmv_year"[^/]*/>', ''
$body = @{ fetchxml = $fx; layoutxml = $lx } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
Write-Host "   Active Vehicles view trimmed"

# 3. Publish -----------------------------------------------------------------
Write-Host "3. PublishXml..."
$pubBody = @{ ParameterXml = "<importexportxml><entities><entity>dmv_vehicle</entity></entities></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null

# 4. Delete column -----------------------------------------------------------
Write-Host "4. Deleting dmv_year (Integer)..."
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_vehicle')/Attributes(LogicalName='dmv_year')" -Method Delete -Headers $h -UseBasicParsing | Out-Null

# 5. Create new String column -------------------------------------------------
Write-Host "5. Creating dmv_year (String, length 4)..."
$newAttr = @{
  "@odata.type"              = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
  LogicalName                = "dmv_year"
  SchemaName                 = "dmv_Year"
  RequiredLevel              = @{ Value = "None" }
  MaxLength                  = 4
  FormatName                 = @{ Value = "Text" }
  DisplayName                = @{ LocalizedLabels = @(@{ Label = "Year"; LanguageCode = 1033 }) }
  Description                = @{ LocalizedLabels = @(@{ Label = "Model year (as text, no grouping)"; LanguageCode = 1033 }) }
} | ConvertTo-Json -Depth 10
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_vehicle')/Attributes" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($newAttr)) -UseBasicParsing | Out-Null

Write-Host "   waiting for metadata settle..."
Start-Sleep -Seconds 5

# 6. Backfill -----------------------------------------------------------------
Write-Host "6. Backfilling $($snapshot.Count) records..."
foreach ($kvp in $snapshot.GetEnumerator()) {
  $body = @{ dmv_year = $kvp.Value } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicles($($kvp.Key))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "   $($kvp.Key) -> $($kvp.Value)"
}

# 7. Re-add to form + view ----------------------------------------------------
Write-Host "7. Re-adding dmv_year to form + view..."

# 7a. Re-add to form after dmv_model
$form = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/systemforms?`$filter=objecttypecode eq 'dmv_vehicle' and type eq 2&`$select=formid,formxml&`$top=1" -Headers $readH).value[0]
$formXml = $form.formxml
$yearCell = '<cell id="{dmv_year_cell}"><labels><label description="Year" languagecode="1033" /></labels><control id="dmv_year" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="dmv_year" disabled="false" /></cell>'
if ($formXml -match 'datafieldname="dmv_model"') {
  $injected = [regex]::Replace($formXml, '(<cell[^>]*>\s*<labels>[^<]*<label[^>]*/>\s*</labels>\s*<control[^>]*datafieldname="dmv_model"[^/]*/>\s*</cell>)', "`$1$yearCell", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($injected -eq $formXml) {
    # simpler: just insert before end of first section's </rows>
    $injected = [regex]::Replace($formXml, '(</rows>)', "<row>$yearCell</row>`$1", 1)
  }
  $body = @{ formxml = $injected } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($($form.formid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "   form updated"
} else {
  Write-Host "   WARN: could not locate dmv_model anchor in form; skipping form re-add"
}

# 7b. Re-add to Active Vehicles view
$view = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)?`$select=fetchxml,layoutxml" -Headers $readH
$fx = $view.fetchxml
$lx = $view.layoutxml
if ($fx -notmatch 'dmv_year') {
  $fx = $fx -replace '(</entity>)', '<attribute name="dmv_year" />$1'
}
if ($lx -notmatch 'name="dmv_year"') {
  $lx = $lx -replace '(</row>)', '<cell name="dmv_year" width="80" />$1'
}
$body = @{ fetchxml = $fx; layoutxml = $lx } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($viewId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

# 8. Publish
Write-Host "8. PublishXml..."
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "Done."
