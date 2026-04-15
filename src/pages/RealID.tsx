import { useState } from 'react'
import { Link } from 'react-router-dom'

const steps = [
  { id: 1, title: 'Check Eligibility', desc: 'Answer a few questions to see if you meet REAL ID requirements.' },
  { id: 2, title: 'Gather Documents', desc: 'Review and prepare the documents you need to bring.' },
  { id: 3, title: 'Schedule Visit', desc: 'Book your in-person appointment at a DMV office.' },
]

const docCategories = [
  {
    title: 'Proof of Identity',
    icon: '🪪',
    docs: ['Valid U.S. Passport or Passport Card', 'Certified Birth Certificate (U.S.)', 'Permanent Resident Card (Green Card)', 'Employment Authorization Document'],
  },
  {
    title: 'Proof of Social Security',
    icon: '🔢',
    docs: ['Social Security Card', 'W-2 Form or SSA-1099', 'Pay stub with full SSN'],
  },
  {
    title: 'Proof of Residency (2 Required)',
    icon: '🏠',
    docs: ['Utility bill (within 90 days)', 'Bank statement (within 90 days)', 'Mortgage or rental agreement', 'Government-issued mail', 'Vehicle registration or title'],
  },
  {
    title: 'Proof of Name Change (if applicable)',
    icon: '📝',
    docs: ['Certified marriage certificate', 'Court order for name change', 'Divorce decree with name reversion'],
  },
]

const eligibilityQuestions = [
  { id: 'citizen', question: 'Are you a U.S. citizen or lawful permanent resident?', required: true },
  { id: 'ssn', question: 'Do you have a Social Security Number?', required: true },
  { id: 'residency', question: 'Can you provide two proofs of state residency?', required: true },
  { id: 'identity', question: 'Do you have a valid identity document (passport, birth certificate)?', required: true },
]

