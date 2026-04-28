<#
  Creates a public, server-rendered Power Pages page for Copilot Studio website
  knowledge ingestion.

  URL: /knowledge-base

  The page uses Liquid FetchXML against the native Customer Service
  knowledgearticle table, so new published knowledge articles appear on the
  page automatically without rebuilding the React SPA.
#>

$envUrl = "https://orga381269e.crm9.dynamics.com"
$websiteId = "461a50ae-9496-419e-a58b-14d56165b009"
$homeRootId = "f96dc62c-ea87-4095-81e4-ac3240f624d6"
$publishStateId = "ba33c999-8687-42f5-84ef-4faf297ad111"
$languageId = "752b3b1f-360c-4132-b154-34e0c7b91b68"

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
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}
$postH = @{
    Authorization              = "Bearer $token"
    "Content-Type"             = "application/json; charset=utf-8"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    Accept                     = "application/json"
    "MSCRM.SolutionUniqueName" = "DMVDigitalServicesPortal"
}

function Get-EntityIdFromResponse($response) {
    $entityId = $response.Headers["OData-EntityId"] | Select-Object -First 1
    if (-not $entityId) { $entityId = $response.Headers["Location"] | Select-Object -First 1 }
    return ($entityId -replace '.*\(([^)]+)\).*', '$1')
}

function Invoke-JsonPatch($uri, $body) {
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    Invoke-WebRequest -Uri $uri -Method Patch -Headers $writeH -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing | Out-Null
}

function Invoke-JsonPost($uri, $body) {
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    return Invoke-WebRequest -Uri $uri -Method Post -Headers $postH -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -UseBasicParsing
}

$templateName = "DMV Knowledge Crawler"
$pageTemplateName = "DMV Knowledge Crawler Template"
$pageName = "Knowledge Base"
$partialUrl = "knowledge-base"

$crawlerLinkHtml = @'
<nav id="contoso-dmv-crawler-links" aria-label="Public DMV knowledge" style="padding: 8px 16px; font: 14px Segoe UI, Arial, sans-serif; background: #ffffff;">
  <a href="/knowledge-base">Contoso DMV Knowledge Base</a>
</nav>
'@

function Add-CrawlerLinkToHtml($html) {
    if ($html -match 'href=["'']/knowledge-base["'']') { return $html }
    if ($html -match '<body[^>]*>') {
        return [regex]::Replace($html, '<body[^>]*>', { param($match) "$($match.Value)`r`n$crawlerLinkHtml" }, 1)
    }
    return "$crawlerLinkHtml`r`n$html"
}

