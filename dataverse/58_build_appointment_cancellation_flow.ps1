<#
  58_build_appointment_cancellation_flow.ps1

  Trigger:  dmv_appointment Update on dmv_status
  Action:   If dmv_status changed to Cancelled (100000005):
            send a cancellation email with METHOD:CANCEL .ics so the
            calendar event is removed automatically.

  Output: dataverse/DMVAppointmentCancellationFlow_1_0_0_0.zip
#>

$ErrorActionPreference = "Stop"

$workRoot = Join-Path $PSScriptRoot "_appt_cancel_flow_build"
$zipPath  = Join-Path $PSScriptRoot "DMVAppointmentCancellationFlow_1_0_0_0.zip"

if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -Path $workRoot -ItemType Directory | Out-Null
New-Item -Path (Join-Path $workRoot "Workflows") -ItemType Directory | Out-Null

$solutionUnique = "DMVAppointmentCancellationFlow"
$flowId         = "9c4dbe53-6f70-4ac1-d934-223344556677"
$dvConnRef      = "dmv_sharedcommondataserviceforapps_cancel"
$o365ConnRef    = "dmv_sharedoffice365_cancel"

# ─── ICS body — METHOD:CANCEL, STATUS:CANCELLED, SEQUENCE:2 ───
$icsExpression = @"
@concat(
'BEGIN:VCALENDAR', decodeUriComponent('%0D%0A'),
'VERSION:2.0', decodeUriComponent('%0D%0A'),
'PRODID:-//Contoso DMV//Appointment//EN', decodeUriComponent('%0D%0A'),
'CALSCALE:GREGORIAN', decodeUriComponent('%0D%0A'),
'METHOD:CANCEL', decodeUriComponent('%0D%0A'),
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
'ATTENDEE;CN=', outputs('Get_contact')?['body/firstname'], ' ', outputs('Get_contact')?['body/lastname'], ';ROLE=REQ-PARTICIPANT;RSVP=FALSE:mailto:', outputs('Get_contact')?['body/emailaddress1'], decodeUriComponent('%0D%0A'),
'DTSTART;TZID=America/Chicago:', outputs('Compose_start_ics'), decodeUriComponent('%0D%0A'),
'DTEND;TZID=America/Chicago:', outputs('Compose_end_ics'), decodeUriComponent('%0D%0A'),
'SUMMARY:CANCELLED - ', triggerOutputs()?['body/dmv_servicetype@OData.Community.Display.V1.FormattedValue'], ' - Contoso DMV', decodeUriComponent('%0D%0A'),
'DESCRIPTION:Your appointment has been cancelled. Confirmation: ', triggerOutputs()?['body/dmv_appointmentnumber'], decodeUriComponent('%0D%0A'),
'STATUS:CANCELLED', decodeUriComponent('%0D%0A'),
'SEQUENCE:2', decodeUriComponent('%0D%0A'),
'END:VEVENT', decodeUriComponent('%0D%0A'),
'END:VCALENDAR', decodeUriComponent('%0D%0A')
)
"@
$icsExpression = $icsExpression -replace "`r?`n", ""

