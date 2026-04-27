<#
  56_build_appointment_confirmation_flow.ps1

  Builds a Power Automate flow solution zip that:
    Trigger:  dmv_appointment created
    Actions:
      1. Get contact (for email, names)
      2. Get office (for address, phone)
      3. Compose start/end datetimes from appointment date + time string
      4. Compose ICS calendar invite body
      5. Base64-encode the ICS for attachment
      6. Send HTML email to citizen with .ics attached (add-to-calendar)
      7. Mark dmv_confirmationsent = true on the appointment

  Output: dataverse/DMVAppointmentConfirmationFlow_1_0_0_1.zip

  Import via: make.powerapps.com -> Solutions -> Import solution
    - Browse to the zip
    - Pick/create connections for Dataverse + Office 365 Outlook
    - After import, open flow -> Turn on
#>

$ErrorActionPreference = "Stop"

$workRoot = Join-Path $PSScriptRoot "_appt_conf_flow_build"
$zipPath  = Join-Path $PSScriptRoot "DMVAppointmentConfirmationFlow_1_0_0_1.zip"

if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -Path $workRoot -ItemType Directory | Out-Null
New-Item -Path (Join-Path $workRoot "Workflows") -ItemType Directory | Out-Null

$solutionUnique = "DMVAppointmentConfirmationFlow"
$flowId         = "7a2b9c31-4d5e-48af-b712-001122334455"
$dvConnRef      = "dmv_sharedcommondataserviceforapps_appt"
$o365ConnRef    = "dmv_sharedoffice365_appt"

