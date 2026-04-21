<#
  40_fix_flow_addyears.ps1
  Power Automate has no addYears() - replace with addToTime(..., 2, 'Year')
#>
$ErrorActionPreference = "Stop"

$envUrl = "https://orga381269e.crm9.dynamics.com"
$flowId = "9f8e7d6c-5b4a-4321-9876-abcdef012345"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

$wf = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode" -Headers $readH
$cd = $wf.clientdata
$before = $cd.Length

$old = "addYears(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 2)"
$new = "addToTime(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 2, 'Year')"

if ($cd -notmatch [regex]::Escape($old)) {
  Write-Host "addYears expression not found. Already patched?" -ForegroundColor Yellow
  $cnt = ([regex]::Matches($cd, [regex]::Escape("addToTime(coalesce(triggerOutputs()?['body/dmv_approveddate']"))).Count
  Write-Host "addToTime occurrences: $cnt"
  exit 0
}

$cd = $cd.Replace($old, $new)
Write-Host "Patched clientdata: $before -> $($cd.Length) bytes"

Write-Host "Turning flow off..." -ForegroundColor Yellow
$offBody = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($offBody)) -UseBasicParsing | Out-Null

$body = @{ clientdata = $cd } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
Write-Host "clientdata updated"

Write-Host "Turning flow back on..." -ForegroundColor Yellow
$onBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($onBody)) -UseBasicParsing | Out-Null

Write-Host "Done." -ForegroundColor Green
