$envUrl="https://orga381269e.crm9.dynamics.com"
$token=az account get-access-token --resource $envUrl --query accessToken -o tsv
$h=@{ Authorization="Bearer $token"; "OData-Version"="4.0" }

$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents(60a6be7b-c4e7-4e06-97eb-31f38b5f9025)?`$select=name,modifiedon,filesize"
Write-Host "DV JS: name=$($r.name) size=$($r.filesize) modified=$($r.modifiedon)"
Write-Host "Local JS bytes: $((Get-Item dist/assets/index-CcBGzUdW.js).Length)"

$bytes = Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents(60a6be7b-c4e7-4e06-97eb-31f38b5f9025)/filecontent" -UseBasicParsing
$serverStr = [System.Text.Encoding]::UTF8.GetString($bytes.Content)
Write-Host "DV filecontent bytes: $($bytes.RawContentLength)"
Write-Host "DV contains 'kellycason': $($serverStr.Contains('kellycason'))"
Write-Host "DV contains 'Jordan': $($serverStr.Contains('Jordan'))"
Write-Host "DV contains 'Sam': $($serverStr.Contains('Sam'))"
$serverStr = $null; [GC]::Collect()

Write-Host ""
Write-Host "=== CDN (unauthenticated - may be login page) ==="
try {
  $cdn = Invoke-WebRequest -Uri "https://site-y5jzr.powerappsportals.us/assets/index-CcBGzUdW.js" -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
  Write-Host "CDN status=$($cdn.StatusCode) bytes=$($cdn.RawContentLength)"
  Write-Host "CDN etag: $($cdn.Headers['ETag'])"
  Write-Host "CDN last-modified: $($cdn.Headers['Last-Modified'])"
  Write-Host "CDN content-type: $($cdn.Headers['Content-Type'])"
} catch {
  Write-Host "CDN error: $($_.Exception.Message)"
}