# ─── ICS calendar invite body (built via concat() at runtime) ───
# Newlines are \r\n per RFC5545; we'll inline them as \n which calendar clients also accept.
$icsExpression = @"
@concat(
'BEGIN:VCALENDAR', decodeUriComponent('%0D%0A'),
'VERSION:2.0', decodeUriComponent('%0D%0A'),
'PRODID:-//Contoso DMV//Appointment//EN', decodeUriComponent('%0D%0A'),
'CALSCALE:GREGORIAN', decodeUriComponent('%0D%0A'),
'METHOD:REQUEST', decodeUriComponent('%0D%0A'),
'BEGIN:VTIMEZONE', decodeUriComponent('%0D%0A'),
'TZID:America/Chicago', decodeUriComponent('%0D%0A'),
'BEGIN:STANDARD', decodeUriComponent('%0D%0A'),
'DTSTART:19701101T020000', decodeUriComponent('%0D%0A'),
'RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=11', decodeUriComponent('%0D%0A'),
'TZOFFSETFROM:-0500', decodeUriComponent('%0D%0A'),
'TZOFFSETTO:-0600', decodeUriComponent('%0D%0A'),
'TZNAME:CST', decodeUriComponent('%0D%0A'),
'END:STANDARD', decodeUriComponent('%0D%0A'),
'BEGIN:DAYLIGHT', decodeUriComponent('%0D%0A'),
'DTSTART:19700308T020000', decodeUriComponent('%0D%0A'),
'RRULE:FREQ=YEARLY;BYDAY=2SU;BYMONTH=3', decodeUriComponent('%0D%0A'),
'TZOFFSETFROM:-0600', decodeUriComponent('%0D%0A'),
'TZOFFSETTO:-0500', decodeUriComponent('%0D%0A'),
'TZNAME:CDT', decodeUriComponent('%0D%0A'),
'END:DAYLIGHT', decodeUriComponent('%0D%0A'),
'END:VTIMEZONE', decodeUriComponent('%0D%0A'),
'BEGIN:VEVENT', decodeUriComponent('%0D%0A'),
'UID:', triggerOutputs()?['body/dmv_appointmentnumber'], '@contosodmv.gov', decodeUriComponent('%0D%0A'),
'DTSTAMP:', formatDateTime(utcNow(), 'yyyyMMddTHHmmss'), 'Z', decodeUriComponent('%0D%0A'),
'ORGANIZER;CN=Contoso DMV:mailto:noreply@contosodmv.gov', decodeUriComponent('%0D%0A'),
'ATTENDEE;CN=', outputs('Get_contact')?['body/firstname'], ' ', outputs('Get_contact')?['body/lastname'], ';ROLE=REQ-PARTICIPANT;RSVP=TRUE:mailto:', outputs('Get_contact')?['body/emailaddress1'], decodeUriComponent('%0D%0A'),
'DTSTART;TZID=America/Chicago:', outputs('Compose_start_ics'), decodeUriComponent('%0D%0A'),
'DTEND;TZID=America/Chicago:', outputs('Compose_end_ics'), decodeUriComponent('%0D%0A'),
'SUMMARY:', triggerOutputs()?['body/dmv_servicetype@OData.Community.Display.V1.FormattedValue'], ' - Contoso DMV', decodeUriComponent('%0D%0A'),
'LOCATION:', outputs('Get_office')?['body/dmv_officename'], ', ', outputs('Get_office')?['body/dmv_address1'], ', ', outputs('Get_office')?['body/dmv_city'], ', ', outputs('Get_office')?['body/dmv_state'], ' ', outputs('Get_office')?['body/dmv_zipcode'], decodeUriComponent('%0D%0A'),
'DESCRIPTION:Confirmation: ', triggerOutputs()?['body/dmv_appointmentnumber'], '\\nPlease arrive 10 minutes early. Bring a valid government-issued photo ID and any required documents for your service.\\n\\nQuestions? Call ', coalesce(outputs('Get_office')?['body/dmv_phone'], '(214) 555-0100'), decodeUriComponent('%0D%0A'),
'STATUS:CONFIRMED', decodeUriComponent('%0D%0A'),
'SEQUENCE:0', decodeUriComponent('%0D%0A'),
'BEGIN:VALARM', decodeUriComponent('%0D%0A'),
'TRIGGER:-PT1H', decodeUriComponent('%0D%0A'),
'ACTION:DISPLAY', decodeUriComponent('%0D%0A'),
'DESCRIPTION:Contoso DMV appointment in 1 hour', decodeUriComponent('%0D%0A'),
'END:VALARM', decodeUriComponent('%0D%0A'),
'END:VEVENT', decodeUriComponent('%0D%0A'),
'END:VCALENDAR', decodeUriComponent('%0D%0A')
)
"@
$icsExpression = $icsExpression -replace "`r?`n", ""  # single-line expression

