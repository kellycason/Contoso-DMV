import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvQuery } from '../hooks/useDataverse'
import knowledgeSeed from '../../dataverse/knowledge_seed.json'

/* ---------- Types ---------- */

type KArticle = {
  id: string
  slug: string
  type: 'Article' | 'FAQ'
  title: string
  summary: string
  body: string
  category: string
  readMinutes: number
  order: number
}

type RawRow = {
  knowledgearticleid: string
  articlepublicnumber: string | null
  title: string | null
  description: string | null
  content: string | null
}

type SeedMeta = {
  slug: string
  type: 'Article' | 'FAQ'
  category: string
  order: number
  readMinutes: number
}

/** Build-time metadata map: slug -> { type, category, order, readMinutes }.
    Pulled from the seed JSON so display structure travels with the app
    and the `keywords` column in Dataverse stays reserved for real
    search terms (used by Copilot Studio grounding). */
const META_BY_SLUG: Record<string, SeedMeta> = (knowledgeSeed as SeedMeta[]).reduce(
  (acc, rec) => {
    acc[rec.slug] = {
      slug: rec.slug,
      type: rec.type,
      category: rec.category,
      order: rec.order,
      readMinutes: rec.readMinutes,
    }
    return acc
  },
  {} as Record<string, SeedMeta>,
)

const SELECT = [
  'knowledgearticleid',
  'articlepublicnumber',
  'title',
  'description',
  'content',
].join(',')

const QUERY = `$select=${SELECT}&$filter=statecode eq 3 and islatestversion eq true&$top=500`

async function loadArticles(): Promise<KArticle[]> {
  const rows = (await dvQuery('knowledgearticles', QUERY)) as RawRow[]
  const mapped: KArticle[] = rows.map(r => {
    const slug = r.articlepublicnumber ?? r.knowledgearticleid
    const meta = META_BY_SLUG[slug]
    return {
      id: r.knowledgearticleid,
      slug,
      type: meta?.type ?? 'Article',
      title: r.title ?? '',
      summary: r.description ?? '',
      body: r.content ?? '',
      category: meta?.category ?? 'General',
      readMinutes: meta?.readMinutes ?? 0,
      order: meta?.order ?? 0,
    }
  })
  // Only show articles whose slug is known to the bundled seed (avoids
  // rendering hand-authored Customer Service articles on the citizen portal).
  const filtered = mapped.filter(a => META_BY_SLUG[a.slug])
  filtered.sort((a, b) => a.order - b.order)
  return filtered
}

/* ---------- HTML body renderer ----------
   Native knowledgearticle.content is already rich HTML, so we render it
   through dangerouslySetInnerHTML. The content is produced by our
   controlled seed script (not user input), so this is a trusted source.
*/

function ArticleBody({ body }: { body: string }) {
  return <div className="ka-body" dangerouslySetInnerHTML={{ __html: body }} />
}

/* ---------- Component ---------- */

