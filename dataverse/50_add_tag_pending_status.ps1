param()
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization="Bearer $token"; "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Content-Type"="application/json"; "MSCRM.SolutionUniqueName"="DMVDigitalServicesPortal" }

Write-Host "Fetching existing dmv_tagstatus option set..." -ForegroundColor Cyan
$attrUrl = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_temporarytag')/Attributes(LogicalName='dmv_tagstatus')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$expand=OptionSet"
$meta = Invoke-RestMethod -Headers $h -Uri $attrUrl
$existing = $meta.OptionSet.Options | ForEach-Object { [pscustomobject]@{ Value=$_.Value; Label=$_.Label.UserLocalizedLabel.Label } }
$existing | Format-Table -AutoSize

if ($existing | Where-Object { $_.Label -eq 'Pending' }) {
  Write-Host "Pending already exists — nothing to do." -ForegroundColor Yellow
  return
}

# Find next value (max+1) but prefer 100000004
$nextVal = 100000004
while ($existing.Value -contains $nextVal) { $nextVal++ }

Write-Host "Adding 'Pending' option with value $nextVal..." -ForegroundColor Cyan
$body = @{
  Value = $nextVal
  Label = @{ LocalizedLabels = @(@{ Label = "Pending"; LanguageCode = 1033 }); }
  AttributeLogicalName = "dmv_tagstatus"
  EntityLogicalName    = "dmv_temporarytag"
  SolutionUniqueName   = "DMVDigitalServicesPortal"
} | ConvertTo-Json -Depth 5
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

Invoke-RestMethod -Headers $h -Method Post -Uri "$envUrl/api/data/v9.2/InsertOptionValue" -Body $bytes | Out-Null

Write-Host "Publishing..." -ForegroundColor Cyan
Invoke-RestMethod -Headers $h -Method Post -Uri "$envUrl/api/data/v9.2/PublishAllXml" | Out-Null
Write-Host ("Done. Pending = {0}" -f $nextVal) -ForegroundColor Green
