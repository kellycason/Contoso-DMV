<#
  46_dealer_portal_setup.ps1

  Pass 1: Dealer Portal foundations for new vehicle registration
    1. Add columns on dmv_vehicleregistration:
         dmv_submissionchannel   (Choice)   Dealer / Self-Service / Walk-in / Bulk Upload
         dmv_rejectionreason     (Choice)   6 values
         dmv_rejectionnotes      (Memo)
         dmv_insuranceverified   (Boolean)
    2. Add option-set values to dmv_regstatus:
         100000006 = Submitted
         100000007 = Under Review
         100000008 = Rejected
    3. Seed Contoso Motors (account) + Sam Smith (contact parented to it)

  No changes to dmv_vehicle or dmv_temporarytag (already complete).
#>

$ErrorActionPreference = "Stop"

$envUrl    = "https://orga381269e.crm9.dynamics.com"
$solution  = "DMVDigitalServicesPortal"
$table     = "dmv_vehicleregistration"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

$hSol = @{
  Authorization              = "Bearer $token"
  "Content-Type"             = "application/json; charset=utf-8"
  "OData-MaxVersion"         = "4.0"
  "OData-Version"            = "4.0"
  "MSCRM.SolutionUniqueName" = $solution
}
$hJson = @{
  Authorization      = "Bearer $token"
  "Content-Type"     = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version"    = "4.0"
}
$hRead = @{
  Authorization      = "Bearer $token"
  "OData-MaxVersion" = "4.0"
  "OData-Version"    = "4.0"
}

function Post-Bytes($url, $body, $hdr) {
  Invoke-WebRequest -Uri $url -Method Post -Headers $hdr -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
}
function Put-Bytes($url, $body, $hdr) {
  Invoke-WebRequest -Uri $url -Method Put -Headers $hdr -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
}
function Patch-Bytes($url, $body, $hdr) {
  Invoke-WebRequest -Uri $url -Method Patch -Headers $hdr -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
}

function Attr-Exists($tbl, $col) {
  try {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$tbl')/Attributes(LogicalName='$col')?`$select=LogicalName" -Headers $hRead | Out-Null
    return $true
  } catch { return $false }
}

# ======================================================================
# 1. Add columns on dmv_vehicleregistration
# ======================================================================
Write-Host "=== Step 1: Adding columns on $table ===" -ForegroundColor Cyan

if (-not (Attr-Exists $table "dmv_submissionchannel")) {
  $body = @{
    "@odata.type"       = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
    AttributeType       = "Picklist"
    AttributeTypeName   = @{ Value = "PicklistType" }
    SchemaName          = "dmv_submissionchannel"
    RequiredLevel       = @{ Value = "None" }
    DisplayName         = @{ LocalizedLabels = @(@{ Label = "Submission Channel"; LanguageCode = 1033 }) }
    Description         = @{ LocalizedLabels = @(@{ Label = "How this registration was submitted to DMV."; LanguageCode = 1033 }) }
    OptionSet           = @{
      "@odata.type"    = "Microsoft.Dynamics.CRM.OptionSetMetadata"
      OptionSetType    = "Picklist"
      IsGlobal         = $false
      Options          = @(
        @{ Value = 100000000; Label = @{ LocalizedLabels = @(@{ Label = "Dealer";       LanguageCode = 1033 }) } },
        @{ Value = 100000001; Label = @{ LocalizedLabels = @(@{ Label = "Self-Service"; LanguageCode = 1033 }) } },
        @{ Value = 100000002; Label = @{ LocalizedLabels = @(@{ Label = "Walk-in";      LanguageCode = 1033 }) } },
        @{ Value = 100000003; Label = @{ LocalizedLabels = @(@{ Label = "Bulk Upload";  LanguageCode = 1033 }) } }
      )
    }
  } | ConvertTo-Json -Depth 10
  Post-Bytes "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes" $body $hSol
  Write-Host "  + dmv_submissionchannel"
} else { Write-Host "  = dmv_submissionchannel (exists)" }

