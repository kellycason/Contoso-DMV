# Add plate number to approval email.
# Adds Get_vehicle_final (post-plate-assignment) and wires email HTML to reference it.

$envUrl = "https://orga381269e.crm9.dynamics.com"
$token  = az account get-access-token --resource $envUrl --query accessToken -o tsv
$wfId = '8a7b6c5d-4e3f-2a1b-9c8d-1f2e3d4c5b6a'

$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-MaxVersion" = "4.0"
  "OData-Version" = "4.0"
  "If-Match" = "*"
}

Write-Host "=== Fetching flow ==="
$wf = Invoke-RestMethod -Headers $h -Uri "$envUrl/api/data/v9.2/workflows($wfId)?`$select=clientdata"
$cd = $wf.clientdata | ConvertFrom-Json -Depth 100

$actions = $cd.properties.definition.actions

# 1) Add Get_vehicle_final — runs after If_no_plate completes (succeeded or skipped)
$getVehicleFinal = [ordered]@{
  runAfter = @{ If_no_plate = @("Succeeded", "Skipped") }
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
Add-Member -InputObject $actions -MemberType NoteProperty -Name "Get_vehicle_final" -Value $getVehicleFinal -Force

# 2) Gate If_pending_tag_found on both List_pending_tags AND Get_vehicle_final
$actions.If_pending_tag_found.runAfter = [ordered]@{
  List_pending_tags = @("Succeeded")
  Get_vehicle_final = @("Succeeded")
}

# 3) Inject plate row into email body, replacing the "plate will arrive by mail" line target
$email = $actions.If_pending_tag_found.actions.Send_approval_email
$body = $email.inputs.parameters."emailMessage/Body"

# Add a new plate card right under the tag card (before the info table)
$plateCard = @'
<table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;"><tbody><tr>
      <td style="background:#1a6e3a;border-radius:8px;padding:20px;text-align:center;">
        <p style="margin:0 0 8px;font-size:10px;font-weight:600;letter-spacing:0.2em;color:#e8c84b;font-family:Arial,sans-serif;text-transform:uppercase;">License Plate Assigned</p>
        <p style="margin:0;font-size:36px;font-weight:700;letter-spacing:0.15em;color:#ffffff;font-family:Courier New,monospace;line-height:1;">
          @{outputs('Get_vehicle_final')?['body/dmv_platenumber']}
        </p>
      </td>
    </tr></tbody></table>

    
'@

# Insert plate card after the tag card — find the closing of tag card and insert
$tagCardEnd = '</tbody></table>' + "`n`n" + '    <table cellpadding="0" cellspacing="0" style="background:#f0f5f1;'
$newTagCardEnd = '</tbody></table>' + "`n`n    " + $plateCard + '    <table cellpadding="0" cellspacing="0" style="background:#f0f5f1;'
if ($body.Contains($tagCardEnd)) {
  $body = $body.Replace($tagCardEnd, $newTagCardEnd)
  Write-Host "  Injected plate card after tag card"
} else {
  # Fallback: do raw match on newline-escaped form in stored JSON string
  $tagCardEndEsc = '</tbody></table>\n\n    <table cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f0f5f1;'
  $newTagCardEndEsc = '</tbody></table>\n\n    ' + $plateCard.Replace("`n", '\n').Replace('"','\"') + '    <table cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f0f5f1;'
  if ($body.Contains($tagCardEndEsc)) {
    $body = $body.Replace($tagCardEndEsc, $newTagCardEndEsc)
    Write-Host "  Injected plate card (escaped path)"
  } else {
    Write-Host "  WARNING: could not find tag card end marker" -ForegroundColor Yellow
  }
}

# Also change the yellow warning note — remove "permanent plate will arrive by mail" since we now show it
$oldNote = 'Your permanent registration plate will arrive by mail within 7–10 business days.'
$newNote = 'Your metal plates and registration sticker will arrive by mail within 7–10 business days.'
$body = $body.Replace($oldNote, $newNote)

$email.inputs.parameters."emailMessage/Body" = $body

$newCd = $cd | ConvertTo-Json -Depth 100 -Compress

# Deactivate -> patch -> reactivate
Write-Host "=== Deactivating ==="
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes((@{statecode=0;statuscode=1}|ConvertTo-Json))) -UseBasicParsing | Out-Null
Write-Host "=== Patching ==="
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes((@{clientdata=$newCd}|ConvertTo-Json -Depth 100))) -UseBasicParsing | Out-Null
Write-Host "=== Reactivating ==="
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($wfId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes((@{statecode=1;statuscode=2}|ConvertTo-Json))) -UseBasicParsing | Out-Null
Write-Host "Done."
