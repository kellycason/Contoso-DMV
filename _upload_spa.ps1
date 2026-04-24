$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$hd = @{
  Authorization="Bearer $token"
  "Content-Type"="application/octet-stream"
  "OData-MaxVersion"="4.0"
  "OData-Version"="4.0"
  "If-Match"="*"
  "MSCRM.SolutionUniqueName"="DMVDigitalServicesPortal"
}
$hd["x-ms-file-name"] = "index-CcBGzUdW.js"
$b = [System.IO.File]::ReadAllBytes("dist/assets/index-CcBGzUdW.js")
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents(60a6be7b-c4e7-4e06-97eb-31f38b5f9025)/filecontent" -Method Patch -Headers $hd -Body $b -UseBasicParsing | Out-Null
Write-Host "JS uploaded ($($b.Length) bytes)"
$hd["x-ms-file-name"] = "index-BksZUihr.css"
$b = [System.IO.File]::ReadAllBytes("dist/assets/index-BksZUihr.css")
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents(b10c112e-3f41-4cb1-89c3-246353b5f5eb)/filecontent" -Method Patch -Headers $hd -Body $b -UseBasicParsing | Out-Null
Write-Host "CSS uploaded ($($b.Length) bytes)"
