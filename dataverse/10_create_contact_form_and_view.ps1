###############################################################################
# 10_create_contact_form_and_view.ps1
# Creates a "DMV Citizen" main form and "DMV Citizens" active view for Contact
###############################################################################
$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization  = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

# ────────────────────────────────────────────────
# STEP 1: Create the DMV Citizen Contact Form
# ────────────────────────────────────────────────
Write-Host "=== Step 1: Create DMV Citizen Contact Form ==="

$formXml = @'
<form showImage="true">
  <tabs>
    <tab name="GENERAL_TAB" id="{a0000001-0001-0001-0001-000000000001}" showlabel="true" expanded="true">
      <labels><label description="General" languagecode="1033" /></labels>
      <columns>
        <column width="50%">
          <sections>
            <section name="CITIZEN_INFO" showlabel="true" showbar="false" id="{b0000001-0001-0001-0001-000000000001}" columns="1" labelwidth="115" celllabelposition="Left">
              <labels><label description="Citizen Information" languagecode="1033" /></labels>
              <rows>
                <row><cell id="{c0000001-0001-0001-0001-000000000001}" showlabel="true"><labels><label description="First Name" languagecode="1033" /></labels><control id="firstname" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="firstname" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000002}" showlabel="true"><labels><label description="Last Name" languagecode="1033" /></labels><control id="lastname" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="lastname" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000003}" showlabel="true"><labels><label description="Date of Birth" languagecode="1033" /></labels><control id="dmv_dateofbirth" classid="{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}" datafieldname="dmv_dateofbirth" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000004}" showlabel="true"><labels><label description="Last 4 SSN" languagecode="1033" /></labels><control id="dmv_last4ssn" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="dmv_last4ssn" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000005}" showlabel="true"><labels><label description="Preferred Language" languagecode="1033" /></labels><control id="dmv_preferredlanguage" classid="{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}" datafieldname="dmv_preferredlanguage" disabled="false" /></cell></row>
              </rows>
            </section>
            <section name="CONTACT_DETAILS" showlabel="true" showbar="false" id="{b0000001-0001-0001-0001-000000000002}" columns="1" labelwidth="115" celllabelposition="Left">
              <labels><label description="Contact Details" languagecode="1033" /></labels>
              <rows>
                <row><cell id="{c0000001-0001-0001-0001-000000000006}" showlabel="true"><labels><label description="Email" languagecode="1033" /></labels><control id="emailaddress1" classid="{ADA2203E-B4CD-49be-9DDF-234642B43B52}" datafieldname="emailaddress1" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000007}" showlabel="true"><labels><label description="Mobile Phone" languagecode="1033" /></labels><control id="mobilephone" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="mobilephone" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000008}" showlabel="true"><labels><label description="Business Phone" languagecode="1033" /></labels><control id="telephone1" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="telephone1" disabled="false" /></cell></row>
              </rows>
            </section>
          </sections>
        </column>
        <column width="50%">
          <sections>
            <section name="DMV_ENROLLMENT" showlabel="true" showbar="false" id="{b0000001-0001-0001-0001-000000000003}" columns="1" labelwidth="115" celllabelposition="Left">
              <labels><label description="MyDMV Portal Enrollment" languagecode="1033" /></labels>
              <rows>
                <row><cell id="{c0000001-0001-0001-0001-000000000009}" showlabel="true"><labels><label description="MyDMV Enrolled" languagecode="1033" /></labels><control id="dmv_mydmvenrolled" classid="{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}" datafieldname="dmv_mydmvenrolled" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-00000000000a}" showlabel="true"><labels><label description="Enrollment Date" languagecode="1033" /></labels><control id="dmv_enrollmentdate" classid="{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}" datafieldname="dmv_enrollmentdate" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-00000000000b}" showlabel="true"><labels><label description="Account Verified" languagecode="1033" /></labels><control id="dmv_accountverified" classid="{B0C6723A-8503-4fd7-BB28-C8A06AC933C2}" datafieldname="dmv_accountverified" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-00000000000c}" showlabel="true"><labels><label description="Profile Last Updated" languagecode="1033" /></labels><control id="dmv_profileupdated" classid="{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}" datafieldname="dmv_profileupdated" disabled="false" /></cell></row>
              </rows>
            </section>
            <section name="ADDRESS_INFO" showlabel="true" showbar="false" id="{b0000001-0001-0001-0001-000000000004}" columns="1" labelwidth="115" celllabelposition="Left">
              <labels><label description="Address" languagecode="1033" /></labels>
              <rows>
                <row><cell id="{c0000001-0001-0001-0001-00000000000d}" showlabel="true"><labels><label description="Street 1" languagecode="1033" /></labels><control id="address1_line1" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="address1_line1" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-00000000000e}" showlabel="true"><labels><label description="Street 2" languagecode="1033" /></labels><control id="address1_line2" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="address1_line2" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-00000000000f}" showlabel="true"><labels><label description="City" languagecode="1033" /></labels><control id="address1_city" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="address1_city" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000010}" showlabel="true"><labels><label description="State/Province" languagecode="1033" /></labels><control id="address1_stateorprovince" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="address1_stateorprovince" disabled="false" /></cell></row>
                <row><cell id="{c0000001-0001-0001-0001-000000000011}" showlabel="true"><labels><label description="ZIP/Postal Code" languagecode="1033" /></labels><control id="address1_postalcode" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="address1_postalcode" disabled="false" /></cell></row>
              </rows>
            </section>
          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
