$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$hR     = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# Scan ALL powerpagecomponents for the bootstrap reference
$r = Invoke-RestMethod -Headers $hR -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$select=powerpagecomponentid,name,powerpagecomponenttype&`$top=5000"
Write-Host "Total components: $($r.value.Count)"
$typeCounts = $r.value | Group-Object powerpagecomponenttype | Sort-Object Count -Descending
$typeCounts | ForEach-Object { Write-Host ("  type {0,-3} = {1,5}" -f $_.Name, $_.Count) }

Write-Host ""
Write-Host "Fetching full content for each to find 'index-CcBGzUdW' ..." -ForegroundColor Cyan
$hits = @()
foreach ($c in $r.value) {
  try {
    $full = Invoke-RestMethod -Headers $hR -Uri "$envUrl/api/data/v9.2/powerpagecomponents($($c.powerpagecomponentid))?`$select=content"
    if ($full.content -and $full.content -match 'index-CcBGzUdW') {
      $hits += [pscustomobject]@{ id=$c.powerpagecomponentid; name=$c.name; type=$c.powerpagecomponenttype }
    }
  } catch {}
}
Write-Host ""
Write-Host "Hits containing 'index-CcBGzUdW':" -ForegroundColor Green
$hits | Format-Table -AutoSize
