<#
  51_build_registration_approval_flow.ps1

  Builds a Power Automate cloud flow in a solution zip:
    Trigger: dmv_vehicleregistration row modified, dmv_regstatus = 100000000 (Active/Approved)
    1. List related temp tags (filter: _dmv_vehicleid_value eq triggerOutputs vehicleid AND dmv_tagstatus eq 100000004 Pending)
    2. For each pending tag: Update dmv_tagstatus = 100000000 (Active)
    3. Get the citizen contact (dmv_regcontactid)
    4. Send HTML email with tag details + portal link

  Output: dataverse/DMVRegApprovalFlow_1_0_0_0.zip
#>

$ErrorActionPreference = "Stop"

$workRoot = Join-Path $PSScriptRoot "_regapproval_flow_build"
$zipPath  = Join-Path $PSScriptRoot "DMVRegApprovalFlow_1_0_0_0.zip"

if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -Path $workRoot -ItemType Directory | Out-Null
New-Item -Path (Join-Path $workRoot "Workflows") -ItemType Directory | Out-Null

$solutionUnique = "DMVRegApprovalFlow"
$flowId         = "8a7b6c5d-4e3f-2a1b-9c8d-1f2e3d4c5b6a"
$dvConnRef      = "dmv_sharedcommondataserviceforapps_c33bb"
$o365ConnRef    = "dmv_sharedoffice365_d44cc"
$portalUrl      = "https://site-y5jzr.powerappsportals.us"

# -- Email HTML template --
$emailBody = @'
<table cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:24px 0;">
<tbody><tr><td>
<table cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;width:600px;">

  <tbody><tr>
    <td style="background:#1D3557;padding:24px 32px;">
      <table cellpadding="0" cellspacing="0"><tbody><tr>
        <td style="color:#ffffff;font-size:24px;font-weight:700;font-family:Georgia,serif;padding-right:12px;vertical-align:middle;">Contoso DMV</td>
        <td style="border-left:2px solid rgba(232,200,75,0.5);padding-left:12px;vertical-align:middle;">
          <span style="display:block;color:#e8c84b;font-size:11px;font-weight:600;letter-spacing:0.12em;text-transform:uppercase;font-family:Arial,sans-serif;">Department of Motor Vehicles</span>
        </td>
      </tr></tbody></table>
    </td>
  </tr>

  <tr><td style="background:#E63946;height:4px;"></td></tr>

  <tr><td style="padding:32px;">
    <p style="margin:0 0 16px;font-size:16px;color:#333;font-family:Arial,sans-serif;">
      Dear <strong>@{outputs('Get_contact')?['body/firstname']} @{outputs('Get_contact')?['body/lastname']}</strong>,
    </p>
    <p style="margin:0 0 24px;font-size:15px;color:#333;line-height:1.6;font-family:Arial,sans-serif;">
      Great news &mdash; your new vehicle registration has been <strong style="color:#1a6e3a;">approved</strong>.
      Your temporary tag is now available for download from your Contoso DMV portal account.
    </p>

    <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;"><tbody><tr>
      <td style="background:#1D3557;border-radius:8px;padding:20px;text-align:center;">
        <p style="margin:0 0 8px;font-size:10px;font-weight:600;letter-spacing:0.2em;color:#e8c84b;font-family:Arial,sans-serif;text-transform:uppercase;">Temporary Tag Number</p>
        <p style="margin:0;font-size:36px;font-weight:700;letter-spacing:0.15em;color:#ffffff;font-family:Courier New,monospace;line-height:1;">
          @{first(outputs('List_pending_tags')?['body/value'])?['dmv_tagnumber']}
        </p>
      </td>
    </tr></tbody></table>

    <table cellpadding="0" cellspacing="0" style="background:#f0f5f1;border-radius:6px;margin:0 0 24px;width:100%;"><tbody><tr><td style="padding:20px 24px;">
      <table cellpadding="0" cellspacing="0" style="font-size:14px;color:#333;width:100%;font-family:Arial,sans-serif;"><tbody>
        <tr>
          <td style="padding:5px 0;color:#5a7a65;width:180px;font-size:13px;">Registration ID</td>
          <td style="padding:5px 0;font-weight:600;font-family:Courier New,monospace;">@{triggerOutputs()?['body/dmv_registrationid']}</td>
        </tr>
        <tr>
          <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Tag Issued</td>
          <td style="padding:5px 0;font-weight:600;">@{formatDateTime(first(outputs('List_pending_tags')?['body/value'])?['dmv_issuedate'], 'MMMM d, yyyy')}</td>
        </tr>
        <tr>
          <td style="padding:5px 0;color:#5a7a65;font-size:13px;">Tag Valid Through</td>
          <td style="padding:5px 0;font-weight:600;color:#E63946;">@{formatDateTime(first(outputs('List_pending_tags')?['body/value'])?['dmv_expirationdate'], 'MMMM d, yyyy')}</td>
        </tr>
      </tbody></table>
    </td></tr></tbody></table>

    <table cellpadding="0" cellspacing="0" style="width:100%;margin:0 0 24px;"><tbody><tr>
      <td style="background:#fffbe6;border-left:4px solid #e8c84b;border-radius:0 6px 6px 0;padding:14px 18px;">
        <p style="margin:0;font-size:13px;color:#7a6010;line-height:1.5;font-family:Arial,sans-serif;">
          <strong>Important:</strong> Print this tag and display it in the lower-right corner of your rear windshield.
          Your permanent registration plate will arrive by mail within 7&ndash;10 business days.
        </p>
      </td>
    </tr></tbody></table>

    <table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tbody><tr>
      <td style="background:#1D3557;border-radius:6px;">
        <a href="PORTAL_URL_PLACEHOLDER/temporary-tags" style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;font-family:Arial,sans-serif;">Download Temporary Tag</a>
      </td>
    </tr></tbody></table>
  </td></tr>

  <tr><td style="background:#f8f8f8;padding:20px 32px;border-top:1px solid #e0e0e0;">
    <p style="margin:0;font-size:12px;color:#888;line-height:1.5;font-family:Arial,sans-serif;">
      This is an automated message from Contoso DMV. Please do not reply to this email.<br>
      If you did not authorize this registration, contact us immediately at (555) 123-4567.
    </p>
  </td></tr>

