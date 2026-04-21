# 43_expire_old_term.ps1
# Extends "DMV - Approve Registration Renewal" flow to:
#   1. Read vehicle registration before update (captures old currenttermid)
#   2. After the new registration term is created, mark the previously-active
#      term as Expired (100000002) — only if a prior term existed and it's
#      different from the newly-created one.
#   3. Then update the vehicle registration (swap currenttermid to the new term).
#
# Also backfills any existing approved renewals so their prior term is expired.

$ErrorActionPreference = "Stop"

$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }
$flowId = "9f8e7d6c-5b4a-4321-9876-abcdef012345"

# ─────────────────────────────────────────────────────────────────────
# Step 1: Fetch clientdata
# ─────────────────────────────────────────────────────────────────────
$wf = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata" -Headers $readH
$cd = $wf.clientdata
Write-Host "Fetched clientdata: $($cd.Length) bytes"

if ($cd -match '"Get_vehicle_registration_before_update"') {
  Write-Host "Already contains Get_vehicle_registration_before_update — skipping flow edit."
  $skipFlowEdit = $true
} else {
  $skipFlowEdit = $false
}

if (-not $skipFlowEdit) {
  # ─────────────────────────────────────────────────────────────────────
  # Step 2: Build the new action fragments (compact JSON)
  # ─────────────────────────────────────────────────────────────────────

  $getVehReg = [ordered]@{
    runAfter = @{ Update_registration_renewal = @("Succeeded") }
    metadata = @{ operationMetadataId = "aaaaaaaa-0000-0000-0000-000000000003" }
    type = "OpenApiConnection"
    inputs = [ordered]@{
      host = [ordered]@{
        connectionName = "shared_commondataserviceforapps"
        operationId   = "GetItem"
        apiId         = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
      }
      parameters = [ordered]@{
        entityName = "dmv_vehicleregistrations"
        recordId   = "@triggerOutputs()?['body/_dmv_registrationid_value']"
      }
      authentication = "@parameters('`$authentication')"
    }
  }

  $ifOldTerm = [ordered]@{
    runAfter = @{ Create_registration_term = @("Succeeded") }
    metadata = @{ operationMetadataId = "aaaaaaaa-0000-0000-0000-000000000004" }
    type = "If"
    expression = [ordered]@{
      and = @(
        @{ not = @{ equals = @("@outputs('Get_vehicle_registration_before_update')?['body/_dmv_currenttermid_value']", $null) } },
        @{ not = @{ equals = @("@outputs('Get_vehicle_registration_before_update')?['body/_dmv_currenttermid_value']", "@outputs('Create_registration_term')?['body/dmv_registrationtermid']") } }
      )
    }
    actions = [ordered]@{
      Update_old_term_to_expired = [ordered]@{
        runAfter = @{}
        metadata = @{ operationMetadataId = "aaaaaaaa-0000-0000-0000-000000000005" }
        type = "OpenApiConnection"
        inputs = [ordered]@{
          host = [ordered]@{
            connectionName = "shared_commondataserviceforapps"
            operationId    = "UpdateRecord"
            apiId          = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
          }
          parameters = [ordered]@{
            entityName = "dmv_registrationterms"
            recordId   = "@outputs('Get_vehicle_registration_before_update')?['body/_dmv_currenttermid_value']"
            "item/dmv_termstatus" = 100000002
          }
          authentication = "@parameters('`$authentication')"
        }
      }
    }
    else = @{ actions = @{} }
  }

  $getVehRegJson = ($getVehReg | ConvertTo-Json -Depth 20 -Compress)
  $ifOldTermJson = ($ifOldTerm | ConvertTo-Json -Depth 20 -Compress)

  # ─────────────────────────────────────────────────────────────────────
  # Step 3: String-insert the new actions
  # ─────────────────────────────────────────────────────────────────────

  # Insert Get_vehicle_registration_before_update BEFORE Create_registration_term
  # and retarget Create_registration_term's runAfter to depend on it.
  $oldA = '"Create_registration_term":{"runAfter":{"Update_registration_renewal":["Succeeded"]}'
  $newA = "`"Get_vehicle_registration_before_update`":$getVehRegJson,`"Create_registration_term`":{`"runAfter`":{`"Get_vehicle_registration_before_update`":[`"Succeeded`"]}"
  if ($cd -notmatch [regex]::Escape($oldA)) { throw "Could not find Create_registration_term runAfter anchor" }
  $cd2 = $cd.Replace($oldA, $newA)

  # Insert If_old_term_exists BEFORE Update_vehicle_registration
  # and retarget Update_vehicle_registration's runAfter to depend on it.
  $oldB = '"Update_vehicle_registration":{"runAfter":{"Create_registration_term":["Succeeded"]}'
  $newB = "`"If_old_term_exists`":$ifOldTermJson,`"Update_vehicle_registration`":{`"runAfter`":{`"If_old_term_exists`":[`"Succeeded`"]}"
  if ($cd2 -notmatch [regex]::Escape($oldB)) { throw "Could not find Update_vehicle_registration runAfter anchor" }
  $cd3 = $cd2.Replace($oldB, $newB)

  Write-Host "Old bytes: $($cd.Length)  New bytes: $($cd3.Length)  (delta $($cd3.Length - $cd.Length))"

  # Validate JSON
  try { $null = $cd3 | ConvertFrom-Json } catch { throw "Resulting clientdata is not valid JSON: $_" }

  # ─────────────────────────────────────────────────────────────────────
  # Step 4: Turn flow off → patch → on
  # ─────────────────────────────────────────────────────────────────────
  Write-Host "Disabling flow..."
  $disableBody = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($disableBody)) -UseBasicParsing | Out-Null

  Write-Host "Patching clientdata..."
  $patchBody = @{ clientdata = $cd3 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($patchBody)) -UseBasicParsing | Out-Null

  Write-Host "Enabling flow..."
  $enableBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($enableBody)) -UseBasicParsing | Out-Null

  $final = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode" -Headers $readH
  Write-Host "Flow now: state=$($final.statecode) status=$($final.statuscode) bytes=$($final.clientdata.Length)"
}

