<#
  Adds a parent-agent registration renewal action topic directly to
  Contact Center DMV Agent. This avoids connected-agent orchestration and uses
  the existing maker Dataverse connection under the parent bot.

  Topic behavior:
  - Requires PortalContactId from the portal chat context.
  - Lists the signed-in citizen's next registration by expiration date.
  - Confirms before creating a dmv_registrationrenewal request.
  - Supports status lookup for the latest renewal requests.
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$solutionName = "DMVDigitalServicesPortal"
$botId = "90a9ebcd-4342-f111-88b4-001dd801f94a"
$gptComponentId = "1d1a10e7-f6b2-4405-ad98-e3e74e7a98bd"
$connectionReference = "dmv_sharedcommondataserviceforapps_2ca64"

$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$readH = @{
    Authorization      = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    Accept             = "application/json"
}
$writeH = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    Accept                     = "application/json"
    "If-Match"                 = "*"
    "MSCRM.SolutionUniqueName" = $solutionName
}
$postH = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    Accept                     = "application/json"
    "MSCRM.SolutionUniqueName" = $solutionName
}

function Invoke-JsonPatch($uri, $body) {
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    Invoke-WebRequest -Uri $uri -Method Patch -Headers $writeH -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
}

function Invoke-JsonPost($uri, $body) {
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    return Invoke-WebRequest -Uri $uri -Method Post -Headers $postH -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing
}

function Get-EntityIdFromResponse($response) {
    $entityId = $response.Headers["OData-EntityId"] | Select-Object -First 1
    if (-not $entityId) { $entityId = $response.Headers["Location"] | Select-Object -First 1 }
    return ($entityId -replace '.*\(([^)]+)\).*', '$1')
}

$topicName = "Registration Renewal Actions"
$topicSchemaName = "crd60_agent.topic.RegistrationRenewalActions"

