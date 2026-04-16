###############################################################################
# 07_migrate_to_native.ps1
# Migrate from dmv_citizenprofile -> contact, dmv_dealer -> account
# Adds DMV-specific columns to native tables, creates new lookup columns
# on child tables, then deletes the old tables.
###############################################################################
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

function Add-Col($table, $body) {
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $uri = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes"
    try {
        $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
        return "OK"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { return "EXISTS" }
        return "ERR: $($msg.Substring(0,[Math]::Min(120,$msg.Length)))"
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

function Col-Bool($table, $schema, $display, $req=$false, $default=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        DefaultValue = $default
        OptionSet = @{
            TrueOption = @{ Value=1; Label=(Label "Yes") }
            FalseOption = @{ Value=0; Label=(Label "No") }
        }
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

function Col-Int($table, $schema, $display, $req=$false, $min=0, $max=2147483647) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        Format = "None"; MinValue = $min; MaxValue = $max
    }
}

function Col-Memo($table, $schema, $display, $req=$false, $maxLen=10000) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = $maxLen; Format = "TextArea"
    }
}

function Col-Email($table, $schema, $display, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = 200; FormatName = @{ Value="Email" }
    }
}

function Col-Phone($table, $schema, $display, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = 40; FormatName = @{ Value="Phone" }
    }
}

function Add-Lookup($table, $schema, $display, $targetTable, $relName, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        SchemaName = $relName
        ReferencedEntity = $targetTable
        ReferencingEntity = $table
        Lookup = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
            SchemaName = $schema
            DisplayName = (Label $display)
            RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        }
    } | ConvertTo-Json -Depth 10 -Compress
    try {
        $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/RelationshipDefinitions" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
        return "OK"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { return "EXISTS" }
        return "ERR: $($msg.Substring(0,[Math]::Min(120,$msg.Length)))"
    }
}

Write-Host "============================================================"
Write-Host " STEP 1: Add DMV columns to CONTACT table (citizen fields)"
Write-Host "============================================================"
$t = "contact"
# Only adding fields that DON'T already exist on contact
# Contact already has: fullname, address1_line1, address1_city, address1_stateorprovince, address1_postalcode, telephone1
Write-Host "  dateofbirth     -> $(Col-Date $t 'dmv_dateofbirth' 'DMV Date of Birth')"
Write-Host "  last4ssn        -> $(Col-String $t 'dmv_last4ssn' 'Last 4 SSN')"
Write-Host "  preferredlang   -> $(Col-Choice $t 'dmv_preferredlanguage' 'Preferred Language' @('English','Spanish','Other'))"
Write-Host "  mydmvenrolled   -> $(Col-Bool $t 'dmv_mydmvenrolled' 'MyDMV Enrolled')"
Write-Host "  enrollmentdate  -> $(Col-Date $t 'dmv_enrollmentdate' 'MyDMV Enrollment Date')"
Write-Host "  accountverified -> $(Col-Bool $t 'dmv_accountverified' 'DMV Account Verified')"
Write-Host "  profileupdated  -> $(Col-Date $t 'dmv_profileupdated' 'Profile Last Updated' $false 'DateAndTime')"
Start-Sleep 3

Write-Host "`n============================================================"
Write-Host " STEP 2: Add DMV columns to ACCOUNT table (dealer fields)"
Write-Host "============================================================"
$t = "account"
# Account already has: name, address1_line1..., telephone1, emailaddress1
Write-Host "  dealernumber    -> $(Col-String $t 'dmv_dealernumber' 'Dealer Number')"
Write-Host "  dealertype      -> $(Col-Choice $t 'dmv_dealertype' 'Dealer Type' @('New Vehicle','Used Vehicle','Motorcycle','RV','Wholesale','Auction'))"
Write-Host "  licensestatus   -> $(Col-Choice $t 'dmv_licensestatus' 'Dealer License Status' @('Active','Expired','Suspended','Revoked','Pending Renewal'))"
Write-Host "  licenseexp      -> $(Col-Date $t 'dmv_licenseexp' 'Dealer License Expiration')"
Write-Host "  county          -> $(Col-String $t 'dmv_county' 'County')"
Write-Host "  portalenrolled  -> $(Col-Bool $t 'dmv_portalenrolled' 'Dealer Portal Enrolled')"
Write-Host "  suretybond      -> $(Col-String $t 'dmv_suretybond' 'Surety Bond Number')"
Write-Host "  suretybondexp   -> $(Col-Date $t 'dmv_suretybondexp' 'Surety Bond Expiration')"
Write-Host "  annualsales     -> $(Col-Int $t 'dmv_annualsales' 'Annual Sales Volume')"
Write-Host "  bulkupload      -> $(Col-Bool $t 'dmv_bulkupload' 'Bulk Upload Enabled')"
Write-Host "  maxtemptags     -> $(Col-Int $t 'dmv_maxtemptags' 'Max Temp Tags Per Day' $false 0 999)"
Write-Host "  compliancestatus-> $(Col-Choice $t 'dmv_compliancestatus' 'Compliance Status' @('Compliant','Review Required','Non-Compliant'))"
Write-Host "  notes           -> $(Col-Memo $t 'dmv_dealernotes' 'Dealer Notes')"
Start-Sleep 3