# ─── Email HTML body — red cancellation accent ───
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

  <tr><td style="background:#c0392b;height:4px;"></td></tr>

  <tr>
    <td style="padding:32px;font-family:Arial,sans-serif;">
      <div style="display:inline-block;background:#fde8e8;color:#7a1d1d;font-size:11px;font-weight:700;letter-spacing:0.1em;text-transform:uppercase;padding:4px 10px;border-radius:4px;margin-bottom:16px;border:1px solid #c0392b;">
        ✕ Appointment Cancelled
      </div>
      <p style="margin:0 0 16px;font-size:16px;color:#333;">
        Dear <strong>@{outputs('Get_contact')?['body/firstname']} @{outputs('Get_contact')?['body/lastname']}</strong>,
      </p>
      <p style="margin:0 0 24px;font-size:15px;color:#333;line-height:1.6;">
        Your Contoso DMV appointment has been <strong>cancelled</strong>. The attached <strong>.ics</strong>
        file will remove the event from your calendar automatically.
      </p>

      <table cellpadding="0" cellspacing="0" style="background:#f7f7f7;border:1px solid #dbe3dc;border-radius:6px;margin:0 0 24px;width:100%;">
        <tbody>
          <tr>
            <td style="padding:14px 18px;border-bottom:1px solid #dbe3dc;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Cancelled Appointment</div>
              <div style="font-size:14px;color:#555;text-decoration:line-through;">
                @{triggerOutputs()?['body/dmv_servicetype@OData.Community.Display.V1.FormattedValue']}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:14px 18px;border-bottom:1px solid #dbe3dc;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Original Date &amp; Time</div>
              <div style="font-size:14px;color:#555;text-decoration:line-through;">
                @{formatDateTime(triggerOutputs()?['body/dmv_appointmentdate'], 'dddd, MMMM d, yyyy')} at @{triggerOutputs()?['body/dmv_appointmenttime']}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:14px 18px;">
              <div style="font-size:11px;font-weight:600;letter-spacing:0.1em;color:#6b7e73;text-transform:uppercase;margin:0 0 4px;">Confirmation Number</div>
              <div style="font-size:14px;color:#555;font-family:Georgia,serif;letter-spacing:0.05em;">
                @{triggerOutputs()?['body/dmv_appointmentnumber']}
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td align="center">
            <a href="https://site-y5jzr.powerappsportals.us/appointments"
               style="display:inline-block;background:#1a3d2b;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:6px;font-size:14px;font-weight:600;font-family:Arial,sans-serif;">
              Book a New Appointment
            </a>
          </td>
        </tr></tbody>
      </table>

      <p style="margin:0 0 8px;font-size:13px;color:#666;line-height:1.6;">
        If you didn't request this cancellation, please contact us right away.
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
# Trigger: Update on dmv_status, then If status==Cancelled
$definition = [ordered]@{
    '$schema' = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion = '1.0.0.0'
    parameters = [ordered]@{
        '$connections'    = [ordered]@{ defaultValue = @{}; type = 'Object' }
        '$authentication' = [ordered]@{ defaultValue = @{}; type = 'SecureObject' }
    }
    triggers = [ordered]@{
        'When_appointment_status_changes' = [ordered]@{
            type = 'OpenApiConnectionWebhook'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'SubscribeWebhookTrigger'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    'subscriptionRequest/message'             = 3   # Update
                    'subscriptionRequest/entityname'          = 'dmv_appointment'
                    'subscriptionRequest/scope'               = 4
                    'subscriptionRequest/filteringattributes' = 'dmv_status'
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }
    actions = [ordered]@{
        'Guard_cancelled_with_contact' = [ordered]@{
            type = 'If'
            expression = [ordered]@{
                and = @(
                    [ordered]@{ equals = @("@triggerOutputs()?['body/dmv_status']", 100000005) },
                    [ordered]@{
                        not = @(
                            [ordered]@{ equals = @("@coalesce(triggerOutputs()?['body/_dmv_contactid_value'], '')", '') }
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
                'Compose_date_part' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Get_contact = @('Succeeded') }
                    inputs = "@formatDateTime(triggerOutputs()?['body/dmv_appointmentdate'], 'yyyy-MM-dd')"
                }
                'Compose_combined_dt' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_date_part = @('Succeeded') }
                    inputs = "@concat(outputs('Compose_date_part'), ' ', triggerOutputs()?['body/dmv_appointmenttime'])"
                }
                'Compose_start_parsed' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_combined_dt = @('Succeeded') }
                    inputs = "@parseDateTime(outputs('Compose_combined_dt'), 'en-US')"
                }
                'Compose_end_parsed' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_start_parsed = @('Succeeded') }
                    inputs = "@addMinutes(outputs('Compose_start_parsed'), 30)"
                }
                'Compose_start_ics' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_end_parsed = @('Succeeded') }
                    inputs = "@formatDateTime(outputs('Compose_start_parsed'), 'yyyyMMddTHHmmss')"
                }
                'Compose_end_ics' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_start_ics = @('Succeeded') }
                    inputs = "@formatDateTime(outputs('Compose_end_parsed'), 'yyyyMMddTHHmmss')"
                }
                'Compose_ics_body' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_end_ics = @('Succeeded') }
                    inputs = $icsExpression
                }
                'Compose_ics_b64' = [ordered]@{
                    type = 'Compose'; runAfter = @{ Compose_ics_body = @('Succeeded') }
                    inputs = "@base64(outputs('Compose_ics_body'))"
                }
                'Send_cancellation_email' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_office365'
                            operationId    = 'SendEmailV2'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_office365'
                        }
                        parameters = [ordered]@{
                            'emailMessage/To'          = "@outputs('Get_contact')?['body/emailaddress1']"
                            'emailMessage/Subject'     = "@concat('Appointment cancelled - ', triggerOutputs()?['body/dmv_appointmentnumber'])"
                            'emailMessage/Body'        = $emailBody
                            'emailMessage/Importance'  = 'Normal'
                            'emailMessage/Attachments' = @(
                                [ordered]@{
                                    '@@odata.type' = '#Microsoft.OutlookServices.FileAttachment'
                                    Name           = "@concat('contoso-dmv-', triggerOutputs()?['body/dmv_appointmentnumber'], '-cancelled.ics')"
                                    ContentBytes   = "@outputs('Compose_ics_b64')"
                                    ContentType    = 'text/calendar; method=CANCEL; charset=UTF-8'
                                }
                            )
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Compose_ics_b64 = @('Succeeded') }
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

