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
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { return $true } # skip existing
        if ($msg -match "CustomizationLock|0x80071151") {
            Write-Host "    LOCK - waiting 10s..."
            Start-Sleep 10
            try {
                $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
                return $true
            } catch {
                Write-Host "    RETRY FAILED: $($_.Exception.Message.Substring(0,100))"
                return $false
            }
        }
        Write-Host "    ERR: $($msg.Substring(0,[Math]::Min(150,$msg.Length)))"
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

function Col-Memo($table, $schema, $display, $req=$false, $maxLen=10000) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = $maxLen; Format = "TextArea"
    }
}

function Col-Int($table, $schema, $display, $req=$false, $min=-2147483648, $max=2147483647) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        Format = "None"; MinValue = $min; MaxValue = $max
    }
}

function Col-Bool($table, $schema, $display, $req=$false, $trueLabel="Yes", $falseLabel="No", $default=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
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

function Col-Currency($table, $schema, $display, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        PrecisionSource = 2
    }
}

function Col-Decimal($table, $schema, $display, $req=$false, $min=0, $max=1000000000, $prec=2) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MinValue = $min; MaxValue = $max; Precision = $prec
    }
}

function Col-Url($table, $schema, $display, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        MaxLength = 2000; FormatName = @{ Value="Url" }
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
            IsGlobal = $false
            OptionSetType = "Picklist"
            Options = $opts
        }
    }
}

function Col-MultiChoice($table, $schema, $display, $options, $req=$false) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    $opts = @()
    $val = 100000000
    foreach ($o in $options) {
        $opts += @{ Value=$val; Label=(Label $o) }
        $val++
    }
    Add-Col $table @{
        "@odata.type" = "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata"
        SchemaName = $schema; DisplayName = (Label $display)
        RequiredLevel = @{ Value=$rl; CanBeChanged=$true }
        OptionSet = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
            IsGlobal = $false
            OptionSetType = "Picklist"
            Options = $opts
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
            Assign = "NoCascade"; Delete = "RemoveLink"; Merge = "NoCascade"
            Reparent = "NoCascade"; Share = "NoCascade"; Unshare = "NoCascade"
            RollupView = "NoCascade"
        }
    }
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $uri = "$envUrl/api/data/v9.2/RelationshipDefinitions"
    try {
        $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { return $true }
        if ($msg -match "CustomizationLock|0x80071151") {
            Write-Host "    LOCK on lookup - waiting 10s..."
            Start-Sleep 10
            try {
                $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing
                return $true
            } catch {
                Write-Host "    RETRY FAILED: $($_.Exception.Message.Substring(0,150))"
                return $false
            }
        }
        Write-Host "    LOOKUP ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        return $false
    }
}

$ok = 0; $fail = 0

# ================================================================
# TABLE 1: Citizen Profile (dmv_citizenprofile)
# ================================================================
Write-Host "`n=== [1/14] Citizen Profile ==="
$t = "dmv_citizenprofile"
# Lookup to Contact
Col-Lookup $t "dmv_contactid" "Contact" "contact" "dmv_contact_citizenprofile" $true
Col-Date $t "dmv_dateofbirth" "Date of Birth" $true
Col-String $t "dmv_last4ssn" "Last 4 SSN"
Col-String $t "dmv_address1" "Mailing Address Line 1" $true
Col-String $t "dmv_address2" "Mailing Address Line 2"
Col-String $t "dmv_city" "City" $true
Col-String $t "dmv_state" "State" $true
Col-String $t "dmv_zipcode" "ZIP Code" $true 20
Col-Phone $t "dmv_phone" "Phone Number"
Col-Choice $t "dmv_preferredlanguage" "Preferred Language" @("English","Spanish","Other")
Col-Bool $t "dmv_myenrolled" "MyDMV Enrolled" $true
Col-Date $t "dmv_enrollmentdate" "Enrollment Date"
Col-Bool $t "dmv_accountverified" "Account Verified" $true
Col-Date $t "dmv_profileupdated" "Profile Last Updated" $false "DateAndTime"
Write-Host "  Done (Citizen Profile)"
Start-Sleep 5

