# 15_refactor_registration.ps1
# Refactors the Vehicle Registration data model into a lifecycle-based design:
#   1. dmv_vehicleregistration — parent registration record (slimmed down)
#   2. dmv_registrationterm     — each registration period / renewal (NEW)
#   3. dmv_registrationpayment  — simplified payment per term (NEW)
#
# Prerequisites: az login with token for $envUrl

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
    @{ "@odata.type"="Microsoft.Dynamics.CRM.Label"; LocalizedLabels=@(@{
        "@odata.type"="Microsoft.Dynamics.CRM.LocalizedLabel"; Label=$text; LanguageCode=1033
    }) }
}

function Add-Col($table, $body) {
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $uri = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes"
    try {
        $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { Write-Host "    (exists, skipped)"; return $true }
        Write-Host "    ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        return $false
    }
}

function Col-String($table, $schema, $display, $req=$false, $maxLen=200) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = $maxLen; FormatName = @{ Value="Text" }
    }
}

function Col-Date($table, $schema, $display, $req=$false, $format="DateOnly") {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        Format = $format; DateTimeBehavior = @{ Value = "UserLocal" }
    }
}

function Col-Currency($table, $schema, $display, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        PrecisionSource = 2
    }
}

function Col-Choice($table, $schema, $display, $options, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    $opts = @(); $val = 100000000
    foreach ($o in $options) { $opts += @{ Value=$val; Label=(Label $o) }; $val++ }
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        OptionSet = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
            IsGlobal = $false; OptionSetType = "Picklist"; Options = $opts
        }
    }
}

function Col-Lookup($table, $schema, $display, $targetTable, $relName, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        SchemaName = $relName
        ReferencedEntity = $targetTable
        ReferencingEntity = $table
        Lookup = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
            SchemaName = $schema; DisplayName = (Label $display)
            RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        }
        CascadeConfiguration = @{
            Assign="NoCascade"; Delete="RemoveLink"; Merge="NoCascade"
            Reparent="NoCascade"; Share="NoCascade"; Unshare="NoCascade"; RollupView="NoCascade"
        }
    }
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    try {
        $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/RelationshipDefinitions" -Method Post -Headers $h -Body $bytes -UseBasicParsing
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { Write-Host "    (exists, skipped)"; return $true }
        Write-Host "    LOOKUP ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        return $false
    }
}

