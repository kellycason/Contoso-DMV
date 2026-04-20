# License Renewal Demo Flow

## Overview
End-to-end walkthrough of a citizen renewing their driver's license through the Contoso DMV portal, followed by DMV staff approval via the model-driven app, and the citizen receiving their temporary license.

---

## Act 1 — Citizen Submits Renewal

1. **Navigate to the portal**
   - Go to `https://site-y5jzr.powerappsportals.us/`
   - Log in as Maria Jennings (citizen account)

2. **Start the renewal**
   - Click **License Renewal** in the top nav (or the card on the home page)
   - The system checks for an existing in-progress renewal — if none, the wizard loads

3. **Step 1 — Identity Verification**
   - First name, last name, date of birth, and license number are entered
   - Last 4 of SSN is masked as dots for security

4. **Step 2 — Current Details**
   - Address, email, and phone are auto-filled from the citizen's profile
   - Citizen confirms or updates their information

5. **Step 3 — Medical Certification**
   - Three yes/no questions: vision, seizures, loss of consciousness
   - If any answer indicates a medical concern → **red banner** appears: "Not eligible for online renewal" with a link to schedule an in-person appointment
   - If all clear → Continue

6. **Step 4 — Payment**
   - Renewal fee displayed ($40.00)
   - Card number, expiration, CVV entered (demo data)
   - Click **Submit Payment & Complete Renewal**

7. **Step 5 — Confirmation Receipt**
   - Reference number displayed (e.g., RNW-2026-XXXX)
   - Status: **Under Review**
   - "What happens next?" box explains the 3-step process:
     1. DMV reviews your renewal (1–3 business days)
     2. You'll receive an email when approved
     3. Download your temporary license from the Documents page
   - _No temporary license is issued at this point_ — it requires staff approval first

---

## Act 2 — DMV Staff Reviews & Approves

1. **Open the model-driven app**
   - Go to `https://orga381269e.crm9.dynamics.com/`
   - Open the **Contoso DMV Customer Service** app
   - Navigate to **License Renewals** under DMV Operations

2. **Find the renewal**
   - The renewal from Maria Jennings appears in the **Pending Review** view
   - Click to open the record

3. **Review the details**
   - All citizen-submitted info is visible: name, license number, address, medical answers, payment reference
   - Staff verifies the information

4. **Approve the renewal**
   - Change **Renewal Status** from "Submitted" → **Approved**
   - The form automation fires:
     - **Approved Date** auto-populates with today's date
     - **New Expiration Date** auto-populates to 10 years from today
   - Save the record

5. **Power Automate triggers** _(if configured)_
   - Flow detects `dmv_renewalstatus eq 100000002` (Approved)
   - Sends an email to the citizen with renewal details and a link to download their temporary license

---

## Act 3 — Citizen Downloads Temporary License

1. **Citizen receives the email**
   - Subject: "Your License Renewal Has Been Approved"
   - Body shows reference number, license number, new expiration date
   - **"Download Temporary License"** button links to the Documents page

2. **Navigate to Documents**
   - Click the link (or go to portal → **Documents** in the nav)
   - The **My Temporary Licenses** section shows the approved renewal

3. **Download the PDF**
   - Click **Download Temporary License**
   - A professional PDF is generated in the browser:
     - Landscape layout with navy header and gold accent
     - Citizen's photo (pulled from their contact record)
     - Full name, DOB, license number, address
     - Issue date, expiration date, restrictions
     - "TEMPORARY — VALID FOR 90 DAYS" status strip
     - Barcode in the footer
   - PDF downloads to the citizen's device — can be printed or stored on their phone

---

## Key Talking Points

| Topic | Detail |
|---|---|
| **Security** | SSN masked, portal login required, CSRF tokens on all writes |
| **Smart validation** | Medical screen blocks ineligible citizens from online renewal |
| **No premature issuance** | Temp license only available after staff approval — not at submission |
| **Automation** | Approved date & expiration auto-set on status change — no manual entry |
| **Real-time data** | Portal reads directly from Dataverse via Web API — no sync delay |
| **Professional output** | PDF matches a real state-issued temporary license format |
| **Email notification** | Power Automate flow triggers on approval to notify the citizen |