# ================================================================
# TABLE 2: Driver License (dmv_driverlicense)
# ================================================================
Write-Host "`n=== [2/14] Driver License ==="
$t = "dmv_driverlicense"
Col-Lookup $t "dmv_citizenprofileid" "Citizen Profile" "dmv_citizenprofile" "dmv_citizenprofile_driverlicense" $true
Col-Choice $t "dmv_licenseclass" "License Class" @("A (CDL)","B (CDL)","C (Standard)","M (Motorcycle)","ID Only") $true
Col-Choice $t "dmv_licensestatus" "License Status" @("Active","Expired","Suspended","Revoked","Pending Renewal","Cancelled") $true
Col-Date $t "dmv_issuedate" "Issue Date" $true
Col-Date $t "dmv_expirationdate" "Expiration Date" $true
Col-Int $t "dmv_daystoexpiration" "Days Until Expiration"
Col-Date $t "dmv_renewaleligibledate" "Renewal Eligible Date"
Col-Bool $t "dmv_realidcompliant" "REAL ID Compliant" $true
Col-Choice $t "dmv_realidstatus" "REAL ID Application Status" @("Not Started","In Progress","Documents Submitted","Approved","Denied")
Col-Url $t "dmv_photourl" "License Photo URL"
Col-MultiChoice $t "dmv_restrictions" "Restrictions" @("Corrective Lenses","Daylight Only","No Highway","Automatic Only","Other")
Col-MultiChoice $t "dmv_endorsements" "Endorsements" @("HazMat","Passenger","School Bus","Tanker","Double/Triple","Other")
Col-Choice $t "dmv_renewalmethod" "Last Renewal Method" @("Online","In-Person","Mail")
Col-Date $t "dmv_lastrenewdate" "Last Renewal Date"
Col-Int $t "dmv_renewalcount" "Renewal Count" $false 0 999
Col-Bool $t "dmv_onlineeligible" "Online Renewal Eligible" $true
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Driver License)"
Start-Sleep 5

# ================================================================
# TABLE 3: Vehicle (dmv_vehicle)
# ================================================================
Write-Host "`n=== [3/14] Vehicle ==="
$t = "dmv_vehicle"
Col-Int $t "dmv_year" "Year" $true 1900 2030
Col-String $t "dmv_make" "Make" $true
Col-String $t "dmv_model" "Model" $true
Col-String $t "dmv_trim" "Trim"
Col-Choice $t "dmv_bodystyle" "Body Style" @("Sedan","SUV","Truck","Van","Motorcycle","RV","Other")
Col-String $t "dmv_color" "Color"
Col-Choice $t "dmv_fueltype" "Fuel Type" @("Gasoline","Diesel","Electric","Hybrid","Hydrogen")
Col-Choice $t "dmv_weightclass" "Weight Class" @("Under 6000 lbs","6001-10000 lbs","10001-26000 lbs","Over 26000 lbs")
Col-String $t "dmv_platenumber" "Plate Number"
Col-Choice $t "dmv_platetype" "Plate Type" @("Standard","Personalized","Dealer","Exempt","Temporary")
Col-String $t "dmv_platestate" "Plate State" $false 5
Col-Lookup $t "dmv_ownercitizenid" "Current Owner (Citizen)" "dmv_citizenprofile" "dmv_citizenprofile_vehicle_owner"
Col-Lookup $t "dmv_ownerdealerid" "Current Owner (Dealer)" "dmv_dealer" "dmv_dealer_vehicle_owner"
Col-Int $t "dmv_odometer" "Odometer (Miles)" $false 0
Col-Currency $t "dmv_msrp" "MSRP"
Col-Bool $t "dmv_salvagetitle" "Salvage Title" $true
Col-Bool $t "dmv_outofstate" "Out-of-State Vehicle" $true
Col-Choice $t "dmv_insurancestatus" "Insurance Status" @("Verified","Unverified","Lapsed")
Col-String $t "dmv_insurancecarrier" "Insurance Carrier"
Col-String $t "dmv_insurancepolicy" "Insurance Policy Number"
Col-Date $t "dmv_insuranceexp" "Insurance Expiration Date"
Write-Host "  Done (Vehicle)"
Start-Sleep 5

