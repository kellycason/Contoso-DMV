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

# ──────────────────────────────────────────────
# 1. Web API Site Settings  (Webapi/<table>/enabled + fields)
# ──────────────────────────────────────────────
$tables = @(
    "dmv_citizenprofile",
    "dmv_driverlicense",
    "dmv_vehicle",
    "dmv_vehicleregistration",
    "dmv_appointment",
    "dmv_documentupload",
    "dmv_dealer",
    "dmv_vehicletitle",
    "dmv_lien",
    "dmv_temporarytag",
    "dmv_bulksubmission",
    "dmv_dmvoffice",
    "dmv_transactionlog",
    "dmv_notification"
)

Write-Host "=== Creating Web API Site Settings ==="
foreach ($t in $tables) {
    foreach ($pair in @(@("enabled","true"), @("fields","*"))) {
        $name = "Webapi/$t/$($pair[0])"
        $body = @{
            mspp_name  = $name
            mspp_value = $pair[1]
            "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
        } | ConvertTo-Json -Compress
        try {
            $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_sitesettings" `
                -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
            Write-Host "  OK: $name"
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match "already exists|DuplicateRecord") {
                Write-Host "  SKIP (exists): $name"
            } else {
                Write-Host "  ERR: $name - $($msg.Substring(0,[Math]::Min(150,$msg.Length)))"
            }
        }
    }
}

# ──────────────────────────────────────────────
# 2. Table Permissions  (Global Read for Authenticated Users)
# ──────────────────────────────────────────────
Write-Host "`n=== Creating Table Permissions ==="

# Scope values for enhanced data model (mspp_entitypermission):
# 756150000 = Global, 756150001 = Contact, 756150002 = Account, 756150003 = Parent, 756150004 = Self
$scopeGlobal  = 756150000
$scopeContact = 756150001

$permissionConfigs = @(
    # Citizen Profile uses Contact scope (dmv_contactid links to portal user)
    @{ table="dmv_citizenprofile"; name="DMV - Citizen Profile (Self)"; scope=$scopeContact; contactCol="dmv_contactid" },
    # All other tables use Global Read for demo simplicity
    @{ table="dmv_driverlicense";       name="DMV - Driver License (Read)";       scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_vehicle";             name="DMV - Vehicle (Read)";              scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_vehicleregistration"; name="DMV - Vehicle Registration (Read)"; scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_appointment";         name="DMV - Appointment (Read)";          scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_documentupload";      name="DMV - Document Upload (Read)";      scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_dealer";              name="DMV - Dealer (Read)";               scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_vehicletitle";        name="DMV - Vehicle Title (Read)";        scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_lien";                name="DMV - Lien (Read)";                 scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_temporarytag";        name="DMV - Temporary Tag (Read)";        scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_bulksubmission";      name="DMV - Bulk Submission (Read)";      scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_dmvoffice";           name="DMV - DMV Office (Read)";           scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_transactionlog";      name="DMV - Transaction Log (Read)";      scope=$scopeGlobal; contactCol=$null },
    @{ table="dmv_notification";        name="DMV - Notification (Read)";         scope=$scopeGlobal; contactCol=$null }
)

foreach ($cfg in $permissionConfigs) {
    $body = @{
        mspp_entitypermissionname = $cfg.name
        mspp_entityname           = $cfg.table
        mspp_scope                = $cfg.scope
        mspp_read                 = $true
        mspp_create               = $false
        mspp_write                = $false
        mspp_delete               = $false
        mspp_append               = $true
        mspp_appendto             = $true
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    }
    if ($cfg.contactCol) {
        $body["mspp_contactidcolumnname"] = $cfg.contactCol
    }
    $json = $body | ConvertTo-Json -Compress
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions" `
            -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing
        # Extract the new entity permission ID from the response Location header
        $epId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
        Write-Host "  OK: $($cfg.name) -> $epId"

        # Associate with Authenticated Users web role
        $assocBody = @{ "@odata.id" = "$envUrl/api/data/v9.2/mspp_webroles($webRoleId)" } | ConvertTo-Json -Compress
        try {
            $null = Invoke-WebRequest `
                -Uri "$envUrl/api/data/v9.2/mspp_entitypermissions($epId)/mspp_entitypermission_webrole/`$ref" `
                -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($assocBody)) -UseBasicParsing
            Write-Host "    Linked to Authenticated Users role"
        } catch {
            Write-Host "    WARN: Role link failed - $($_.Exception.Message.Substring(0,100))"
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists|DuplicateRecord") {
            Write-Host "  SKIP (exists): $($cfg.name)"
        } else {
            Write-Host "  ERR: $($cfg.name) - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        }
    }
}

Write-Host "`n==========================================="
Write-Host "WEB API SETUP COMPLETE"
Write-Host "==========================================="
