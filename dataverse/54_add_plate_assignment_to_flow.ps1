# Inject plate assignment into "DMV - Approve New Registration" flow
# Adds: Get_vehicle -> If plate empty -> Generate & assign plate (format: ABC-1234, TX, Standard)
#
# Must deactivate flow before PATCH clientdata, then reactivate.

$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "If-Match" = "*"
}

$wfId = '8a7b6c5d-4e3f-2a1b-9c8d-1f2e3d4c5b6a'

Write-Host "=== Fetching flow ==="
$wf = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/workflows($wfId)?`$select=name,statecode,statuscode,clientdata"
$cd = $wf.clientdata | ConvertFrom-Json -Depth 100

# ---- Build new actions ----
# 1) Get_vehicle (runs from trigger)
$getVehicle = [ordered]@{
  runAfter = @{}
  type = "OpenApiConnection"
  inputs = [ordered]@{
    parameters = [ordered]@{
      entityName = "dmv_vehicles"
      recordId = "@triggerOutputs()?['body/_dmv_vehicleid_value']"
    }
    host = [ordered]@{
      apiId = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
      operationId = "GetItem"
      connectionName = "shared_commondataserviceforapps"
    }
  }
}

# 2) Assign_plate_if_needed — condition: plate is empty
# Plate generator: 3 upper hex letters from guid + "-" + 4 digits from ticks
$plateExpr = "@concat(toUpper(substring(replace(guid(),'-',''),0,3)),'-',substring(string(add(mod(ticks(utcNow()),9000),1000)),0,4))"

$assignPlate = [ordered]@{
  type = "OpenApiConnection"
  inputs = [ordered]@{
    parameters = [ordered]@{
      entityName = "dmv_vehicles"
      recordId = "@triggerOutputs()?['body/_dmv_vehicleid_value']"
      "item/dmv_platenumber" = $plateExpr
      "item/dmv_platestate" = "TX"
      "item/dmv_platetype" = 100000000
    }
    host = [ordered]@{
      apiId = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
      operationId = "UpdateRecord"
      connectionName = "shared_commondataserviceforapps"
    }
  }
}

$ifNoPlate = [ordered]@{
  runAfter = @{ Get_vehicle = @("Succeeded") }
  type = "If"
  expression = [ordered]@{
    or = @(
      @{ equals = @("@outputs('Get_vehicle')?['body/dmv_platenumber']", $null) },
      @{ equals = @("@outputs('Get_vehicle')?['body/dmv_platenumber']", "") }
    )
  }
  actions = [ordered]@{ Assign_plate = $assignPlate }
  "else" = [ordered]@{ actions = @{} }
}

# Add new actions to the definition
$actions = $cd.properties.definition.actions
# Need to convert PSCustomObject to hashtable-like and add properties
Add-Member -InputObject $actions -MemberType NoteProperty -Name "Get_vehicle" -Value $getVehicle -Force
Add-Member -InputObject $actions -MemberType NoteProperty -Name "If_no_plate" -Value $ifNoPlate -Force

$newCd = $cd | ConvertTo-Json -Depth 100 -Compress

# ---- Deactivate, patch, reactivate ----
$patchHdr = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "If-Match" = "*"
}

Write-Host "=== Deactivating flow ==="
$deact = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $patchHdr -Body ([System.Text.Encoding]::UTF8.GetBytes($deact)) -UseBasicParsing | Out-Null

Write-Host "=== Patching clientdata ==="
$body = @{ clientdata = $newCd } | ConvertTo-Json -Depth 100
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $patchHdr -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null

Write-Host "=== Reactivating flow ==="
$act = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $patchHdr -Body ([System.Text.Encoding]::UTF8.GetBytes($act)) -UseBasicParsing | Out-Null

Write-Host "Done."
