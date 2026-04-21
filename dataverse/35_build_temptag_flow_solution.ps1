<#
  35_build_temptag_flow_solution.ps1

  Generates an unmanaged solution .zip that contains a single Cloud Flow:
    "DMV - Stamp Temporary Tag on Approval"

  Trigger: Dataverse row modified on dmv_registrationrenewal where
           dmv_renewalstatus = 100000002 (Approved)
  Action:  Only if dmv_temptagnumber is empty, compute tag number + expiration
           and patch the row so the portal (and the email) can read real
           Dataverse values instead of placeholders.

  After import, open the flow, turn it on, and fix the Dataverse connection
  reference if it asks.

  Output: dataverse/DMVTempTagFlow_1_0_0_0.zip
#>

$ErrorActionPreference = "Stop"

$workRoot = Join-Path $PSScriptRoot "_temptag_flow_build"
$zipPath  = Join-Path $PSScriptRoot "DMVTempTagFlow_1_0_0_0.zip"

if (Test-Path $workRoot) { Remove-Item $workRoot -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -Path $workRoot -ItemType Directory | Out-Null
New-Item -Path (Join-Path $workRoot "Workflows") -ItemType Directory | Out-Null

# Stable IDs (regeneratable — pin these so re-exports are diff-friendly)
$solutionUnique = "DMVTempTagFlow"
$flowId         = "9f8e7d6c-5b4a-4321-9876-abcdef012345"
$connRefLogical = "dmv_sharedcommondataserviceforapps_a11ee"
$connRefDisplay = "Dataverse"

# Flow definition (Power Automate workflow JSON)
$flowDefinition = @'
{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "$connections": {
      "defaultValue": {},
      "type": "Object"
    },
    "$authentication": {
      "defaultValue": {},
      "type": "SecureObject"
    }
  },
  "triggers": {
    "When_a_row_is_added,_modified_or_deleted": {
      "type": "OpenApiConnectionWebhook",
      "inputs": {
        "host": {
          "connectionName": "shared_commondataserviceforapps",
          "operationId": "SubscribeWebhookTrigger",
          "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
        },
        "parameters": {
          "subscriptionRequest/message": 2,
          "subscriptionRequest/entityname": "dmv_registrationrenewal",
          "subscriptionRequest/scope": 4,
          "subscriptionRequest/filteringattributes": "dmv_renewalstatus,dmv_approveddate",
          "subscriptionRequest/filterexpression": "dmv_renewalstatus eq 100000002"
        },
        "authentication": "@parameters('\''$authentication'\'')"
      }
    }
  },
  "actions": {
    "Check_if_tag_already_stamped": {
      "type": "If",
      "expression": {
        "and": [
          {
            "equals": [
              "@coalesce(triggerOutputs()?['\''body/dmv_temptagnumber'\''], '\'''\'')",
              ""
            ]
          }
        ]
      },
      "actions": {
        "Compose_tag_number": {
          "type": "Compose",
          "inputs": "@concat('\''TMP-'\'', formatDateTime(coalesce(triggerOutputs()?['\''body/dmv_approveddate'\''], utcNow()), '\''yyyy'\''), '\''-'\'', last(split(coalesce(triggerOutputs()?['\''body/dmv_renewalid'\''], formatDateTime(utcNow(), '\''yyyyMMddHHmmss'\'')), '\''-'\'')))"
        },
        "Compose_expiration": {
          "type": "Compose",
          "inputs": "@formatDateTime(addDays(coalesce(triggerOutputs()?['\''body/dmv_approveddate'\''], utcNow()), 30), '\''yyyy-MM-dd'\'')",
          "runAfter": {
            "Compose_tag_number": ["Succeeded"]
          }
        },
        "Update_registration_renewal": {
          "type": "OpenApiConnection",
          "inputs": {
            "host": {
              "connectionName": "shared_commondataserviceforapps",
              "operationId": "UpdateRecord",
              "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
            },
            "parameters": {
              "entityName": "dmv_registrationrenewals",
              "recordId": "@triggerOutputs()?['\''body/dmv_registrationrenewalid'\'']",
              "item/dmv_temptagnumber": "@outputs('\''Compose_tag_number'\'')",
              "item/dmv_temptagexpirationdate": "@outputs('\''Compose_expiration'\'')"
            },
            "authentication": "@parameters('\''$authentication'\'')"
          },
          "runAfter": {
            "Compose_expiration": ["Succeeded"]
          }
        }
      },
      "else": {
        "actions": {
          "Terminate_already_stamped": {
            "type": "Terminate",
            "inputs": {
              "runStatus": "Succeeded"
            }
          }
        }
      },
      "runAfter": {}
    }
  }
}
'@

# Replace the placeholder escape-quoting back to normal (PowerShell here-string quirk)
$flowDefinition = $flowDefinition -replace "'\\''", "'"