function New-Table($schemaName, $displayName, $pluralName, $primaryCol, $primaryDisplay) {
    $logicalName = $schemaName.ToLower()
    try {
        $null = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId" -Method Get -Headers $h -ErrorAction SilentlyContinue
        Write-Host "  TABLE EXISTS: $schemaName (skipping creation)"
        return
    } catch {}

    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName = $schemaName
        DisplayName = (Label $displayName)
        DisplayCollectionName = (Label $pluralName)
        Description = (Label "$displayName table for DMV Digital Services Portal")
        HasActivities = $false; HasNotes = $false; IsActivity = $false
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
            MaxLength = 200; FormatName = @{ Value = "Text" }; IsPrimaryName = $true
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

# ================================================================
# STEP 1: Create dmv_registrationterm table
# ================================================================
Write-Host "`n=== STEP 1: Create Registration Term table ===" -ForegroundColor Cyan
New-Table "dmv_registrationterm" "Registration Term" "Registration Terms" "dmv_termnumber" "Term Number"
Start-Sleep 8

Write-Host "  Adding columns..."
$t = "dmv_registrationterm"
Col-Choice $t "dmv_termtype"   "Term Type"   @("New","Renewal","Transfer") $true
Col-Choice $t "dmv_termstatus" "Term Status"  @("Active","Pending","Expired") $true
Col-Date   $t "dmv_startdate"  "Start Date"   $true
Col-Date   $t "dmv_enddate"    "End Date"     $true
Col-Date   $t "dmv_issuedate"  "Issue Date"
Col-String $t "dmv_stickernumber" "Sticker/Decal Number"
Write-Host "  Done (Registration Term columns)" -ForegroundColor Green
Start-Sleep 5

# Lookup: term → parent registration
Write-Host "  Adding lookup to Vehicle Registration..."
Col-Lookup $t "dmv_vehicleregistrationid" "Vehicle Registration" "dmv_vehicleregistration" "dmv_vehreg_regterm" $true
Write-Host "  Done (Registration Term lookups)" -ForegroundColor Green
Start-Sleep 5

# ================================================================
# STEP 2: Create dmv_registrationpayment table
# ================================================================
Write-Host "`n=== STEP 2: Create Registration Payment table ===" -ForegroundColor Cyan
New-Table "dmv_registrationpayment" "Registration Payment" "Registration Payments" "dmv_paymentref" "Payment Reference"
Start-Sleep 8

Write-Host "  Adding columns..."
$t = "dmv_registrationpayment"
Col-Currency $t "dmv_amount"    "Amount"
Col-Currency $t "dmv_latefee"   "Late Fee"
Col-Currency $t "dmv_total"     "Total"
Col-Choice   $t "dmv_paymentstatus"  "Payment Status"  @("Unpaid","Paid","Refunded","Waived") $true
Col-Choice   $t "dmv_paymentmethod"  "Payment Method"  @("Credit Card","eCheck","Cash","Money Order")
Col-Date     $t "dmv_paymentdate"    "Payment Date"    $false "DateAndTime"
Col-String   $t "dmv_transactionid"  "Transaction ID"
Write-Host "  Done (Registration Payment columns)" -ForegroundColor Green
Start-Sleep 5

# Lookup: payment → term
Write-Host "  Adding lookup to Registration Term..."
Col-Lookup $t "dmv_registrationtermid" "Registration Term" "dmv_registrationterm" "dmv_regterm_regpayment" $true
Write-Host "  Done (Registration Payment lookups)" -ForegroundColor Green
Start-Sleep 5

# ================================================================
# STEP 3: Add dmv_currenttermid lookup on parent registration
# ================================================================
Write-Host "`n=== STEP 3: Add currenttermid lookup on Vehicle Registration ===" -ForegroundColor Cyan
Col-Lookup "dmv_vehicleregistration" "dmv_currenttermid" "Current Term" "dmv_registrationterm" "dmv_regterm_currentreg"
Write-Host "  Done (Current Term lookup)" -ForegroundColor Green
Start-Sleep 3

# ================================================================
# STEP 4: Publish all customizations
# ================================================================
Write-Host "`n=== STEP 4: Publishing All Customizations ===" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
        "OData-MaxVersion" = "4.0"
        "OData-Version" = "4.0"
    } -Method Post | Out-Null
    Write-Host "  Published successfully" -ForegroundColor Green
} catch {
    Write-Host "  Publish warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ================================================================
# STEP 5: Verify
# ================================================================
Write-Host "`n=== STEP 5: Verification ===" -ForegroundColor Cyan
$readH = @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }

foreach ($entity in @("dmv_registrationterm","dmv_registrationpayment")) {
    try {
        $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$entity')?`$select=LogicalName,EntitySetName,PrimaryNameAttribute" -Headers $readH
        Write-Host "  OK: $($meta.LogicalName) (EntitySet: $($meta.EntitySetName), PrimaryName: $($meta.PrimaryNameAttribute))" -ForegroundColor Green
    } catch {
        Write-Host "  MISSING: $entity" -ForegroundColor Red
    }
}

# Verify the currenttermid lookup exists
try {
    $attr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='dmv_vehicleregistration')/Attributes(LogicalName='dmv_currenttermid')?`$select=LogicalName,AttributeType" -Headers $readH
    Write-Host "  OK: dmv_vehicleregistration.dmv_currenttermid ($($attr.AttributeType))" -ForegroundColor Green
} catch {
    Write-Host "  MISSING: dmv_currenttermid on dmv_vehicleregistration" -ForegroundColor Red
}

Write-Host "`n=== REFACTOR COMPLETE ===" -ForegroundColor Green
Write-Host "New tables: dmv_registrationterm, dmv_registrationpayment"
Write-Host "New lookup: dmv_vehicleregistration.dmv_currenttermid"
Write-Host "Old columns on dmv_vehicleregistration are preserved (non-breaking)."