export default function FAQ() {
  useEffect(() => { document.title = 'FAQ & Guides — Contoso DMV' }, [])

  const [view, setView] = useState<'guides' | 'faqs'>('guides')
  const [query, setQuery] = useState('')
  const [openKey, setOpenKey] = useState<string | null>(null)
  const [activeSlug, setActiveSlug] = useState<string | null>(null)
  const [all, setAll] = useState<KArticle[]>([])
  const [loading, setLoading] = useState(true)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    loadArticles()
      .then(data => { if (!cancelled) { setAll(data); setErr(null) } })
      .catch(e => { if (!cancelled) setErr(e?.message ?? 'Failed to load knowledge base') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  const articles = useMemo(() => all.filter(a => a.type === 'Article'), [all])
  const faqRows = useMemo(() => all.filter(a => a.type === 'FAQ'), [all])

  /* FAQs grouped by category, preserving first-seen order */
  const faqGroups = useMemo(() => {
    const order: string[] = []
    const map = new Map<string, KArticle[]>()
    for (const row of faqRows) {
      if (!map.has(row.category)) { map.set(row.category, []); order.push(row.category) }
      map.get(row.category)!.push(row)
    }
    return order.map(cat => ({ category: cat, items: map.get(cat)! }))
  }, [faqRows])

  const q = query.trim().toLowerCase()

  const filteredArticles = useMemo(() => {
    if (!q) return articles
    return articles.filter(
      a => a.title.toLowerCase().includes(q) || a.summary.toLowerCase().includes(q) ||
           a.category.toLowerCase().includes(q) || a.body.toLowerCase().includes(q),
    )
  }, [articles, q])

  const filteredFaqGroups = useMemo(() => {
    if (!q) return faqGroups
    return faqGroups
      .map(g => ({
        ...g,
        items: g.items.filter(it => it.title.toLowerCase().includes(q) || it.body.toLowerCase().includes(q)),
      }))
      .filter(g => g.items.length > 0)
  }, [faqGroups, q])

  const current = activeSlug ? articles.find(a => a.slug === activeSlug) : null

  function toggle(key: string) {
    setOpenKey(prev => (prev === key ? null : key))
  }

  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">FAQ &amp; Guides</span>
          </nav>
          <h1>Help Center</h1>
          <p>Step-by-step guides and answers to frequently asked questions about Contoso DMV services.</p>
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: '920px' }}>
          <div style={tabBar} role="tablist" aria-label="Help topics">
            <button
              role="tab"
              aria-selected={view === 'guides'}
              onClick={() => { setView('guides'); setActiveSlug(null) }}
              style={{ ...tabBtn, ...(view === 'guides' ? tabActive : {}) }}
            >
              📘 Process Guides
            </button>
            <button
              role="tab"
              aria-selected={view === 'faqs'}
              onClick={() => { setView('faqs'); setActiveSlug(null) }}
              style={{ ...tabBtn, ...(view === 'faqs' ? tabActive : {}) }}
            >
              ❓ Frequently Asked Questions
            </button>
          </div>

          {!current && (
            <div style={{ margin: '16px 0 24px' }}>
              <input
                type="search"
                value={query}
                onChange={e => setQuery(e.target.value)}
                placeholder={view === 'guides' ? 'Search guides…' : 'Search questions and answers…'}
                aria-label="Search help center"
                style={searchBox}
              />
            </div>
          )}

          {loading && <p style={{ color: 'var(--color-text-muted)' }}>Loading knowledge base…</p>}
          {err && <p style={{ color: 'var(--color-error, #b00)' }}>Could not load articles: {err}</p>}

          {!loading && !err && view === 'guides' && current && (
            <article style={articleBody}>
              <button
                type="button"
                onClick={() => setActiveSlug(null)}
                style={backBtn}
                aria-label="Back to all guides"
              >
                ← All guides
              </button>
              <span style={catPill}>{current.category}</span>
              <h2 style={articleTitle}>{current.title}</h2>
              <p style={articleMeta}>{current.readMinutes} min read</p>
              {current.summary && <p style={articleSummary}>{current.summary}</p>}
              <ArticleBody body={current.body} />
            </article>
          )}

          {!loading && !err && view === 'guides' && !current && (
            <div style={guideGrid}>
              {filteredArticles.length === 0 && (
                <p style={{ color: 'var(--color-text-muted)' }}>No guides match your search.</p>
              )}
              {filteredArticles.map(a => (
                <button
                  key={a.id}
                  type="button"
                  style={guideCard}
                  onClick={() => setActiveSlug(a.slug)}
                  aria-label={`Read guide: ${a.title}`}
                >
                  <span style={catPill}>{a.category}</span>
                  <h3 style={guideCardTitle}>{a.title}</h3>
                  <p style={guideCardSummary}>{a.summary}</p>
                  <span style={guideCardLink}>Read guide →<span style={{ opacity: 0.6, marginLeft: 8 }}>{a.readMinutes} min</span></span>
                </button>
              ))}
            </div>
          )}

          {!loading && !err && view === 'faqs' && (
            <>
              {filteredFaqGroups.length === 0 && (
                <p style={{ color: 'var(--color-text-muted)' }}>No questions match your search.</p>
              )}
              {filteredFaqGroups.map(section => (
                <section key={section.category} style={faqSection} aria-labelledby={`faq-cat-${section.category}`}>
                  <h2 id={`faq-cat-${section.category}`} style={catHeading}>{section.category}</h2>
                  <dl>
                    {section.items.map((item) => {
                      const key = item.id
                      const isOpen = openKey === key
                      return (
                        <div key={key} style={faqItem}>
                          <dt>
                            <button
                              type="button"
                              aria-expanded={isOpen}
                              aria-controls={`faq-answer-${key}`}
                              id={`faq-question-${key}`}
                              onClick={() => toggle(key)}
                              style={questionBtn}
                            >
                              <span style={{ flex: 1, textAlign: 'left' }}>{item.title}</span>
                              <span style={{ ...chevron, ...(isOpen ? chevronOpen : {}) }} aria-hidden="true">›</span>
                            </button>
                          </dt>
                          <dd
                            id={`faq-answer-${key}`}
                            role="region"
                            aria-labelledby={`faq-question-${key}`}
                            hidden={!isOpen}
                            style={answerStyle}
                            dangerouslySetInnerHTML={{ __html: item.body }}
                          />
                        </div>
                      )
                    })}
                  </dl>
                </section>
              ))}
            </>
          )}

          <div style={contactBox}>
            <h2 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.2rem', marginBottom: '8px' }}>
              Can't find what you're looking for?
            </h2>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: '16px', fontSize: '15px' }}>
              Our customer service team is available Monday through Friday, 8:00 AM to 5:00 PM.
            </p>
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              <a href="tel:+15551234567" className="btn btn-primary">📞 Call 1-555-123-4567</a>
              <a href="mailto:info@contosodmv.example" className="btn btn-outline">✉ Email Us</a>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

/* ---------- Styles ---------- */

const tabBar: React.CSSProperties = {
  display: 'flex',
  gap: '8px',
  borderBottom: '1px solid var(--color-border)',
}