if (-not (Attr-Exists $table "dmv_rejectionreason")) {
  $body = @{
    "@odata.type"     = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
    AttributeType     = "Picklist"
    AttributeTypeName = @{ Value = "PicklistType" }
    SchemaName        = "dmv_rejectionreason"
    RequiredLevel     = @{ Value = "None" }
    DisplayName       = @{ LocalizedLabels = @(@{ Label = "Rejection Reason"; LanguageCode = 1033 }) }
    OptionSet         = @{
      "@odata.type"   = "Microsoft.Dynamics.CRM.OptionSetMetadata"
      OptionSetType   = "Picklist"
      IsGlobal        = $false
      Options         = @(
        @{ Value = 100000000; Label = @{ LocalizedLabels = @(@{ Label = "Invalid VIN";         LanguageCode = 1033 }) } },
        @{ Value = 100000001; Label = @{ LocalizedLabels = @(@{ Label = "Insurance Lapsed";    LanguageCode = 1033 }) } },
        @{ Value = 100000002; Label = @{ LocalizedLabels = @(@{ Label = "Title Defect";        LanguageCode = 1033 }) } },
        @{ Value = 100000003; Label = @{ LocalizedLabels = @(@{ Label = "Sales Tax Dispute";   LanguageCode = 1033 }) } },
        @{ Value = 100000004; Label = @{ LocalizedLabels = @(@{ Label = "Missing Documents";   LanguageCode = 1033 }) } },
        @{ Value = 100000005; Label = @{ LocalizedLabels = @(@{ Label = "Other";               LanguageCode = 1033 }) } }
      )
    }
  } | ConvertTo-Json -Depth 10
  Post-Bytes "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes" $body $hSol
  Write-Host "  + dmv_rejectionreason"
} else { Write-Host "  = dmv_rejectionreason (exists)" }

if (-not (Attr-Exists $table "dmv_rejectionnotes")) {
  $body = @{
    "@odata.type"       = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
    AttributeType       = "Memo"
    AttributeTypeName   = @{ Value = "MemoType" }
    SchemaName          = "dmv_rejectionnotes"
    MaxLength           = 2000
    Format              = "TextArea"
    RequiredLevel       = @{ Value = "None" }
    DisplayName         = @{ LocalizedLabels = @(@{ Label = "Rejection Notes"; LanguageCode = 1033 }) }
  } | ConvertTo-Json -Depth 10
  Post-Bytes "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes" $body $hSol
  Write-Host "  + dmv_rejectionnotes"
} else { Write-Host "  = dmv_rejectionnotes (exists)" }

if (-not (Attr-Exists $table "dmv_insuranceverified")) {
  $body = @{
    "@odata.type"       = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
    AttributeType       = "Boolean"
    AttributeTypeName   = @{ Value = "BooleanType" }
    SchemaName          = "dmv_insuranceverified"
    RequiredLevel       = @{ Value = "None" }
    DisplayName         = @{ LocalizedLabels = @(@{ Label = "Insurance Verified"; LanguageCode = 1033 }) }
    DefaultValue        = $false
    OptionSet           = @{
      "@odata.type"   = "Microsoft.Dynamics.CRM.BooleanOptionSetMetadata"
      TrueOption  = @{ Value = 1; Label = @{ LocalizedLabels = @(@{ Label = "Yes"; LanguageCode = 1033 }) } }
      FalseOption = @{ Value = 0; Label = @{ LocalizedLabels = @(@{ Label = "No";  LanguageCode = 1033 }) } }
    }
  } | ConvertTo-Json -Depth 10
  Post-Bytes "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes" $body $hSol
  Write-Host "  + dmv_insuranceverified"
} else { Write-Host "  = dmv_insuranceverified (exists)" }

# ======================================================================
# 2. Add dmv_regstatus values: Submitted, Under Review, Rejected
# ======================================================================
Write-Host "`n=== Step 2: Extending dmv_regstatus option set ===" -ForegroundColor Cyan