# ─── Email HTML body ───
$emailBody = @'
<table cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:24px 0;width:100%;">
<tbody><tr><td align="center">
<table cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;width:600px;">

  <tbody><tr>
    <td style="background:#1a3d2b;padding:24px 32px;">
      <table cellpadding="0" cellspacing="0">
        <tbody>
          <tr>
            <td style="color:#ffffff;font-size:24px;font-weight:700;font-family:Georgia,serif;letter-spacing:-0.3px;padding-right:12px;vertical-align:middle;">
              Contoso DMV
            </td>
            <td style="border-left:2px solid rgba(232,200,75,0.5);padding-left:12px;vertical-align:middle;">
              <span style="display:block;color:#e8c84b;font-size:11px;font-weight:600;letter-spacing:0.12em;text-transform:uppercase;font-family:Arial,sans-serif;line-height:1;">
                Department of Motor Vehicles
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </td>
  </tr>

  <tr><td style="background:#e8c84b;height:4px;"></td></tr>

  <tr>
    <td style="padding:32px;font-family:Arial,sans-serif;">
      <p style="margin:0 0 16px;font-size:16px;color:#333;">
        Dear <strong>@{outputs('Get_contact')?['body/firstname']} @{outputs('Get_contact')?['body/lastname']}</strong>,
      </p>
      <p style="margin:0 0 24px;font-size:15px;color:#333;line-height:1.6;">
        Your appointment at Contoso DMV is <strong style="color:#1a6e3a;">confirmed</strong>.
        Add it to your calendar using the attached <strong>.ics</strong> invite, or use the details below.
      </p>

      <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td style="background:#1a3d2b;border-radius:8px;padding:20px;text-align:center;">
            <p style="margin:0 0 8px;font-size:10px;font-weight:600;letter-spacing:0.2em;color:#e8c84b;font-family:Arial,sans-serif;text-transform:uppercase;">Confirmation Number</p>
            <p style="margin:0;font-size:28px;font-weight:700;letter-spacing:0.1em;color:#ffffff;font-family:Georgia,serif;line-height:1;">
              @{triggerOutputs()?['body/dmv_appointmentnumber']}
            </p>
          </td>
        </tr></tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="background:#f0f5f1;border-radius:6px;margin:0 0 24px;width:100%;">
        <tbody>
          <tr>
            <td style="padding:16px 20px;border-bottom:1px solid #dbe3dc;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Service</div>
              <div style="font-size:15px;color:#1a3d2b;font-weight:600;">@{triggerOutputs()?['body/dmv_servicetype@OData.Community.Display.V1.FormattedValue']}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 20px;border-bottom:1px solid #dbe3dc;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Date &amp; Time</div>
              <div style="font-size:15px;color:#1a3d2b;font-weight:600;">
                @{formatDateTime(triggerOutputs()?['body/dmv_appointmentdate'], 'dddd, MMMM d, yyyy')} at @{triggerOutputs()?['body/dmv_appointmenttime']}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 20px;border-bottom:1px solid #dbe3dc;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Location</div>
              <div style="font-size:15px;color:#1a3d2b;font-weight:600;margin:0 0 4px;">@{outputs('Get_office')?['body/dmv_officename']}</div>
              <div style="font-size:13px;color:#333;line-height:1.5;">
                @{outputs('Get_office')?['body/dmv_address1']}<br/>
                @{outputs('Get_office')?['body/dmv_city']}, @{outputs('Get_office')?['body/dmv_state']} @{outputs('Get_office')?['body/dmv_zipcode']}<br/>
                @{outputs('Get_office')?['body/dmv_phone']}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 20px;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Hours</div>
              <div style="font-size:13px;color:#333;line-height:1.6;white-space:pre-line;">@{outputs('Get_office')?['body/dmv_hours']}</div>
            </td>
          </tr>
        </tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td align="center">
            <a href="https://www.google.com/maps/search/?api=1&amp;query=@{encodeUriComponent(concat(outputs('Get_office')?['body/dmv_address1'], ', ', outputs('Get_office')?['body/dmv_city'], ', ', outputs('Get_office')?['body/dmv_state'], ' ', outputs('Get_office')?['body/dmv_zipcode']))}"
               style="display:inline-block;background:#1a3d2b;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:6px;font-size:14px;font-weight:600;font-family:Arial,sans-serif;">
              Get Directions
            </a>
          </td>
        </tr></tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="background:#fdf7e0;border-left:3px solid #e8c84b;border-radius:4px;width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td style="padding:14px 18px;font-size:13px;color:#5a4a00;line-height:1.6;">
            <strong>What to bring:</strong><br/>
            Valid government-issued photo ID, any current license/registration related to your visit, and required documents for your service type. Arrive <strong>10 minutes early</strong>.
          </td>
        </tr></tbody>
      </table>

      <p style="margin:0 0 8px;font-size:13px;color:#666;line-height:1.6;">
        Need to reschedule? Visit <a href="https://site-y5jzr.powerappsportals.us/appointments" style="color:#1a3d2b;font-weight:600;">My DMV</a> or call the office directly.
      </p>
      <p style="margin:0;font-size:12px;color:#999;">
        This is an automated message from Contoso DMV. Please do not reply.
      </p>
    </td>
  </tr>
</tbody></table>
</td></tr></tbody></table>
'@

