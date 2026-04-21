# 49_autonumber_and_view_sort.ps1
# 1. Converts these columns to AutoNumber format so every new record gets a uniform ref:
#      dmv_registrationterm.dmv_termnumber     → TERM-{SEQNUM:6}
#      dmv_registrationpayment.dmv_paymentref  → PAY-{SEQNUM:6}
#      dmv_vehicleregistration.dmv_registrationid → REG-{SEQNUM:6}
#      dmv_registrationrenewal.dmv_renewalid   → REGRN-{SEQNUM:6}
#      dmv_licenserenewal.dmv_renewalid        → LIC-{SEQNUM:6}
# 2. Re-numbers existing records sequentially using the same uniform pattern.
# 3. Sets the autonumber seed past the last assigned value (so new records continue cleanly).
# 4. Updates all Active public views to sort newest-first by createdon.

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization    = "Bearer $token"
  "Content-Type"   = "application/json; charset=utf-8"
  "OData-Version"  = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ───────────────────────── 1. Apply AutoNumberFormat ─────────────────────────
$autonumCols = @(
  @{ entity='dmv_registrationterm';     attr='dmv_termnumber';    schema='dmv_TermNumber';     prefix='TERM';  set='dmv_registrationterms' }
  @{ entity='dmv_registrationpayment';  attr='dmv_paymentref';    schema='dmv_PaymentRef';     prefix='PAY';   set='dmv_registrationpayments' }
  @{ entity='dmv_vehicleregistration';  attr='dmv_registrationid';schema='dmv_RegistrationId'; prefix='REG';   set='dmv_vehicleregistrations' }
  @{ entity='dmv_registrationrenewal';  attr='dmv_renewalid';     schema='dmv_RenewalId';      prefix='REGRN'; set='dmv_registrationrenewals' }
  @{ entity='dmv_licenserenewal';       attr='dmv_renewalid';     schema='dmv_RenewalId';      prefix='LIC';   set='dmv_licenserenewals' }
)

foreach ($c in $autonumCols) {
  $fmt = "$($c.prefix)-{SEQNUM:6}"
  Write-Host "  Setting AutoNumberFormat on $($c.entity).$($c.attr) = $fmt"
  # Fetch full existing StringAttribute metadata so PUT doesn't strip properties
  $meta = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$($c.entity)')/Attributes(LogicalName='$($c.attr)')/Microsoft.Dynamics.CRM.StringAttributeMetadata" -Headers $readH
  $meta.AutoNumberFormat = $fmt
  # Strip odata response-only fields
  $put = @{
    "@odata.type"   = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
    LogicalName     = $meta.LogicalName
    SchemaName      = $meta.SchemaName
    MaxLength       = $meta.MaxLength
    RequiredLevel   = $meta.RequiredLevel
    FormatName      = $meta.FormatName
    DisplayName     = $meta.DisplayName
    Description     = $meta.Description
    AutoNumberFormat = $fmt
    MetadataId      = $meta.MetadataId
  } | ConvertTo-Json -Depth 10
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$($c.entity)')/Attributes(LogicalName='$($c.attr)')" -Method Put -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($put)) -UseBasicParsing | Out-Null
}

