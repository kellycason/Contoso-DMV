$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

# Read file and manually escape for JSON
$css = [System.IO.File]::ReadAllText("C:\Users\kellycason\source\repos\Contoso-DMV\_header_v3.html")
# Remove BOM
if ($css.Length -gt 0 -and [int]$css[0] -eq 65279) { $css = $css.Substring(1) }

Add-Type -AssemblyName System.Web
$escaped = [System.Web.HttpUtility]::JavaScriptStringEncode($css)
$json = '{"mspp_source":"' + $escaped + '"}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
Write-Host "Payload: $($bytes.Length) bytes"

$h = @{
  Authorization   = "Bearer $token"
  "Content-Type"  = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "If-Match"      = "*"
}

$uri = "$envUrl/api/data/v9.2/mspp_webtemplates(990d6c35-0a56-47ca-b151-bff1bad21af7)"

try {
  $resp = Invoke-WebRequest -Uri $uri -Method Patch -Headers $h -Body $bytes -UseBasicParsing
  Write-Host "DEPLOY SUCCESS: $($resp.StatusCode)"
} catch {
  Write-Host "DEPLOY FAILED: $($_.Exception.Message)"
  try {
    $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $sr.BaseStream.Position = 0
    $errBody = $sr.ReadToEnd()
    Write-Host "Error body (first 500): $($errBody.Substring(0, [Math]::Min(500, $errBody.Length)))"
  } catch {}
}

# Verify
$h2 = @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
$r = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webtemplates(990d6c35-0a56-47ca-b151-bff1bad21af7)?`$select=mspp_source" -Method Get -Headers $h2
Write-Host "Verify length: $($r.mspp_source.Length)"
Write-Host "Has grid: $($r.mspp_source.Contains('1fr 1fr'))"
Write-Host "Has V3: $($r.mspp_source.Contains('V3'))"