# ─── Flow definition ───
$definition = [ordered]@{
    '$schema' = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion = '1.0.0.0'
    parameters = [ordered]@{
        '$connections'    = [ordered]@{ defaultValue = @{}; type = 'Object' }
        '$authentication' = [ordered]@{ defaultValue = @{}; type = 'SecureObject' }
    }
    triggers = [ordered]@{
        'When_an_appointment_is_created' = [ordered]@{
            type = 'OpenApiConnectionWebhook'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'SubscribeWebhookTrigger'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    'subscriptionRequest/message'    = 1   # Create
                    'subscriptionRequest/entityname' = 'dmv_appointment'
                    'subscriptionRequest/scope'      = 4   # Organization
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }
    actions = [ordered]@{
        'Guard_has_contact' = [ordered]@{
            type = 'If'
            expression = [ordered]@{
                and = @(
                    [ordered]@{
                        not = @(
                            [ordered]@{ equals = @("@coalesce(triggerOutputs()?['body/_dmv_contactid_value'], '')", '') }
                        )
                    },
                    # Idempotency: only send if confirmation hasn't already been sent
                    [ordered]@{
                        not = @(
                            [ordered]@{ equals = @("@coalesce(triggerOutputs()?['body/dmv_confirmationsent'], false)", $true) }
                        )
                    }
                )
            }
            actions = [ordered]@{
                'Get_contact' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_commondataserviceforapps'
                            operationId    = 'GetItem'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        }
                        parameters = [ordered]@{
                            entityName = 'contacts'
                            recordId   = "@triggerOutputs()?['body/_dmv_contactid_value']"
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{}
                }
                'Get_office' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_commondataserviceforapps'
                            operationId    = 'GetItem'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        }
                        parameters = [ordered]@{
                            entityName = 'dmv_dmvoffices'
                            recordId   = "@triggerOutputs()?['body/_dmv_officeid_value']"
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Get_contact = @('Succeeded') }
                }
                'Compose_date_part' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@formatDateTime(triggerOutputs()?['body/dmv_appointmentdate'], 'yyyy-MM-dd')"
                    runAfter = @{ Get_office = @('Succeeded') }
                }
                'Compose_combined_dt' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@concat(outputs('Compose_date_part'), ' ', triggerOutputs()?['body/dmv_appointmenttime'])"
                    runAfter = @{ Compose_date_part = @('Succeeded') }
                }
                'Compose_start_parsed' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@parseDateTime(outputs('Compose_combined_dt'), 'en-US')"
                    runAfter = @{ Compose_combined_dt = @('Succeeded') }
                }
                'Compose_end_parsed' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@addMinutes(outputs('Compose_start_parsed'), 30)"
                    runAfter = @{ Compose_start_parsed = @('Succeeded') }
                }
                'Compose_start_ics' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@formatDateTime(outputs('Compose_start_parsed'), 'yyyyMMddTHHmmss')"
                    runAfter = @{ Compose_end_parsed = @('Succeeded') }
                }
                'Compose_end_ics' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@formatDateTime(outputs('Compose_end_parsed'), 'yyyyMMddTHHmmss')"
                    runAfter = @{ Compose_start_ics = @('Succeeded') }
                }
                'Compose_ics_body' = [ordered]@{
                    type   = 'Compose'
                    inputs = $icsExpression
                    runAfter = @{ Compose_end_ics = @('Succeeded') }
                }
                'Compose_ics_b64' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@base64(outputs('Compose_ics_body'))"
                    runAfter = @{ Compose_ics_body = @('Succeeded') }
                }
                'Send_confirmation_email' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_office365'
                            operationId    = 'SendEmailV2'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_office365'
                        }
                        parameters = [ordered]@{
                            'emailMessage/To'                  = "@outputs('Get_contact')?['body/emailaddress1']"
                            'emailMessage/Subject'             = "@concat('Appointment confirmed - ', triggerOutputs()?['body/dmv_appointmentnumber'], ' - ', formatDateTime(triggerOutputs()?['body/dmv_appointmentdate'], 'MMM d'))"
                            'emailMessage/Body'                = $emailBody
                            'emailMessage/Importance'          = 'Normal'
                            'emailMessage/Attachments'         = @(
                                [ordered]@{
                                    '@@odata.type' = '#Microsoft.OutlookServices.FileAttachment'
                                    Name           = "@concat('contoso-dmv-', triggerOutputs()?['body/dmv_appointmentnumber'], '.ics')"
                                    ContentBytes   = "@outputs('Compose_ics_b64')"
                                    ContentType    = 'text/calendar; method=REQUEST; charset=UTF-8'
                                }
                            )
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Compose_ics_b64 = @('Succeeded') }
                }
                'Mark_confirmation_sent' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_commondataserviceforapps'
                            operationId    = 'UpdateRecord'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        }
                        parameters = [ordered]@{
                            entityName = 'dmv_appointments'
                            recordId   = "@triggerOutputs()?['body/dmv_appointmentid']"
                            'item/dmv_confirmationsent' = $true
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Send_confirmation_email = @('Succeeded') }
                }
            }
            else = [ordered]@{ actions = @{} }
            runAfter = @{}
        }
    }
}

