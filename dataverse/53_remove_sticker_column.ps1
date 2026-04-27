$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "If-Match" = "*"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

function Strip-Sticker([string]$xml) {
  # Remove <attribute name="dmv_stickernumber" /> and <cell name="dmv_stickernumber" ... />
  $xml = [regex]::Replace($xml, '<attribute\s+name="dmv_stickernumber"\s*/>', '')
  $xml = [regex]::Replace($xml, '<cell\s+name="dmv_stickernumber"[^/]*/>', '')
  # Remove form control + its containing <row> if row only wraps that control
  $xml = [regex]::Replace($xml, '<control[^>]*datafieldname="dmv_stickernumber"[^/]*/>', '')
  # Drop any <row> that becomes empty/only-whitespace after the above
  $xml = [regex]::Replace($xml, '<row[^>]*>\s*</row>', '')
  return $xml
}

Write-Host "=== Patching views ==="
$viewIds = @(
  '1ce8a6a3-d139-f111-88b3-001dd801f94a',
  '2227a990-d139-f111-88b4-001dd80340cd',
  'ee5b49a3-7a75-4d77-b04c-72086709eaf1',
  'd33b4d72-66ba-4902-b687-7abd8bdad9d0'
)
foreach ($id in $viewIds) {
  $v = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/savedqueries($id)?`$select=name,fetchxml,layoutxml"
  $newFetch  = Strip-Sticker $v.fetchxml
  $newLayout = Strip-Sticker $v.layoutxml
  $body = @{ fetchxml = $newFetch; layoutxml = $newLayout } | ConvertTo-Json -Depth 5
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($id)" -Method Patch -Headers $h -Body $bytes -UseBasicParsing | Out-Null
  Write-Host "  Patched view $($v.name)"
}

Write-Host "=== Patching form ==="
$formId = '08509d60-d139-f111-88b4-001dd80340cd'
$f = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/systemforms($formId)?`$select=name,formxml"
$newForm = Strip-Sticker $f.formxml
$body = @{ formxml = $newForm } | ConvertTo-Json -Depth 5
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms($formId)" -Method Patch -Headers $h -Body $bytes -UseBasicParsing | Out-Null
Write-Host "  Patched form $($f.name)"

Write-Host "=== PublishAllXml ==="
$pubHdr = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
}
$pubBody = '{"ParameterXml":"<importexportxml><entities><entity>dmv_registrationterm</entity><entity>dmv_vehicleregistration</entity></entities></importexportxml>"}'
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $pubHdr -Body $pubBody -UseBasicParsing | Out-Null
Write-Host "  Published"

Write-Host "=== Deleting columns ==="
$delHdr = @{
  Authorization = "Bearer $token"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
foreach ($e in @('dmv_registrationterm','dmv_vehicleregistration')) {
  try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$e')/Attributes(LogicalName='dmv_stickernumber')" -Method Delete -Headers $delHdr -UseBasicParsing | Out-Null
    Write-Host "  Deleted dmv_stickernumber from $e"
  } catch {
    Write-Host "  ERROR on $e : $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host "Done."