# Workflow JSON wrapper expected in a solution zip
$workflowJson = [ordered]@{
    properties = [ordered]@{
        connectionReferences = [ordered]@{
            shared_commondataserviceforapps = [ordered]@{
                runtimeSource = "embedded"
                connection    = [ordered]@{
                    connectionReferenceLogicalName = $connRefLogical
                }
                api = [ordered]@{
                    name = "shared_commondataserviceforapps"
                }
            }
        }
        definition = ($flowDefinition | ConvertFrom-Json)
    }
    schemaVersion = "1.0.0.0"
}

$flowFileName = "DMV-StampTemporaryTagOnApproval-$flowId.json"
$flowPath = Join-Path $workRoot "Workflows/$flowFileName"
($workflowJson | ConvertTo-Json -Depth 30) | Set-Content -Path $flowPath -Encoding UTF8

# customizations.xml — declares the workflow + connection reference
$customizations = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml>
  <Entities />
  <Roles />
  <Workflows>
    <Workflow WorkflowId="{$flowId}" Name="DMV - Stamp Temporary Tag on Approval">
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
    <connectionreference connectionreferencelogicalname="$connRefLogical">
      <connectionreferencedisplayname>$connRefDisplay</connectionreferencedisplayname>
      <connectorid>/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps</connectorid>
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

# solution.xml
$solutionXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ImportExportXml version="9.2.0.0" SolutionPackageVersion="9.2" languagecode="1033" generatedBy="PS35" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SolutionManifest>
    <UniqueName>$solutionUnique</UniqueName>
    <LocalizedNames>
      <LocalizedName description="DMV Temp Tag Flow" languagecode="1033" />
    </LocalizedNames>
    <Descriptions>
      <Description description="Stamps temporary tag number and expiration onto approved registration renewals so the Power Pages PDF and approval email can read real Dataverse values." languagecode="1033" />
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
          <AddressNumber>1</AddressNumber>
          <AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" />
          <County xsi:nil="true" />
          <Country xsi:nil="true" />
          <Fax xsi:nil="true" />
          <FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" />
          <Latitude xsi:nil="true" />
          <Line1 xsi:nil="true" />
          <Line2 xsi:nil="true" />
          <Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" />
          <Name xsi:nil="true" />
          <PostalCode xsi:nil="true" />
          <PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" />
          <ShippingMethodCode xsi:nil="true" />
          <StateOrProvince xsi:nil="true" />
          <Telephone1 xsi:nil="true" />
          <Telephone2 xsi:nil="true" />
          <Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" />
          <UPSZone xsi:nil="true" />
          <UTCOffset xsi:nil="true" />
          <UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
        <Address>
          <AddressNumber>2</AddressNumber>
          <AddressTypeCode>1</AddressTypeCode>
          <City xsi:nil="true" />
          <County xsi:nil="true" />
          <Country xsi:nil="true" />
          <Fax xsi:nil="true" />
          <FreightTermsCode xsi:nil="true" />
          <ImportSequenceNumber xsi:nil="true" />
          <Latitude xsi:nil="true" />
          <Line1 xsi:nil="true" />
          <Line2 xsi:nil="true" />
          <Line3 xsi:nil="true" />
          <Longitude xsi:nil="true" />
          <Name xsi:nil="true" />
          <PostalCode xsi:nil="true" />
          <PostOfficeBox xsi:nil="true" />
          <PrimaryContactName xsi:nil="true" />
          <ShippingMethodCode xsi:nil="true" />
          <StateOrProvince xsi:nil="true" />
          <Telephone1 xsi:nil="true" />
          <Telephone2 xsi:nil="true" />
          <Telephone3 xsi:nil="true" />
          <TimeZoneRuleVersionNumber xsi:nil="true" />
          <UPSZone xsi:nil="true" />
          <UTCOffset xsi:nil="true" />
          <UTCConversionTimeZoneCode xsi:nil="true" />
        </Address>
      </Addresses>
    </Publisher>
    <RootComponents>
      <RootComponent type="29" schemaName="DMV - Stamp Temporary Tag on Approval" behavior="0" />
      <RootComponent type="10112" schemaName="$connRefLogical" behavior="0" />
    </RootComponents>
    <MissingDependencies />
  </SolutionManifest>
</ImportExportXml>
"@

Set-Content -Path (Join-Path $workRoot "solution.xml") -Value $solutionXml -Encoding UTF8

# [Content_Types].xml
$contentTypes = @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="xml" ContentType="application/octet-stream" />
  <Default Extension="json" ContentType="application/octet-stream" />
</Types>
"@

Set-Content -LiteralPath (Join-Path $workRoot "[Content_Types].xml") -Value $contentTypes -Encoding UTF8

# Zip it
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workRoot, $zipPath)

# Clean up working dir
Remove-Item $workRoot -Recurse -Force

Write-Host ""
Write-Host "=== Solution zip created ==="
Write-Host "  Path: $zipPath"
Write-Host "  Size: $([IO.FileInfo]::new($zipPath).Length) bytes"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. make.powerapps.com -> Solutions -> Import solution"
Write-Host "  2. Browse and select: $zipPath"
Write-Host "  3. Connect the Dataverse connection reference when prompted"
Write-Host "  4. After import, open the flow and click 'Turn on'"
