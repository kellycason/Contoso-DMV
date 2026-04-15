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
    @{ "@odata.type"="Microsoft.Dynamics.CRM.Label"; LocalizedLabels=@(@{ "@odata.type"="Microsoft.Dynamics.CRM.LocalizedLabel"; Label=$text; LanguageCode=1033 }) }
}

$t = "dmv_dmvoffice"

# Fix 1: Latitude (Decimal, -90 to 90, precision 6)
Write-Host "Adding Latitude..."
$body = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
    SchemaName = "dmv_latitude"; DisplayName = (Label "Latitude")
    RequiredLevel = @{ Value="None"; CanBeChanged=$true }
    MinValue = -90; MaxValue = 90; Precision = 6
} | ConvertTo-Json -Depth 10 -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$t')/Attributes" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  OK"
} catch { Write-Host "  ERR: $($_.Exception.Message.Substring(0,200))" }

Start-Sleep 3

# Fix 2: Longitude (Decimal, -180 to 180, precision 6)
Write-Host "Adding Longitude..."
$body = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
    SchemaName = "dmv_longitude"; DisplayName = (Label "Longitude")
    RequiredLevel = @{ Value="None"; CanBeChanged=$true }
    MinValue = -180; MaxValue = 180; Precision = 6
} | ConvertTo-Json -Depth 10 -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$t')/Attributes" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  OK"
} catch { Write-Host "  ERR: $($_.Exception.Message.Substring(0,200))" }

Start-Sleep 3

# Fix 3: Active (Boolean with default true)
Write-Host "Adding Active..."
$body = @{
    "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
    SchemaName = "dmv_active"; DisplayName = (Label "Active")
    RequiredLevel = @{ Value="ApplicationRequired"; CanBeChanged=$true }
    DefaultValue = $true
    OptionSet = @{
        TrueOption = @{ Value=1; Label=(Label "Yes") }
        FalseOption = @{ Value=0; Label=(Label "No") }
    }
} | ConvertTo-Json -Depth 10 -Compress
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$t')/Attributes" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  OK"
} catch { Write-Host "  ERR: $($_.Exception.Message.Substring(0,200))" }

Write-Host "`nDMV Office fixes complete."
