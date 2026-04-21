<#
  33_enrich_knowledge_keywords_and_descriptions.ps1
  ------------------------------------------------------------------
  Replaces the placeholder keywords (which had type/category/order/
  minutes encoded in them) with REAL search keywords so Copilot can
  find these articles, and ensures every article has a good
  standalone description (the field shown in list views and used by
  Copilot as a summary snippet).

  Uses hand-curated per-slug metadata below. Idempotent: safe to
  re-run.
#>

$ErrorActionPreference = "Stop"
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}
$readH = @{
    Authorization = "Bearer $token"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
}

# ──────────────────────────────────────────────────────────────────
# Per-article real keywords + real descriptions
#   keywords: comma-separated search terms (natural phrases + acronyms)
#   description: 1–2 sentence standalone summary shown in list views
#                and used by Copilot Studio as a grounding snippet
# ──────────────────────────────────────────────────────────────────
$meta = @{
  # ── Articles / Process Guides ──
  "how-license-renewal-works" = @{
    description = "Step-by-step guide to renewing your driver license online: eligibility, documents, fees, and the 7-10 day mail timeline."
    keywords = "driver license renewal, renew DL online, license expiration, online renewal eligibility, license renewal fee, license renewal process, DL renewal, temporary license, vision screening, class D license, online DMV renewal"
  }
  "how-registration-renewal-works" = @{
    description = "Complete walkthrough of renewing vehicle registration online: eligibility, insurance, emissions, fees, and decal mail timing."
    keywords = "vehicle registration renewal, registration renewal, renew car tag, renew registration online, vehicle tag renewal, proof of insurance, emissions test, registration fee, temporary registration tag, vehicle decal, license plate renewal, registration sticker"
  }
  "renewal-lifecycle" = @{
    description = "Explains the status flow every renewal goes through: Submitted, Under Review, Approved, Mailed, Action Required, and Denied."
    keywords = "renewal status, renewal lifecycle, submitted status, under review, approved, mailed, action required, denied renewal, MyDMV status, renewal tracking, how to check renewal status, renewal reference number"
  }
  "online-vs-in-person" = @{
    description = "Decision guide: which DMV transactions can be completed online versus those that require an in-person branch visit."
    keywords = "online vs in person, DMV branch visit, which transactions require visit, in person appointment, online transactions, first time license, REAL ID, CDL, commercial driver license, title transfer, name change, gender marker change, license reinstatement, out of state transfer"
  }
  "appointment-tips" = @{
    description = "Five tips for a faster branch appointment: book online, arrive 10 minutes early, bring originals, pre-fill forms, cancel early."
    keywords = "appointment tips, DMV branch appointment, reduce wait time, arrive early, bring original documents, pre-fill forms, cancel appointment, appointment preparation, faster DMV visit, walk in vs appointment"
  }
  "data-security" = @{
    description = "How Contoso DMV protects your data: TLS encryption, MFA, tokenized payments, data minimization, and phishing reporting."
    keywords = "data security, privacy, encryption, TLS, multi factor authentication, MFA, passwordless, payment security, PCI DSS, tokenized payments, phishing, suspicious email, protect personal information, identity protection, secure portal"
  }

  # ── FAQs: General ──
  "faq-general-services-online" = @{
    description = "Summary of Contoso DMV services available through the portal: licenses, registration, address changes, appointments, and more."
    keywords = "online services, what can I do online, available services, portal services, driver license renewal, vehicle registration, address change, appointment scheduling, document upload, driver record, dealer transactions"
  }
  "faq-general-processing-time" = @{
    description = "How long online submissions take to go from Submitted to Approved: typically 1-2 business days, with confirmation email sent immediately."
    keywords = "processing time, how long does it take, online submission time, approval time, renewal timeline, submitted to approved, business days, confirmation email, reference number"
  }
  "faq-general-security" = @{
    description = "Confirms the portal is secure with TLS, MFA on accounts, tokenized payments, and a no-sell-data privacy guarantee."
    keywords = "is the portal secure, portal security, online DMV safety, TLS encryption, multi factor authentication, PCI compliant, personal information protection, privacy policy, do you sell my data"
  }
  "faq-general-mydmv-account" = @{
    description = "Whether you need a MyDMV account (recommended but not required) and the benefits: status tracking, saved documents, reminders."
    keywords = "MyDMV account, do I need account, create MyDMV, sign up, benefits of account, track status, saved documents, expiration reminders, automatic reminders, DMV dashboard"
  }
  "faq-general-mobile" = @{
    description = "Confirms the portal is fully mobile-friendly and supports uploading document photos directly from a phone camera."
    keywords = "mobile, phone, smartphone, mobile friendly, responsive design, upload from phone, phone camera, use on iPhone, use on Android, mobile browser"
  }

  # ── FAQs: Driver License ──
  "faq-license-renew-online" = @{
    description = "Steps to renew a driver license online using license number, date of birth, and last four of SSN."
    keywords = "how do I renew my license, renew driver license, renew DL, online license renewal, license number, date of birth, SSN, temporary license, license renewal steps, renew license without visiting"
  }
  "faq-license-expired" = @{
    description = "You can renew online within 60 days of expiration; beyond that, an in-person appointment is required."
    keywords = "expired license, license expired, renew expired license, 60 day grace period, lapsed license, in person renewal required, late license renewal, past expiration"
  }
  "faq-license-term" = @{
    description = "Standard Class D driver licenses at Contoso DMV are issued for an 8-year term."
    keywords = "license validity, license term, how long valid, 8 years, class D license, expiration date, license duration, when does license expire"
  }
  "faq-license-address" = @{
    description = "How to update your address on your driver license through MyDMV - free, immediate, and recommended before renewing."
    keywords = "change address, update address, address change, moved, new address on license, MyDMV address change, free address update"
  }
  "faq-license-duplicate" = @{
    description = "Request a duplicate license online if lost or stolen. Fee is $26; police report recommended if stolen."
    keywords = "lost license, stolen license, duplicate license, replacement license, lost ID, replace driver license, duplicate fee, police report, get new license copy"
  }
  "faq-license-photo" = @{
    description = "New license photos are taken only during in-person renewal or duplicate issuance. Online renewals reuse the on-file photo."
    keywords = "license photo, change photo, new photo, update license picture, in person photo, license picture, photo update, old photo on license"
  }

  # ── FAQs: Vehicle Registration ──
  "faq-reg-expire" = @{
    description = "Vehicle registration is valid for one year; a renewal notice is posted to MyDMV 60 days before expiration."
    keywords = "when does registration expire, registration expiration, one year registration, renewal notice, 60 days before expiration, check registration status, plate expiration, registration lookup"
  }
  "faq-reg-new-vehicle" = @{
    description = "Documents needed to register a new vehicle: title, bill of sale, insurance, VIN, odometer reading, and sometimes emissions."
    keywords = "register new vehicle, new vehicle registration, first time registration, vehicle title, bill of sale, VIN, odometer, proof of insurance, emissions test, new car registration, newly purchased vehicle"
  }
  "faq-reg-early" = @{
    description = "You can renew vehicle registration up to 75 days before expiration without losing time on your current term."
    keywords = "renew registration early, early renewal, 75 days before expiration, renewal window, do I lose time renewing early, early registration renewal"
  }
  "faq-reg-lapsed" = @{
    description = "Consequences of lapsed registration: citation risk, late fees after 30 days, possible re-inspection after 60 days."
    keywords = "lapsed registration, expired registration, driving with expired registration, registration late fee, 30 day grace, 60 day penalty, vehicle inspection, citation, ticket for expired tag"
  }
  "faq-reg-title-transfer" = @{
    description = "Vehicle title transfers between private parties can be done online with electronic signatures and photo ID uploads."
    keywords = "title transfer, transfer vehicle title, sell car, buy car, private party sale, online title, electronic title, buyer seller, transfer ownership, vehicle sale paperwork"
  }
  "faq-reg-emissions" = @{
    description = "Emissions test requirements vary by model year and county; your renewal notice shows whether one is required."
    keywords = "emissions test, smog test, emissions inspection, do I need emissions, model year, county requirement, certified station, renewal notice emissions, air quality inspection"
  }

  # ── FAQs: Appointments ──
  "faq-appt-advance" = @{
    description = "Appointments can be booked up to 90 days in advance; same-day slots are released nightly at 8:00 PM."
    keywords = "schedule appointment, how far in advance, 90 days, same day appointment, book DMV appointment, appointment availability, walk in, 8 PM release, same day slots"
  }
  "faq-appt-cancel" = @{
    description = "How to cancel or reschedule a DMV appointment via confirmation email or MyDMV; please cancel at least 24 hours ahead."
    keywords = "cancel appointment, reschedule appointment, change appointment, appointment cancellation, 24 hours notice, confirmation email, modify appointment, MyDMV appointments"
  }
  "faq-appt-arrival" = @{
    description = "Arrive 10 minutes before your scheduled time; arriving much earlier does not speed up check-in."
    keywords = "how early arrive, arrival time, when to arrive, early arrival, 10 minutes early, appointment time, check in, on time arrival"
  }
  "faq-appt-late" = @{
    description = "Late policy: a short grace window is provided, but more than 15 minutes late usually means rescheduling."
    keywords = "late to appointment, running late, grace period, 15 minutes late, miss appointment, tardy, appointment late policy, reschedule if late"
  }
  "faq-appt-companion" = @{
    description = "A family member, translator, or support person can attend. Minors need a parent or guardian for identity transactions."
    keywords = "bring someone, companion, family member, translator, support person, interpreter, minor accompanied, parent guardian, bring child, bring friend"
  }

  # ── FAQs: Fees & Payment ──
  "faq-fees-methods" = @{
    description = "Accepted online payments: Visa, Mastercard, American Express, Discover, and e-check. No cash or wire transfers."
    keywords = "payment methods, accepted payment, credit card, Visa, Mastercard, American Express, Discover, e-check, electronic check, debit card, how to pay, accepted forms of payment, no cash online"
  }
  "faq-fees-convenience" = @{
    description = "A $2.00 convenience fee applies to online credit card payments; e-check payments have no additional fee."
    keywords = "convenience fee, credit card fee, extra fee, online payment fee, e-check no fee, $2 fee, surcharge, processing fee"
  }
  "faq-fees-late" = @{
    description = "Late penalty fees apply when a renewal is submitted after the grace period; exact amount shown on the renewal notice."
    keywords = "late fee, late penalty, why was I charged, penalty fee, overdue fee, grace period, late renewal charge, additional fees, past due penalty"
  }
  "faq-fees-refund" = @{
    description = "Refund policy: submit a request through MyDMV within 10 business days; fees for completed services are non-refundable."
    keywords = "refund, request refund, money back, reimbursement, refund policy, 10 business days, refund request, get money back, non refundable"
  }
  "faq-fees-receipt" = @{
    description = "Receipts are emailed with the confirmation and downloadable as PDF from the Documents page for 7 years."
    keywords = "receipt, get receipt, payment receipt, PDF receipt, confirmation email, download receipt, proof of payment, transaction record, 7 year history"
  }

  # ── FAQs: Documents & Identity ──
  "faq-docs-upload" = @{
    description = "Documents you can upload: insurance, emissions, residency, medical, POA, bill of sale, and signed titles (PDF or JPG, 10 MB)."
    keywords = "upload documents, what can I upload, PDF upload, JPG upload, proof of insurance, emissions test result, residency document, medical clearance, power of attorney, POA, bill of sale, signed title, 10 MB limit"
  }
  "faq-docs-review-time" = @{
    description = "Most uploaded documents are auto-reviewed in seconds; flagged items typically clear within one business day."
    keywords = "document review time, how long review, automatic review, auto review, human review, document approval, flagged document, upload status, one business day"
  }
  "faq-docs-residency" = @{
    description = "Acceptable proof of residency: utility bill, bank statement, lease, or mortgage statement dated within 90 days."
    keywords = "proof of residency, residency documents, utility bill, bank statement, lease agreement, mortgage statement, residency proof, 90 days old, prove I live here, address verification"
  }
  "faq-docs-originals" = @{
    description = "Uploads speed up review but do not replace physical originals for identity transactions at your appointment."
    keywords = "original documents, bring originals, physical documents, do I still need originals, identity transaction, in person verification, uploaded documents not enough"
  }

  # ── FAQs: Accessibility & Support ──
  "faq-access-screenreader" = @{
    description = "Built to WCAG 2.1 AA standards; report accessibility barriers to the support team so we can fix them."
    keywords = "accessibility, screen reader, WCAG, WCAG 2.1 AA, accessible portal, disability access, blind users, vision impaired, accessibility barrier, accessible design, ADA compliance"
  }
  "faq-access-language" = @{
    description = "English and Spanish supported by phone; branches offer free over-the-phone interpretation in 200+ languages."
    keywords = "language assistance, Spanish, English, translator, interpreter, over the phone interpretation, OPI, 200 languages, language help, non English speaker, bilingual support"
  }
  "faq-access-contact" = @{
    description = "Contact a real agent: phone 1-555-123-4567 (Mon-Fri 8-5) or email info@contosodmv.example, or book an appointment."
    keywords = "contact us, talk to human, speak to person, customer service phone, 1-555-123-4567, email DMV, info@contosodmv.example, hours, Monday Friday, contact information, support phone number"
  }
}

