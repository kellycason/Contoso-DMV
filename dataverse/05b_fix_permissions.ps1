$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$webRoleId = "c7500f9c-350c-471b-a6da-e16f0f18009c"  # Authenticated Users

# Delete test record first
Write-Host "Cleaning up test record..."
$existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions?`$filter=mspp_entitylogicalname eq 'dmv_vehicle'&`$select=mspp_entitypermissionid" -Headers @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
foreach ($e in $existing.value) {
    try {
        Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($($e.mspp_entitypermissionid))" -Method Delete -Headers @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
        Write-Host "  Deleted: $($e.mspp_entitypermissionid)"
    } catch { Write-Host "  Skip delete" }
}

$scopeGlobal  = 756150000
$scopeContact = 756150001

$permissionConfigs = @(
    @{ table="dmv_citizenprofile"; name="DMV - Citizen Profile (Contact)"; scope=$scopeContact; rel="dmv_contact_citizenprofile" },
    @{ table="dmv_driverlicense";       name="DMV - Driver License (Read)";       scope=$scopeGlobal; rel=$null },
    @{ table="dmv_vehicle";             name="DMV - Vehicle (Read)";              scope=$scopeGlobal; rel=$null },
    @{ table="dmv_vehicleregistration"; name="DMV - Vehicle Registration (Read)"; scope=$scopeGlobal; rel=$null },
    @{ table="dmv_appointment";         name="DMV - Appointment (Read)";          scope=$scopeGlobal; rel=$null },
    @{ table="dmv_documentupload";      name="DMV - Document Upload (Read)";      scope=$scopeGlobal; rel=$null },
    @{ table="dmv_dealer";              name="DMV - Dealer (Read)";               scope=$scopeGlobal; rel=$null },
    @{ table="dmv_vehicletitle";        name="DMV - Vehicle Title (Read)";        scope=$scopeGlobal; rel=$null },
    @{ table="dmv_lien";                name="DMV - Lien (Read)";                 scope=$scopeGlobal; rel=$null },
    @{ table="dmv_temporarytag";        name="DMV - Temporary Tag (Read)";        scope=$scopeGlobal; rel=$null },
    @{ table="dmv_bulksubmission";      name="DMV - Bulk Submission (Read)";      scope=$scopeGlobal; rel=$null },
    @{ table="dmv_dmvoffice";           name="DMV - DMV Office (Read)";           scope=$scopeGlobal; rel=$null },
    @{ table="dmv_transactionlog";      name="DMV - Transaction Log (Read)";      scope=$scopeGlobal; rel=$null },
    @{ table="dmv_notification";        name="DMV - Notification (Read)";         scope=$scopeGlobal; rel=$null }
)

Write-Host "`n=== Creating Table Permissions ==="
foreach ($cfg in $permissionConfigs) {
    $body = @{
        mspp_entityname         = $cfg.name
        mspp_entitylogicalname  = $cfg.table
        mspp_scope              = $cfg.scope
        mspp_read               = $true
        mspp_create             = $false
        mspp_write              = $false
        mspp_delete             = $false
        mspp_append             = $true
        mspp_appendto           = $true
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    }
    if ($cfg.rel) {
        $body["mspp_contactrelationship"] = $cfg.rel
    }
    $json = $body | ConvertTo-Json -Compress
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions" `
            -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing
        $epId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
        Write-Host "  OK: $($cfg.name) -> $epId"

        # Associate with Authenticated Users web role
        $assocBody = @{ "@odata.id" = "$envUrl/api/data/v9.2/mspp_webroles($webRoleId)" } | ConvertTo-Json -Compress
        try {
            $null = Invoke-WebRequest `
                -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($epId)/mspp_entitypermission_webrole/`$ref" `
                -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($assocBody)) -UseBasicParsing
            Write-Host "    -> Linked to Authenticated Users"
        } catch {
            Write-Host "    WARN: Role link: $($_.Exception.Message.Substring(0,[Math]::Min(100,$_.Exception.Message.Length)))"
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ERR: $($cfg.name) - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
    }
}

Write-Host "`n=== DONE ==="
