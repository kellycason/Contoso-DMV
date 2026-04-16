###############################################################################
# 08_reseed_maria_native.ps1
# Patch Maria's Contact record with DMV fields and re-point all child records
# from old citizen profile lookups to new contact lookups.
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

$mariaContactId = "d2c23913-f238-f111-88b3-001dd801f94a"

# ── 1. Patch Maria's Contact record with DMV-specific fields ──
Write-Host "Patching Maria's Contact with DMV fields..."
$contactPatch = @{
    address1_line1 = "123 Main Street"
    address1_city = "Contoso City"
    address1_stateorprovince = "ST"
    address1_postalcode = "12345"
    telephone1 = "(555) 867-5309"
    dmv_dateofbirth = "1988-06-15"
    dmv_last4ssn = "4721"
    dmv_mydmvenrolled = $true
    dmv_enrollmentdate = "2024-03-10"
    dmv_accountverified = $true
} | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/contacts($mariaContactId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($contactPatch)) -UseBasicParsing | Out-Null
Write-Host "  Contact patched OK"
Start-Sleep 2

# ── 2. Find the existing citizen profile ID (to locate child records) ──
Write-Host "Finding existing citizen profile..."
$cpResult = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_citizenprofiles?`$filter=_dmv_contactid_value eq $mariaContactId&`$select=dmv_citizenprofileid&`$top=1" -Headers $h
$cpId = $cpResult.value[0].dmv_citizenprofileid
Write-Host "  Found citizen profile: $cpId"

# ── 3. Patch driver licenses: set new dmv_contactid lookup ──
Write-Host "Patching driver licenses..."
$licenses = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_driverlicenses?`$filter=_dmv_citizenprofileid_value eq $cpId&`$select=dmv_driverlicenseid" -Headers $h
foreach ($lic in $licenses.value) {
    $patch = @{ "dmv_contactid@odata.bind" = "/contacts($mariaContactId)" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_driverlicenses($($lic.dmv_driverlicenseid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
    Write-Host "  License $($lic.dmv_driverlicenseid) -> OK"
}
Start-Sleep 2

# ── 4. Patch vehicles: set new dmv_ownercontactid lookup ──
Write-Host "Patching vehicles..."
$vehicles = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicles?`$filter=_dmv_ownercitizenid_value eq $cpId&`$select=dmv_vehicleid,dmv_make,dmv_model" -Headers $h
foreach ($v in $vehicles.value) {
    $patch = @{ "dmv_ownercontactid@odata.bind" = "/contacts($mariaContactId)" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicles($($v.dmv_vehicleid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
    Write-Host "  Vehicle $($v.dmv_make) $($v.dmv_model) -> OK"
}
Start-Sleep 2

# ── 5. Patch registrations: set new dmv_regcontactid lookup ──
Write-Host "Patching registrations..."
$regs = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations?`$filter=_dmv_registrantid_value eq $cpId&`$select=dmv_vehicleregistrationid,dmv_registrationid" -Headers $h
foreach ($r in $regs.value) {
    $patch = @{ "dmv_regcontactid@odata.bind" = "/contacts($mariaContactId)" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($($r.dmv_vehicleregistrationid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
    Write-Host "  Reg $($r.dmv_registrationid) -> OK"
}
Start-Sleep 2

# ── 6. Patch transactions: set new dmv_contactid lookup ──
Write-Host "Patching transactions..."
$txns = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_transactionlogs?`$filter=_dmv_citizenid_value eq $cpId&`$select=dmv_transactionlogid,dmv_transactionid" -Headers $h
foreach ($t in $txns.value) {
    $patch = @{ "dmv_contactid@odata.bind" = "/contacts($mariaContactId)" } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_transactionlogs($($t.dmv_transactionlogid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
    Write-Host "  Txn $($t.dmv_transactionid) -> OK"
}

Write-Host "`n==========================================="
Write-Host "MIGRATION COMPLETE"
Write-Host "==========================================="
Write-Host "  Contact patched with DMV fields"
Write-Host "  All child records now point to Contact"
Write-Host "  Old citizen profile lookups still populated (will become orphan when table deleted)"
