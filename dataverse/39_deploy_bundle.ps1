<#
  Deploy updated index-CcBGzUdW.js to powerpagecomponent
#>
$ErrorActionPreference = "Stop"

$envUrl = "https://orga381269e.crm9.dynamics.com"
$bundleId = "60a6be7b-c4e7-4e06-97eb-31f38b5f9025"
$localPath = "C:\Users\kellycason\source\repos\Contoso-DMV\dist\assets\index-CcBGzUdW.js"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

$bytes = [System.IO.File]::ReadAllBytes($localPath)
$b64 = [Convert]::ToBase64String($bytes)
Write-Host "Uploading $($bytes.Length) bytes..."

$body = @{ filecontent = $b64 } | ConvertTo-Json
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
}

Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($bundleId)" `
  -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

Write-Host "Deployed."

# Verify content strings
$resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($bundleId)?`$select=filecontent" `
  -Headers @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" } -UseBasicParsing
$deployedB64 = ($resp.Content | ConvertFrom-Json).filecontent
$deployedBytes = [Convert]::FromBase64String($deployedB64)
$tmp = Join-Path $env:TEMP "deployed-bundle.js"
[System.IO.File]::WriteAllBytes($tmp, $deployedBytes)

$decal = (Select-String -Path $tmp -Pattern "Registration Decal" -SimpleMatch).Count
$renewal = (Select-String -Path $tmp -Pattern "Registration Renewal Confirmation" -SimpleMatch).Count
$renewed = (Select-String -Path $tmp -Pattern "RENEWED" -SimpleMatch).Count
$confNo = (Select-String -Path $tmp -Pattern "Confirmation No" -SimpleMatch).Count

Write-Host ""
Write-Host "Verification of deployed bundle:" -ForegroundColor Cyan
Write-Host "  'Registration Decal' occurrences: $decal (expect 0)"
Write-Host "  'Registration Renewal Confirmation': $renewal (expect >=1)"
Write-Host "  'RENEWED' watermark: $renewed (expect >=1)"
Write-Host "  'Confirmation No' field label: $confNo (expect >=1)"