$flowFileName = "DMV-AppointmentCancellation-$flowId.json"
$flowPath = Join-Path $workRoot "Workflows/$flowFileName"
($workflowJson | ConvertTo-Json -Depth 60) | Set-Content -Path $flowPath -Encoding UTF8

$customizations = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml>
  <Entities />
  <Roles />
  <Workflows>
    <Workflow WorkflowId="{$flowId}" Name="DMV - Appointment Cancellation Email">
      <JsonFileName>/Workflows/$flowFileName</JsonFileName>
      <Type>1</Type><Subprocess>0</Subprocess><Category>5</Category><Mode>0</Mode><Scope>4</Scope>
      <OnDemand>0</OnDemand><Trigger>0</Trigger><IsTransacted>1</IsTransacted>
      <IntroducedVersion>1.0.0.0</IntroducedVersion><IsCustomizable>1</IsCustomizable>
      <BusinessProcessType>0</BusinessProcessType>
      <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>
      <PrimaryEntity>none</PrimaryEntity>
    </Workflow>
  </Workflows>
  <FieldSecurityProfiles /><Templates /><EntityMaps /><EntityRelationships />
  <OrganizationSettings /><optionsets /><CustomControls /><EntityDataProviders />
  <connectionreferences>
    <connectionreference connectionreferencelogicalname="$dvConnRef">
      <connectionreferencedisplayname>Dataverse</connectionreferencedisplayname>
      <connectorid>/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps</connectorid>
      <iscustomizable>1</iscustomizable><statecode>0</statecode><statuscode>1</statuscode>
    </connectionreference>
    <connectionreference connectionreferencelogicalname="$o365ConnRef">
      <connectionreferencedisplayname>Office 365 Outlook</connectionreferencedisplayname>
      <connectorid>/providers/Microsoft.PowerApps/apis/shared_office365</connectorid>
      <iscustomizable>1</iscustomizable><statecode>0</statecode><statuscode>1</statuscode>
    </connectionreference>
  </connectionreferences>
  <Languages><Language>1033</Language></Languages>
</ImportExportXml>
"@
Set-Content -Path (Join-Path $workRoot "customizations.xml") -Value $customizations -Encoding UTF8

$solutionXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="PS58" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>$solutionUnique</UniqueName>
    <LocalizedNames><LocalizedName description="DMV Appointment Cancellation Flow" languagecode="1033" /></LocalizedNames>
    <Descriptions><Description description="On appointment status -> Cancelled: sends a cancellation email with METHOD:CANCEL .ics so the calendar event is removed automatically." languagecode="1033" /></Descriptions>
    <Version>1.0.0.0</Version><Managed>0</Managed>
    <Publisher>
      <UniqueName>dmv</UniqueName>
      <LocalizedNames><LocalizedName description="DMV" languagecode="1033" /></LocalizedNames>
      <Descriptions><Description description="DMV Digital Services Publisher" languagecode="1033" /></Descriptions>
      <EMailAddress xsi:nil="true" /><SupportingWebsiteUrl xsi:nil="true" />
      <CustomizationPrefix>dmv</CustomizationPrefix>
      <CustomizationOptionValuePrefix>75615</CustomizationOptionValuePrefix>
      <Addresses>
        <Address><AddressNumber>1</AddressNumber><AddressTypeCode>1</AddressTypeCode><City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" /><Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" /><ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" /><Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" /><Longitude xsi:nil="true" /><Name xsi:nil="true" /><PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" /><PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" /><StateOrProvince xsi:nil="true" /><Telephone1 xsi:nil="true" /><Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" /><TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" /><UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" /></Address>
        <Address><AddressNumber>2</AddressNumber><AddressTypeCode>1</AddressTypeCode><City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" /><Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" /><ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" /><Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" /><Longitude xsi:nil="true" /><Name xsi:nil="true" /><PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" /><PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" /><StateOrProvince xsi:nil="true" /><Telephone1 xsi:nil="true" /><Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" /><TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" /><UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" /></Address>
      </Addresses>
    </Publisher>
    <RootComponents><RootComponent type="29" id="{$flowId}" behavior="0" /></RootComponents>
    <MissingDependencies />
  </SolutionManifest>
</ImportExportXml>
"@
Set-Content -Path (Join-Path $workRoot "solution.xml") -Value $solutionXml -Encoding UTF8

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
Write-Host "=== Cancellation flow zip created ==="
Write-Host "  Path: $zipPath"
Write-Host "  Size: $([IO.FileInfo]::new($zipPath).Length) bytes"
Write-Host ""
Write-Host "Import: make.powerapps.com -> Solutions -> Import solution -> select zip"
Write-Host "After import: open 'DMV - Appointment Cancellation Email' -> Turn on"