# ================================================================
# TABLE 4: Vehicle Registration (dmv_vehicleregistration)
# ================================================================
Write-Host "`n=== [4/14] Vehicle Registration ==="
$t = "dmv_vehicleregistration"
Col-Lookup $t "dmv_vehicleid" "Vehicle" "dmv_vehicle" "dmv_vehicle_registration" $true
Col-Lookup $t "dmv_registrantid" "Registrant (Citizen)" "dmv_citizenprofile" "dmv_citizenprofile_registration"
Col-Lookup $t "dmv_dealerregistrantid" "Registrant (Dealer)" "dmv_dealer" "dmv_dealer_registration"
Col-Choice $t "dmv_regstatus" "Registration Status" @("Active","Expired","Pending Payment","Pending Inspection","Suspended","Cancelled") $true
Col-Choice $t "dmv_regtype" "Registration Type" @("New","Renewal","Transfer","Out-of-State") $true
Col-Int $t "dmv_regyear" "Registration Year" $true 2000 2050
Col-Date $t "dmv_effectivedate" "Effective Date" $true
Col-Date $t "dmv_expirationdate" "Expiration Date" $true
Col-Int $t "dmv_daystoexpiration" "Days Until Expiration"
Col-Date $t "dmv_renewaleligible" "Renewal Eligible Date"
Col-Bool $t "dmv_onlineeligible" "Online Renewal Eligible" $true
Col-Currency $t "dmv_fee" "Registration Fee"
Col-Currency $t "dmv_latefee" "Late Fee"
Col-Currency $t "dmv_totaldue" "Total Amount Due"
Col-Choice $t "dmv_paymentstatus" "Payment Status" @("Unpaid","Paid","Refunded","Waived")
Col-Date $t "dmv_paymentdate" "Payment Date" $false "DateAndTime"
Col-String $t "dmv_paymenttransactionid" "Payment Transaction ID"
Col-Choice $t "dmv_paymentmethod" "Payment Method" @("Credit Card","eCheck","Cash","Money Order")
Col-String $t "dmv_stickernumber" "Sticker/Decal Number"
Col-String $t "dmv_county" "County"
Col-Date $t "dmv_submitteddate" "Submitted Date" $false "DateAndTime"
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Vehicle Registration)"
Start-Sleep 5

# ================================================================
# TABLE 5: DMV Appointment (dmv_appointment)
# ================================================================
Write-Host "`n=== [5/14] DMV Appointment ==="
$t = "dmv_appointment"
Col-Lookup $t "dmv_citizenprofileid" "Citizen Profile" "dmv_citizenprofile" "dmv_citizenprofile_appointment" $true
Col-Lookup $t "dmv_officeid" "DMV Office" "dmv_dmvoffice" "dmv_dmvoffice_appointment" $true
Col-Choice $t "dmv_servicetype" "Service Type" @("REAL ID","License Renewal","Vehicle Inspection","Road Test","Title Transfer","General") $true
Col-Date $t "dmv_appointmentdate" "Appointment Date" $true
Col-String $t "dmv_appointmenttime" "Appointment Time" $true 20
Col-Int $t "dmv_duration" "Duration (Minutes)" $false 0 480
Col-Choice $t "dmv_status" "Status" @("Scheduled","Confirmed","Checked In","Completed","No-Show","Cancelled") $true
Col-Bool $t "dmv_confirmationsent" "Confirmation Sent" $true
Col-Bool $t "dmv_remindersent" "Reminder Sent" $true
Col-Date $t "dmv_checkintime" "Check-In Time" $false "DateAndTime"
Col-Date $t "dmv_completiontime" "Completion Time" $false "DateAndTime"
Col-Lookup $t "dmv_relatedlicenseid" "Related License" "dmv_driverlicense" "dmv_driverlicense_appointment"
Col-Lookup $t "dmv_relatedregid" "Related Registration" "dmv_vehicleregistration" "dmv_vehiclereg_appointment"
Col-Memo $t "dmv_notes" "Notes / Special Needs"
Col-String $t "dmv_cancelreason" "Cancellation Reason"
Write-Host "  Done (DMV Appointment)"
Start-Sleep 5

