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
        $null = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId" -Method Get -Headers $h -ErrorAction SilentlyContinue
        Write-Host "  SKIP (exists): $schemaName"
        return
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
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions" -Method Post -Headers $h -Body $bytes -UseBasicParsing
        Write-Host "  CREATED: $schemaName"
    } catch {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $sr.BaseStream.Position=0
        Write-Host "  FAILED: $schemaName - $($sr.ReadToEnd().Substring(0,400))"
    }
}

# Fix: primary name columns renamed to avoid collision with auto-generated GUID PK column
# dmv_appointmentid conflicts -> use dmv_appointmentnumber
# dmv_lienid conflicts -> use dmv_lienreference
# dmv_notificationid conflicts -> use dmv_notificationref

Write-Host "[1/3] DMV Appointment (primary col: dmv_appointmentnumber)"
New-Table "dmv_appointment" "DMV Appointment" "DMV Appointments" "dmv_appointmentnumber" "Appointment ID"

Write-Host "  Waiting 15s..."
Start-Sleep -Seconds 15

Write-Host "[2/3] Lien (primary col: dmv_lienreference)"
New-Table "dmv_lien" "Lien" "Liens" "dmv_lienreference" "Lien ID"

Write-Host "  Waiting 15s..."
Start-Sleep -Seconds 15

Write-Host "[3/3] Notification (primary col: dmv_notificationref)"
New-Table "dmv_notification" "Notification" "Notifications" "dmv_notificationref" "Notification ID"

Write-Host "`n=== FIX COMPLETE ==="
