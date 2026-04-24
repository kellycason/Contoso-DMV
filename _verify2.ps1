$envUrl="https://orga381269e.crm9.dynamics.com"
$token=az account get-access-token --resource $envUrl --query accessToken -o tsv
$h=@{ Authorization="Bearer $token"; "OData-Version"="4.0" }

$r = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents(60a6be7b-c4e7-4e06-97eb-31f38b5f9025)?`$select=name,modifiedon,filesize"
"DV JS: name=$($r.name) size=$($r.filesize) modified=$($r.modifiedon)"
"Local JS bytes: $((Get-Item dist/assets/index-CcBGzUdW.js).Length)"

$bytes = Invoke-WebRequest -Headers $h -Uri "$envUrl/api/data/v9.2/powerpagecomponents(60a6be7b-c4e7-4e06-97eb-31f38b5f9025)/filecontent" -UseBasicParsing
$serverStr = [System.Text.Encoding]::UTF8.GetString($bytes.Content)
"DV filecontent bytes: $($bytes.RawContentLength)"
"DV contains 'kellycason': $($serverStr.Contains('kellycason'))"
"DV contains 'Jordan': $($serverStr.Contains('Jordan'))"
"DV contains 'Sam': $($serverStr.Contains('Sam'))"

try {
  $cdn = Invoke-WebRequest -Uri "https://site-y5jzr.powerappsportals.us/assets/index-CcBGzUdW.js" -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
  $cdnStr = [System.Text.Encoding]::UTF8.GetString($cdn.Content)
  "CDN status=$($cdn.StatusCode) bytes=$($cdn.RawContentLength)"
  "CDN contains 'kellycason': $($cdnStr.Contains('kellycason'))"
  "CDN contains 'Jordan': $($cdnStr.Contains('Jordan'))"
  "CDN etag: $($cdn.Headers['ETag'])"
  "CDN last-modified: $($cdn.Headers['Last-Modified'])"
} catch {
  "CDN error: $($_.Exception.Message)"
}