# ──────────────────────────────────────────────────────────────────
# Apply to each published article
# ──────────────────────────────────────────────────────────────────
Write-Host "=== Loading existing published articles ==="
$arts = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/knowledgearticles?`$filter=statecode eq 3 and islatestversion eq true&`$select=knowledgearticleid,articlepublicnumber,title,description,keywords&`$top=200" -Headers $readH
Write-Host "  Found $($arts.value.Count) articles"

$updated = 0; $skipped = 0; $missing = @()

foreach ($a in $arts.value) {
    $slug = $a.articlepublicnumber
    if (-not $meta.ContainsKey($slug)) {
        $missing += $slug
        continue
    }
    $m = $meta[$slug]
    $desc = $m.description
    if ($desc.Length -gt 155) { $desc = $desc.Substring(0,152) + "..." }

    # Unpublish -> patch -> republish cycle (description/keywords are locked while published)
    $id = $a.knowledgearticleid
    try {
        $draft = @{ statecode = 0; statuscode = 2 } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($id)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($draft)) -UseBasicParsing | Out-Null

        $patch = @{ description = $desc; keywords = $m.keywords } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($id)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) -UseBasicParsing | Out-Null

        $pub = @{ statecode = 3; statuscode = 7 } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$envUrl/api/data/v9.2/knowledgearticles($id)" -Method Patch -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($pub)) -UseBasicParsing | Out-Null

        Write-Host "  UPDATED: $slug"
        $updated++
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ERR: $slug - $($msg.Substring(0,[Math]::Min(200,$msg.Length)))"
    }
}

Write-Host "`n=== DONE ==="
Write-Host "  Updated: $updated"
if ($missing.Count -gt 0) {
    Write-Host "  Missing metadata for: $($missing -join ', ')"
}
