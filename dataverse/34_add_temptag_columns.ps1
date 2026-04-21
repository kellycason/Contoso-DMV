<#
  34_add_temptag_columns.ps1

  Adds the temporary-tag source-of-truth columns to dmv_registrationrenewal:
    - dmv_temptagnumber        (Text, 20)   e.g. TMP-2026-4642
    - dmv_temptagexpirationdate (DateOnly)  Approved date + 30 days

  Then backfills existing Approved records (renewalstatus = 100000002) so
  both the portal PDF and any Power Automate flow can read the same values.
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

function Label($text) {
    @{ "@odata.type"="Microsoft.Dynamics.CRM.Label"; LocalizedLabels=@(@{ "@odata.type"="Microsoft.Dynamics.CRM.LocalizedLabel"; Label=$text; LanguageCode=1033 }) }
}

function Add-Col($table, $body) {
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $uri = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes"
    try {
        $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
        Write-Host "  OK: $($body.SchemaName)"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists|duplicate") { Write-Host "  SKIP (exists): $($body.SchemaName)" }
        else { Write-Host "  ERR: $($body.SchemaName) - $($msg.Substring(0,[Math]::Min(250,$msg.Length)))" }
    }
}

$tbl = "dmv_registrationrenewal"

Write-Host "`n=== Adding temp-tag columns to $tbl ==="

Add-Col $tbl @{
    "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
    SchemaName = "dmv_temptagnumber"
    DisplayName = (Label "Temporary Tag Number")
    Description = (Label "Generated at approval. Format: TMP-YYYY-####.")
    RequiredLevel = @{ Value="None"; CanBeChanged=$true }
    MaxLength = 20
    FormatName = @{ Value="Text" }
}

Add-Col $tbl @{
    "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
    SchemaName = "dmv_temptagexpirationdate"
    DisplayName = (Label "Temporary Tag Expiration")
    Description = (Label "Approved date + 30 days. Populated at approval time.")
    RequiredLevel = @{ Value="None"; CanBeChanged=$true }
    Format = "DateOnly"
    DateTimeBehavior = @{ Value = "DateOnly" }
}

# ════════════════════════════════════════════════════════════
# BACKFILL existing Approved records
# ════════════════════════════════════════════════════════════
Write-Host "`n=== Backfilling existing Approved records ==="

# Wait for the new columns to become queryable (metadata cache can lag)
Write-Host "  Waiting for metadata cache to refresh..."
$approved = $null
for ($i = 1; $i -le 12; $i++) {
    Start-Sleep -Seconds 10
    try {
        $select = "dmv_registrationrenewalid,dmv_renewalid,dmv_approveddate,dmv_temptagnumber,dmv_temptagexpirationdate"
        $filter = "dmv_renewalstatus eq 100000002"
        $approved = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=$filter&`$select=$select&`$top=500" -Headers $readH
        Write-Host "  Metadata ready after $($i * 10)s"
        break
    } catch {
        if ($_.Exception.Message -match "dmv_temptagnumber") {
            Write-Host "  still waiting... ($($i * 10)s)"
            continue
        }
        throw
    }
}
if (-not $approved) { throw "Metadata cache did not refresh in time; rerun script to backfill." }

Write-Host "  Found $($approved.value.Count) approved records"

$updated = 0
$skipped = 0
foreach ($r in $approved.value) {
    # Skip if already populated
    if ($r.dmv_temptagnumber -and $r.dmv_temptagexpirationdate) {
        $skipped++
        continue
    }

    # Base the expiration on the approved date (fall back to today if missing)
    $base = if ($r.dmv_approveddate) { [DateTime]::Parse($r.dmv_approveddate) } else { Get-Date }
    $expiry = $base.AddDays(30).ToString("yyyy-MM-dd")

    # Tag number — derive deterministically from the renewalid so reruns stay stable
    $suffix = if ($r.dmv_renewalid) {
        ($r.dmv_renewalid -split '-')[-1]
    } else {
        (Get-Random -Minimum 1000 -Maximum 9999).ToString()
    }
    $tagNum = "TMP-$($base.Year)-$suffix"

    $patch = @{
        dmv_temptagnumber = $tagNum
        dmv_temptagexpirationdate = $expiry
    } | ConvertTo-Json -Compress

    try {
        Invoke-WebRequest `
            -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($r.dmv_registrationrenewalid))" `
            -Method Patch -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
        Write-Host "  UPDATED: $($r.dmv_renewalid) -> $tagNum / $expiry"
        $updated++
    } catch {
        Write-Host "  ERR: $($r.dmv_renewalid) - $($_.Exception.Message.Substring(0,[Math]::Min(150,$_.Exception.Message.Length)))"
    }
}

Write-Host "`n=== DONE ==="
Write-Host "  Updated: $updated"
Write-Host "  Already populated (skipped): $skipped"