'@

$formBody = @{
    name = "DMV Citizen Contact"
    description = "Contact form for DMV citizen records with all DMV enrollment and identity fields."
    objecttypecode = "contact"
    type = 2                    # Main form
    formactivationstate = 1     # Active
    formxml = $formXml
} | ConvertTo-Json -Compress

try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/systemforms" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($formBody)) -UseBasicParsing
    $formId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  Created form: $formId"
} catch {
    $err = $_.ErrorDetails.Message
    Write-Host "  Form ERR: $err"
    exit 1
}

# ────────────────────────────────────────────────
# STEP 2: Create DMV Citizens View
# ────────────────────────────────────────────────
Write-Host "`n=== Step 2: Create DMV Citizens View ==="

$fetchXml = @'
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
  <entity name="contact">
    <attribute name="fullname" />
    <attribute name="emailaddress1" />
    <attribute name="mobilephone" />
    <attribute name="address1_city" />
    <attribute name="address1_stateorprovince" />
    <attribute name="dmv_dateofbirth" />
    <attribute name="dmv_mydmvenrolled" />
    <attribute name="dmv_accountverified" />
    <attribute name="dmv_enrollmentdate" />
    <attribute name="dmv_preferredlanguage" />
    <attribute name="dmv_last4ssn" />
    <attribute name="contactid" />
    <order attribute="fullname" descending="false" />
  </entity>
</fetch>
'@

$layoutXml = @'
<grid name="resultset" jump="fullname" select="1" icon="1" preview="1">
  <row name="result" id="contactid">
    <cell name="fullname" width="200" />
    <cell name="emailaddress1" width="180" />
    <cell name="mobilephone" width="130" />
    <cell name="dmv_dateofbirth" width="110" />
    <cell name="dmv_last4ssn" width="80" />
    <cell name="dmv_mydmvenrolled" width="100" />
    <cell name="dmv_accountverified" width="100" />
    <cell name="dmv_enrollmentdate" width="120" />
    <cell name="address1_city" width="120" />
    <cell name="address1_stateorprovince" width="100" />
    <cell name="dmv_preferredlanguage" width="110" />
  </row>
</grid>
'@

$viewBody = @{
    name = "DMV Citizens"
    description = "All contacts with DMV enrollment and identity columns."
    returnedtypecode = "contact"
    querytype = 0               # Public view
    fetchxml = $fetchXml
    layoutxml = $layoutXml
} | ConvertTo-Json -Compress

try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/savedqueries" -Method Post -Headers $h `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($viewBody)) -UseBasicParsing
    $viewId = ($resp.Headers["OData-EntityId"] -replace ".*\(","" -replace "\).*","")
    Write-Host "  Created view: $viewId"
} catch {
    $err = $_.ErrorDetails.Message
    Write-Host "  View ERR: $err"
}

# ────────────────────────────────────────────────
# STEP 3: Add form and view to app
# ────────────────────────────────────────────────
Write-Host "`n=== Step 3: Add form and view to DMV Operations Hub ==="
$appId = "d6331d8d-a239-f111-88b4-001dd80a6132"

# Add form (type 60 = systemform)
if ($formId) {
    $json = "{`"AppId`":`"$appId`",`"Components`":[{`"@odata.type`":`"Microsoft.Dynamics.CRM.systemform`",`"formid`":`"$formId`"}]}"
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  Form added to app"
    } catch { Write-Host "  Form add ERR: $($_.ErrorDetails.Message)" }
}

# Add view (type 26 = savedquery)
if ($viewId) {
    $json = "{`"AppId`":`"$appId`",`"Components`":[{`"@odata.type`":`"Microsoft.Dynamics.CRM.savedquery`",`"savedqueryid`":`"$viewId`"}]}"
    try {
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/AddAppComponents" -Method Post -Headers $h `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
        Write-Host "  View added to app"
    } catch { Write-Host "  View add ERR: $($_.ErrorDetails.Message)" }
}

# ────────────────────────────────────────────────
# STEP 4: Publish
# ────────────────────────────────────────────────
Write-Host "`n=== Step 4: Publish ==="
$pubBody = @{ ParameterXml = "<importexportxml><entities><entity>contact</entity></entities><appmodules><appmodule>$appId</appmodule></appmodules></importexportxml>" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/PublishXml" -Method Post -Headers $h `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
Write-Host "  Published"

Write-Host "`n==========================================="
Write-Host " DMV CITIZEN FORM & VIEW CREATED"
Write-Host "==========================================="
Write-Host "  Form: DMV Citizen Contact ($formId)"
Write-Host "  View: DMV Citizens ($viewId)"
Write-Host ""
Write-Host "  Form Sections:"
Write-Host "    Tab 1 - General:"
Write-Host "      Left:  Citizen Info (Name, DOB, SSN, Language)"
Write-Host "              Contact Details (Email, Mobile, Business Phone)"
Write-Host "      Right: MyDMV Enrollment (Enrolled, Date, Verified, Updated)"
Write-Host "              Address (Street, City, State, ZIP)"
Write-Host "    Tab 2 - Related Records (Timeline)"
Write-Host ""
Write-Host "  View Columns:"
Write-Host "    Full Name | Email | Mobile | DOB | Last 4 SSN | Enrolled"
Write-Host "    | Verified | Enrollment Date | City | State | Language"
Write-Host ""
