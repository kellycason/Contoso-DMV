import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { dvCreate, dvQuery, fmt } from '../hooks/useDataverse'

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

  useEffect(() => {
    if (isAuthenticated && userId) {
      dvQuery('dmv_documentuploads',
        `$filter=_dmv_contactid_value eq ${userId}&$select=dmv_documentname,dmv_documenttype,dmv_uploaddate,dmv_verificationstatus,dmv_filesize,dmv_filetype&$orderby=dmv_uploaddate desc&$top=50`
      ).then(setExistingDocs).catch(() => {}).finally(() => setLoadingDocs(false))
    } else {
      setLoadingDocs(false)
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
