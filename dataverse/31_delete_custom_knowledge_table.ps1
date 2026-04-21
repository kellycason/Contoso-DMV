<#
  31_delete_custom_knowledge_table.ps1
  ------------------------------------------------------------------
  Cleans up the old custom `dmv_knowledgearticle` table that was
  replaced by the native OOB `knowledgearticle` table (see script 30).

  Removes, in order:
    1. The old table permission (powerpagecomponent type=18 with
       entitylogicalname=dmv_knowledgearticle)
    2. The Portal Web API site settings (Webapi/dmv_knowledgearticle/*)
    3. The custom entity itself (deletes all 40 seeded rows as a
       side effect)
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

# ──────────────────────────────────────────────────────────────────
# 1. Find and delete OLD table permissions that referenced the custom table.
#    Match any type=18 component whose content JSON references
#    "entitylogicalname":"dmv_knowledgearticle".
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Scanning for old table permissions ==="
$comps = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18&`$select=powerpagecomponentid,name,content&`$top=500" -Headers $readH
$toDelete = $comps.value | Where-Object { $_.content -and ($_.content -match '"entitylogicalname"\s*:\s*"dmv_knowledgearticle"') }
Write-Host "  Found $($toDelete.Count) matching permission component(s)"
foreach ($c in $toDelete) {
    Write-Host "  DELETE: $($c.name) ($($c.powerpagecomponentid))"
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($($c.powerpagecomponentid))" -Method Delete -Headers $h -UseBasicParsing | Out-Null
        Write-Host "    OK"
    } catch {
        Write-Host "    ERR: $($_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)))"
    }
}

# ──────────────────────────────────────────────────────────────────
# 2. Delete portal Web API site settings for the old table
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Removing Portal Web API site settings ==="
foreach ($suffix in @("enabled","fields")) {
    $name = "Webapi/dmv_knowledgearticle/$suffix"
    $hits = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_sitesettings?`$filter=mspp_name eq '$name'&`$select=mspp_sitesettingid,mspp_name" -Headers $readH
    foreach ($s in $hits.value) {
        Write-Host "  DELETE: $($s.mspp_name)"
        try {
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_sitesettings($($s.mspp_sitesettingid))" -Method Delete -Headers $h -UseBasicParsing | Out-Null
            Write-Host "    OK"
        } catch {
            Write-Host "    ERR: $($_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)))"
        }
    }
}

# ──────────────────────────────────────────────────────────────────
# 3. Delete the custom entity. This also deletes every row.
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Deleting custom entity dmv_knowledgearticle ==="
$entityUri = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_knowledgearticle')"
try {
    $meta = Invoke-RestMethod -Uri "$entityUri`?`$select=MetadataId,LogicalName" -Headers $readH
    Write-Host "  Found entity MetadataId=$($meta.MetadataId) — deleting..."
    Invoke-WebRequest -Uri $entityUri -Method Delete -Headers $h -UseBasicParsing | Out-Null
    Write-Host "  OK — entity deleted"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "Could not find" -or $msg -match "does not exist" -or $msg -match "404") {
        Write-Host "  (already gone)"
    } else {
        Write-Host "  ERR: $($msg.Substring(0,[Math]::Min(400,$msg.Length)))"
    }
}

Write-Host "`n=== DONE ==="
Write-Host "Custom dmv_knowledgearticle table + 40 rows + Web API settings + permission removed."
Write-Host "Portal now reads exclusively from the native knowledgearticle table."
