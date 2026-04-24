$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h      = @{
  Authorization      = "Bearer $token"
  "OData-Version"    = "4.0"
  "OData-MaxVersion" = "4.0"
  "Content-Type"     = "application/json; charset=utf-8"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

# Find ALL content pages with the SPA bootstrap (not just home — there are 12)
$hR = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }
$pages = Invoke-RestMethod -Headers $hR -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 2&`$select=powerpagecomponentid,name,content&`$top=200"
Write-Host "Found $($pages.value.Count) type-2 (webpage) components"

$v = Get-Date -Format "yyyyMMddHHmmss"
Write-Host "Cache-buster version: $v" -ForegroundColor Cyan

$updated = 0
foreach ($p in $pages.value) {
  $c = $null
  try { $c = $p.content | ConvertFrom-Json } catch { continue }
  $html = $c.copy
  if (-not $html) { continue }
  if ($html -notmatch 'index-CcBGzUdW\.js') { continue }

  # Replace with version query string (idempotent - strips any existing ?v=)
  $newHtml = $html `
    -replace 'index-CcBGzUdW\.js(\?v=[\d]+)?', "index-CcBGzUdW.js?v=$v" `
    -replace 'index-BksZUihr\.css(\?v=[\d]+)?',  "index-BksZUihr.css?v=$v"

  if ($newHtml -eq $html) { continue }

  $c.copy = $newHtml
  $body = @{ content = ($c | ConvertTo-Json -Depth 10 -Compress) } | ConvertTo-Json -Depth 10
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  try {
    Invoke-WebRequest -Headers $h -Method Patch -Uri "$envUrl/api/data/v9.2/powerpagecomponents($($p.powerpagecomponentid))" -Body $bytes -UseBasicParsing | Out-Null
    Write-Host "  Updated: $($p.name)" -ForegroundColor Green
    $updated++
  } catch {
    Write-Host "  FAIL $($p.name): $($_.Exception.Message)" -ForegroundColor Red
  }
}
Write-Host ""
Write-Host "Updated $updated pages with cache-buster ?v=$v" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== PublishAllXml ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $h -Method Post | Out-Null
  Write-Host "Published." -ForegroundColor Green
} catch { Write-Host "Publish WARN: $($_.Exception.Message)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Now hard-refresh (Ctrl+Shift+R) — browser will fetch /assets/index-CcBGzUdW.js?v=$v which bypasses CDN cache." -ForegroundColor Green