$source = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Contoso DMV Knowledge Base</title>
  <meta name="description" content="Public Contoso DMV knowledge articles for registration renewal, license renewal, appointments, fees, documents, emissions testing, processing timelines, accessibility, language support, and portal security.">
  <meta name="robots" content="index,follow">
  <style>
    body { margin: 0; font-family: Segoe UI, Arial, sans-serif; color: #1f2937; background: #ffffff; line-height: 1.55; }
    main { max-width: 920px; margin: 0 auto; padding: 32px 20px 56px; }
    header { border-bottom: 1px solid #d1d5db; margin-bottom: 28px; padding-bottom: 18px; }
    h1 { color: #12395b; font-size: 32px; margin: 0 0 8px; }
    h2 { color: #12395b; font-size: 23px; margin: 34px 0 8px; }
    h3 { color: #334155; margin-top: 22px; }
    article { border-bottom: 1px solid #e5e7eb; padding-bottom: 24px; margin-bottom: 24px; }
    .summary, .meta { color: #4b5563; }
    .meta { font-size: 14px; margin: 0 0 10px; }
    a { color: #0f5b99; }
    ul, ol { padding-left: 24px; }
  </style>
</head>
<body>
<main>
  <header>
    <h1>Contoso DMV Knowledge Base</h1>
    <p class="summary">Public DMV help articles and FAQs for online services, vehicle registration renewal, driver license renewal, appointments, fees, documents, emissions testing, processing timelines, accessibility, language support, and portal security.</p>
    <p class="meta">This page is generated from published Contoso DMV Knowledge Articles and updates automatically when new articles are published.</p>
  </header>

  {% fetchxml knowledge_articles %}
  <fetch version="1.0" mapping="logical" distinct="false">
    <entity name="knowledgearticle">
      <attribute name="knowledgearticleid" />
      <attribute name="title" />
      <attribute name="articlepublicnumber" />
      <attribute name="description" />
      <attribute name="keywords" />
      <attribute name="content" />
      <attribute name="modifiedon" />
      <order attribute="title" descending="false" />
      <filter type="and">
        <condition attribute="statecode" operator="eq" value="3" />
        <condition attribute="islatestversion" operator="eq" value="1" />
      </filter>
    </entity>
  </fetch>
  {% endfetchxml %}

  {% assign articles = knowledge_articles.results.entities %}
  {% if articles.size > 0 %}
    {% for article in articles %}
      <article id="{{ article.articlepublicnumber | default: article.knowledgearticleid | escape }}">
        <h2>{{ article.title | default: 'Knowledge Article' | escape }}</h2>
        {% if article.articlepublicnumber %}<p class="meta">Article ID: {{ article.articlepublicnumber | escape }}</p>{% endif %}
        {% if article.description %}<p class="summary">{{ article.description | escape }}</p>{% endif %}
        {% if article.keywords %}<p class="meta">Keywords: {{ article.keywords | escape }}</p>{% endif %}
        <section>
          {{ article.content }}
        </section>
      </article>
    {% endfor %}
  {% else %}
    <p>No published knowledge articles are currently available.</p>
  {% endif %}
</main>
</body>
</html>
'@

Write-Host "=== Ensuring web template ===" -ForegroundColor Cyan
$existingTemplate = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webtemplates?`$filter=_mspp_websiteid_value eq $websiteId and mspp_name eq '$templateName'&`$select=mspp_webtemplateid&`$top=1" -Headers $readH
if ($existingTemplate.value.Count -gt 0) {
    $webTemplateId = $existingTemplate.value[0].mspp_webtemplateid
    Invoke-JsonPatch "$envUrl/api/data/v9.2/mspp_webtemplates($webTemplateId)" @{ mspp_source = $source }
    $content = @{ source = $source; websiteid = $websiteId } | ConvertTo-Json -Depth 4
    Invoke-JsonPatch "$envUrl/api/data/v9.2/powerpagecomponents($webTemplateId)" @{ content = $content }
    Write-Host "Updated web template: $webTemplateId"
} else {
    $resp = Invoke-JsonPost "$envUrl/api/data/v9.2/mspp_webtemplates" @{
        mspp_name = $templateName
        mspp_source = $source
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    }
    $webTemplateId = Get-EntityIdFromResponse $resp
    Write-Host "Created web template: $webTemplateId"
}

Write-Host "`n=== Ensuring page template ===" -ForegroundColor Cyan
$existingPageTemplate = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_pagetemplates?`$filter=_mspp_websiteid_value eq $websiteId and mspp_name eq '$pageTemplateName'&`$select=mspp_pagetemplateid&`$top=1" -Headers $readH
if ($existingPageTemplate.value.Count -gt 0) {
    $pageTemplateId = $existingPageTemplate.value[0].mspp_pagetemplateid
    Invoke-JsonPatch "$envUrl/api/data/v9.2/mspp_pagetemplates($pageTemplateId)" @{
        mspp_description = "Server-rendered public knowledge page for Copilot Studio website knowledge ingestion."
        mspp_entityname = "adx_webpage"
        mspp_type = 756150001
        mspp_usewebsiteheaderandfooter = $false
        "mspp_webtemplateid@odata.bind" = "/mspp_webtemplates($webTemplateId)"
    }
    Write-Host "Updated page template: $pageTemplateId"
} else {
    $resp = Invoke-JsonPost "$envUrl/api/data/v9.2/mspp_pagetemplates" @{
        mspp_name = $pageTemplateName
        mspp_description = "Server-rendered public knowledge page for Copilot Studio website knowledge ingestion."
        mspp_entityname = "adx_webpage"
        mspp_type = 756150001
        mspp_usewebsiteheaderandfooter = $false
        "mspp_webtemplateid@odata.bind" = "/mspp_webtemplates($webTemplateId)"
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
    }
    $pageTemplateId = Get-EntityIdFromResponse $resp
    Write-Host "Created page template: $pageTemplateId"
}

Write-Host "`n=== Ensuring /$partialUrl page ===" -ForegroundColor Cyan
$existingRoot = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webpages?`$filter=_mspp_websiteid_value eq $websiteId and mspp_partialurl eq '$partialUrl' and mspp_isroot eq true&`$select=mspp_webpageid&`$top=1" -Headers $readH
if ($existingRoot.value.Count -gt 0) {
    $rootId = $existingRoot.value[0].mspp_webpageid
    Invoke-JsonPatch "$envUrl/api/data/v9.2/mspp_webpages($rootId)" @{
        mspp_name = $pageName
        mspp_title = "Contoso DMV Knowledge Base"
        mspp_hiddenfromsitemap = $false
        "mspp_pagetemplateid@odata.bind" = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind" = "/mspp_publishingstates($publishStateId)"
    }
    Write-Host "Updated root page: $rootId"
} else {
    $resp = Invoke-JsonPost "$envUrl/api/data/v9.2/mspp_webpages" @{
        mspp_name = $pageName
        mspp_title = "Contoso DMV Knowledge Base"
        mspp_partialurl = $partialUrl
        mspp_isroot = $true
        mspp_hiddenfromsitemap = $false
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
        "mspp_parentpageid@odata.bind" = "/mspp_webpages($homeRootId)"
        "mspp_pagetemplateid@odata.bind" = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind" = "/mspp_publishingstates($publishStateId)"
    }
    $rootId = Get-EntityIdFromResponse $resp
    Write-Host "Created root page: $rootId"
}

$existingContent = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/mspp_webpages?`$filter=_mspp_websiteid_value eq $websiteId and _mspp_rootwebpageid_value eq $rootId and mspp_isroot eq false&`$select=mspp_webpageid&`$top=1" -Headers $readH
if ($existingContent.value.Count -gt 0) {
    $contentId = $existingContent.value[0].mspp_webpageid
    Invoke-JsonPatch "$envUrl/api/data/v9.2/mspp_webpages($contentId)" @{
        mspp_name = $pageName
        mspp_title = "Contoso DMV Knowledge Base"
        mspp_copy = ""
        mspp_hiddenfromsitemap = $false
        "mspp_pagetemplateid@odata.bind" = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind" = "/mspp_publishingstates($publishStateId)"
    }
    Write-Host "Updated content page: $contentId"
} else {
    $resp = Invoke-JsonPost "$envUrl/api/data/v9.2/mspp_webpages" @{
        mspp_name = $pageName
        mspp_title = "Contoso DMV Knowledge Base"
        mspp_partialurl = $partialUrl
        mspp_isroot = $false
        mspp_copy = ""
        mspp_hiddenfromsitemap = $false
        "mspp_websiteid@odata.bind" = "/mspp_websites($websiteId)"
        "mspp_parentpageid@odata.bind" = "/mspp_webpages($homeRootId)"
        "mspp_rootwebpageid@odata.bind" = "/mspp_webpages($rootId)"
        "mspp_pagetemplateid@odata.bind" = "/mspp_pagetemplates($pageTemplateId)"
        "mspp_publishingstateid@odata.bind" = "/mspp_publishingstates($publishStateId)"
        "mspp_webpagelanguageid@odata.bind" = "/mspp_websitelanguages($languageId)"
    }
    $contentId = Get-EntityIdFromResponse $resp
    Write-Host "Created content page: $contentId"
}

  Write-Host "`n=== Ensuring root crawler link ===" -ForegroundColor Cyan
  $shellPages = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/powerpagecomponents?`$filter=powerpagecomponenttype eq 2 and name eq 'Home'&`$select=powerpagecomponentid,name,content&`$top=10" -Headers $readH
  $linkUpdated = $false
  foreach ($shellPage in $shellPages.value) {
    try {
      $componentContent = $shellPage.content | ConvertFrom-Json
    } catch {
      Write-Host "Skipped Home component with unreadable content: $($shellPage.powerpagecomponentid)" -ForegroundColor Yellow
      continue
    }

    if (-not $componentContent.copy -or $componentContent.copy -notmatch 'index-CcBGzUdW\.js') { continue }

    $newCopy = Add-CrawlerLinkToHtml $componentContent.copy
    if ($newCopy -eq $componentContent.copy) {
      Write-Host "Root page already links to /$partialUrl"
      continue
    }

    $componentContent.copy = $newCopy
    $contentJson = $componentContent | ConvertTo-Json -Depth 20 -Compress
    Invoke-JsonPatch "$envUrl/api/data/v9.2/powerpagecomponents($($shellPage.powerpagecomponentid))" @{ content = $contentJson }
    $linkUpdated = $true
    Write-Host "Updated root page crawler link: $($shellPage.powerpagecomponentid)"
  }

  if (-not $linkUpdated -and $shellPages.value.Count -eq 0) {
    Write-Host "No Home powerpagecomponent found to patch." -ForegroundColor Yellow
  }

  Write-Host "`n=== PublishAllXml ===" -ForegroundColor Cyan
  try {
    Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/PublishAllXml" -Headers $writeH -Method Post | Out-Null
    Write-Host "Published."
  } catch {
    Write-Host "Publish warning: $($_.Exception.Message)" -ForegroundColor Yellow
  }

Write-Host "`nDone. Public crawler URL: https://site-y5jzr.powerappsportals.us/$partialUrl" -ForegroundColor Green
Write-Host "Power Pages may take a few minutes to refresh metadata/cache."