export default function RealID() {
  const [currentStep, setCurrentStep] = useState(0)
  const [answers, setAnswers] = useState<Record<string, boolean | null>>({})
  const [checklist, setChecklist] = useState<Record<string, boolean>>({})

  const allAnswered = eligibilityQuestions.every(q => answers[q.id] !== undefined && answers[q.id] !== null)
  const allYes = eligibilityQuestions.every(q => answers[q.id] === true)

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>REAL ID Readiness Assistant</h1>
          <p style={styles.heroSub}>
            Starting May 7, 2025, you need a REAL ID-compliant license or another acceptable form of ID to board domestic flights.
            Use this tool to check your eligibility and prepare your documents.
          </p>
          <div style={styles.stepIndicator}>
            {steps.map((s, i) => (
              <div key={s.id} style={{ ...styles.step, ...(currentStep >= i ? styles.stepActive : {}) }}
                onClick={() => { if (i <= currentStep + 1) setCurrentStep(i) }}>
                <div style={{ ...styles.stepCircle, ...(currentStep >= i ? styles.stepCircleActive : {}) }}>{s.id}</div>
                <div>
                  <div style={styles.stepTitle}>{s.title}</div>
                  <div style={styles.stepDesc}>{s.desc}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        {currentStep === 0 && (
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>Step 1: Eligibility Check</h2>
            <p style={{ color: '#666', marginBottom: '24px' }}>Answer the following questions to determine if you're eligible for a REAL ID.</p>
            {eligibilityQuestions.map(q => (
              <div key={q.id} style={styles.questionRow}>
                <span style={{ flex: 1 }}>{q.question}</span>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button onClick={() => setAnswers(p => ({ ...p, [q.id]: true }))}
                    style={{ ...styles.answerBtn, ...(answers[q.id] === true ? styles.answerYes : {}) }}>Yes</button>
                  <button onClick={() => setAnswers(p => ({ ...p, [q.id]: false }))}
                    style={{ ...styles.answerBtn, ...(answers[q.id] === false ? styles.answerNo : {}) }}>No</button>
                </div>
              </div>
            ))}
            {allAnswered && (
              <div style={{ ...styles.resultBanner, background: allYes ? '#d4edda' : '#f8d7da', borderColor: allYes ? '#c3e6cb' : '#f5c6cb' }}>
                {allYes ? (
                  <>
                    <strong style={{ color: '#155724' }}>✅ You appear to be eligible for a REAL ID!</strong>
                    <p style={{ margin: '8px 0 0', color: '#155724' }}>Proceed to Step 2 to review the required documents.</p>
                    <button onClick={() => setCurrentStep(1)} className="btn btn-primary" style={{ marginTop: '12px' }}>Continue to Documents →</button>
                  </>
                ) : (
                  <>
                    <strong style={{ color: '#721c24' }}>❌ You may not be eligible for a REAL ID at this time.</strong>
                    <p style={{ margin: '8px 0 0', color: '#721c24' }}>Please review the requirements or contact your local DMV office for assistance.</p>
                  </>
                )}
              </div>
            )}
          </div>
        )}

        {currentStep === 1 && (
          <div>
            <h2 style={{ marginBottom: '24px' }}>Step 2: Document Checklist</h2>
            <p style={{ color: '#666', marginBottom: '24px' }}>Check off each document as you gather it. You'll need to bring originals to your appointment.</p>
            <div style={styles.docGrid}>
              {docCategories.map(cat => (
                <div key={cat.title} style={styles.card}>
                  <h3 style={styles.cardTitle}>{cat.icon} {cat.title}</h3>
                  {cat.docs.map(doc => (
                    <label key={doc} style={styles.checkItem}>
                      <input type="checkbox" checked={!!checklist[doc]} onChange={() => setChecklist(p => ({ ...p, [doc]: !p[doc] }))} />
                      <span style={checklist[doc] ? { textDecoration: 'line-through', color: '#999' } : {}}>{doc}</span>
                    </label>
                  ))}
                </div>
              ))}
            </div>
            <button onClick={() => setCurrentStep(2)} className="btn btn-primary" style={{ marginTop: '24px' }}>
              Continue to Schedule →
            </button>
          </div>
        )}

        {currentStep === 2 && (
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>Step 3: Schedule Your Visit</h2>
            <p style={{ color: '#666', marginBottom: '24px' }}>
              REAL ID applications require an in-person visit. Book your appointment now to avoid long wait times.
            </p>
            <div style={styles.readyCard}>
              <span style={{ fontSize: '48px' }}>🎉</span>
              <h3 style={{ margin: '16px 0 8px', fontSize: '22px' }}>You're Ready!</h3>
              <p style={{ color: '#666', marginBottom: '24px' }}>
                You've checked your eligibility and prepared your documents.
                Schedule your in-person appointment to complete the REAL ID process.
              </p>
              <Link to="/appointments" className="btn btn-primary" style={{ fontSize: '16px', padding: '14px 32px' }}>
                📅 Schedule REAL ID Appointment
              </Link>
            </div>
          </div>
        )}
      </section>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #1D3557 0%, #264674 100%)', color: '#fff', padding: '48px 0 40px' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 12px' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: '0 0 32px', maxWidth: '700px' },
  stepIndicator: { display: 'flex', gap: '24px', flexWrap: 'wrap' as const },
  step: { display: 'flex', alignItems: 'flex-start', gap: '12px', padding: '12px 16px', borderRadius: '8px', background: 'rgba(255,255,255,0.06)', flex: '1 1 200px', cursor: 'pointer', transition: 'all 0.2s' },
  stepActive: { background: 'rgba(255,255,255,0.15)' },
  stepCircle: { width: '32px', height: '32px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: '14px', background: 'rgba(255,255,255,0.15)', color: 'rgba(255,255,255,0.6)', flexShrink: 0 },
  stepCircleActive: { background: '#E63946', color: '#fff' },
  stepTitle: { fontWeight: 600, fontSize: '14px' },
  stepDesc: { fontSize: '12px', opacity: 0.7, marginTop: '2px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  questionRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 0', borderBottom: '1px solid #f0f0f0', fontSize: '15px', gap: '16px' },
  answerBtn: { padding: '8px 20px', border: '1px solid #ccc', borderRadius: '6px', background: '#fff', cursor: 'pointer', fontWeight: 500, fontSize: '13px', transition: 'all 0.2s' },
  answerYes: { background: '#d4edda', borderColor: '#28a745', color: '#155724' },
  answerNo: { background: '#f8d7da', borderColor: '#dc3545', color: '#721c24' },
  resultBanner: { marginTop: '24px', padding: '20px', borderRadius: '8px', border: '1px solid' },
  docGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px' },
  checkItem: { display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 0', borderBottom: '1px solid #f5f5f5', cursor: 'pointer', fontSize: '14px' },
  readyCard: { textAlign: 'center' as const, padding: '40px 20px' },
}
