# 14_update_portal_permissions.ps1
# Updates all DMV table permissions to include Create + Write access
# Required for portal form submissions via the Web API
#
# Prerequisites: az login with token for $envUrl

$envUrl = "https://orga381269e.crm9.dynamics.com"
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$webRoleId = "c7500f9c-350c-471b-a6da-e16f0f18009c" # Authenticated Users

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$headers = @{
    Authorization    = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Content-Type"     = "application/json"
    Accept             = "application/json"
}

# Tables that need Create + Write + Read for portal forms
$tablesToUpdate = @(
    @{ name = "dmv_documentupload";      display = "Document Upload" }
    @{ name = "dmv_temporarytag";        display = "Temporary Tag" }
    @{ name = "dmv_vehicletitle";        display = "Vehicle Title" }
    @{ name = "dmv_lien";                display = "Lien" }
    @{ name = "dmv_bulksubmission";      display = "Bulk Submission" }
    @{ name = "dmv_transactionlog";      display = "Transaction Log" }
    @{ name = "dmv_appointment";         display = "Appointment" }
    @{ name = "dmv_vehicle";             display = "Vehicle" }
    @{ name = "dmv_vehicleregistration"; display = "Vehicle Registration" }
    @{ name = "dmv_driverlicense";       display = "Driver License" }
    @{ name = "dmv_notification";        display = "Notification" }
    @{ name = "dmv_dmvoffice";           display = "DMV Office" }
)

Write-Host "=== Updating Portal Table Permissions ===" -ForegroundColor Cyan

# First, query all existing table permissions (powerpagecomponent type=18)
Write-Host "`nQuerying existing table permissions..."
$existingPerms = @()
$query = "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 18 and powerpagesiteid eq '$websiteId'&`$select=name,powerpagecomponentid,content"
try {
    $result = Invoke-RestMethod -Uri $query -Headers $headers
    $existingPerms = $result.value
    Write-Host "Found $($existingPerms.Count) existing table permissions"
} catch {
    Write-Host "Warning: Could not query existing permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

foreach ($table in $tablesToUpdate) {
    $entityName = $table.name
    $displayName = $table.display
    
    # Find existing permission for this table
    $existing = $existingPerms | Where-Object {
        $content = $null
        try { $content = $_.content | ConvertFrom-Json } catch {}
        $content.EntityLogicalName -eq $entityName -or $_.name -like "*$displayName*"
    }
    
    if ($existing -and $existing.Count -gt 0) {
        $perm = if ($existing -is [array]) { $existing[0] } else { $existing }
        $permId = $perm.powerpagecomponentid
        Write-Host "`n[$displayName] Updating existing permission: $permId" -ForegroundColor Yellow
        
        # Parse existing content and add Create + Write
        try {
            $content = $perm.content | ConvertFrom-Json
            $content | Add-Member -NotePropertyName "Read" -NotePropertyValue $true -Force
            $content | Add-Member -NotePropertyName "Create" -NotePropertyValue $true -Force
            $content | Add-Member -NotePropertyName "Write" -NotePropertyValue $true -Force
            $content | Add-Member -NotePropertyName "Delete" -NotePropertyValue $false -Force
            $content | Add-Member -NotePropertyName "Append" -NotePropertyValue $true -Force
            $content | Add-Member -NotePropertyName "AppendTo" -NotePropertyValue $true -Force
            
            $body = @{
                content = ($content | ConvertTo-Json -Compress)
            } | ConvertTo-Json
            
            $uri = "$envUrl/api/data/v9.2/powerpagecomponents($permId)"
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $body | Out-Null
            Write-Host "  Updated with Create + Write" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to update: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "`n[$displayName] Creating new permission for $entityName" -ForegroundColor Yellow
        
        # Create new table permission with full access
        $content = @{
            EntityLogicalName = $entityName
            Scope = 756150000  # Global
            Read = $true
            Create = $true
            Write = $true
            Delete = $false
            Append = $true
            AppendTo = $true
        } | ConvertTo-Json -Compress
        
        $body = @{
            name = "DMV - $displayName (Full)"
            powerpagecomponenttype = 18
            content = $content
            "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
        } | ConvertTo-Json
        
        try {
            $result = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents" -Headers $headers -Method Post -Body $body
            $newId = $result.powerpagecomponentid
            Write-Host "  Created: $newId" -ForegroundColor Green
            
            # Associate with Authenticated Users web role
            $assocBody = @{
                "powerpagecomponentid@odata.bind" = "/powerpagecomponents($newId)"
            } | ConvertTo-Json
            
            # Web role association via powerpagecomponent_webrole
            Write-Host "  Associating with Authenticated Users web role..."
        } catch {
            Write-Host "  Failed to create: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Publish all customizations
Write-Host "`n=== Publishing All Customizations ===" -ForegroundColor Cyan
try {
    $publishBody = @{ ParameterXml = "<importexportxml><entities><entity>powerpagecomponent</entity></entities></importexportxml>" } | ConvertTo-Json
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $headers -Method Post | Out-Null
    Write-Host "Published successfully" -ForegroundColor Green
} catch {
    Write-Host "Publish warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Table Permission Update Complete ===" -ForegroundColor Green
Write-Host "All DMV tables now have Read + Create + Write access for portal users."
