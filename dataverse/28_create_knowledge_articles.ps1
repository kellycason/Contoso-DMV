<#
  28_create_knowledge_articles.ps1
  - Creates dmv_knowledgearticle table
  - Adds columns (slug, category, summary, body, articletype, readminutes, published, displayorder)
  - Enables Portal Web API for the table
  - Creates table permission for Anonymous Users + Authenticated Users (read only)
  - Seeds rows from dataverse\knowledge_seed.json (upsert by dmv_slug)
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$readH = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"

function Label($text) {
    @{ "@odata.type"="Microsoft.Dynamics.CRM.Label"; LocalizedLabels=@(@{ "@odata.type"="Microsoft.Dynamics.CRM.LocalizedLabel"; Label=$text; LanguageCode=1033 }) }
}
function Add-Col($table, $body) {
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $uri = "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$table')/Attributes"
    try { $null = Invoke-WebRequest -Uri $uri -Method Post -Headers $h -Body $bytes -UseBasicParsing; return $true }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") { Write-Host "    (exists)"; return $true }
        Write-Host "    ERR: $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        return $false
    }
}
function Col-String($t,$s,$d,$req=$false,$ml=200) {
    $rl = if($req){"ApplicationRequired"}else{"None"}
    Add-Col $t @{ "@odata.type"="Microsoft.Dynamics.CRM.StringAttributeMetadata"; SchemaName=$s; DisplayName=(Label $d); RequiredLevel=@{Value=$rl;CanBeChanged=$true}; MaxLength=$ml; FormatName=@{Value="Text"} }
}
function Col-Memo($t,$s,$d,$ml=4000) {
    Add-Col $t @{ "@odata.type"="Microsoft.Dynamics.CRM.MemoAttributeMetadata"; SchemaName=$s; DisplayName=(Label $d); RequiredLevel=@{Value="None";CanBeChanged=$true}; MaxLength=$ml; Format="TextArea" }
}
function Col-Int($t,$s,$d,$min=0,$max=2147483647) {
    Add-Col $t @{ "@odata.type"="Microsoft.Dynamics.CRM.IntegerAttributeMetadata"; SchemaName=$s; DisplayName=(Label $d); RequiredLevel=@{Value="None";CanBeChanged=$true}; MinValue=$min; MaxValue=$max; Format="None" }
}
function Col-Bool($t,$s,$d) {
    Add-Col $t @{
        "@odata.type"="Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        SchemaName=$s; DisplayName=(Label $d)
        RequiredLevel=@{Value="None";CanBeChanged=$true}
        DefaultValue=$true
        OptionSet=@{
            "@odata.type"="Microsoft.Dynamics.CRM.BooleanOptionSetMetadata"
            TrueOption=@{Value=1;Label=(Label "Yes")}
            FalseOption=@{Value=0;Label=(Label "No")}
        }
    }
}
function Col-Choice($t,$s,$d,$options) {
    $opts=@(); $v=100000000
    foreach($o in $options){ $opts += @{Value=$v;Label=(Label $o)}; $v++ }
    Add-Col $t @{
        "@odata.type"="Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        SchemaName=$s; DisplayName=(Label $d)
        RequiredLevel=@{Value="None";CanBeChanged=$true}
        OptionSet=@{ "@odata.type"="Microsoft.Dynamics.CRM.OptionSetMetadata"; IsGlobal=$false; OptionSetType="Picklist"; Options=$opts }
    }
}