# Fetch existing
$opt = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='dmv_regstatus')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata/OptionSet?`$select=MetadataId,Options" -Headers $hRead
$existingValues = @($opt.Options | ForEach-Object { $_.Value })

$toAdd = @(
  @{ Value = 100000006; Label = "Submitted" },
  @{ Value = 100000007; Label = "Under Review" },
  @{ Value = 100000008; Label = "Rejected" }
)

foreach ($o in $toAdd) {
  if ($existingValues -contains $o.Value) {
    Write-Host "  = $($o.Value) $($o.Label) (exists)"
  } else {
    $body = @{
      AttributeLogicalName = "dmv_regstatus"
      EntityLogicalName    = $table
      Value                = $o.Value
      Label                = @{ LocalizedLabels = @(@{ Label = $o.Label; LanguageCode = 1033 }) }
      SolutionUniqueName   = $solution
    } | ConvertTo-Json -Depth 10
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/InsertOptionValue" -Method Post -Headers $hJson -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    Write-Host "  + $($o.Value) $($o.Label)"
  }
}

# ======================================================================
# 3. Seed Contoso Motors + Sam Smith
# ======================================================================
Write-Host "`n=== Step 3: Seeding dealer data ===" -ForegroundColor Cyan

# Contoso Motors Account
$acct = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/accounts?`$filter=name eq 'Contoso Motors'&`$select=accountid,name" -Headers $hRead
if ($acct.value.Count -gt 0) {
  $accountId = $acct.value[0].accountid
  Write-Host "  = Contoso Motors exists ($accountId)"
} else {
  $body = @{
    name          = "Contoso Motors"
    address1_line1= "4200 Dealership Way"
    address1_city = "Contoso"
    address1_stateorprovince = "TX"
    address1_postalcode = "90210"
    telephone1    = "(555) 314-1592"
    emailaddress1 = "sales@contosomotors.example.com"
    websiteurl    = "https://contosomotors.example.com"
    description   = "Franchised new-vehicle dealership. Authorized DMV dealer for online registrations and temporary tag issuance."
  } | ConvertTo-Json
  $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/accounts" -Method Post -Headers ($hJson + @{Prefer="return=representation"}) -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
  $accountId = ($resp.Content | ConvertFrom-Json).accountid
  Write-Host "  + Created Contoso Motors ($accountId)"
}

# Sam Smith Contact
$cnt = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/contacts?`$filter=firstname eq 'Sam' and lastname eq 'Smith'&`$select=contactid,fullname,_parentcustomerid_value" -Headers $hRead
if ($cnt.value.Count -gt 0) {
  $contactId = $cnt.value[0].contactid
  Write-Host "  = Sam Smith exists ($contactId)"
  # Ensure parent is Contoso Motors
  if ($cnt.value[0]._parentcustomerid_value -ne $accountId) {
    $patch = @{ "parentcustomerid_account@odata.bind" = "/accounts($accountId)" } | ConvertTo-Json
    Patch-Bytes "$envUrl/api/data/v9.2/contacts($contactId)" $patch $hJson
    Write-Host "    linked Sam Smith -> Contoso Motors"
  }
} else {
  $body = @{
    firstname      = "Sam"
    lastname       = "Smith"
    fullname       = "Sam Smith"
    emailaddress1  = "sam.smith@contosomotors.example.com"
    telephone1     = "(555) 314-1593"
    mobilephone    = "(555) 314-1594"
    jobtitle       = "Sales & Registration Manager"
    address1_line1 = "4200 Dealership Way"
    address1_city  = "Contoso"
    address1_stateorprovince = "TX"
    address1_postalcode = "90210"
    description    = "Authorized dealer rep for Contoso Motors. Processes new vehicle registrations and issues temporary tags."
    "parentcustomerid_account@odata.bind" = "/accounts($accountId)"
  } | ConvertTo-Json
  $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/contacts" -Method Post -Headers ($hJson + @{Prefer="return=representation"}) -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
  $contactId = ($resp.Content | ConvertFrom-Json).contactid
  Write-Host "  + Created Sam Smith ($contactId)"
}

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "  Contoso Motors accountId: $accountId"
Write-Host "  Sam Smith contactId:      $contactId"
Write-Host ""
Write-Host "Save these GUIDs; the portal will hardcode them for the persona toggle."
