<#
  36_build_temptag_flow_solution_v2.ps1

  Builds a single merged flow:
    Trigger: renewal modified, status = Approved
    1. Compose tag number
    2. Compose expiration
    3. Update row (stamp dmv_temptagnumber + dmv_temptagexpirationdate)
    4. Get row (refetch for fresh values)
    5. Send email (HTML template) to the citizen
    (If tag already stamped, skips 1-3 and jumps straight to Get row + Send)

  Output: dataverse/DMVTempTagFlow_1_0_0_0.zip
#>

$ErrorActionPreference = "Stop"

$workRoot = Join-Path $PSScriptRoot "_temptag_flow_build"
$zipPath  = Join-Path $PSScriptRoot "DMVTempTagFlow_1_0_0_0.zip"

if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -Path $workRoot -ItemType Directory | Out-Null
New-Item -Path (Join-Path $workRoot "Workflows") -ItemType Directory | Out-Null

$solutionUnique    = "DMVTempTagFlow"
$flowId            = "9f8e7d6c-5b4a-4321-9876-abcdef012345"
$dvConnRef         = "dmv_sharedcommondataserviceforapps_a11ee"
$o365ConnRef       = "dmv_sharedoffice365_b22ff"

# -- Email HTML template (references Get_renewal_row outputs with real field names) --
$emailBody = @'
<table cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:24px 0;">
<tbody><tr><td>
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
    <td style="padding:32px;">
      <p style="margin:0 0 16px;font-size:16px;color:#333;font-family:Arial,sans-serif;">
        Dear <strong>@{outputs('Get_renewal_row')?['body/dmv_firstname']} @{outputs('Get_renewal_row')?['body/dmv_lastname']}</strong>,
      </p>
      <p style="margin:0 0 24px;font-size:15px;color:#333;line-height:1.6;font-family:Arial,sans-serif;">
        Great news &mdash; your vehicle registration renewal has been <strong style="color:#1a6e3a;">approved</strong>.
        Your temporary registration tag is now available for download from your Contoso DMV portal account.
      </p>

      <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td style="background:#1a3d2b;border-radius:8px;padding:20px;text-align:center;">
            <p style="margin:0 0 8px;font-size:10px;font-weight:600;letter-spacing:0.2em;color:#e8c84b;font-family:Arial,sans-serif;text-transform:uppercase;">Registered Plate</p>
            <p style="margin:0;font-size:36px;font-weight:700;letter-spacing:0.15em;color:#ffffff;font-family:Georgia,serif;line-height:1;">
              @{outputs('Get_renewal_row')?['body/dmv_platenumber']}
            </p>
          </td>
        </tr></tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="background:#f0f5f1;border-radius:6px;margin:0 0 24px;width:100%;">
        <tbody><tr><td style="padding:20px 24px;">
          <table cellpadding="0" cellspacing="0" style="font-size:14px;color:#333;width:100%;font-family:Arial,sans-serif;">
            <tbody>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;width:180px;font-size:13px;">Transaction Number</td>
                <td style="padding:5px 0;font-weight:600;">@{outputs('Get_renewal_row')?['body/dmv_renewalid']}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Temporary Tag Number</td>
                <td style="padding:5px 0;font-weight:600;font-family:Courier New,monospace;">@{outputs('Get_renewal_row')?['body/dmv_temptagnumber']}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Vehicle</td>
                <td style="padding:5px 0;font-weight:600;">@{outputs('Get_renewal_row')?['body/dmv_vehicleyear']} @{outputs('Get_renewal_row')?['body/dmv_vehiclemake']} @{outputs('Get_renewal_row')?['body/dmv_vehiclemodel']}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">VIN</td>
                <td style="padding:5px 0;font-weight:600;font-family:Courier New,monospace;">@{outputs('Get_renewal_row')?['body/dmv_vin']}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Tag Issued</td>
                <td style="padding:5px 0;font-weight:600;">@{if(empty(outputs('Get_renewal_row')?['body/dmv_approveddate']), 'N/A', formatDateTime(outputs('Get_renewal_row')?['body/dmv_approveddate'], 'MMMM d, yyyy'))}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Tag Valid Through</td>
                <td style="padding:5px 0;font-weight:600;">@{if(empty(outputs('Get_renewal_row')?['body/dmv_temptagexpirationdate']), 'N/A', formatDateTime(outputs('Get_renewal_row')?['body/dmv_temptagexpirationdate'], 'MMMM d, yyyy'))}</td>
              </tr>
              <tr>
                <td style="padding:5px 0;color:#5a7a65;font-size:13px;">New Reg. Expiration</td>
                <td style="padding:5px 0;font-weight:600;">@{if(empty(outputs('Get_renewal_row')?['body/dmv_newexpirationdate']), 'N/A', formatDateTime(outputs('Get_renewal_row')?['body/dmv_newexpirationdate'], 'MMMM d, yyyy'))}</td>
              </tr>
            </tbody>
          </table>
        </td></tr>
      </tbody></table>

      <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;">
        <tbody><tr>
          <td style="background:#fffbe6;border-left:4px solid #e8c84b;border-radius:0 6px 6px 0;padding:14px 18px;">
            <p style="margin:0;font-size:13px;color:#7a6010;line-height:1.5;font-family:Arial,sans-serif;">
              <strong>Important:</strong> Print this tag and display it in your rear window until your permanent registration sticker arrives in the mail.
            </p>
          </td>
        </tr></tbody>
      </table>

      <table cellpadding="0" cellspacing="0" style="margin:0 auto;">
        <tbody><tr>
          <td style="background:#1a3d2b;border-radius:6px;">
            <a href="https://site-y5jzr.powerappsportals.us/documents/" style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;font-family:Arial,sans-serif;">
              Download Temporary Tag
            </a>
          </td>
        </tr>
      </tbody></table>

      <p style="margin:24px 0 0;font-size:14px;color:#555;line-height:1.6;font-family:Arial,sans-serif;">
        Your permanent registration sticker will be mailed to the address on file within 7&ndash;10 business days.
        The temporary tag is valid for 30 days from the date of issue.
      </p>
    </td>
  </tr>

  <tr>
    <td style="background:#f8f8f8;padding:20px 32px;border-top:1px solid #e0e0e0;">
      <p style="margin:0;font-size:12px;color:#888;line-height:1.5;font-family:Arial,sans-serif;">
        This is an automated message from Contoso DMV. Please do not reply to this email.<br>
        If you did not submit a renewal, contact us immediately at (555) 123-4567.
      </p>
    </td>
  </tr>