$workflowJson = [ordered]@{
    properties = [ordered]@{
        connectionReferences = [ordered]@{
            shared_commondataserviceforapps = [ordered]@{
                runtimeSource = 'embedded'
                connection    = [ordered]@{ connectionReferenceLogicalName = $dvConnRef }
                api           = [ordered]@{ name = 'shared_commondataserviceforapps' }
            }
            shared_office365 = [ordered]@{
                runtimeSource = 'embedded'
                connection    = [ordered]@{ connectionReferenceLogicalName = $o365ConnRef }
                api           = [ordered]@{ name = 'shared_office365' }
            }
        }
        definition = $definition
    }
    schemaVersion = '1.0.0.0'
}

$flowFileName = "DMV-AppointmentConfirmation-$flowId.json"
$flowPath = Join-Path $workRoot "Workflows/$flowFileName"
($workflowJson | ConvertTo-Json -Depth 60) | Set-Content -Path $flowPath -Encoding UTF8

# ─── customizations.xml ───
$customizations = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml>
  <Entities />
  <Roles />
  <Workflows>
    <Workflow WorkflowId="{$flowId}" Name="DMV - Appointment Confirmation Email">
      <JsonFileName>/Workflows/$flowFileName</JsonFileName>
      <Type>1</Type>
      <Subprocess>0</Subprocess>
      <Category>5</Category>
      <Mode>0</Mode>
      <Scope>4</Scope>
      <OnDemand>0</OnDemand>
      <Trigger>0</Trigger>
      <IsTransacted>1</IsTransacted>
      <IntroducedVersion>1.0.0.0</IntroducedVersion>
      <IsCustomizable>1</IsCustomizable>
      <BusinessProcessType>0</BusinessProcessType>
      <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>
      <PrimaryEntity>none</PrimaryEntity>
    </Workflow>
  </Workflows>
  <FieldSecurityProfiles />
  <Templates />
  <EntityMaps />
  <EntityRelationships />
  <OrganizationSettings />
  <optionsets />
  <CustomControls />
  <EntityDataProviders />
  <connectionreferences>
    <connectionreference connectionreferencelogicalname="$dvConnRef">
      <connectionreferencedisplayname>Dataverse</connectionreferencedisplayname>
      <connectorid>/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps</connectorid>
      <iscustomizable>1</iscustomizable>
      <statecode>0</statecode>
      <statuscode>1</statuscode>
    </connectionreference>
    <connectionreference connectionreferencelogicalname="$o365ConnRef">
      <connectionreferencedisplayname>Office 365 Outlook</connectionreferencedisplayname>
      <connectorid>/providers/Microsoft.PowerApps/apis/shared_office365</connectorid>
      <iscustomizable>1</iscustomizable>
      <statecode>0</statecode>
      <statuscode>1</statuscode>
    </connectionreference>
  </connectionreferences>
  <Languages>
    <Language>1033</Language>
  </Languages>