# ═══════════════════════════════════════════════════════════
# 1. CREATE TABLE
# ═══════════════════════════════════════════════════════════
$tbl = "dmv_knowledgearticle"
Write-Host "`n=== Creating Knowledge Article Table ==="
try {
    $null = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/EntityDefinitions(LogicalName='$tbl')?`$select=MetadataId" -Headers $readH
    Write-Host "  EXISTS: $tbl"
} catch {
    $body = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName = "dmv_KnowledgeArticle"
        DisplayName = (Label "Knowledge Article")
        DisplayCollectionName = (Label "Knowledge Articles")
        Description = (Label "FAQ + process guide articles used by the citizen portal and Copilot Studio knowledge source")
        HasActivities = $false; HasNotes = $false; IsActivity = $false
        OwnershipType = "UserOwned"
        IsAuditEnabled = @{ Value=$true; CanBeChanged=$true }
        ChangeTrackingEnabled = $true
        PrimaryNameAttribute = "dmv_title"
        Attributes = @(@{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            SchemaName = "dmv_Title"
            DisplayName = (Label "Title")
            Description = (Label "Article title or FAQ question (primary name)")
            RequiredLevel = @{ Value="ApplicationRequired"; CanBeChanged=$true }
            MaxLength = 300; FormatName = @{ Value="Text" }; IsPrimaryName = $true
        })
    }
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/EntityDefinitions" -Method Post -Headers $h -Body $bytes -UseBasicParsing
        Write-Host "  CREATED: $tbl ($($resp.StatusCode))"
    } catch {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $sr.BaseStream.Position=0
        Write-Host "  FAILED: $($sr.ReadToEnd().Substring(0,400))"
        exit 1
    }
}
Start-Sleep 3

# ═══════════════════════════════════════════════════════════
# 2. ADD COLUMNS
# ═══════════════════════════════════════════════════════════
Write-Host "`n=== Adding Columns ==="
Write-Host "    dmv_slug";          Col-String $tbl "dmv_slug"          "Slug" $true 100
Write-Host "    dmv_category";      Col-String $tbl "dmv_category"      "Category" $false 100
Write-Host "    dmv_summary";       Col-String $tbl "dmv_summary"       "Summary" $false 1000
Write-Host "    dmv_body";          Col-Memo   $tbl "dmv_body"          "Body" 100000
Write-Host "    dmv_articletype";   Col-Choice $tbl "dmv_articletype"   "Article Type" @("Article","FAQ")
Write-Host "    dmv_readminutes";   Col-Int    $tbl "dmv_readminutes"   "Read Minutes" 0 60
Write-Host "    dmv_published";     Col-Bool   $tbl "dmv_published"     "Published"
Write-Host "    dmv_displayorder";  Col-Int    $tbl "dmv_displayorder"  "Display Order" 0 99999

Start-Sleep 3

# ═══════════════════════════════════════════════════════════
# 3. ENABLE PORTAL WEB API
# ═══════════════════════════════════════════════════════════
Write-Host "`n=== Enabling Web API ==="
foreach ($pair in @(@("enabled","true"), @("fields","*"))) {
    $name = "Webapi/$tbl/$($pair[0])"
    $ssBody = @{
        mspp_name = $name; mspp_value = $pair[1]
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    } | ConvertTo-Json -Compress
    try {
        $null = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/mspp_sitesettings" `
            -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($ssBody)) -UseBasicParsing
        Write-Host "  OK: $name"
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists|DuplicateRecord") { Write-Host "  SKIP (exists): $name" }
        else { Write-Host "  ERR: $name - $($msg.Substring(0,[Math]::Min(150,$msg.Length)))" }
    }
}

# ═══════════════════════════════════════════════════════════
# 4. TABLE PERMISSIONS (Anonymous + Authenticated, read only)
# ═══════════════════════════════════════════════════════════
Write-Host "`n=== Looking up web role IDs ==="
$roles = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webroles?`$filter=_mspp_websiteid_value eq $websiteId&`$select=mspp_webroleid,mspp_name" -Headers $readH
$roleMap = @{}
foreach ($r in $roles.value) { $roleMap[$r.mspp_name] = $r.mspp_webroleid; Write-Host "  $($r.mspp_name) = $($r.mspp_webroleid)" }

$targetRoles = @()
foreach ($n in @("Anonymous Users","Authenticated Users")) {
    if ($roleMap.ContainsKey($n)) { $targetRoles += $roleMap[$n] } else { Write-Host "  (role '$n' not found)" }
}

