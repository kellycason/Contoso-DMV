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
    # Check if exists
    try {
        $check = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId" -Method Get -Headers $h -ErrorAction SilentlyContinue
        Write-Host "  TABLE EXISTS: $schemaName"
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
        Write-Host "  CREATED: $schemaName (Status: $($resp.StatusCode))"
    } catch {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $sr.BaseStream.Position=0
        Write-Host "  FAILED: $schemaName - $($sr.ReadToEnd().Substring(0,300))"
    }
}

# ============================================
# CREATE ALL 14 TABLES (primary columns only)
# ============================================
Write-Host "`n=== CREATING TABLES ==="

Write-Host "`n[1/14] DMV Office (reference table, no custom lookups)"
New-Table "dmv_dmvoffice" "DMV Office" "DMV Offices" "dmv_officename" "Office Name"

Write-Host "`n[2/14] Citizen Profile"
New-Table "dmv_citizenprofile" "Citizen Profile" "Citizen Profiles" "dmv_fullname" "Full Name"

Write-Host "`n[3/14] Dealer"
New-Table "dmv_dealer" "Dealer" "Dealers" "dmv_dealername" "Dealer Name"

Write-Host "`n[4/14] Driver License"
New-Table "dmv_driverlicense" "Driver License" "Driver Licenses" "dmv_licensenumber" "License Number"

Write-Host "`n[5/14] Vehicle"
New-Table "dmv_vehicle" "Vehicle" "Vehicles" "dmv_vin" "VIN"

Write-Host "`n[6/14] Vehicle Registration"
New-Table "dmv_vehicleregistration" "Vehicle Registration" "Vehicle Registrations" "dmv_registrationid" "Registration ID"

Write-Host "`n[7/14] DMV Appointment"
New-Table "dmv_appointment" "DMV Appointment" "DMV Appointments" "dmv_appointmentid" "Appointment ID"

Write-Host "`n[8/14] Document Upload"
New-Table "dmv_documentupload" "Document Upload" "Document Uploads" "dmv_documentname" "Document Name" $true

Write-Host "`n[9/14] Vehicle Title"
New-Table "dmv_vehicletitle" "Vehicle Title" "Vehicle Titles" "dmv_titlenumber" "Title Number"

Write-Host "`n[10/14] Lien"
New-Table "dmv_lien" "Lien" "Liens" "dmv_lienid" "Lien ID"

Write-Host "`n[11/14] Temporary Tag"
New-Table "dmv_temporarytag" "Temporary Tag" "Temporary Tags" "dmv_tagnumber" "Tag Number"

Write-Host "`n[12/14] Bulk Registration Submission"
New-Table "dmv_bulksubmission" "Bulk Registration Submission" "Bulk Registration Submissions" "dmv_batchid" "Batch ID"

Write-Host "`n[13/14] DMV Transaction Log"
New-Table "dmv_transactionlog" "DMV Transaction Log" "DMV Transaction Logs" "dmv_transactionid" "Transaction ID"

Write-Host "`n[14/14] Notification"
New-Table "dmv_notification" "Notification" "Notifications" "dmv_notificationid" "Notification ID"

Write-Host "`n=== ALL TABLES CREATED ==="