$topicData = @'
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  id: main
  intent:
    displayName: Registration Renewal Actions
    includeInOnSelectIntent: false
    triggerQueries:
      - renew my registration
      - renew my vehicle registration
      - renew my tags
      - renew my Tesla
      - start my renewal
      - submit my registration renewal
      - check my renewal status
      - what vehicles do I have
      - look up my registration
  actions:
    - kind: ConditionGroup
      id: conditionGroup_signedIn
      conditions:
        - id: conditionItem_notSignedIn
          condition: =IsBlank(Global.PortalContactId) Or Lower(Global.PortalContactId) = "unknown" Or Lower(Global.PortalContactId) = "not signed in"
          actions:
            - kind: SendActivity
              id: sendActivity_notSignedIn
              activity: You are not currently signed in to the Contoso DMV portal, so I cannot access your records. Please sign in to continue.
            - kind: EndDialog
              id: endDialog_notSignedIn

    - kind: ConditionGroup
      id: conditionGroup_statusIntent
      conditions:
        - id: conditionItem_statusIntent
          condition: =Find("status", Lower(System.Activity.Text)) > 0 Or Find("check", Lower(System.Activity.Text)) > 0
          actions:
            - kind: InvokeConnectorAction
              id: invokeConnectorAction_listRenewals
              input:
                binding:
                  $filter: ="_dmv_contactid_value eq " & Global.PortalContactId
                  $orderby: createdon desc
                  $select: dmv_renewalid,dmv_renewalstatus,dmv_submitteddate,dmv_newexpirationdate,dmv_confirmationnumber,dmv_platenumber,dmv_vehicleyear,dmv_vehiclemake,dmv_vehiclemodel
                  $top: 3
                  entityName: dmv_registrationrenewals
                  organization: current
              output:
                kind: SingleVariableOutputBinding
                variable: Topic.RenewalRows
              connectionReference: dmv_sharedcommondataserviceforapps_2ca64
              connectionProperties:
                mode: Maker
              operationId: ListRecordsWithOrganization

            - kind: ConditionGroup
              id: conditionGroup_hasRenewals
              conditions:
                - id: conditionItem_noRenewals
                  condition: =CountRows(Topic.RenewalRows.value) = 0
                  actions:
                    - kind: SendActivity
                      id: sendActivity_noRenewals
                      activity: I do not see any registration renewal requests for your portal account yet.
                    - kind: EndDialog
                      id: endDialog_noRenewals
              elseActions:
                - kind: SendActivity
                  id: sendActivity_showRenewals
                  activity: |-
                    Here are your latest registration renewal requests:

                    {Concat(Topic.RenewalRows.value, Coalesce(dmv_renewalid, "Renewal request") & " - status code " & Text(dmv_renewalstatus) & If(IsBlank(dmv_platenumber), "", " - plate " & dmv_platenumber), Char(10))}
                - kind: EndDialog
                  id: endDialog_statusDone

    - kind: InvokeConnectorAction
      id: invokeConnectorAction_listRegistrations
      input:
        binding:
          $filter: ="_dmv_regcontactid_value eq " & Global.PortalContactId & " and statecode eq 0"
          $orderby: dmv_expirationdate asc
          $select: dmv_vehicleregistrationid,dmv_registrationid,dmv_regstatus,dmv_expirationdate,_dmv_vehicleid_value
          $top: 1
          entityName: dmv_vehicleregistrations
          organization: current
      output:
        kind: SingleVariableOutputBinding
        variable: Topic.RegistrationRows
      connectionReference: dmv_sharedcommondataserviceforapps_2ca64
      connectionProperties:
        mode: Maker
      operationId: ListRecordsWithOrganization

    - kind: ConditionGroup
      id: conditionGroup_hasRegistration
      conditions:
        - id: conditionItem_noRegistration
          condition: =CountRows(Topic.RegistrationRows.value) = 0
          actions:
            - kind: SendActivity
              id: sendActivity_noRegistration
              activity: I could not find an active vehicle registration connected to your portal account.
            - kind: EndDialog
              id: endDialog_noRegistration

    - kind: SetVariable
      id: setVariable_selectedRegistration
      variable: init:Topic.SelectedRegistration
      value: =First(Topic.RegistrationRows.value)

    - kind: Question
      id: question_confirmRenewal
      variable: init:Topic.ConfirmRenewal
      prompt: |-
        I found registration {Topic.SelectedRegistration.dmv_registrationid}, expiring {Text(DateTimeValue(Topic.SelectedRegistration.dmv_expirationdate), DateTimeFormat.ShortDate)}.

        Would you like me to submit a registration renewal request for it now?
      entity: BooleanPrebuiltEntity

    - kind: ConditionGroup
      id: conditionGroup_confirmRenewal
      conditions:
        - id: conditionItem_cancelRenewal
          condition: =Topic.ConfirmRenewal = false
          actions:
            - kind: SendActivity
              id: sendActivity_cancelRenewal
              activity: No problem. I have not submitted a renewal request.
            - kind: EndDialog
              id: endDialog_cancelRenewal

    - kind: InvokeConnectorAction
      id: invokeConnectorAction_getVehicle
      input:
        binding:
          entityName: dmv_vehicles
          organization: current
          recordId: =Topic.SelectedRegistration._dmv_vehicleid_value
      output:
        kind: SingleVariableOutputBinding
        variable: Topic.VehicleRow
      connectionReference: dmv_sharedcommondataserviceforapps_2ca64
      connectionProperties:
        mode: Maker
      operationId: GetItemWithOrganization

    - kind: InvokeConnectorAction
      id: invokeConnectorAction_createRenewal
      input:
        binding:
          entityName: dmv_registrationrenewals
          organization: current
          item/dmv_channel: =100000003
          item/dmv_contactid@odata.bind: ="contacts(" & Global.PortalContactId & ")"
          item/dmv_registrationid@odata.bind: ="dmv_vehicleregistrations(" & Topic.SelectedRegistration.dmv_vehicleregistrationid & ")"
          item/dmv_vehicleid@odata.bind: ="dmv_vehicles(" & Topic.SelectedRegistration._dmv_vehicleid_value & ")"
          item/dmv_renewalstatus: =100000000
          item/dmv_submitteddate: =Now()
          item/dmv_renewalfee: =50
          item/dmv_platenumber: =Topic.VehicleRow.dmv_platenumber
          item/dmv_vin: =Topic.VehicleRow.dmv_vin
          item/dmv_vehicleyear: =Text(Topic.VehicleRow.dmv_year)
          item/dmv_vehiclemake: =Topic.VehicleRow.dmv_make
          item/dmv_vehiclemodel: =Topic.VehicleRow.dmv_model
          item/dmv_vehiclecolor: =Topic.VehicleRow.dmv_color
          item/dmv_email: =Global.Email
      output:
        kind: SingleVariableOutputBinding
        variable: Topic.CreatedRenewal
      connectionReference: dmv_sharedcommondataserviceforapps_2ca64
      connectionProperties:
        mode: Maker
      operationId: CreateRecord

    - kind: SendActivity
      id: sendActivity_renewalCreated
      activity: |-
        Done. I submitted your registration renewal request for registration {Topic.SelectedRegistration.dmv_registrationid}.

        The request is now in Submitted status with a $50 renewal fee. DMV staff can review it in Registration Renewals, and you can ask me to check your renewal status later.

