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
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { Write-Host "    (exists)"; return $true }
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

function Col-Memo($table, $schema, $display, $maxLen=4000) {
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value="None"; CanBeChanged=$true }
        MaxLength = $maxLen; Format = "TextArea"
    }
}

function Col-Bool($table, $schema, $display, $trueLabel="Yes", $falseLabel="No", $default=$false) {
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value="None"; CanBeChanged=$true }
        DefaultValue = $default
        OptionSet = @{
            TrueOption = @{ Value=1; Label=(Label $trueLabel) }
            FalseOption = @{ Value=0; Label=(Label $falseLabel) }
        }
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

function Col-Currency($table, $schema, $display) {
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value="None"; CanBeChanged=$true }
        PrecisionSource = 2
    }
}

function Col-Email($table, $schema, $display) {
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value="None"; CanBeChanged=$true }
        MaxLength = 200; FormatName = @{ Value="Email" }
    }
}

function Col-Phone($table, $schema, $display) {
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value="None"; CanBeChanged=$true }
        MaxLength = 40; FormatName = @{ Value="Phone" }
    }
}

function Col-Choice($table, $schema, $display, $options, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    $opts = @()
    $val = 100000000
    foreach ($o in $options) {
        $opts += @{ Value=$val; Label=(Label $o) }
        $val++
    }
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
            SchemaName = $schema
            DisplayName = (Label $display)
            RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        }
        CascadeConfiguration = @{
            Assign="NoCascade"; Delete="RemoveLink"; Merge="NoCascade"
            Reparent="NoCascade"; Share="NoCascade"; Unshare="NoCascade"
            RollupView="NoCascade"
        }
    }
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    try {
        $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/RelationshipDefinitions" -Method Post -Headers $h -Body $bytes -UseBasicParsing
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { Write-Host "    (exists)"; return $true }
        Write-Host "    ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        return $false
    }
}

# ════════════════════════════════════════════════════════════
# 1. CREATE TABLE
# ════════════════════════════════════════════════════════════
$tbl = "dmv_licenserenewal"
Write-Host "`n=== Creating License Renewal Table ==="