# ─────────────────────────────────────────────────────────────────────
# Step 5: Backfill — expire prior Active terms on already-approved records
# For each approved renewal, find the vehicle reg's currenttermid. Then
# find any terms for that vehicle reg that ARE NOT that current one AND
# are not yet Expired → mark Expired.
# ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Backfilling old terms on approved renewals ==="
$approved = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_renewalstatus eq 100000002 and _dmv_registrationid_value ne null&`$select=dmv_renewalid,_dmv_registrationid_value" -Headers $readH).value
Write-Host "Approved renewals with vehicle reg: $($approved.Count)"

foreach ($r in $approved) {
  $vrId = $r._dmv_registrationid_value
  $vr = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($vrId)?`$select=_dmv_currenttermid_value,dmv_registrationid" -Headers $readH
  $currentTermId = $vr._dmv_currenttermid_value
  Write-Host "  $($r.dmv_renewalid) veh=$($vr.dmv_registrationid) current=$currentTermId"

  # all non-expired terms for this vehicle reg that are NOT the current term
  $filter = "_dmv_vehicleregistrationid_value eq $vrId and dmv_termstatus ne 100000002"
  if ($currentTermId) { $filter += " and dmv_registrationtermid ne $currentTermId" }
  $olds = (Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationterms?`$filter=$filter&`$select=dmv_registrationtermid,dmv_termnumber,dmv_termstatus" -Headers $readH).value
  foreach ($o in $olds) {
    Write-Host "    expiring $($o.dmv_termnumber) ($($o.dmv_registrationtermid)) status=$($o.dmv_termstatus) → 100000002"
    $body = @{ dmv_termstatus = 100000002 } | ConvertTo-Json
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationterms($($o.dmv_registrationtermid))" -Method Patch -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
  }
}

Write-Host ""
Write-Host "Done."
