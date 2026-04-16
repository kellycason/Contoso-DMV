$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

$mariaContactId = "d2c23913-f238-f111-88b3-001dd801f94a"

# ── 1. Citizen Profile ──
Write-Host "Creating Citizen Profile..."
$cpBody = @{
    dmv_fullname = "Maria Jennings"
    dmv_dateofbirth = "1988-06-15"
    dmv_last4ssn = "4721"
    dmv_address1 = "123 Main Street"
    dmv_city = "Contoso City"
    dmv_state = "ST"
    dmv_zipcode = "12345"
    dmv_phone = "(555) 867-5309"
    dmv_myenrolled = $true
    dmv_enrollmentdate = "2024-03-10"
    dmv_accountverified = $true
    "dmv_contactid@odata.bind" = "/contacts($mariaContactId)"
} | ConvertTo-Json -Compress
$cpResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_citizenprofiles" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($cpBody)) -UseBasicParsing
$cpId = ($cpResp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Citizen Profile: $cpId"
Start-Sleep 3

# ── 2. Driver License ──
Write-Host "Creating Driver License..."
$dlBody = @{
    dmv_licensenumber = "D1234567"
    dmv_licenseclass = 100000002    # C (Standard)
    dmv_licensestatus = 100000000   # Active
    dmv_issuedate = "2023-03-15"
    dmv_expirationdate = "2027-03-15"
    dmv_realidcompliant = $true
    dmv_realidstatus = 100000003    # Approved
    dmv_renewalmethod = 100000000   # Online
    dmv_lastrenewdate = "2023-03-15"
    dmv_renewalcount = 2
    dmv_onlineeligible = $true
    "dmv_citizenprofileid@odata.bind" = "/dmv_citizenprofiles($cpId)"
} | ConvertTo-Json -Compress
$dlResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_driverlicenses" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($dlBody)) -UseBasicParsing
$dlId = ($dlResp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Driver License: $dlId"
Start-Sleep 3

# ── 3. Vehicle 1: 2023 Honda Accord ──
Write-Host "Creating Vehicle 1 (Honda Accord)..."
$v1Body = @{
    dmv_vin = "1HGCM82633A004352"
    dmv_year = 2023
    dmv_make = "Honda"
    dmv_model = "Accord"
    dmv_color = "Silver"
    dmv_bodystyle = 100000000       # Sedan
    dmv_fueltype = 100000000        # Gasoline
    dmv_platenumber = "ABC-1234"
    dmv_platetype = 100000000       # Standard
    dmv_platestate = "ST"
    dmv_odometer = 28500
    dmv_salvagetitle = $false
    dmv_outofstate = $false
    dmv_insurancestatus = 100000000 # Verified
    dmv_insurancecarrier = "Contoso Insurance"
    dmv_insurancepolicy = "CI-2026-78901"
    dmv_insuranceexp = "2027-01-15"
    "dmv_ownercitizenid@odata.bind" = "/dmv_citizenprofiles($cpId)"
} | ConvertTo-Json -Compress
$v1Resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicles" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($v1Body)) -UseBasicParsing
$v1Id = ($v1Resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Vehicle 1: $v1Id"
Start-Sleep 3

# ── 4. Vehicle 2: 2024 Tesla Model S ──
Write-Host "Creating Vehicle 2 (Tesla Model S)..."
$v2Body = @{
    dmv_vin = "5YJSA1E26HF000316"
    dmv_year = 2024
    dmv_make = "Tesla"
    dmv_model = "Model S"
    dmv_color = "Red"
    dmv_bodystyle = 100000000       # Sedan
    dmv_fueltype = 100000002        # Electric
    dmv_platenumber = "XYZ-5678"
    dmv_platetype = 100000000       # Standard
    dmv_platestate = "ST"
    dmv_odometer = 12300
    dmv_salvagetitle = $false
    dmv_outofstate = $false
    dmv_insurancestatus = 100000000 # Verified
    dmv_insurancecarrier = "Contoso Insurance"
    dmv_insurancepolicy = "CI-2026-78902"
    dmv_insuranceexp = "2026-06-15"
    "dmv_ownercitizenid@odata.bind" = "/dmv_citizenprofiles($cpId)"
} | ConvertTo-Json -Compress
$v2Resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicles" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($v2Body)) -UseBasicParsing
$v2Id = ($v2Resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Vehicle 2: $v2Id"
Start-Sleep 3

# ── 5. Registration for Vehicle 1 (Active) ──
Write-Host "Creating Registration for Honda Accord..."
$r1Body = @{
    dmv_registrationid = "REG-2026-00142"
    dmv_regstatus = 100000000       # Active
    dmv_regtype = 100000001         # Renewal
    dmv_regyear = 2026
    dmv_effectivedate = "2025-08-01"
    dmv_expirationdate = "2026-08-01"
    dmv_onlineeligible = $true
    dmv_fee = 75.00
    dmv_totaldue = 0
    dmv_paymentstatus = 100000001   # Paid
    dmv_paymentdate = "2025-07-15T10:30:00Z"
    dmv_paymentmethod = 100000000   # Credit Card
    dmv_stickernumber = "STK-2026-A1234"
    dmv_county = "Contoso County"
    "dmv_vehicleid@odata.bind" = "/dmv_vehicles($v1Id)"
    "dmv_registrantid@odata.bind" = "/dmv_citizenprofiles($cpId)"
} | ConvertTo-Json -Compress
$r1Resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($r1Body)) -UseBasicParsing
$r1Id = ($r1Resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Reg 1: $r1Id"
Start-Sleep 3

# ── 6. Registration for Vehicle 2 (Expiring Soon) ──
Write-Host "Creating Registration for Tesla Model S..."
$r2Body = @{
    dmv_registrationid = "REG-2025-00891"
    dmv_regstatus = 100000000       # Active
    dmv_regtype = 100000000         # New
    dmv_regyear = 2025
    dmv_effectivedate = "2024-05-01"
    dmv_expirationdate = "2026-05-01"
    dmv_onlineeligible = $true
    dmv_fee = 85.00
    dmv_totaldue = 85.00
    dmv_paymentstatus = 100000000   # Unpaid
    dmv_stickernumber = "STK-2025-B5678"
    dmv_county = "Contoso County"
    "dmv_vehicleid@odata.bind" = "/dmv_vehicles($v2Id)"
    "dmv_registrantid@odata.bind" = "/dmv_citizenprofiles($cpId)"
} | ConvertTo-Json -Compress
$r2Resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($r2Body)) -UseBasicParsing
$r2Id = ($r2Resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
Write-Host "  Reg 2: $r2Id"
Start-Sleep 3

# ── 7. Transaction History ──
Write-Host "Creating Transactions..."
$txns = @(
    @{ dmv_transactionid="TXN-2026-0412"; dmv_transactiontype=100000001; dmv_transactiondate="2026-01-10T14:22:00Z"; dmv_status=100000001; dmv_amount=85.00; dmv_channel=100000000; dmv_paymentref="PMT-CC-20260110-001" },
    @{ dmv_transactionid="TXN-2025-0298"; dmv_transactiontype=100000000; dmv_transactiondate="2025-11-22T09:15:00Z"; dmv_status=100000001; dmv_amount=45.00; dmv_channel=100000000; dmv_paymentref="PMT-CC-20251122-003" },
    @{ dmv_transactionid="TXN-2025-0187"; dmv_transactiontype=100000002; dmv_transactiondate="2025-09-05T11:45:00Z"; dmv_status=100000001; dmv_amount=120.00; dmv_channel=100000001; dmv_paymentref="PMT-CC-20250905-007" }
)
foreach ($txn in $txns) {
    $txn["dmv_citizenid@odata.bind"] = "/dmv_citizenprofiles($cpId)"
    $txn["dmv_initiatedby@odata.bind"] = "/contacts($mariaContactId)"
    $json = $txn | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_transactionlogs" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
    Write-Host "  OK: $($txn.dmv_transactionid)"
    Start-Sleep 2
}

Write-Host "`n==========================================="
Write-Host "DEMO DATA SEEDED FOR MARIA JENNINGS"
Write-Host "==========================================="
Write-Host "  Citizen Profile: $cpId"
Write-Host "  Driver License:  $dlId"
Write-Host "  Vehicle 1:       $v1Id (Honda Accord)"
Write-Host "  Vehicle 2:       $v2Id (Tesla Model S)"
Write-Host "  2 Registrations, 3 Transactions"
