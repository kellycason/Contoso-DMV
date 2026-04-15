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

function Label($text) {
    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.Label"
        LocalizedLabels = @(@{
            "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"
            Label = $text
            LanguageCode = 1033
        })
    }
}

function New-Table($schemaName, $displayName, $pluralName, $primaryCol, $primaryDisplay, $hasNotes=$false) {
    $logicalName = $schemaName.ToLower()
    try {
        $check = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId" -Method Get -Headers $h -ErrorAction SilentlyContinue
        Write-Host "  SKIP (exists): $schemaName"
        return $true
    } catch {}

    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName = $schemaName
        DisplayName = (Label $displayName)
        DisplayCollectionName = (Label $pluralName)
        Description = (Label "$displayName table for DMV Digital Services Portal")
        HasActivities = $false
        HasNotes = $hasNotes
        IsActivity = $false
        OwnershipType = "UserOwned"
        IsAuditEnabled = @{ Value = $true; CanBeChanged = $true }
        ChangeTrackingEnabled = $true
        PrimaryNameAttribute = $primaryCol.ToLower()
        Attributes = @(@{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = $primaryCol
            DisplayName = (Label $primaryDisplay)
            Description = (Label "Primary column for $displayName")
            RequiredLevel = @{ Value = "ApplicationRequired"; CanBeChanged = $true }
            MaxLength = 200
            FormatName = @{ Value = "Text" }
            IsPrimaryName = $true
        })
    }

    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $maxRetries = 3
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions" -Method Post -Headers $h -Body $bytes -UseBasicParsing
            Write-Host "  CREATED: $schemaName"
            return $true
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg -match "CustomizationLock" -or $errMsg -match "0x80071151") {
                Write-Host "  LOCKED (attempt $attempt/$maxRetries) - waiting 15s..."
                Start-Sleep -Seconds 15
            } else {
                $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $sr.BaseStream.Position=0
                Write-Host "  FAILED: $schemaName - $($sr.ReadToEnd().Substring(0,300))"
                return $false
            }
        }
    }
    Write-Host "  GAVE UP: $schemaName after $maxRetries attempts"
    return $false
}

$tables = @(
    @("dmv_appointment",     "DMV Appointment",                "DMV Appointments",                "dmv_appointmentid",  "Appointment ID",  $false),
    @("dmv_documentupload",  "Document Upload",                "Document Uploads",                "dmv_documentname",   "Document Name",   $true),
    @("dmv_vehicletitle",    "Vehicle Title",                  "Vehicle Titles",                  "dmv_titlenumber",    "Title Number",    $false),
    @("dmv_lien",            "Lien",                           "Liens",                           "dmv_lienid",         "Lien ID",         $false),
    @("dmv_temporarytag",    "Temporary Tag",                  "Temporary Tags",                  "dmv_tagnumber",      "Tag Number",      $false),
    @("dmv_bulksubmission",  "Bulk Registration Submission",   "Bulk Registration Submissions",   "dmv_batchid",        "Batch ID",        $false),
    @("dmv_transactionlog",  "DMV Transaction Log",            "DMV Transaction Logs",            "dmv_transactionid",  "Transaction ID",  $false),
    @("dmv_notification",    "Notification",                   "Notifications",                   "dmv_notificationid", "Notification ID", $false)
)

$i = 0
foreach ($t in $tables) {
    $i++
    Write-Host "[$i/$($tables.Count)] $($t[1])"
    $result = New-Table $t[0] $t[1] $t[2] $t[3] $t[4] $t[5]
    if ($result -and $i -lt $tables.Count) {
        Write-Host "  Waiting 12s for customization lock to clear..."
        Start-Sleep -Seconds 12
    }
}

Write-Host "`n=== REMAINING TABLES COMPLETE ==="
