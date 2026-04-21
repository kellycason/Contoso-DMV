<#
  30_migrate_to_native_knowledge.ps1
  ------------------------------------------------------------------
  Migrates the Contoso DMV knowledge base from the custom
  dmv_knowledgearticle table to the OOB Dynamics Customer Service
  `knowledgearticle` table.

  Idempotent: safe to re-run. Skips articles that already exist
  (matched by articlepublicnumber = slug).

  - Seeds rows from knowledge_seed.json
  - Converts markdown body -> HTML content
  - Publishes each article (statecode=3, statuscode=7)
  - Enables Portal Web API for `knowledgearticle`
  - Creates a single table permission (Global, Read) associated with
    BOTH Anonymous Users and Authenticated Users web roles
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
$languageId = "56940b3e-300f-4070-a559-5a6a4d11a8a3"   # en-US

# ──────────────────────────────────────────────────────────────────
# Markdown -> HTML converter (matches the seed's simple subset:
#   ## headings, `- ` bullet lists, blank-line paragraphs)
# ──────────────────────────────────────────────────────────────────
function ConvertTo-Html {
    param([string]$md)
    if (-not $md) { return "" }
    $lines = $md -replace "`r`n","`n" -split "`n"
    $html = New-Object System.Text.StringBuilder
    $para = @()
    $list = @()

    function Encode-Html([string]$s) {
        return [System.Net.WebUtility]::HtmlEncode($s)
    }
    function Flush-Para {
        if ($script:para.Count -gt 0) {
            $text = ($script:para -join ' ').Trim()
            if ($text) { [void]$script:html.Append("<p>$(Encode-Html $text)</p>") }
            $script:para = @()
        }
    }
    function Flush-List {
        if ($script:list.Count -gt 0) {
            [void]$script:html.Append("<ul>")
            foreach ($li in $script:list) { [void]$script:html.Append("<li>$(Encode-Html $li)</li>") }
            [void]$script:html.Append("</ul>")
            $script:list = @()
        }
    }

    $script:para = @()
    $script:list = @()
    $script:html = $html

    foreach ($raw in $lines) {
        $line = $raw.TrimEnd()
        if ($line.StartsWith("## ")) {
            Flush-Para; Flush-List
            [void]$html.Append("<h3>$(Encode-Html ($line.Substring(3).Trim()))</h3>")
        } elseif ($line.StartsWith("- ")) {
            Flush-Para
            $script:list += ,($line.Substring(2).Trim())
        } elseif ($line.Trim() -eq "") {
            Flush-Para; Flush-List
        } else {
            Flush-List
            $script:para += ,($line.Trim())
        }
    }
    Flush-Para; Flush-List
    return $html.ToString()
}

# ──────────────────────────────────────────────────────────────────
# 1. Enable Portal Web API for knowledgearticle
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Enabling Portal Web API for knowledgearticle ==="
foreach ($pair in @(@("enabled","true"), @("fields","*"))) {
    $name = "Webapi/knowledgearticle/$($pair[0])"
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
        if ($msg -match "already exists|DuplicateRecord|duplicate") { Write-Host "  SKIP (exists): $name" }
        else { Write-Host "  ERR: $name - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" }
    }
}

# ──────────────────────────────────────────────────────────────────
# 2. Table permission (Anonymous + Authenticated, Read, Global)
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Looking up web role IDs ==="
$roles = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webroles?`$filter=_mspp_websiteid_value eq $websiteId&`$select=mspp_webroleid,mspp_name" -Headers $readH
$roleMap = @{}
foreach ($r in $roles.value) { $roleMap[$r.mspp_name] = $r.mspp_webroleid }
$targetRoles = @()
foreach ($n in @("Anonymous Users","Authenticated Users")) {
    if ($roleMap.ContainsKey($n)) { $targetRoles += $roleMap[$n]; Write-Host "  $n = $($roleMap[$n])" }
    else { Write-Host "  (role '$n' not found)" }
}