</tbody></table>
</td></tr>
</tbody></table>
'@

# -- Build flow definition as a hashtable (avoids escape hell) --
$definition = [ordered]@{
    '$schema'        = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion   = '1.0.0.0'
    parameters       = [ordered]@{
        '$connections'    = [ordered]@{ defaultValue = @{}; type = 'Object' }
        '$authentication' = [ordered]@{ defaultValue = @{}; type = 'SecureObject' }
    }
    triggers = [ordered]@{
        'When_a_row_is_modified' = [ordered]@{
            type = 'OpenApiConnectionWebhook'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'SubscribeWebhookTrigger'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    'subscriptionRequest/message'              = 2
                    'subscriptionRequest/entityname'           = 'dmv_registrationrenewal'
                    'subscriptionRequest/scope'                = 4
                    'subscriptionRequest/filteringattributes'  = 'dmv_renewalstatus,dmv_approveddate'
                    'subscriptionRequest/filterexpression'     = 'dmv_renewalstatus eq 100000002'
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }
    actions = [ordered]@{
        'Check_if_tag_already_stamped' = [ordered]@{
            type = 'If'
            expression = [ordered]@{
                and = @(
                    [ordered]@{
                        equals = @(
                            "@coalesce(triggerOutputs()?['body/dmv_temptagnumber'], '')",
                            ''
                        )
                    }
                )
            }
            actions = [ordered]@{
                'Compose_tag_number' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@concat('TMP-', formatDateTime(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 'yyyy'), '-', last(split(coalesce(triggerOutputs()?['body/dmv_renewalid'], formatDateTime(utcNow(), 'yyyyMMddHHmmss')), '-')))"
                }
                'Compose_expiration' = [ordered]@{
                    type   = 'Compose'
                    inputs = "@formatDateTime(addDays(coalesce(triggerOutputs()?['body/dmv_approveddate'], utcNow()), 30), 'yyyy-MM-dd')"
                    runAfter = @{ Compose_tag_number = @('Succeeded') }
                }
                'Update_registration_renewal' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_commondataserviceforapps'
                            operationId    = 'UpdateRecord'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        }
                        parameters = [ordered]@{
                            entityName = 'dmv_registrationrenewals'
                            recordId   = "@triggerOutputs()?['body/dmv_registrationrenewalid']"
                            'item/dmv_temptagnumber'         = "@outputs('Compose_tag_number')"
                            'item/dmv_temptagexpirationdate' = "@outputs('Compose_expiration')"
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Compose_expiration = @('Succeeded') }
                }
            }
            else = [ordered]@{ actions = @{} }
            runAfter = @{}
        }
        'Get_renewal_row' = [ordered]@{
            type = 'OpenApiConnection'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'GetItem'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    entityName = 'dmv_registrationrenewals'
                    recordId   = "@triggerOutputs()?['body/dmv_registrationrenewalid']"
                }
                authentication = "@parameters('`$authentication')"
            }
            runAfter = @{ Check_if_tag_already_stamped = @('Succeeded') }
        }
        'Send_approval_email' = [ordered]@{
            type = 'OpenApiConnection'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_office365'
                    operationId    = 'SendEmailV2'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_office365'
                }
                parameters = [ordered]@{
                    'emailMessage/To'         = "@outputs('Get_renewal_row')?['body/dmv_email']"
                    'emailMessage/Subject'    = "@concat('Your registration renewal is approved - ', coalesce(outputs('Get_renewal_row')?['body/dmv_platenumber'], ''))"
                    'emailMessage/Body'       = $emailBody
                    'emailMessage/Importance' = 'Normal'
                }
                authentication = "@parameters('`$authentication')"
            }
            runAfter = @{ Get_renewal_row = @('Succeeded') }
        }
    }
}

