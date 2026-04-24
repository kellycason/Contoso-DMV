import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { dvCreate, dvQuery, fmt } from '../hooks/useDataverse'

// Parse a Dataverse date value as *local* calendar date to avoid UTC-shift
// display bugs for DateOnly fields (e.g. "2027-04-21" rendering as April 20 in
// negative-offset timezones).
function parseDvDate(value: string | null | undefined): Date | null {
  if (!value) return null
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:[T ]|$)/.exec(String(value))
  if (m) return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  const d = new Date(value)
  return isNaN(d.getTime()) ? null : d
}

const docTypeOptions = [
  { label: 'Proof of Identity', value: 100000000 },
  { label: 'Proof of Residency', value: 100000001 },
  { label: 'Insurance Certificate', value: 100000002 },
  { label: 'Vehicle Title', value: 100000003 },
  { label: 'Lien Release', value: 100000004 },
  { label: 'Other', value: 100000005 },
]

const acceptedTypes = [
  { ext: 'PDF', desc: "Driver's License / ID" },
  { ext: 'PDF', desc: 'Proof of Insurance' },
  { ext: 'JPG/PNG', desc: 'Vehicle Title (photo)' },
  { ext: 'PDF', desc: 'Proof of Residency' },
  { ext: 'PDF', desc: 'Social Security Card' },
  { ext: 'JPG/PNG/PDF', desc: 'Other Supporting Documents' },
]

interface UploadedFile {
  name: string
  size: number
  type: string
  id: string
}