</tbody></table>
</td></tr></tbody></table>
'@

$emailBody = $emailBody.Replace("PORTAL_URL_PLACEHOLDER", $portalUrl)

# -- Flow definition --
$definition = [ordered]@{
    '$schema'      = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion = '1.0.0.0'
    parameters     = [ordered]@{
        '$connections'    = [ordered]@{ defaultValue = @{}; type = 'Object' }
        '$authentication' = [ordered]@{ defaultValue = @{}; type = 'SecureObject' }
    }
    triggers = [ordered]@{
        'When_registration_approved' = [ordered]@{
            type = 'OpenApiConnectionWebhook'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'SubscribeWebhookTrigger'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    'subscriptionRequest/message'             = 2
                    'subscriptionRequest/entityname'          = 'dmv_vehicleregistration'
                    'subscriptionRequest/scope'               = 4
                    'subscriptionRequest/filteringattributes' = 'dmv_regstatus'
                    'subscriptionRequest/filterexpression'    = 'dmv_regstatus eq 100000000'
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }
    actions = [ordered]@{
        'List_pending_tags' = [ordered]@{
            type = 'OpenApiConnection'
            inputs = [ordered]@{
                host = [ordered]@{
                    connectionName = 'shared_commondataserviceforapps'
                    operationId    = 'ListRecords'
                    apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                }
                parameters = [ordered]@{
                    entityName      = 'dmv_temporarytags'
                    '$filter'       = "_dmv_vehicleid_value eq @{triggerOutputs()?['body/_dmv_vehicleid_value']} and dmv_tagstatus eq 100000004"
                    '$select'       = 'dmv_temporarytagid,dmv_tagnumber,dmv_issuedate,dmv_expirationdate'
                    '$top'          = 1
                }
                authentication = "@parameters('`$authentication')"
            }
            runAfter = @{}
        }
        'If_pending_tag_found' = [ordered]@{
            type = 'If'
            expression = [ordered]@{
                greater = @(
                    "@length(outputs('List_pending_tags')?['body/value'])",
                    0
                )
            }
            actions = [ordered]@{
                'Activate_temp_tag' = [ordered]@{
                    type = 'OpenApiConnection'
                    inputs = [ordered]@{
                        host = [ordered]@{
                            connectionName = 'shared_commondataserviceforapps'
                            operationId    = 'UpdateRecord'
                            apiId          = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        }
                        parameters = [ordered]@{
                            entityName          = 'dmv_temporarytags'
                            recordId            = "@first(outputs('List_pending_tags')?['body/value'])?['dmv_temporarytagid']"
                            'item/dmv_tagstatus' = 100000000
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                }
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
                            recordId   = "@triggerOutputs()?['body/_dmv_regcontactid_value']"
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Activate_temp_tag = @('Succeeded') }
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
                            'emailMessage/To'         = "@outputs('Get_contact')?['body/emailaddress1']"
                            'emailMessage/Subject'    = "@concat('Your vehicle registration is approved - ', coalesce(triggerOutputs()?['body/dmv_registrationid'], ''))"
                            'emailMessage/Body'       = $emailBody
                            'emailMessage/Importance' = 'Normal'
                        }
                        authentication = "@parameters('`$authentication')"
                    }
                    runAfter = @{ Get_contact = @('Succeeded') }
                }
            }
            else = [ordered]@{ actions = @{} }
            runAfter = @{ List_pending_tags = @('Succeeded') }
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

$flowFileName = "DMV-ApproveRegistration-$flowId.json"
$flowPath = Join-Path $workRoot "Workflows/$flowFileName"
($workflowJson | ConvertTo-Json -Depth 50) | Set-Content -Path $flowPath -Encoding UTF8

$customizations = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml>
  <Entities />
  <Roles />
  <Workflows>
    <Workflow WorkflowId="{$flowId}" Name="DMV - Approve New Registration">
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
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="PS51" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>$solutionUnique</UniqueName>
    <LocalizedNames><LocalizedName description="DMV Registration Approval Flow" languagecode="1033" /></LocalizedNames>
    <Descriptions><Description description="On new registration approval: activates pending temporary tag and emails the citizen." languagecode="1033" /></Descriptions>
    <Version>1.0.0.0</Version>
    <Managed>0</Managed>
    <Publisher>
      <UniqueName>dmv</UniqueName>
      <LocalizedNames><LocalizedName description="DMV" languagecode="1033" /></LocalizedNames>
      <Descriptions><Description description="DMV Digital Services Publisher" languagecode="1033" /></Descriptions>
      <EMailAddress xsi:nil="true" /><SupportingWebsiteUrl xsi:nil="true" />
      <CustomizationPrefix>dmv</CustomizationPrefix>
      <CustomizationOptionValuePrefix>75615</CustomizationOptionValuePrefix>
      <Addresses>
        <Address><AddressNumber>1</AddressNumber><AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" /><Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" /><Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" /><Name xsi:nil="true" /><PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" /><StateOrProvince xsi:nil="true" />
          <Telephone1 xsi:nil="true" /><Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" /><UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
        <Address><AddressNumber>2</AddressNumber><AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" /><County xsi:nil="true" /><Country xsi:nil="true" /><Fax xsi:nil="true" /><FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" /><Latitude xsi:nil="true" /><Line1 xsi:nil="true" /><Line2 xsi:nil="true" /><Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" /><Name xsi:nil="true" /><PostalCode xsi:nil="true" /><PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" /><ShippingMethodCode xsi:nil="true" /><StateOrProvince xsi:nil="true" />
          <Telephone1 xsi:nil="true" /><Telephone2 xsi:nil="true" /><Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" /><UPSZone xsi:nil="true" /><UTCOffset xsi:nil="true" /><UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
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
Write-Host "=== Solution zip created ===" -ForegroundColor Green
Write-Host "  Path: $zipPath"
Write-Host "  Size: $([IO.FileInfo]::new($zipPath).Length) bytes"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. make.powerapps.com  ->  Solutions  ->  Import solution"
Write-Host "  2. Browse and select: $zipPath"
Write-Host "  3. Create/select connections when prompted:"
Write-Host "       - Dataverse"
Write-Host "       - Office 365 Outlook"
Write-Host "  4. After import, open 'DMV - Approve New Registration' and click Turn on."
Write-Host ""
Write-Host "Flow logic:" -ForegroundColor Cyan
Write-Host "  Trigger:  Registration modified, dmv_regstatus = 100000000 (Active/Approved)"
Write-Host "  - List Pending tags for this vehicle (status=100000004)"
Write-Host "  - If found:"
Write-Host "      - Update tag status -> Active (100000000)"
Write-Host "      - Get citizen contact"
Write-Host "      - Send HTML email with tag number + portal /temporary-tags link"