try {
    $check = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$tbl')?`$select=MetadataId" -Headers $readH
    Write-Host "  TABLE EXISTS: $tbl"
} catch {
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName = "dmv_licenserenewal"
        DisplayName = (Label "License Renewal")
        DisplayCollectionName = (Label "License Renewals")
        Description = (Label "License renewal requests submitted from the citizen portal")
        HasActivities = $false
        HasNotes = $false
        IsActivity = $false
        OwnershipType = "UserOwned"
        IsAuditEnabled = @{ Value = $true; CanBeChanged = $true }
        ChangeTrackingEnabled = $true
        PrimaryNameAttribute = "dmv_renewalid"
        Attributes = @(@{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "dmv_renewalid"
            DisplayName = (Label "Renewal ID")
            Description = (Label "Auto-generated renewal request identifier")
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
        Write-Host "  CREATED: $tbl ($($resp.StatusCode))"
    } catch {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $sr.BaseStream.Position=0
        Write-Host "  FAILED: $($sr.ReadToEnd().Substring(0,400))"
        exit 1
    }
}

Start-Sleep 3  # Let metadata propagate

# ════════════════════════════════════════════════════════════
# 2. ADD COLUMNS
# ════════════════════════════════════════════════════════════
Write-Host "`n=== Adding Columns ==="

# -- Status / Workflow --
Write-Host "`n  [Status]"
Write-Host "    dmv_renewalstatus"
Col-Choice $tbl "dmv_renewalstatus" "Renewal Status" @("Submitted","Under Review","Approved","Denied","Cancelled")

# -- Lookups --
Write-Host "`n  [Lookups]"
Write-Host "    dmv_contactid (Contact)"
Col-Lookup $tbl "dmv_contactid" "Contact" "contact" "dmv_contact_licenserenewal"
Write-Host "    dmv_licenseid (Driver License)"
Col-Lookup $tbl "dmv_licenseid" "Driver License" "dmv_driverlicense" "dmv_driverlicense_licenserenewal"

# -- Identity (Step 1) --
Write-Host "`n  [Identity - Step 1]"
Write-Host "    dmv_licensenumber"
Col-String $tbl "dmv_licensenumber" "License Number" $true
Write-Host "    dmv_dateofbirth"
Col-Date   $tbl "dmv_dateofbirth"   "Date of Birth"  $true
Write-Host "    dmv_ssn4"
Col-String $tbl "dmv_ssn4"          "Last 4 SSN"     $false 4

# -- Personal Details (Step 2) --
Write-Host "`n  [Details - Step 2]"
Write-Host "    dmv_firstname"
Col-String $tbl "dmv_firstname"  "First Name" $true
Write-Host "    dmv_lastname"
Col-String $tbl "dmv_lastname"   "Last Name"  $true
Write-Host "    dmv_email"
Col-Email  $tbl "dmv_email"      "Email"
Write-Host "    dmv_phone"
Col-Phone  $tbl "dmv_phone"      "Phone"
Write-Host "    dmv_streetaddress"
Col-String $tbl "dmv_streetaddress" "Street Address" $false 500
Write-Host "    dmv_city"
Col-String $tbl "dmv_city"       "City"
Write-Host "    dmv_state"
Col-String $tbl "dmv_state"      "State" $false 2
Write-Host "    dmv_zipcode"
Col-String $tbl "dmv_zipcode"    "ZIP Code" $false 10

# -- Medical (Step 3) --
Write-Host "`n  [Medical - Step 3]"
Write-Host "    dmv_visionok"
Col-Bool   $tbl "dmv_visionok"      "Vision OK"
Write-Host "    dmv_seizures"
Col-Bool   $tbl "dmv_seizures"      "Seizure History"
Write-Host "    dmv_lossofconsciousness"
Col-Bool   $tbl "dmv_lossofconsciousness" "Loss of Consciousness"
Write-Host "    dmv_medicalconditions"
Col-Memo   $tbl "dmv_medicalconditions"   "Medical Conditions / Notes"

# -- Payment (Step 4) --
Write-Host "`n  [Payment - Step 4]"
Write-Host "    dmv_renewalfee"
Col-Currency $tbl "dmv_renewalfee"  "Renewal Fee"
Write-Host "    dmv_paymentmethod"
Col-Choice   $tbl "dmv_paymentmethod" "Payment Method" @("Credit Card","Debit Card","eCheck / ACH")
Write-Host "    dmv_paymentconfirmation"
Col-String   $tbl "dmv_paymentconfirmation" "Payment Confirmation" $false 100

# -- Dates --
Write-Host "`n  [Dates]"
Write-Host "    dmv_submitteddate"
Col-Date $tbl "dmv_submitteddate" "Submitted Date" $false "DateAndTime"
Write-Host "    dmv_approveddate"
Col-Date $tbl "dmv_approveddate"  "Approved Date"  $false "DateAndTime"
Write-Host "    dmv_newexpirationdate"
Col-Date $tbl "dmv_newexpirationdate" "New Expiration Date"

# -- Channel --
Write-Host "`n  [Channel]"
Write-Host "    dmv_channel"
Col-Choice $tbl "dmv_channel" "Channel" @("Online Portal","In-Person","Mail","Phone")

Write-Host "`n=== Columns complete ==="

# ════════════════════════════════════════════════════════════
# 3. ENABLE WEB API + TABLE PERMISSIONS
# ════════════════════════════════════════════════════════════
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$webRoleId = "c7500f9c-350c-471b-a6da-e16f0f18009c"  # Authenticated Users

Write-Host "`n=== Enabling Web API ==="
foreach ($pair in @(@("enabled","true"), @("fields","*"))) {
    $name = "Webapi/$tbl/$($pair[0])"
    $ssBody = @{
        mspp_name  = $name
        mspp_value = $pair[1]
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    } | ConvertTo-Json -Compress
    try {
        $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_sitesettings" `
            -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($ssBody)) -UseBasicParsing
        Write-Host "  OK: $name"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists|DuplicateRecord") { Write-Host "  SKIP (exists): $name" }
        else { Write-Host "  ERR: $name - $($msg.Substring(0,[Math]::Min(150,$msg.Length)))" }
    }
}

Write-Host "`n=== Creating Table Permission ==="
# Global scope, CRUD for Authenticated Users
$permContent = @{
    entitylogicalname = $tbl
    entityname = "License Renewal"
    scope = 756150000  # Global
    read = $true
    create = $true
    write = $true
    delete = $false
    append = $true
    appendto = $true
    accountrelationship = $null
    contactrelationship = $null
    parentrelationship = $null
    parententitypermission = $null
    permissionfetchxml = $null
    childTablePermissions = @()
    "adx_entitypermission_webrole" = @($webRoleId)
} | ConvertTo-Json -Compress

$permBody = @{
    name = "DMV - License Renewal (CRUD)"
    powerpagecomponenttype = 18
    content = $permContent
    "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
} | ConvertTo-Json -Compress

try {
    $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents" `
        -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($permBody)) -UseBasicParsing
    Write-Host "  OK: Table permission created"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "already exists|DuplicateRecord") { Write-Host "  SKIP (exists)" }
    else { Write-Host "  ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" }
}

Write-Host "`n=== DONE! dmv_licenserenewal table is ready ==="
Write-Host "Entity set name for Web API: dmv_licenserenewals"