# ================================================================
# TABLE 6: Document Upload (dmv_documentupload)
# ================================================================
Write-Host "`n=== [6/14] Document Upload ==="
$t = "dmv_documentupload"
Col-Choice $t "dmv_documenttype" "Document Type" @("Proof of Identity","Proof of Residency","Insurance Certificate","Vehicle Title","Lien Release","Other") $true
Col-Lookup $t "dmv_citizenid" "Submitted By (Citizen)" "dmv_citizenprofile" "dmv_citizenprofile_documentupload"
Col-Lookup $t "dmv_dealerid" "Submitted By (Dealer)" "dmv_dealer" "dmv_dealer_documentupload"
Col-Lookup $t "dmv_licenseid" "Related License" "dmv_driverlicense" "dmv_driverlicense_documentupload"
Col-Lookup $t "dmv_registrationid" "Related Registration" "dmv_vehicleregistration" "dmv_vehiclereg_documentupload"
Col-Lookup $t "dmv_titleid" "Related Title" "dmv_vehicletitle" "dmv_vehicletitle_documentupload"
Col-Url $t "dmv_fileurl" "File URL"
Col-Int $t "dmv_filesize" "File Size (KB)" $false 0
Col-String $t "dmv_filetype" "File Type" $false 20
Col-Date $t "dmv_uploaddate" "Upload Date" $true "DateAndTime"
Col-Choice $t "dmv_verificationstatus" "Verification Status" @("Pending Review","Accepted","Rejected","Expired") $true
Col-Date $t "dmv_verifieddate" "Verified Date" $false "DateAndTime"
Col-Memo $t "dmv_rejectionreason" "Rejection Reason"
Col-Date $t "dmv_expirationdate" "Expiration Date"
Col-Memo $t "dmv_aiextracteddata" "AI Extracted Data"
Col-Decimal $t "dmv_aiconfidence" "AI Confidence Score" $false 0 1 4
Write-Host "  Done (Document Upload)"
Start-Sleep 5

# ================================================================
# TABLE 7: Dealer (dmv_dealer)
# ================================================================
Write-Host "`n=== [7/14] Dealer ==="
$t = "dmv_dealer"
Col-String $t "dmv_dealernumber" "Dealer Number" $true
Col-Choice $t "dmv_dealertype" "Dealer Type" @("New Vehicle","Used Vehicle","Motorcycle","RV","Wholesale","Auction") $true
Col-Choice $t "dmv_licensestatus" "License Status" @("Active","Expired","Suspended","Revoked","Pending Renewal") $true
Col-Date $t "dmv_licenseexp" "License Expiration Date" $true
Col-String $t "dmv_address1" "Address Line 1" $true
Col-String $t "dmv_address2" "Address Line 2"
Col-String $t "dmv_city" "City" $true
Col-String $t "dmv_state" "State" $true
Col-String $t "dmv_zipcode" "ZIP Code" $true 20
Col-String $t "dmv_county" "County"
Col-Lookup $t "dmv_primarycontactid" "Primary Contact" "contact" "dmv_contact_dealer" $true
Col-Phone $t "dmv_phone" "Phone" $true
Col-Email $t "dmv_email" "Email" $true
Col-Bool $t "dmv_portalenrolled" "Dealer Portal Enrolled" $true
Col-String $t "dmv_suretybond" "Surety Bond Number"
Col-Date $t "dmv_suretybondexp" "Surety Bond Expiration"
Col-Int $t "dmv_annualsales" "Annual Sales Volume" $false 0
Col-Bool $t "dmv_bulkupload" "Bulk Upload Enabled" $true
Col-Int $t "dmv_maxtemptags" "Max Temp Tags Per Day" $false 0 999
Col-Choice $t "dmv_compliancestatus" "Compliance Status" @("Compliant","Review Required","Non-Compliant")
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Dealer)"
Start-Sleep 5