Write-Host "`n============================================================"
Write-Host " STEP 3: Add new CONTACT lookup columns on child tables"
Write-Host "  (replacing dmv_citizenprofile lookups)"
Write-Host "============================================================"
# New lookups point to contact instead of dmv_citizenprofile
Write-Host "  driverlicense.contactid     -> $(Add-Lookup 'dmv_driverlicense' 'dmv_contactid' 'Citizen (Contact)' 'contact' 'dmv_contact_driverlicense')"
Write-Host "  vehicle.ownercontactid      -> $(Add-Lookup 'dmv_vehicle' 'dmv_ownercontactid' 'Owner (Contact)' 'contact' 'dmv_contact_vehicle_owner')"
Write-Host "  registration.regcontactid   -> $(Add-Lookup 'dmv_vehicleregistration' 'dmv_regcontactid' 'Registrant (Contact)' 'contact' 'dmv_contact_registration')"
Write-Host "  appointment.contactid       -> $(Add-Lookup 'dmv_appointment' 'dmv_contactid' 'Citizen (Contact)' 'contact' 'dmv_contact_appointment')"
Write-Host "  documentupload.contactid    -> $(Add-Lookup 'dmv_documentupload' 'dmv_contactid' 'Submitted By (Contact)' 'contact' 'dmv_contact_documentupload')"
Write-Host "  vehicletitle.ownercontactid -> $(Add-Lookup 'dmv_vehicletitle' 'dmv_ownercontactid' 'Owner (Contact)' 'contact' 'dmv_contact_title')"
Write-Host "  temporarytag.buyercontactid -> $(Add-Lookup 'dmv_temporarytag' 'dmv_buyercontactid' 'Buyer (Contact)' 'contact' 'dmv_contact_temporarytag')"
Write-Host "  transactionlog.contactid    -> $(Add-Lookup 'dmv_transactionlog' 'dmv_contactid' 'Citizen (Contact)' 'contact' 'dmv_contact_transactionlog')"
Write-Host "  notification.recipcontactid -> $(Add-Lookup 'dmv_notification' 'dmv_recipientcontactid' 'Recipient (Contact)' 'contact' 'dmv_contact_notification')"
Start-Sleep 3

Write-Host "`n============================================================"
Write-Host " STEP 4: Add new ACCOUNT lookup columns on child tables"
Write-Host "  (replacing dmv_dealer lookups)"
Write-Host "============================================================"
Write-Host "  vehicle.owneraccountid      -> $(Add-Lookup 'dmv_vehicle' 'dmv_owneraccountid' 'Owner (Dealer Account)' 'account' 'dmv_account_vehicle_owner')"
Write-Host "  registration.dealeracctid   -> $(Add-Lookup 'dmv_vehicleregistration' 'dmv_dealeracctid' 'Registrant (Dealer Account)' 'account' 'dmv_account_registration')"
Write-Host "  documentupload.dealeracctid -> $(Add-Lookup 'dmv_documentupload' 'dmv_dealeracctid' 'Submitted By (Dealer Account)' 'account' 'dmv_account_documentupload')"
Write-Host "  vehicletitle.owneracctid    -> $(Add-Lookup 'dmv_vehicletitle' 'dmv_owneracctid' 'Owner (Dealer Account)' 'account' 'dmv_account_title')"
Write-Host "  vehicletitle.submitteracctid-> $(Add-Lookup 'dmv_vehicletitle' 'dmv_submitteracctid' 'Submitted By (Dealer Account)' 'account' 'dmv_account_title_submitted')"
Write-Host "  temporarytag.dealeracctid   -> $(Add-Lookup 'dmv_temporarytag' 'dmv_dealeracctid' 'Dealer (Account)' 'account' 'dmv_account_temporarytag')"
Write-Host "  bulksub.dealeracctid        -> $(Add-Lookup 'dmv_bulksubmission' 'dmv_dealeracctid' 'Dealer (Account)' 'account' 'dmv_account_bulksubmission')"
Write-Host "  transactionlog.dealeracctid -> $(Add-Lookup 'dmv_transactionlog' 'dmv_dealeracctid' 'Dealer (Account)' 'account' 'dmv_account_transactionlog')"
Write-Host "  notification.recipacctid    -> $(Add-Lookup 'dmv_notification' 'dmv_recipientacctid' 'Recipient (Dealer Account)' 'account' 'dmv_account_notification')"

Write-Host "`n============================================================"
Write-Host " STEP 5: Publish all changes"
Write-Host "============================================================"
$pubH = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
try {
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Method Post -Headers $pubH -Body '{}' -UseBasicParsing | Out-Null
    Write-Host "  Published OK"
} catch { Write-Host "  Publish error: $($_.Exception.Message)" }

Write-Host "`n============================================================"
Write-Host " DONE - Columns and lookups created"
Write-Host "============================================================"
Write-Host ""
Write-Host 'NEXT STEPS (manual):'
Write-Host '  1. Delete old dmv_citizenprofile and dmv_dealer tables'
Write-Host '     (must first remove old lookup columns that reference them)'
Write-Host '  2. Update seed data to write directly to contact'
Write-Host '  3. Update Liquid FetchXML to use contact instead of citizenprofile'
Write-Host ""