export default function Documents() {
  useEffect(() => { document.title = 'Document Upload — Contoso DMV' }, [])

  const { isAuthenticated, userId } = useAuth()
  const [files, setFiles] = useState<UploadedFile[]>([])
  const [dragging, setDragging] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState('')
  const [docType, setDocType] = useState(100000005)
  const [existingDocs, setExistingDocs] = useState<Record<string, any>[]>([])
  const [loadingDocs, setLoadingDocs] = useState(true)
  const [refNum, setRefNum] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)
  const [approvedRenewals, setApprovedRenewals] = useState<Record<string, any>[]>([])
  const [loadingRenewals, setLoadingRenewals] = useState(true)
  const [downloadingId, setDownloadingId] = useState<string | null>(null)
  const [approvedRegRenewals, setApprovedRegRenewals] = useState<Record<string, any>[]>([])
  const [loadingRegRenewals, setLoadingRegRenewals] = useState(true)

  useEffect(() => {
    if (isAuthenticated && userId) {
      dvQuery('dmv_documentuploads',
        `$filter=_dmv_contactid_value eq ${userId}&$select=dmv_documentname,dmv_documenttype,dmv_uploaddate,dmv_verificationstatus,dmv_filesize,dmv_filetype&$orderby=dmv_uploaddate desc&$top=50`
      ).then(setExistingDocs).catch(() => {}).finally(() => setLoadingDocs(false))

      dvQuery('dmv_licenserenewals',
        `$filter=_dmv_contactid_value eq ${userId} and dmv_renewalstatus eq 100000002&$select=dmv_renewalid,dmv_licensenumber,dmv_firstname,dmv_lastname,dmv_dateofbirth,dmv_streetaddress,dmv_city,dmv_state,dmv_zipcode,dmv_approveddate,dmv_newexpirationdate&$top=10`
      ).then(setApprovedRenewals).catch(() => {}).finally(() => setLoadingRenewals(false))

      dvQuery('dmv_registrationrenewals',
        `$filter=_dmv_contactid_value eq ${userId} and dmv_renewalstatus eq 100000002&$select=dmv_renewalid,dmv_platenumber,dmv_vin,dmv_vehicleyear,dmv_vehiclemake,dmv_vehiclemodel,dmv_vehiclecolor,dmv_firstname,dmv_lastname,dmv_streetaddress,dmv_city,dmv_state,dmv_zipcode,dmv_approveddate,dmv_newexpirationdate,dmv_confirmationnumber&$top=10`
      ).then(setApprovedRegRenewals).catch(() => {}).finally(() => setLoadingRegRenewals(false))
    } else {
      setLoadingDocs(false)
      setLoadingRenewals(false)
      setLoadingRegRenewals(false)
    }
  }, [isAuthenticated, userId])

  function addFiles(incoming: FileList | null) {
    if (!incoming) return
    const newFiles = Array.from(incoming).map(f => ({
      name: f.name,
      size: f.size,
      type: f.type,
      id: Math.random().toString(36).slice(2),
    }))
    setFiles(prev => [...prev, ...newFiles])
  }

  function removeFile(id: string) { setFiles(prev => prev.filter(f => f.id !== id)) }

  function formatSize(bytes: number) {
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
    return (bytes / 1048576).toFixed(1) + ' MB'
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault(); setDragging(false)
    addFiles(e.dataTransfer.files)
  }

  const handleSubmit = async () => {
    setSubmitting(true)
    setSubmitError('')
    try {
      for (const f of files) {
        await dvCreate('dmv_documentuploads', {
          dmv_documentname: f.name,
          dmv_documenttype: docType,
          dmv_uploaddate: new Date().toISOString(),
          dmv_verificationstatus: 100000000, // Pending Review
          dmv_filesize: Math.round(f.size / 1024),
          dmv_filetype: f.type.split('/').pop() ?? 'pdf',
          ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
        })
      }
      // Also log a transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000004, // Document Uploaded
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_channel: 100000000, // Online Portal
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        })
      }
      setRefNum(`DOC-${Math.floor(Math.random() * 9000000 + 1000000)}`)
      setSubmitted(true)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Upload failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const statusColor = (val: string) => {
    if (val === 'Accepted') return { bg: '#d4edda', color: '#155724' }
    if (val === 'Rejected') return { bg: '#f8d7da', color: '#721c24' }
    if (val === 'Expired') return { bg: '#e2e3e5', color: '#383d41' }
    return { bg: '#fff3cd', color: '#856404' }
  }

  if (submitted) {
    return (
      <>
        <div className="page-header"><div className="container"><h1>Document Upload</h1></div></div>
        <div className="container" style={{ padding: '64px 24px', maxWidth: '600px', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }} aria-hidden="true">📨</div>
          <h2 style={{ marginBottom: '12px', color: 'var(--color-success)' }}>Documents Submitted!</h2>
          <p style={{ color: 'var(--color-text-muted)', marginBottom: '8px' }}>
            {files.length} document{files.length !== 1 ? 's' : ''} uploaded successfully. Our team will review them within 1–2 business days.
          </p>
          <p style={{ marginBottom: '32px' }}>
            Reference number: <span className="mono">{refNum}</span>
          </p>
          <Link to="/my-dmv" className="btn btn-primary">Return to My DMV</Link>
        </div>
      </>
    )
  }

  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">Document Upload</span>
          </nav>
          <h1>Upload Documents</h1>
          <p>Securely submit required documents for your DMV transaction.</p>
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: '820px' }}>
          <div style={infoBox}>
            <strong>Accepted formats:</strong> PDF, JPG, PNG (max 10 MB per file).
            Documents are encrypted in transit and stored securely per government data regulations.
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px', marginBottom: '32px' }}>
            <section aria-labelledby="upload-zone-heading">
              <h2 id="upload-zone-heading" className="sr-only">Upload files</h2>
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label htmlFor="docType" style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-primary)' }}>Document Type</label>
                <select id="docType" value={docType} onChange={e => setDocType(Number(e.target.value))}
                  style={{ padding: '10px 14px', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', fontSize: '14px', width: '100%' }}>
                  {docTypeOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
              </div>
              <div
                role="button"
                tabIndex={0}
                aria-label="Drop files here or click to browse"
                style={{ ...dropZone, ...(dragging ? dropZoneActive : {}) }}
                onClick={() => inputRef.current?.click()}
                onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') inputRef.current?.click() }}
                onDragEnter={() => setDragging(true)}
                onDragLeave={() => setDragging(false)}
                onDragOver={e => e.preventDefault()}
                onDrop={handleDrop}
              >
                <span style={{ fontSize: '40px', display: 'block', marginBottom: '12px' }} aria-hidden="true">📂</span>
                <p style={{ fontWeight: 500, marginBottom: '6px', color: 'var(--color-primary)' }}>Drop files here</p>
                <p style={{ fontSize: '13px', color: 'var(--color-text-muted)' }}>or click to browse your device</p>
                <input ref={inputRef} type="file" multiple accept=".pdf,.jpg,.jpeg,.png"
                  style={{ display: 'none' }} onChange={e => addFiles(e.target.files)} aria-label="Choose files to upload" />
              </div>
            </section>

            <section aria-labelledby="accepted-docs-heading">
              <h2 id="accepted-docs-heading" style={{ fontFamily: 'var(--font-heading)', fontSize: '1rem', color: 'var(--color-primary)', marginBottom: '14px' }}>
                Commonly Requested Documents
              </h2>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {acceptedTypes.map(item => (
                  <li key={item.desc} style={{ display: 'flex', gap: '10px', fontSize: '13px', alignItems: 'center' }}>
                    <span className="mono" style={{ fontSize: '11px', flexShrink: 0 }}>{item.ext}</span>
                    <span style={{ color: 'var(--color-text-muted)' }}>{item.desc}</span>
                  </li>
                ))}
              </ul>
            </section>
          </div>

          {files.length > 0 && (
            <section aria-labelledby="file-list-heading" style={{ marginBottom: '32px' }}>
              <h2 id="file-list-heading" style={sectionH}>Selected Files ({files.length})</h2>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '8px' }} role="list">
                {files.map(f => (
                  <li key={f.id} style={fileRow}>
                    <span style={{ fontSize: '20px' }} aria-hidden="true">📄</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontWeight: 500, fontSize: '14px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.name}</p>
                      <p style={{ fontSize: '12px', color: 'var(--color-text-muted)' }}>{formatSize(f.size)}</p>
                    </div>
                    <button type="button" onClick={() => removeFile(f.id)} style={removeBtn} aria-label={`Remove ${f.name}`}>✕</button>
                  </li>
                ))}
              </ul>
            </section>
          )}

          <div style={{ display: 'flex', gap: '16px', alignItems: 'center', flexWrap: 'wrap' }}>
            <button type="button" className="btn btn-primary" disabled={files.length === 0 || submitting}
              onClick={handleSubmit} style={{ fontSize: '15px', padding: '12px 28px' }}>
              {submitting ? 'Submitting...' : 'Submit Documents'}
            </button>
            {submitError && <span style={{ fontSize: '13px', color: 'var(--color-danger)' }}>{submitError}</span>}
            {files.length === 0 && <span style={{ fontSize: '13px', color: 'var(--color-text-muted)' }}>Add at least one file to continue.</span>}
          </div>

          {/* Approved Temporary Licenses */}
          {isAuthenticated && (
            <section style={{ marginTop: '48px' }}>
              <h2 style={sectionH}>My Temporary Licenses</h2>
              {loadingRenewals ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>Loading...</p>
              ) : approvedRenewals.length === 0 ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>No approved temporary licenses available. Once your renewal is approved, your temporary license will appear here.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                  {approvedRenewals.map(r => {
                    const approved = r.dmv_approveddate ? new Date(r.dmv_approveddate).toLocaleDateString() : '—'
                    const expiresDate = parseDvDate(r.dmv_newexpirationdate)
                    const expires = expiresDate ? expiresDate.toLocaleDateString() : '—'
                    return (
                      <div key={r.dmv_licenserenewallid || r.dmv_renewalid} style={{
                        display: 'flex', alignItems: 'center', gap: 16, background: 'var(--color-surface)',
                        border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '16px 20px',
                      }}>
                        <div style={{ fontSize: 32, flexShrink: 0 }} aria-hidden="true">🪪</div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <p style={{ fontWeight: 600, fontSize: 14, color: 'var(--color-primary)' }}>
                            Temporary License — {r.dmv_firstname} {r.dmv_lastname}
                          </p>
                          <p style={{ fontSize: 12, color: 'var(--color-text-muted)', marginTop: 2 }}>
                            <span className="mono">{r.dmv_licensenumber}</span>
                            {' · '}Ref: <span className="mono">{r.dmv_renewalid}</span>
                            {' · '}Approved: {approved}
                            {' · '}License expires: {expires}
                          </p>
                        </div>
                        <span style={{ display: 'inline-block', padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 700, background: '#d4edda', color: '#155724', textTransform: 'uppercase', letterSpacing: 0.3, flexShrink: 0 }}>
                          Approved
                        </span>
                        <button
                          className="btn btn-primary"
                          style={{ fontSize: 13, padding: '8px 16px', flexShrink: 0 }}
                          disabled={downloadingId === (r.dmv_licenserenewallid || r.dmv_renewalid)}
                          onClick={async () => {
                            const id = r.dmv_licenserenewallid || r.dmv_renewalid
                            setDownloadingId(id)
                            try {
                              await downloadTempLicenseFromRenewal(r, userId!)
                            } finally {
                              setDownloadingId(null)
                            }
                          }}
                        >
                          {downloadingId === (r.dmv_licenserenewallid || r.dmv_renewalid) ? 'Generating...' : '⬇ Download PDF'}
                        </button>
                      </div>
                    )
                  })}
                </div>
              )}
            </section>
          )}

          {/* Approved Registration Renewals */}
          {isAuthenticated && (
            <section style={{ marginTop: '48px' }}>
              <h2 style={sectionH}>My Registration Renewals</h2>
              {loadingRegRenewals ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>Loading...</p>
              ) : approvedRegRenewals.length === 0 ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>No approved registration renewals available. Once your renewal is approved, your confirmation will appear here.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                  {approvedRegRenewals.map(r => {
                    const approved = r.dmv_approveddate ? new Date(r.dmv_approveddate).toLocaleDateString() : '—'
                    const expiresDate = parseDvDate(r.dmv_newexpirationdate)
                    const expires = expiresDate ? expiresDate.toLocaleDateString() : '—'
                    const rid = r.dmv_registrationrenewalid || r.dmv_renewalid
                    return (
                      <div key={rid} style={{
                        display: 'flex', alignItems: 'center', gap: 16, background: 'var(--color-surface)',
                        border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '16px 20px',
                      }}>
                        <div style={{ fontSize: 32, flexShrink: 0 }} aria-hidden="true">📄</div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <p style={{ fontWeight: 600, fontSize: 14, color: 'var(--color-primary)' }}>
                            Renewal Confirmation — {r.dmv_vehicleyear} {r.dmv_vehiclemake} {r.dmv_vehiclemodel}
                          </p>
                          <p style={{ fontSize: 12, color: 'var(--color-text-muted)', marginTop: 2 }}>
                            Plate: <span className="mono">{r.dmv_platenumber}</span>
                            {' · '}Confirmation: <span className="mono">{r.dmv_confirmationnumber || r.dmv_renewalid}</span>
                            {' · '}Approved: {approved}
                            {' · '}New registration expires: {expires}
                          </p>
                        </div>
                        <span style={{ display: 'inline-block', padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 700, background: '#d4edda', color: '#155724', textTransform: 'uppercase', letterSpacing: 0.3, flexShrink: 0 }}>
                          Approved
                        </span>
                        <button
                          className="btn btn-primary"
                          style={{ fontSize: 13, padding: '8px 16px', flexShrink: 0 }}
                          disabled={downloadingId === rid}
                          onClick={async () => {
                            setDownloadingId(rid)
                            try { await downloadTempRegTag(r) } finally { setDownloadingId(null) }
                          }}
                        >
                          {downloadingId === rid ? 'Generating...' : '⬇ Download PDF'}
                        </button>
                      </div>
                    )
                  })}
                </div>
              )}
            </section>
          )}

          {/* Previously Submitted Documents */}
          {isAuthenticated && (
            <section style={{ marginTop: '48px' }}>
              <h2 style={sectionH}>Previously Submitted Documents</h2>
              {loadingDocs ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>Loading documents...</p>
              ) : existingDocs.length === 0 ? (
                <p style={{ color: 'var(--color-text-muted)', fontSize: '14px' }}>No documents on file.</p>
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', background: 'var(--color-surface)', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
                    <thead>
                      <tr>
                        <th style={th}>Document Name</th>
                        <th style={th}>Type</th>
                        <th style={th}>Uploaded</th>
                        <th style={th}>Size</th>
                        <th style={th}>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {existingDocs.map(d => {
                        const st = fmt(d, 'dmv_verificationstatus') || 'Pending Review'
                        const sc = statusColor(st)
                        return (
                          <tr key={d.dmv_documentuploadid}>
                            <td style={td}>{d.dmv_documentname}</td>
                            <td style={td}>{fmt(d, 'dmv_documenttype')}</td>
                            <td style={td}>{fmt(d, 'dmv_uploaddate')}</td>
                            <td style={td}>{d.dmv_filesize ? d.dmv_filesize + ' KB' : '—'}</td>
                            <td style={td}>
                              <span style={{ display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600, background: sc.bg, color: sc.color }}>{st}</span>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}
        </div>
      </div>
    </>
  )
}

const infoBox: React.CSSProperties = {
  background: 'var(--color-info-bg)',
  border: '1px solid var(--color-border)',
  borderLeft: '4px solid var(--color-secondary)',
  borderRadius: 'var(--radius-md)',
  padding: '16px 20px',
  fontSize: '14px',
  lineHeight: 1.6,
  marginBottom: '32px',
}

const sectionH: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.1rem',
  fontWeight: 600,
  color: 'var(--color-primary)',
  paddingBottom: '12px',
  borderBottom: '1px solid var(--color-border)',
  marginBottom: '16px',
}

const dropZone: React.CSSProperties = {
  border: '2px dashed var(--color-border)',
  borderRadius: 'var(--radius-lg)',
  padding: '40px 24px',
  textAlign: 'center',
  cursor: 'pointer',
  transition: 'border-color 0.15s, background 0.15s',
  background: 'var(--color-surface)',
}

const dropZoneActive: React.CSSProperties = {
  borderColor: 'var(--color-secondary)',
  background: 'var(--color-info-bg)',
}

const fileRow: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: '12px',
  padding: '12px 16px',
  background: 'var(--color-surface)',
  border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-md)',
}

const removeBtn: React.CSSProperties = {
  background: 'transparent',
  border: 'none',
  cursor: 'pointer',
  color: 'var(--color-text-muted)',
  fontSize: '14px',
  padding: '4px 8px',
  borderRadius: 'var(--radius-sm)',
  flexShrink: 0,
}

const th: React.CSSProperties = {
  textAlign: 'left',
  padding: '12px 16px',
  background: 'var(--color-surface-alt, #f8f9fa)',
  fontWeight: 600,
  fontSize: '13px',
  color: 'var(--color-primary)',
  borderBottom: '2px solid var(--color-border)',
}

const td: React.CSSProperties = {
  padding: '10px 16px',
  borderBottom: '1px solid var(--color-border)',
  fontSize: '14px',
}

/* ════════════════════════════════════════════════════════════
   PDF Generator — Temporary License (from approved renewal)
   ════════════════════════════════════════════════════════════ */
async function downloadTempLicenseFromRenewal(r: Record<string, any>, userId: string) {
  const { jsPDF } = await import('jspdf')
  const firstName = r.dmv_firstname || ''
  const lastName = r.dmv_lastname || ''
  const licenseNum = (r.dmv_licensenumber || '').toUpperCase()
  const refNumber = r.dmv_renewalid || ''
  const dob = r.dmv_dateofbirth
    ? new Date(r.dmv_dateofbirth).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    : ''
  const address1 = r.dmv_streetaddress || ''
  const cityStateZip = `${r.dmv_city || ''}, ${r.dmv_state || ''} ${r.dmv_zipcode || ''}`
  const approvedDate = r.dmv_approveddate
    ? new Date(r.dmv_approveddate) : new Date()
  const expiry = new Date(approvedDate)
  expiry.setDate(expiry.getDate() + 90)
  const expiryStr = expiry.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
  const issuedStr = approvedDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })

  // Try to fetch entity image
  let photoDataUrl: string | null = null
  if (userId) {
    try {
      const resp = await fetch(`/_api/contacts(${userId})?$select=entityimage`)
      if (resp.ok) { const d = await resp.json(); if (d.entityimage) photoDataUrl = 'data:image/jpeg;base64,' + d.entityimage }
    } catch {}
    if (!photoDataUrl) {
      try {
        const resp = await fetch(`/_api/contacts(${userId})/entityimage/$value`)
        if (resp.ok && resp.headers.get('content-type')?.startsWith('image')) {
          const blob = await resp.blob()
          photoDataUrl = await new Promise<string>(res => { const rd = new FileReader(); rd.onloadend = () => res(rd.result as string); rd.readAsDataURL(blob) })
        }
      } catch {}
    }
  }

  const W = 760, H = 546
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: [W, H] })

  // Background
  doc.setFillColor(245, 243, 239); doc.rect(0, 0, W, H, 'F')
  // Watermark
  doc.setFontSize(80); doc.setFont('helvetica', 'bold'); doc.setTextColor(235, 233, 229)
  doc.text('TEMPORARY', W / 2, H / 2, { align: 'center', angle: 25 })
  // Header
  const headerH = 68
  doc.setFillColor(200, 168, 75); doc.rect(0, 0, 8, headerH, 'F')
  doc.setFillColor(15, 39, 68); doc.rect(8, 0, W - 8, headerH, 'F')
  doc.setFontSize(9); doc.setFont('helvetica', 'bold'); doc.setTextColor(200, 168, 75)
  doc.text('CONTOSO COUNTY \u2014 DEPARTMENT OF MOTOR VEHICLES', 40, 28)
  doc.setFontSize(26); doc.setTextColor(255, 255, 255)
  doc.text('TEMPORARY DRIVER LICENSE', 40, 52)
  // Badge
  const bx = 620, by = 14, bw = 106, bh = 40
  doc.setFillColor(30, 50, 75); doc.setDrawColor(200, 168, 75); doc.roundedRect(bx, by, bw, bh, 4, 4, 'FD')
  doc.setFontSize(8); doc.setTextColor(200, 168, 75); doc.setFont('helvetica', 'normal')
  doc.text('VALID FOR', bx + bw / 2, by + 15, { align: 'center' })
  doc.setFontSize(20); doc.setFont('helvetica', 'bold'); doc.setTextColor(255, 255, 255)
  doc.text('90 DAYS', bx + bw / 2, by + 34, { align: 'center' })
  // Status strip
  const stripY = headerH, stripH = 20
  doc.setFillColor(200, 168, 75); doc.rect(0, stripY, W, stripH, 'F')
  doc.setFillColor(15, 39, 68); doc.circle(40, stripY + stripH / 2, 3, 'F')
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(15, 39, 68)
  doc.text('OFFICIAL DOCUMENT \u2014 CARRY WITH VALID PHOTO ID', 50, stripY + 13)

  // Body fields
  const bodyY = stripY + stripH + 32, fieldX = 40, valueX = 188, rightX = 528
  const fields = [
    { label: 'FULL NAME', value: `${firstName} ${lastName}`, large: true },
    { label: 'LICENSE NO.', value: licenseNum, mono: true },
    { label: 'DATE OF BIRTH', value: dob },
    { label: 'ADDRESS', value: `${address1}\n${cityStateZip}` },
    { label: 'VALID THROUGH', value: expiryStr },
    { label: 'ISSUED', value: issuedStr },
    { label: 'TRANSACTION', value: refNumber, mono: true },
  ]
  let fy = bodyY; const rowH = 38
  for (const f of fields) {
    if (fy > bodyY) { doc.setDrawColor(230, 228, 222); doc.setLineWidth(0.4); doc.line(fieldX, fy, rightX - 16, fy) }
    doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(138, 138, 130); doc.text(f.label, fieldX, fy + 18)
    if (f.large) { doc.setFontSize(16); doc.setFont('helvetica', 'bold') }
    else if (f.mono) { doc.setFontSize(12); doc.setFont('courier', 'bold') }
    else { doc.setFontSize(13); doc.setFont('helvetica', 'normal') }
    doc.setTextColor(26, 26, 24)
    if (f.value.includes('\n')) { const lines = f.value.split('\n'); doc.text(lines[0], valueX, fy + 17); doc.text(lines[1], valueX, fy + 30); fy += rowH + 14 }
    else { doc.text(f.value, valueX, fy + 18); fy += rowH }
  }

  // Photo
  const photoX = rightX, photoY = bodyY - 4, photoW = 192, photoH = 192
  if (photoDataUrl) {
    try {
      const cropped = await cropSquare(photoDataUrl)
      doc.addImage(cropped, 'JPEG', photoX, photoY, photoW, photoH)
      doc.setDrawColor(200, 200, 195); doc.setLineWidth(1); doc.roundedRect(photoX, photoY, photoW, photoH, 8, 8, 'S')
    } catch { drawPlaceholder(doc, photoX, photoY, photoW, photoH) }
  } else { drawPlaceholder(doc, photoX, photoY, photoW, photoH) }

  // Restrictions
  const rY = photoY + photoH + 14
  doc.setFillColor(255, 248, 232); doc.setDrawColor(232, 216, 154); doc.roundedRect(photoX, rY, photoW, 50, 6, 6, 'FD')
  doc.setFontSize(7); doc.setFont('helvetica', 'bold'); doc.setTextColor(160, 124, 32)
  doc.text('CLASS & RESTRICTIONS', photoX + 10, rY + 16)
  doc.setFontSize(9); doc.setFont('helvetica', 'normal'); doc.setTextColor(90, 74, 26)
  doc.text('Class C \u2014 Standard', photoX + 10, rY + 30); doc.text('No restrictions', photoX + 10, rY + 42)

  // Footer
  const footerY = H - 56
  doc.setDrawColor(220, 218, 212); doc.setLineWidth(0.5); doc.line(40, footerY, W - 40, footerY)
  doc.setFontSize(8.5); doc.setFont('helvetica', 'normal'); doc.setTextColor(138, 138, 130)
  doc.text('This document serves as a valid temporary license for 90 days from the date of issue.', 40, footerY + 18)
  doc.text('Must be carried alongside a valid government-issued photo ID.', 40, footerY + 32)
  // Barcode
  const bcX = W - 140, bcY = footerY + 8
  const bars = [2,1,3,1,2,1,1,2,3,1,2,1,1,3,2,1,1,2,3,1], barHt = [24,19,24,14,24,22,24,17,24,19,24,12,24,22,24,16,24,19,24,24]
  let bcOff = bcX; doc.setFillColor(26, 26, 24)
  for (let i = 0; i < bars.length; i++) { doc.rect(bcOff, bcY + (24 - barHt[i]), bars[i], barHt[i], 'F'); bcOff += bars[i] + 2 }
  doc.setFontSize(7); doc.setFont('courier', 'normal'); doc.setTextColor(138, 138, 130)
  doc.text(`${licenseNum} \u00b7 ${refNumber}`, bcX, bcY + 38)

  doc.save(`Temp-License-${licenseNum}-${refNumber}.pdf`)
}