# ================================================================
# TABLE 8: Vehicle Title (dmv_vehicletitle)
# ================================================================
Write-Host "`n=== [8/14] Vehicle Title ==="
$t = "dmv_vehicletitle"
Col-Lookup $t "dmv_vehicleid" "Vehicle" "dmv_vehicle" "dmv_vehicle_title" $true
Col-Choice $t "dmv_titlestatus" "Title Status" @("Active","Transferred","Salvage","Junked","Electronic (ELT)","Pending") $true
Col-Choice $t "dmv_titletype" "Title Type" @("Clean","Salvage","Rebuilt","Flood","Lemon Law") $true
Col-Date $t "dmv_issuedate" "Issue Date" $true
Col-Lookup $t "dmv_ownercitizenid" "Owner Name (Citizen)" "dmv_citizenprofile" "dmv_citizenprofile_title"
Col-Lookup $t "dmv_ownerdealerid" "Owner Name (Dealer)" "dmv_dealer" "dmv_dealer_title"
Col-String $t "dmv_coownername" "Co-Owner Name"
Col-String $t "dmv_prevtitlenumber" "Previous Title Number"
Col-Date $t "dmv_transferdate" "Transfer Date"
Col-Int $t "dmv_transferodometer" "Odometer at Transfer" $false 0
Col-Currency $t "dmv_saleprice" "Sale Price"
Col-Currency $t "dmv_salestax" "Sales Tax Amount"
Col-Bool $t "dmv_eltenabled" "ELT Enabled" $true
Col-String $t "dmv_lienholdername" "Lienholder Name"
Col-Date $t "dmv_liendate" "Lien Date"
Col-Date $t "dmv_lienreleasedate" "Lien Release Date"
Col-Lookup $t "dmv_submittedbydid" "Submitted By (Dealer)" "dmv_dealer" "dmv_dealer_title_submitted"
Col-Choice $t "dmv_processingstatus" "Processing Status" @("Pending Review","Approved","Rejected","Requires Inspection")
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Vehicle Title)"
Start-Sleep 5

# ================================================================
# TABLE 9: Lien (dmv_lien)
# ================================================================
Write-Host "`n=== [9/14] Lien ==="
$t = "dmv_lien"
Col-Lookup $t "dmv_titleid" "Vehicle Title" "dmv_vehicletitle" "dmv_vehicletitle_lien" $true
Col-Lookup $t "dmv_vehicleid" "Vehicle" "dmv_vehicle" "dmv_vehicle_lien" $true
Col-Choice $t "dmv_lienstatus" "Lien Status" @("Active","Released","Transferred","Cancelled") $true
Col-String $t "dmv_lienholdername" "Lienholder Name" $true
Col-String $t "dmv_eltid" "Lienholder ELT ID"
Col-Date $t "dmv_liendate" "Lien Date" $true
Col-Currency $t "dmv_loanamount" "Loan Amount"
Col-Int $t "dmv_loanterm" "Loan Term (Months)" $false 0 600
Col-Date $t "dmv_loanmaturity" "Loan Maturity Date"
Col-Date $t "dmv_releasedate" "Release Date"
Col-Choice $t "dmv_releasemethod" "Release Method" @("Payoff","Voluntary Release","Repo","Other")
Col-Bool $t "dmv_eltnotification" "ELT Notification Sent"
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Lien)"
Start-Sleep 5