# ───────────────────────── 2. Renumber existing records ─────────────────────────
# Renumbering: sort by createdon asc, assign prefix-000001, 000002, ...
Write-Host ""
Write-Host "Renumbering existing records..."
$renumberPlan = @{}
foreach ($c in $autonumCols) {
  $select = "$($c.attr),createdon"
  $all = @()
  $uri = "$envUrl/api/data/v9.2/$($c.set)?`$select=$select&`$orderby=createdon asc"
  do {
    $page = Invoke-RestMethod -Uri $uri -Headers $readH
    $all += $page.value
    $uri = $page.'@odata.nextLink'
  } while ($uri)

  $i = 1
  $lastAssigned = 0
  foreach ($rec in $all) {
    $newVal = "{0}-{1:D6}" -f $c.prefix, $i
    $idProp = ($c.entity + "id").Replace('dmv_','dmv_')
    $recId = $rec.$idProp
    if (-not $recId) { $recId = $rec.PSObject.Properties | Where-Object { $_.Name -like "*id" -and $_.Value -match '^[0-9a-f-]{36}$' } | Select-Object -First 1 -ExpandProperty Value }
    $body = @{ $c.attr = $newVal } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/$($c.set)($recId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
    $lastAssigned = $i
    $i++
  }
  Write-Host "  $($c.entity): renumbered $($all.Count) records ($($c.prefix)-000001..$($c.prefix)-$('{0:D6}' -f $lastAssigned))"
  $renumberPlan[$c.entity] = $lastAssigned
}

# ───────────────────────── 3. Set autonumber seed ─────────────────────────
# SetAutoNumberSeed sets the NEXT number to emit. To continue cleanly, seed = last + 1.
Write-Host ""
Write-Host "Setting autonumber seeds..."
foreach ($c in $autonumCols) {
  $next = [int]$renumberPlan[$c.entity] + 1
  $seedBody = @{
    EntityName    = $c.entity
    AttributeName = $c.attr
    Value         = $next
  } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/SetAutoNumberSeed" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($seedBody)) -UseBasicParsing | Out-Null
  Write-Host "  $($c.entity).$($c.attr) next = $next"
}

# ───────────────────────── 4. View sorts: newest-first by createdon ─────────────────────────
Write-Host ""
Write-Host "Updating view sorts to newest-first (createdon desc)..."
$viewsToResort = @(
  '1ce8a6a3-d139-f111-88b3-001dd801f94a'  # Active Registration Terms
  '2227a990-d139-f111-88b4-001dd80340cd'
  'd33b4d72-66ba-4902-b687-7abd8bdad9d0'
  'a916ae90-d139-f111-88b3-001dd801f94a'  # Active Registration Payments
  '1b9aa4a9-d139-f111-88b3-001dd801f94a'
  'a46ddddf-d03e-4643-bbe8-d9703183b493'
  '26761996-a173-40f5-8a59-ce0d837fdbf1'  # Active Vehicle Registrations
  '1b6547ed-cb94-4194-8a5c-6a22ae1f5eaf'  # Active Registration Renewals
  'd17c7ec0-6ced-459d-b42c-afafcd56e91f'  # Active License Renewals
  '8baa7d66-102d-4a34-810c-17440a8751c7'  # Active Vehicles
  '8e73e80f-c53b-4752-b748-5a38efe10fb5'  # Active Driver Licenses
  '9b4d2135-db38-4e36-91e4-79b43775349f'  # Active Vehicle Titles
  '86234468-3bab-48b4-a824-c7b7a587a4e2'  # Active DMV Transaction Logs
)
foreach ($vid in $viewsToResort) {
  $v = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/savedqueries($vid)?`$select=name,fetchxml" -Headers $readH
  $fx = $v.fetchxml
  # Remove any existing <order .../> tags
  $fx = [regex]::Replace($fx, '<order\s[^/]*/>\s*', '')
  # Inject createdon desc just before </entity>
  $fx = $fx -replace '(</entity>)', '<order attribute="createdon" descending="true" />$1'
  $body = @{ fetchxml = $fx } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries($vid)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  Write-Host "  $($v.name) ($vid)"
}

# ───────────────────────── 5. Publish ─────────────────────────
Write-Host ""
Write-Host "Publishing..."
$entityList = ($autonumCols | ForEach-Object { "<entity>$($_.entity)</entity>" }) -join ''
# Also publish vehicle + driverlicense + vehicletitle + transactionlog
$entityList += '<entity>dmv_vehicle</entity><entity>dmv_driverlicense</entity><entity>dmv_vehicletitle</entity><entity>dmv_transactionlog</entity>'
$pubBody = @{ ParameterXml = "<importexportxml><entities>$entityList</entities></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null

Write-Host "Done."