Write-Host "`n=== Creating/Updating Table Permission ==="
$permName = "DMV - Knowledge Article (Read)"
$permContent = @{
    entitylogicalname = "knowledgearticle"
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

$existingPerm = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=name eq '$permName' and powerpagecomponenttype eq 18&`$select=powerpagecomponentid" -Headers $readH
if ($existingPerm.value.Count -gt 0) {
    $permId = $existingPerm.value[0].powerpagecomponentid
    $patch = @{ content = $permContent } | ConvertTo-Json -Compress
    Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($permId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
    Write-Host "  PATCHED existing permission: $permId"
} else {
    $permBody = @{
        name = $permName
        powerpagecomponenttype = 18
        content = $permContent
        "powerpagesiteid@odata.bind" = "/powerpagesites($websiteId)"
    } | ConvertTo-Json -Compress
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($permBody)) -UseBasicParsing
        $newId = ($resp.Headers['OData-EntityId'] -replace '.*\(([^)]+)\).*','$1')
        Write-Host "  CREATED permission: $newId"
        # Auto-created permission may strip the webrole array — patch to ensure it sticks
        Start-Sleep 2
        $patch = @{ content = $permContent } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/powerpagecomponents($newId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null
        Write-Host "  (re-patched content to ensure webrole list persists)"
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ERR: $($msg.Substring(0,[Math]::Min(300,$msg.Length)))"
    }
}

# ──────────────────────────────────────────────────────────────────
# 3. Seed native knowledgearticle records
# ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Seeding Native Knowledge Articles ==="
$seedPath = Join-Path $PSScriptRoot "knowledge_seed.json"
$seed = Get-Content $seedPath -Raw | ConvertFrom-Json
Write-Host "  Loaded $($seed.Count) records from seed file"

$created = 0; $skipped = 0; $failed = 0

foreach ($rec in $seed) {
    $slug = $rec.slug
    # Check if already exists (by articlepublicnumber)
    $existing = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/knowledgearticles?`$filter=articlepublicnumber eq '$slug'&`$select=knowledgearticleid,statecode&`$top=1" -Headers $readH
    if ($existing.value.Count -gt 0) {
        Write-Host "  SKIP (exists): $slug (state=$($existing.value[0].statecode))"
        $skipped++
        continue
    }

    $htmlContent = ConvertTo-Html $rec.body
    $keywords = "type=$($rec.type);category=$($rec.category);order=$($rec.order);minutes=$($rec.readMinutes)"
    $description = $rec.summary
    if ($description.Length -gt 250) { $description = $description.Substring(0,247) + "..." }

    $row = @{
        title                         = $rec.title
        description                   = $description
        content                       = $htmlContent
        articlepublicnumber           = $slug
        keywords                      = $keywords
        isrootarticle                 = $false
        islatestversion               = $true
        isprimary                     = $true
        majorversionnumber            = 1
        minorversionnumber            = 0
        "languagelocaleid@odata.bind" = "/languagelocale($languageId)"
    }
    $body = $row | ConvertTo-Json -Compress -Depth 5
    try {
        $resp = Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles" -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
        $newId = ($resp.Headers['OData-EntityId'] -replace '.*\(([^)]+)\).*','$1')

        # Publish: statecode=3 (Published), statuscode=7 (Published)
        $pubBody = @{ statecode = 3; statuscode = 7 } | ConvertTo-Json -Compress
        try {
            Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($newId)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($pubBody)) -UseBasicParsing | Out-Null
            Write-Host "  CREATED + PUBLISHED: $slug"
        } catch {
            $msg = $_.Exception.Message
            Write-Host "  CREATED but PUBLISH FAILED: $slug - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
        }
        $created++
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ERR creating $slug - $($msg.Substring(0,[Math]::Min(300,$msg.Length)))"
        $failed++
    }
}

Write-Host "`n=== DONE ==="
Write-Host "  Created:  $created"
Write-Host "  Skipped:  $skipped (already existed)"
Write-Host "  Failed:   $failed"
Write-Host ""
Write-Host "Portal endpoint: /_api/knowledgearticles"
Write-Host "Filter for portal: \$filter=statecode eq 3 and islatestversion eq true"