# ================================================================
# TABLE 10: Temporary Tag (dmv_temporarytag)
# ================================================================
Write-Host "`n=== [10/14] Temporary Tag ==="
$t = "dmv_temporarytag"
Col-Lookup $t "dmv_dealerid" "Dealer" "dmv_dealer" "dmv_dealer_temporarytag" $true
Col-Lookup $t "dmv_vehicleid" "Vehicle" "dmv_vehicle" "dmv_vehicle_temporarytag" $true
Col-String $t "dmv_buyername" "Buyer Name" $true
Col-Lookup $t "dmv_buyerid" "Buyer Citizen Profile" "dmv_citizenprofile" "dmv_citizenprofile_temporarytag"
Col-Date $t "dmv_issuedate" "Issue Date" $true
Col-Date $t "dmv_expirationdate" "Expiration Date" $true
Col-Choice $t "dmv_tagstatus" "Tag Status" @("Active","Expired","Voided","Converted to Plate") $true
Col-Currency $t "dmv_saleprice" "Sale Price"
Col-Url $t "dmv_tagpdfurl" "Tag PDF URL"
Col-Int $t "dmv_printcount" "Print Count" $false 0 999
Col-Lookup $t "dmv_generatedby" "Generated By" "contact" "dmv_contact_temporarytag_generated"
Col-String $t "dmv_voidedreason" "Voided Reason"
Write-Host "  Done (Temporary Tag)"
Start-Sleep 5

# ================================================================
# TABLE 11: Bulk Registration Submission (dmv_bulksubmission)
# ================================================================
Write-Host "`n=== [11/14] Bulk Registration Submission ==="
$t = "dmv_bulksubmission"
Col-Lookup $t "dmv_dealerid" "Dealer" "dmv_dealer" "dmv_dealer_bulksubmission" $true
Col-Lookup $t "dmv_submittedby" "Submitted By" "contact" "dmv_contact_bulksubmission" $true
Col-Date $t "dmv_submissiondate" "Submission Date" $true "DateAndTime"
Col-Choice $t "dmv_batchstatus" "Batch Status" @("Submitted","Validating","Validation Errors","Processing","Completed","Failed") $true
Col-Int $t "dmv_totalrecords" "Total Records" $false 0
Col-Int $t "dmv_processedrecords" "Processed Records" $false 0
Col-Int $t "dmv_failedrecords" "Failed Records" $false 0
Col-Url $t "dmv_fileurl" "File URL"
Col-Url $t "dmv_errorlogurl" "Error Log URL"
Col-Currency $t "dmv_totalfees" "Total Fees"
Col-Choice $t "dmv_paymentstatus" "Payment Status" @("Unpaid","Paid","Partially Paid")
Col-Memo $t "dmv_notes" "Notes"
Write-Host "  Done (Bulk Registration Submission)"
Start-Sleep 5

# ================================================================
# TABLE 12: DMV Office (dmv_dmvoffice)
# ================================================================
Write-Host "`n=== [12/14] DMV Office ==="
$t = "dmv_dmvoffice"
Col-String $t "dmv_officecode" "Office Code" $true 20
Col-String $t "dmv_address1" "Address Line 1" $true
Col-String $t "dmv_city" "City" $true
Col-String $t "dmv_state" "State" $true
Col-String $t "dmv_zipcode" "ZIP Code" $true 20
Col-String $t "dmv_county" "County"
Col-Phone $t "dmv_phone" "Phone"
Col-Memo $t "dmv_hours" "Hours of Operation"
Col-Decimal $t "dmv_latitude" "Latitude" $false -90 90 6
Col-Decimal $t "dmv_longitude" "Longitude" $false -180 180 6
Col-MultiChoice $t "dmv_services" "Services Available" @("License Renewal","REAL ID","Road Test","Title Transfer","Vehicle Registration","Vehicle Inspection")
Col-Bool $t "dmv_schedulingenabled" "Online Scheduling Enabled" $true
Col-Int $t "dmv_maxappointments" "Max Daily Appointments" $false 0 999
Col-Int $t "dmv_currentwait" "Current Wait (Minutes)" $false 0 999
Col-Bool $t "dmv_active" "Active" $true "" "" $true
Write-Host "  Done (DMV Office)"
Start-Sleep 5