function cropSquare(dataUrl: string): Promise<string> {
  return new Promise(res => {
    const img = new Image()
    img.onload = () => {
      const s = Math.min(img.width, img.height), sx = (img.width - s) / 2, sy = (img.height - s) / 2
      const c = document.createElement('canvas'); c.width = s; c.height = s
      c.getContext('2d')!.drawImage(img, sx, sy, s, s, 0, 0, s, s)
      res(c.toDataURL('image/jpeg', 0.92))
    }
    img.onerror = () => res(dataUrl)
    img.src = dataUrl
  })
}

function drawPlaceholder(doc: any, x: number, y: number, w: number, h: number) {
  doc.setFillColor(226, 224, 218); doc.setDrawColor(184, 181, 174); doc.setLineWidth(1)
  doc.roundedRect(x, y, w, h, 8, 8, 'FD')
  const cx = x + w / 2, cy = y + h / 2 - 10
  doc.setDrawColor(160, 158, 150); doc.setLineWidth(1.5); doc.circle(cx, cy - 12, 14, 'S')
  doc.line(cx - 24, cy + 20, cx - 12, cy + 10); doc.line(cx + 12, cy + 10, cx + 24, cy + 20)
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(138, 138, 130)
  doc.text('PHOTO ID', cx, cy + 40, { align: 'center' })
}

