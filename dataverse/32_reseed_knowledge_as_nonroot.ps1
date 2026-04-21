<#
  32_reseed_knowledge_as_nonroot.ps1
  ------------------------------------------------------------------
  The initial migration created records with isrootarticle=true.
  The OOB system views (All Active Articles, My Active Articles,
  Published Articles, etc.) all filter `isrootarticle eq 0`, so
  nothing shows up.

  Fix: delete all existing and re-create via 30_migrate_to_native_knowledge.ps1
  (which has been updated to create with isrootarticle=false).
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}
$readH = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

# Load slugs from seed so we only touch articles we own
$seedPath = Join-Path $PSScriptRoot "knowledge_seed.json"
$seed = Get-Content $seedPath -Raw | ConvertFrom-Json
$slugs = $seed | ForEach-Object { $_.slug }
Write-Host "Seed has $($slugs.Count) articles to reseed"

# ──────────────────────────────────────────────────────────────────
# 1. Unpublish and delete each existing article
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Deleting existing seeded articles ==="
$deleted = 0
foreach ($slug in $slugs) {
    $r = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/knowledgearticles?`$filter=articlepublicnumber eq '$slug'&`$select=knowledgearticleid,statecode&`$top=5" -Headers $readH
    foreach ($a in $r.value) {
        $id = $a.knowledgearticleid
        # Must unpublish (set to draft) before delete
        if ($a.statecode -ne 0) {
            $draft = @{ statecode = 0; statuscode = 2 } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($id)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($draft)) -UseBasicParsing | Out-Null
            } catch {
                Write-Host "  WARN: unpublish failed for $slug - $($_.Exception.Message.Substring(0,[Math]::Min(150,$_.Exception.Message.Length)))"
            }
        }
        try {
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($id)" -Method Delete -Headers $h -UseBasicParsing | Out-Null
            Write-Host "  DELETED: $slug"
            $deleted++
        } catch {
            Write-Host "  ERR deleting $slug : $($_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)))"
        }
    }
}
Write-Host "Total deleted: $deleted"

# ──────────────────────────────────────────────────────────────────
# 2. Re-run the migration script (now creates with isrootarticle=false)
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Re-running migration script ==="
& (Join-Path $PSScriptRoot "30_migrate_to_native_knowledge.ps1")
