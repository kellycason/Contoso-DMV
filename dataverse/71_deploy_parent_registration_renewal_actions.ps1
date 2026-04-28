<#
  Adds a parent-agent registration renewal action topic directly to
  Contact Center DMV Agent. This avoids connected-agent orchestration and uses
  the existing maker Dataverse connection under the parent bot.

  Topic behavior:
  - Requires PortalContactId from the portal chat context.
  - Confirms before creating a contact-based dmv_registrationrenewal request.
  - Avoids connector output row parsing so the topic remains publishable in
    Copilot Studio's Power Fx validator.
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

    - kind: Question
      id: question_confirmRenewal
      variable: init:Topic.ConfirmRenewal
      prompt: |-
        I can submit a registration renewal request for your portal account.

        Would you like me to submit it now?
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
      id: invokeConnectorAction_createRenewal
      input:
        binding:
          entityName: dmv_registrationrenewals
          organization: current
          item/dmv_channel: =100000003
          item/dmv_contactid@odata.bind: ="contacts(" & Global.PortalContactId & ")"
          item/dmv_renewalstatus: =100000000
          item/dmv_submitteddate: =Now()
          item/dmv_renewalfee: =50
          item/dmv_email: =Global.Email
      output:
        kind: SingleVariableOutputBinding
        variable: Topic.CreatedRenewal
      connectionReference: dmv_sharedcommondataserviceforapps_2ca64
      connectionProperties:
        name: dmv_sharedcommondataserviceforapps_2ca64
        mode: Maker
      dynamicInputSchema:
        properties:
          entityName:
            displayName: Table name
            isRequired: true
            order: 0
            type: String
          organization:
            displayName: Environment
            isRequired: true
            order: 1
            type: String
          item:
            displayName: Row
            order: 2
            type:
              kind: Record
              properties:
                dmv_channel:
                  displayName: Channel
                  order: 0
                  type: Number
                dmv_contactid@odata.bind:
                  displayName: Contact
                  order: 1
                  type: String
                dmv_renewalstatus:
                  displayName: Renewal Status
                  order: 2
                  type: Number
                dmv_submitteddate:
                  displayName: Submitted Date
                  order: 3
                  type: DateTime
                dmv_renewalfee:
                  displayName: Renewal Fee
                  order: 4
                  type: Number
                dmv_email:
                  displayName: Email
                  order: 5
                  type: String
      dynamicOutputSchema:
        kind: Record
        properties:
          dmv_registrationrenewalid:
            displayName: Registration Renewal
            order: 0
            type: String
      operationId: CreateRecord

    - kind: SendActivity
      id: sendActivity_renewalCreated
      activity: |-
        Done. I submitted your registration renewal request.

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