/* ════════════════════════════════════════════════════════════
   PDF Generator — Registration Renewal Confirmation
   Digital proof of renewal. The physical sticker is mailed to the
   customer; this document confirms the renewal was processed and
   shows the new registration period.
   ════════════════════════════════════════════════════════════ */
async function downloadTempRegTag(r: Record<string, any>) {
  const { jsPDF } = await import('jspdf')
  const plate = (r.dmv_platenumber || '').toUpperCase()
  const vin = (r.dmv_vin || '').toUpperCase()
  const vehicle = `${r.dmv_vehicleyear || ''} ${r.dmv_vehiclemake || ''} ${r.dmv_vehiclemodel || ''}`.trim()
  const owner = `${r.dmv_firstname || ''} ${r.dmv_lastname || ''}`.trim()
  const ref = r.dmv_confirmationnumber || r.dmv_renewalid || ''
  const txnRef = r.dmv_renewalid || ''
  const approvedDate = r.dmv_approveddate ? new Date(r.dmv_approveddate) : new Date()
  // New registration expiration. Parse as local calendar date to prevent
  // UTC-midnight → previous-day shift.
  const expiry = parseDvDate(r.dmv_newexpirationdate)
    ?? (() => { const d = new Date(approvedDate); d.setFullYear(d.getFullYear() + 1); return d })()
  const issuedStr = approvedDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
  const expiryStr = expiry.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })

  // Landscape layout matching the HTML template's 680px-wide card proportions
  const W = 760, H = 546
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: [W, H] })

  // ── Palette (from HTML template) ──
  const green: [number, number, number] = [26, 61, 43]      // #1a3d2b
  const gold: [number, number, number] = [232, 200, 75]     // #e8c84b
  const cream: [number, number, number] = [247, 249, 246]   // #f7f9f6
  const bg: [number, number, number] = [221, 227, 224]      // #dde3e0 page bg
  const textDark: [number, number, number] = [26, 26, 24]   // #1a1a18
  const textMuted: [number, number, number] = [122, 138, 125] // #7a8a7d
  const divider: [number, number, number] = [230, 230, 225]

  // ── Page background ──
  doc.setFillColor(...bg); doc.rect(0, 0, W, H, 'F')

  // ── Card ──
  const cardX = 40, cardY = 30, cardW = W - 80, cardH = H - 60
  doc.setFillColor(...cream)
  doc.roundedRect(cardX, cardY, cardW, cardH, 12, 12, 'F')

  // ── Watermark "RENEWED" (diagonal, very faint) ──
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(100)
  doc.setTextColor(0, 0, 0)
  doc.saveGraphicsState()
  // jsPDF doesn't expose alpha easily without GState; use very light gray instead
  doc.setTextColor(235, 235, 230)
  doc.text('RENEWED', W / 2, H / 2 + 20, { align: 'center', angle: 25 })
  doc.restoreGraphicsState()

  // ── Header bar (green with gold accent strip on left) ──
  const hY = cardY, hH = 68
  // Gold accent (8px wide left strip inside card)
  doc.setFillColor(...gold)
  doc.rect(cardX, hY, 8, hH, 'F')
  // Green header
  doc.setFillColor(...green)
  doc.rect(cardX + 8, hY, cardW - 8, hH, 'F')
  // Round the top corners by drawing corner fills over bg
  doc.setFillColor(...bg)
  // top-left rounded corner cover
  doc.triangle(cardX, cardY, cardX, cardY + 12, cardX + 12, cardY, 'F')
  doc.triangle(cardX + cardW, cardY, cardX + cardW, cardY + 12, cardX + cardW - 12, cardY, 'F')
  // Redraw card rounded top corners
  doc.setFillColor(...gold); doc.circle(cardX + 8, cardY + 12, 0, 'F') // no-op placeholder

  // Header text — left side
  doc.setFontSize(9)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(...gold)
  doc.text('CONTOSO COUNTY \u2014 DEPARTMENT OF MOTOR VEHICLES', cardX + 32, hY + 28)

  doc.setFontSize(22)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(255, 255, 255)
  doc.text('REGISTRATION RENEWAL CONFIRMATION', cardX + 32, hY + 54)

  // Header badge — right side ("RENEWAL APPROVED")
  const bW = 130, bH = 44, bX = cardX + cardW - bW - 24, bY = hY + 12
  doc.setFillColor(40, 75, 55)  // slightly lighter green
  doc.setDrawColor(...gold); doc.setLineWidth(1)
  doc.roundedRect(bX, bY, bW, bH, 5, 5, 'FD')
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(...gold)
  doc.text('RENEWAL', bX + bW / 2, bY + 15, { align: 'center' })
  doc.setFontSize(16); doc.setTextColor(255, 255, 255)
  doc.text('APPROVED', bX + bW / 2, bY + 35, { align: 'center' })

  // ── Gold status strip ──
  const sY = hY + hH, sH = 22
  doc.setFillColor(...gold); doc.rect(cardX, sY, cardW, sH, 'F')
  doc.setFillColor(...green); doc.circle(cardX + 32, sY + sH / 2, 3, 'F')
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(...green)
  doc.text('OFFICIAL PROOF OF RENEWAL — NEW STICKER ARRIVES BY MAIL', cardX + 42, sY + sH / 2 + 3)

  // ── Plate display section (green background with centered plate) ──
  const pY = sY + sH, pH = 96
  doc.setFillColor(...green); doc.rect(cardX, pY, cardW, pH, 'F')
  // License plate
  const plW = 260, plH = 76, plX = cardX + (cardW - plW) / 2, plY = pY + (pH - plH) / 2
  doc.setFillColor(...cream)
  doc.setDrawColor(...gold); doc.setLineWidth(3)
  doc.roundedRect(plX, plY, plW, plH, 6, 6, 'FD')
  // "CONTOSO" top
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(...green)
  doc.text('CONTOSO', plX + plW / 2, plY + 14, { align: 'center' })
  // Plate number (large)
  doc.setFontSize(38); doc.setFont('helvetica', 'bold'); doc.setTextColor(...green)
  doc.text(plate || 'ABC-1234', plX + plW / 2, plY + 50, { align: 'center' })
  // "REGISTERED PLATE" bottom
  doc.setFontSize(7); doc.setFont('helvetica', 'bold'); doc.setTextColor(90, 122, 101)
  doc.text('REGISTERED PLATE', plX + plW / 2, plY + 68, { align: 'center' })

  // ── Body fields (two columns) ──
  const fieldsY = pY + pH + 18
  const col1X = cardX + 32, col2X = cardX + cardW / 2 + 10
  const labelToValue = 14
  const rowH = 46

  const drawField = (x: number, y: number, label: string, value: string, opts?: { mono?: boolean; large?: boolean }) => {
    doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(...textMuted)
    doc.text(label.toUpperCase(), x, y)
    if (opts?.large) {
      doc.setFontSize(15); doc.setFont('helvetica', 'bold')
    } else if (opts?.mono) {
      doc.setFontSize(12); doc.setFont('courier', 'bold')
    } else {
      doc.setFontSize(12); doc.setFont('helvetica', 'normal')
    }
    doc.setTextColor(...textDark)
    doc.text(value || '\u2014', x, y + labelToValue)
    // divider under each field
    doc.setDrawColor(...divider); doc.setLineWidth(0.5)
    doc.line(x, y + labelToValue + 14, x + (cardW / 2) - 56, y + labelToValue + 14)
  }

  // Row 1
  drawField(col1X, fieldsY, 'Registered Owner', owner, { large: true })
  drawField(col2X, fieldsY, 'Confirmation No.', ref, { mono: true })
  // Row 2
  drawField(col1X, fieldsY + rowH, 'Year / Make / Model', vehicle)
  drawField(col2X, fieldsY + rowH, 'VIN', vin, { mono: true })
  // Row 3
  drawField(col1X, fieldsY + rowH * 2, 'Renewal Approved', issuedStr)
  drawField(col2X, fieldsY + rowH * 2, 'New Registration Expires', expiryStr)

  // ── Footer ──
  const fY = cardY + cardH - 58
  doc.setDrawColor(...divider); doc.setLineWidth(0.5)
  doc.line(cardX + 32, fY, cardX + cardW - 32, fY)

  // Footer note (left)
  doc.setFontSize(9); doc.setFont('helvetica', 'normal'); doc.setTextColor(...textMuted)
  doc.text(
    'Your new registration sticker will arrive by mail within 7–10 business days.',
    cardX + 32, fY + 18
  )
  doc.text(
    'Apply it to your rear license plate when it arrives. Keep this confirmation for your records.',
    cardX + 32, fY + 32
  )

  // Barcode (right)
  const bars = [2,1,3,1,2,1,1,2,3,1,2,1,1,3,2,1,1,2,3,1]
  const barHts = [100,80,100,60,100,90,100,70,100,80,100,50,100,90,100,65,100,80,100,100]
  const bcH = 26
  const bcTotalW = bars.reduce((a, b) => a + b + 2, 0)
  const bcX = cardX + cardW - 32 - bcTotalW
  const bcY = fY + 12
  doc.setFillColor(...textDark)
  let off = bcX
  for (let i = 0; i < bars.length; i++) {
    const h = (barHts[i] / 100) * bcH
    doc.rect(off, bcY + (bcH - h), bars[i], h, 'F')
    off += bars[i] + 2
  }
  doc.setFontSize(7); doc.setFont('courier', 'normal'); doc.setTextColor(...textMuted)
  doc.text(`${plate} \u00B7 ${txnRef}`, cardX + cardW - 32, bcY + bcH + 10, { align: 'right' })

  doc.save(`Registration-Renewal-Confirmation-${plate}-${txnRef}.pdf`)
}