inputType: {}
outputType: {}
'@

Write-Host "=== Deploy parent registration renewal topic ===" -ForegroundColor Cyan
$existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/botcomponents?`$filter=_parentbotid_value eq $botId and schemaname eq '$topicSchemaName'&`$select=botcomponentid&`$top=1" -Headers $readH
if ($existing.value.Count -gt 0) {
    $topicId = $existing.value[0].botcomponentid
    Invoke-JsonPatch "$envUrl/api/data/v9.2/botcomponents($topicId)" @{
        name = $topicName
        data = $topicData
        description = "Parent-owned vehicle registration renewal action flow."
    }
    Write-Host "Updated topic: $topicId"
} else {
    $resp = Invoke-JsonPost "$envUrl/api/data/v9.2/botcomponents" @{
        name = $topicName
        schemaname = $topicSchemaName
        componenttype = 9
        data = $topicData
        description = "Parent-owned vehicle registration renewal action flow."
        "parentbotid@odata.bind" = "/bots($botId)"
    }
    $topicId = Get-EntityIdFromResponse $resp
    Write-Host "Created topic: $topicId"
}

Write-Host "`n=== Update parent instructions ===" -ForegroundColor Cyan
$gpt = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/botcomponents($gptComponentId)?`$select=data" -Headers $readH
$data = $gpt.data
$marker = "  Registration renewal actions:"
if ($data -notmatch [regex]::Escape($marker)) {
    $addition = @'

  Registration renewal actions:
  - Handle record-specific vehicle registration renewal inside this parent agent only. Do not hand off to a connected or child agent.
  - When a signed-in user asks to renew registration, renew tags, renew a specific vehicle, list their vehicles, or check renewal status, use the Registration Renewal Actions topic.
  - The topic uses PortalContactId from the portal identity context and the maker Dataverse connection. Do not ask the user to authenticate with Copilot Studio.
  - General policy questions about renewal are still knowledge questions; actual submission/status/record lookup requests are action requests.
'@
    $data = $data.TrimEnd() + $addition
    Invoke-JsonPatch "$envUrl/api/data/v9.2/botcomponents($gptComponentId)" @{ data = $data }
    Write-Host "Instructions updated."
} else {
    Write-Host "Instructions already include renewal action guidance."
}

Write-Host "`n=== PublishAllXml ===" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $writeH -Method Post | Out-Null
    Write-Host "Published Dataverse customizations."
} catch {
    Write-Host "Publish warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nDone. Open Copilot Studio, review the Registration Renewal Actions topic, publish the parent agent, then test from a new portal chat." -ForegroundColor Green