# Workflow JSON wrapper
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

$flowFileName = "DMV-ApproveRegistrationRenewal-$flowId.json"
$flowPath = Join-Path $workRoot "Workflows/$flowFileName"
($workflowJson | ConvertTo-Json -Depth 50) | Set-Content -Path $flowPath -Encoding UTF8

# -- customizations.xml --
$customizations = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml>
  <Entities />
  <Roles />
  <Workflows>
    <Workflow WorkflowId="{$flowId}" Name="DMV - Approve Registration Renewal">
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

# -- solution.xml --
$solutionXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="PS36" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>$solutionUnique</UniqueName>
    <LocalizedNames>
      <LocalizedName description="DMV Temp Tag Flow" languagecode="1033" />
    </LocalizedNames>
    <Descriptions>
      <Description description="On registration renewal approval: stamps temporary tag number and expiration onto the renewal row, then emails the citizen an HTML notification." languagecode="1033" />
    </Descriptions>
    <Version>1.0.0.0</Version>
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

# -- [Content_Types].xml --
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
Write-Host "Next steps:"
Write-Host "  1. make.powerapps.com -> Solutions -> Import solution"
Write-Host "  2. Browse and select: $zipPath"
Write-Host "  3. When prompted, create/select connections for:"
Write-Host "       - Dataverse"
Write-Host "       - Office 365 Outlook (this is who sends the email)"
Write-Host "  4. After import, open the flow and click 'Turn on'"
Write-Host ""
Write-Host "Flow steps:"
Write-Host "  Trigger:  Renewal modified, status=Approved, filter on renewalstatus+approveddate"
Write-Host "  If temptagnumber is empty:"
Write-Host "    - Compose tag number  (TMP-YYYY-NNNN)"
Write-Host "    - Compose expiration  (approved + 30 days)"
Write-Host "    - Update renewal row  (stamp both fields)"
Write-Host "  Get renewal row         (refetch with fresh values)"
Write-Host "  Send approval email     (HTML template, to dmv_email)"