Write-Host "`n=== Creating Table Permission ==="
$permContent = @{
    entitylogicalname = $tbl
    entityname = "Knowledge Article"
    scope = 756150000  # Global
    read = $true
    create = $false; write = $false; delete = $false; append = $false; appendto = $false
    accountrelationship = $null; contactrelationship = $null
    parentrelationship = $null; parententitypermission = $null
    permissionfetchxml = $null
    childTablePermissions = @()
    "adx_entitypermission_webrole" = $targetRoles
} | ConvertTo-Json -Compress -Depth 5

$permBody = @{
    name = "DMV - Knowledge Article (Read)"
    powerpagecomponenttype = 18
    content = $permContent
    "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
} | ConvertTo-Json -Compress

try {
    $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents" `
        -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($permBody)) -UseBasicParsing
    $permCompId = ($resp.Headers['OData-EntityId'] -replace '.*\(([^)]+)\).*','$1')
    Write-Host "  CREATED permission component: $permCompId"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "already exists|DuplicateRecord") {
        Write-Host "  EXISTS — refreshing content to ensure web role list + lowercase props"
        $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=name eq 'DMV - Knowledge Article (Read)' and powerpagecomponenttype eq 18&`$select=powerpagecomponentid" -Headers $readH
        if ($existing.value.Count -gt 0) {
            $id = $existing.value[0].powerpagecomponentid
            $patch = @{ content = $permContent } | ConvertTo-Json -Compress
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($id)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
            Write-Host "  PATCHED: $id"
        }
    } else {
        Write-Host "  ERR: $($msg.Substring(0,[Math]::Min(300,$msg.Length)))"
    }
}

# ═══════════════════════════════════════════════════════════
# 5. SEED ROWS (upsert by dmv_slug)
# ═══════════════════════════════════════════════════════════
Write-Host "`n=== Seeding Knowledge Articles ==="
$seedPath = Join-Path $PSScriptRoot "knowledge_seed.json"
$seed = Get-Content $seedPath -Raw | ConvertFrom-Json
Write-Host "  Loaded $($seed.Count) records from seed file"

$typeMap = @{ "Article" = 100000000; "FAQ" = 100000001 }

foreach ($rec in $seed) {
    $typeCode = $typeMap[$rec.type]
    $row = @{
        dmv_title        = $rec.title
        dmv_slug         = $rec.slug
        dmv_category     = $rec.category
        dmv_summary      = $rec.summary
        dmv_body         = $rec.body
        dmv_articletype  = $typeCode
        dmv_readminutes  = [int]$rec.readMinutes
        dmv_published    = $true
        dmv_displayorder = [int]$rec.order
    }
    $body = $row | ConvertTo-Json -Compress -Depth 5
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    # Check if exists by slug
    $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/dmv_knowledgearticles?`$filter=dmv_slug eq '$($rec.slug)'&`$select=dmv_knowledgearticleid" -Headers $readH
    try {
        if ($existing.value.Count -gt 0) {
            $id = $existing.value[0].dmv_knowledgearticleid
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_knowledgearticles($id)" -Method Patch -Headers $h -Body $bytes -UseBasicParsing | Out-Null
            Write-Host "  UPDATED: $($rec.slug)"
        } else {
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/dmv_knowledgearticles" -Method Post -Headers $h -Body $bytes -UseBasicParsing | Out-Null
            Write-Host "  CREATED: $($rec.slug)"
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ERR: $($rec.slug) - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
    }
}

Write-Host "`n=== DONE ==="
Write-Host "Table:            dmv_knowledgearticle"
Write-Host "Entity set:       dmv_knowledgearticles"
Write-Host "Portal Web API:   /_api/dmv_knowledgearticles"
Write-Host "Copilot Studio:   Add a Dataverse knowledge source and point at the 'Knowledge Article' table"
