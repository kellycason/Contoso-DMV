<#
  42_extend_flow_downstream.ps1

  - Change registration renewal term from +2 years to +1 year
  - Extend the approval flow with two new actions:
      Create_registration_term       (adds an Active Renewal term)
      Update_vehicle_registration    (rolls expiration/effective/status/currenttermid)
  - Re-backfill existing approved record REGRN-2026-4307 (1-year term + new term row + vehicle reg update)
#>
$ErrorActionPreference = "Stop"

$envUrl = "https://orga381269e.crm9.dynamics.com"
$flowId = "9f8e7d6c-5b4a-4321-9876-abcdef012345"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json; charset=utf-8"
  "OData-Version" = "4.0"
  "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{ Authorization = "Bearer $token"; "OData-Version" = "4.0" }

# ============================================================
# 1. Patch flow clientdata
# ============================================================
Write-Host "=== Step 1: Patching flow ===" -ForegroundColor Cyan
$wf = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/workflows($flowId)?`$select=clientdata,statecode,statuscode" -Headers $readH
$cd = $wf.clientdata
$before = $cd.Length

# 1a. 2 years -> 1 year
$cd = $cd.Replace(
  "addToTime(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 2, 'Year')",
  "addToTime(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 1, 'Year')"
)

# 1b. Append Create_registration_term + Update_vehicle_registration
$old = '"Update_registration_renewal":{"runAfter":{"Compose_expiration":["Succeeded"]},"metadata":{"operationMetadataId":"cd161c73-da4d-4e03-80cf-c592bcc442d8"},"type":"OpenApiConnection","inputs":{"host":{"connectionName":"shared_commondataserviceforapps","operationId":"UpdateRecord","apiId":"/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"},"parameters":{"entityName":"dmv_registrationrenewals","recordId":"@triggerOutputs()?[''body/dmv_registrationrenewalid'']","item/dmv_newexpirationdate":"@outputs(''Compose_expiration'')","item/dmv_temptagnumber":"@outputs(''Compose_tag_number'')"},"authentication":"@parameters(''$authentication'')"}}'

$createTerm = '"Create_registration_term":{"runAfter":{"Update_registration_renewal":["Succeeded"]},"metadata":{"operationMetadataId":"aaaaaaaa-0000-0000-0000-000000000001"},"type":"OpenApiConnection","inputs":{"host":{"connectionName":"shared_commondataserviceforapps","operationId":"CreateRecord","apiId":"/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"},"parameters":{"entityName":"dmv_registrationterms","item/dmv_termnumber":"@concat(''TERM-'', formatDateTime(utcNow(), ''yyyy''), ''-'', substring(guid(), 0, 8))","item/dmv_startdate":"@formatDateTime(coalesce(triggerOutputs()?[''body/dmv_approveddate''], utcNow()), ''yyyy-MM-dd'')","item/dmv_enddate":"@outputs(''Compose_expiration'')","item/dmv_issuedate":"@formatDateTime(coalesce(triggerOutputs()?[''body/dmv_approveddate''], utcNow()), ''yyyy-MM-dd'')","item/dmv_termstatus":100000000,"item/dmv_termtype":100000001,"item/dmv_vehicleregistrationid@odata.bind":"@concat(''dmv_vehicleregistrations('', triggerOutputs()?[''body/_dmv_registrationid_value''], '')'')"},"authentication":"@parameters(''$authentication'')"}}'

$updateVehReg = '"Update_vehicle_registration":{"runAfter":{"Create_registration_term":["Succeeded"]},"metadata":{"operationMetadataId":"aaaaaaaa-0000-0000-0000-000000000002"},"type":"OpenApiConnection","inputs":{"host":{"connectionName":"shared_commondataserviceforapps","operationId":"UpdateRecord","apiId":"/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"},"parameters":{"entityName":"dmv_vehicleregistrations","recordId":"@triggerOutputs()?[''body/_dmv_registrationid_value'']","item/dmv_effectivedate":"@formatDateTime(coalesce(triggerOutputs()?[''body/dmv_approveddate''], utcNow()), ''yyyy-MM-dd'')","item/dmv_expirationdate":"@outputs(''Compose_expiration'')","item/dmv_regstatus":100000000,"item/dmv_regyear":"@int(formatDateTime(outputs(''Compose_expiration''), ''yyyy''))","item/dmv_currenttermid@odata.bind":"@concat(''dmv_registrationterms('', outputs(''Create_registration_term'')?[''body/dmv_registrationtermid''], '')'')"},"authentication":"@parameters(''$authentication'')"}}'

$new = $old + ',' + $createTerm + ',' + $updateVehReg

if (-not $cd.Contains($old)) {
  Write-Host "ERROR: Update_registration_renewal block not matched verbatim. Already extended?" -ForegroundColor Red
  $alreadyHas = $cd.Contains('"Create_registration_term"')
  Write-Host "Create_registration_term present: $alreadyHas"
  exit 1
}
$cd = $cd.Replace($old, $new)

Write-Host "  clientdata: $before -> $($cd.Length) bytes (delta $($cd.Length - $before))"

Write-Host "  Turning flow off..." -ForegroundColor Yellow
$offBody = @{ statecode = 0; statuscode = 1 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($offBody)) -UseBasicParsing | Out-Null

$body = @{ clientdata = $cd } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing | Out-Null
Write-Host "  clientdata updated"

Write-Host "  Turning flow back on..." -ForegroundColor Yellow
$onBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/workflows($flowId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($onBody)) -UseBasicParsing | Out-Null

# ============================================================
# 2. Re-backfill approved renewals (+1 year) AND apply downstream
# ============================================================
Write-Host ""
Write-Host "=== Step 2: Re-backfilling approved renewals ===" -ForegroundColor Cyan
$recs = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals?`$filter=dmv_renewalstatus eq 100000002&`$select=dmv_registrationrenewalid,dmv_renewalid,dmv_approveddate,dmv_newexpirationdate,_dmv_registrationid_value,dmv_temptagnumber" -Headers $readH

foreach ($r in $recs.value) {
  if (-not $r.dmv_approveddate)            { Write-Host "  SKIP (no approved date): $($r.dmv_renewalid)"; continue }
  if (-not $r._dmv_registrationid_value)   { Write-Host "  SKIP (no registration lookup): $($r.dmv_renewalid)"; continue }

  $approved = [datetime]$r.dmv_approveddate
  $newExpiry = $approved.AddYears(1).ToString("yyyy-MM-dd")
  $approvedStr = $approved.ToString("yyyy-MM-dd")

  # 2a. Update renewal record's expiration
  $patch = @{ dmv_newexpirationdate = $newExpiry } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationrenewals($($r.dmv_registrationrenewalid))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
  Write-Host "  $($r.dmv_renewalid): dmv_newexpirationdate -> $newExpiry"

  # 2b. Create new active Renewal term
  $termNumber = "TERM-{0}-{1}" -f $approved.Year, (Get-Random -Minimum 10000 -Maximum 99999)
  $termBody = @{
    "dmv_termnumber"                            = $termNumber
    "dmv_startdate"                             = $approvedStr
    "dmv_enddate"                               = $newExpiry
    "dmv_issuedate"                             = $approvedStr
    "dmv_termstatus"                            = 100000000
    "dmv_termtype"                              = 100000001
    "dmv_vehicleregistrationid@odata.bind"      = "/dmv_vehicleregistrations($($r._dmv_registrationid_value))"
  } | ConvertTo-Json
  $createResp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_registrationterms" -Method Post -Headers ($h + @{ Prefer = "return=representation" }) -Body ([System.Text.Encoding]::UTF8.GetBytes($termBody)) -UseBasicParsing
  $newTerm = $createResp.Content | ConvertFrom-Json
  $newTermId = $newTerm.dmv_registrationtermid
  Write-Host "    New term: $termNumber ($newTermId), ends $newExpiry"

  # 2c. Update the vehicle registration
  $vrPatch = @{
    "dmv_effectivedate"                 = $approvedStr
    "dmv_expirationdate"                = $newExpiry
    "dmv_regstatus"                     = 100000000
    "dmv_regyear"                       = $approved.AddYears(1).Year
    "dmv_currenttermid@odata.bind"      = "/dmv_registrationterms($newTermId)"
  } | ConvertTo-Json
  Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_vehicleregistrations($($r._dmv_registrationid_value))" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($vrPatch)) -UseBasicParsing | Out-Null
  Write-Host "    Vehicle reg $($r._dmv_registrationid_value) updated: effective=$approvedStr, expires=$newExpiry, regyear=$($approved.AddYears(1).Year)"
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