# ================================================================
# TABLE 13: DMV Transaction Log (dmv_transactionlog)
# ================================================================
Write-Host "`n=== [13/14] DMV Transaction Log ==="
$t = "dmv_transactionlog"
Col-Choice $t "dmv_transactiontype" "Transaction Type" @("License Renewal","Registration Renewal","Title Transfer","Tag Issued","Document Uploaded","Appointment Booked","Payment Received","Account Created","Compliance Check") $true
Col-Date $t "dmv_transactiondate" "Transaction Date" $true "DateAndTime"
Col-Choice $t "dmv_status" "Status" @("Initiated","Completed","Failed","Reversed") $true
Col-Lookup $t "dmv_citizenid" "Citizen Profile" "dmv_citizenprofile" "dmv_citizenprofile_transactionlog"
Col-Lookup $t "dmv_dealerid" "Dealer" "dmv_dealer" "dmv_dealer_transactionlog"
Col-Lookup $t "dmv_licenseid" "Related License" "dmv_driverlicense" "dmv_driverlicense_transactionlog"
Col-Lookup $t "dmv_registrationid" "Related Registration" "dmv_vehicleregistration" "dmv_vehiclereg_transactionlog"
Col-Lookup $t "dmv_titleid" "Related Title" "dmv_vehicletitle" "dmv_vehicletitle_transactionlog"
Col-Lookup $t "dmv_vehicleid" "Related Vehicle" "dmv_vehicle" "dmv_vehicle_transactionlog"
Col-Currency $t "dmv_amount" "Amount"
Col-String $t "dmv_paymentref" "Payment Reference"
Col-Choice $t "dmv_channel" "Channel" @("Online Portal","In-Person","Dealer Portal","Bulk Upload","Phone")
Col-Lookup $t "dmv_initiatedby" "Initiated By (User)" "contact" "dmv_contact_transactionlog_initiated"
Col-Memo $t "dmv_notes" "Notes"
Col-Memo $t "dmv_errordetails" "Error Details"
Write-Host "  Done (DMV Transaction Log)"
Start-Sleep 5

# ================================================================
# TABLE 14: Notification (dmv_notification)
# ================================================================
Write-Host "`n=== [14/14] Notification ==="
$t = "dmv_notification"
Col-Choice $t "dmv_notificationtype" "Notification Type" @("Renewal Reminder","Appointment Confirmation","Appointment Reminder","Document Status","Payment Confirmation","Account Alert","Compliance Alert") $true
Col-Choice $t "dmv_channel" "Channel" @("Email","SMS","In-Portal","Push") $true
Col-Lookup $t "dmv_recipientcitizenid" "Recipient (Citizen)" "dmv_citizenprofile" "dmv_citizenprofile_notification"
Col-Lookup $t "dmv_recipientdealerid" "Recipient (Dealer)" "dmv_dealer" "dmv_dealer_notification"
Col-Date $t "dmv_sentdate" "Sent Date" $false "DateAndTime"
Col-Choice $t "dmv_deliverystatus" "Delivery Status" @("Queued","Sent","Delivered","Failed","Bounced") $true
Col-String $t "dmv_subject" "Subject"
Col-String $t "dmv_previewtext" "Preview Text" $false 500
Col-Choice $t "dmv_relatedrecordtype" "Related Record Type" @("License","Registration","Appointment","Document")
Col-Lookup $t "dmv_licenseid" "Related License" "dmv_driverlicense" "dmv_driverlicense_notification"
Col-Lookup $t "dmv_registrationid" "Related Registration" "dmv_vehicleregistration" "dmv_vehiclereg_notification"
Col-Lookup $t "dmv_appointmentid" "Related Appointment" "dmv_appointment" "dmv_appointment_notification"
Col-Int $t "dmv_retrycount" "Retry Count" $false 0 99
Col-String $t "dmv_templatename" "Template Used"
Write-Host "  Done (Notification)"

Write-Host "`n========================================="
Write-Host "ALL COLUMNS AND LOOKUPS COMPLETE"
Write-Host "========================================="