const tabBtn: React.CSSProperties = {
  padding: '12px 18px',
  background: 'none',
  border: 'none',
  borderBottom: '3px solid transparent',
  cursor: 'pointer',
  fontFamily: 'var(--font-body)',
  fontSize: '15px',
  fontWeight: 500,
  color: 'var(--color-text-muted)',
  marginBottom: '-1px',
}

const tabActive: React.CSSProperties = {
  color: 'var(--color-primary)',
  borderBottom: '3px solid var(--color-primary)',
  fontWeight: 600,
}

const searchBox: React.CSSProperties = {
  width: '100%',
  padding: '12px 16px',
  fontFamily: 'var(--font-body)',
  fontSize: '15px',
  border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-md)',
  background: 'var(--color-surface)',
  color: 'var(--color-text)',
  boxSizing: 'border-box',
}

const guideGrid: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
  gap: '16px',
}

const guideCard: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: '10px',
  textAlign: 'left',
  padding: '20px',
  background: 'var(--color-surface)',
  border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-lg)',
  cursor: 'pointer',
  fontFamily: 'var(--font-body)',
}

const guideCardTitle: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.05rem',
  fontWeight: 600,
  color: 'var(--color-primary)',
  margin: 0,
  lineHeight: 1.3,
}

const guideCardSummary: React.CSSProperties = {
  fontSize: '14px',
  color: 'var(--color-text-muted)',
  lineHeight: 1.55,
  margin: 0,
}

const guideCardLink: React.CSSProperties = {
  marginTop: 'auto',
  fontSize: '14px',
  fontWeight: 600,
  color: 'var(--color-primary)',
}

const catPill: React.CSSProperties = {
  alignSelf: 'flex-start',
  display: 'inline-block',
  background: 'var(--color-surface-alt)',
  color: 'var(--color-text-muted)',
  fontSize: '11px',
  fontWeight: 600,
  letterSpacing: '0.04em',
  textTransform: 'uppercase',
  padding: '4px 10px',
  borderRadius: '999px',
}

const articleBody: React.CSSProperties = {
  padding: '8px 0',
}

const backBtn: React.CSSProperties = {
  background: 'none',
  border: 'none',
  color: 'var(--color-primary)',
  fontWeight: 600,
  fontSize: '14px',
  cursor: 'pointer',
  padding: 0,
  marginBottom: '18px',
}

const articleTitle: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.75rem',
  fontWeight: 700,
  color: 'var(--color-primary)',
  margin: '12px 0 6px',
  lineHeight: 1.2,
}

const articleMeta: React.CSSProperties = {
  fontSize: '13px',
  color: 'var(--color-text-muted)',
  margin: '0 0 14px',
}

const articleSummary: React.CSSProperties = {
  fontSize: '16px',
  color: 'var(--color-text)',
  lineHeight: 1.55,
  margin: '0 0 8px',
}

const articleHeading: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.1rem',
  fontWeight: 600,
  color: 'var(--color-primary)',
  margin: '24px 0 6px',
}

const articleText: React.CSSProperties = {
  fontSize: '15px',
  lineHeight: 1.7,
  color: 'var(--color-text)',
  margin: '0 0 12px',
}

const articleList: React.CSSProperties = {
  margin: '6px 0 12px 20px',
  padding: 0,
}

const articleListItem: React.CSSProperties = {
  fontSize: '15px',
  lineHeight: 1.7,
  color: 'var(--color-text)',
  marginBottom: '4px',
}

const faqSection: React.CSSProperties = { marginBottom: '40px' }

const catHeading: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontWeight: 600,
  fontSize: '1.25rem',
  color: 'var(--color-primary)',
  paddingBottom: '12px',
  borderBottom: '2px solid var(--color-primary)',
  marginBottom: '4px',
}

const faqItem: React.CSSProperties = {
  borderBottom: '1px solid var(--color-border)',
}

const questionBtn: React.CSSProperties = {
  width: '100%',
  display: 'flex',
  alignItems: 'center',
  gap: '12px',
  padding: '16px 0',
  background: 'none',
  border: 'none',
  cursor: 'pointer',
  fontFamily: 'var(--font-body)',
  fontSize: '15px',
  fontWeight: 500,
  color: 'var(--color-text)',
  textAlign: 'left',
}

const chevron: React.CSSProperties = {
  display: 'inline-block',
  fontSize: '20px',
  color: 'var(--color-text-muted)',
  transition: 'transform 0.2s ease',
  transform: 'rotate(0deg)',
  flexShrink: 0,
}

const chevronOpen: React.CSSProperties = { transform: 'rotate(90deg)' }

const answerStyle: React.CSSProperties = {
  padding: '0 0 20px 0',
  fontSize: '14px',
  lineHeight: 1.7,
  color: 'var(--color-text-muted)',
}

const contactBox: React.CSSProperties = {
  background: 'var(--color-surface-alt)',
  border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-lg)',
  padding: '32px',
  marginTop: '48px',
}