</ImportExportXml>
"@

Set-Content -Path (Join-Path $workRoot "customizations.xml") -Value $customizations -Encoding UTF8

# ─── solution.xml ───
$solutionXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="PS56" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>$solutionUnique</UniqueName>
    <LocalizedNames>
      <LocalizedName description="DMV Appointment Confirmation Flow" languagecode="1033" />
    </LocalizedNames>
    <Descriptions>
      <Description description="On appointment create: sends the citizen an HTML confirmation email with a .ics calendar invite attached." languagecode="1033" />
    </Descriptions>
    <Version>1.0.0.1</Version>
    <Managed>0</Managed>
    <Publisher>
      <UniqueName>dmv</UniqueName>
      <LocalizedNames>
        <LocalizedName description="DMV" languagecode="1033" />
      </LocalizedNames>
      <Descriptions>
        <Description description="DMV Digital Services Publisher" languagecode="1033" />
      </Descriptions>
      <EMailAddress xsi:nil="true" />
      <SupportingWebsiteUrl xsi:nil="true" />
      <CustomizationPrefix>dmv</CustomizationPrefix>
      <CustomizationOptionValuePrefix>75615</CustomizationOptionValuePrefix>
      <Addresses>
        <Address>
          <AddressNumber>1</AddressNumber><AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" />
          <Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" />
          <Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" /><Name xsi:nil="true" />
          <PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" />
          <StateOrProvince xsi:nil="true" /><Telephone1 xsi:nil="true" />
          <Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" />
          <UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
        <Address>
          <AddressNumber>2</AddressNumber><AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" />
          <Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" />
          <Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" /><Name xsi:nil="true" />
          <PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" />
          <StateOrProvince xsi:nil="true" /><Telephone1 xsi:nil="true" />
          <Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" />
          <UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
      </Addresses>
    </Publisher>
    <RootComponents>
      <RootComponent type="29" id="{$flowId}" behavior="0" />
    </RootComponents>
    <MissingDependencies />
  </SolutionManifest>
</ImportExportXml>
"@

Set-Content -Path (Join-Path $workRoot "solution.xml") -Value $solutionXml -Encoding UTF8

# ─── [Content_Types].xml ───
$contentTypes = @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="xml" ContentType="application/octet-stream" />
  <Default Extension="json" ContentType="application/octet-stream" />
</Types>
"@

Set-Content -LiteralPath (Join-Path $workRoot "[Content_Types].xml") -Value $contentTypes -Encoding UTF8

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workRoot, $zipPath)
Remove-Item $workRoot -Recurse -Force

Write-Host ""
Write-Host "=== Solution zip created ==="
Write-Host "  Path: $zipPath"
Write-Host "  Size: $([IO.FileInfo]::new($zipPath).Length) bytes"
Write-Host ""
Write-Host "Import steps:"
Write-Host "  1. make.powerapps.com -> Solutions -> Import solution"
Write-Host "  2. Browse and select: $zipPath"
Write-Host "  3. When prompted, pick/create connections for:"
Write-Host "       - Dataverse"
Write-Host "       - Office 365 Outlook (sends email from your mailbox)"
Write-Host "  4. After import, open 'DMV - Appointment Confirmation Email' flow -> Turn on"
Write-Host ""
Write-Host "Flow logic:"
Write-Host "  Trigger:  New dmv_appointment record"
Write-Host "  If contact linked:"
Write-Host "    - Get contact + office rows"
Write-Host "    - Parse appt date + time -> build start/end datetimes"
Write-Host "    - Compose ICS (VCALENDAR with America/Chicago TZ + VALARM 1-hr reminder)"
Write-Host "    - Send HTML email with .ics attachment (add-to-calendar)"
Write-Host "    - Stamp dmv_confirmationsent = true"
