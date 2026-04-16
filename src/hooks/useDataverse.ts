const API_BASE = '/_api'

/** Get the request verification token required for write operations */
function getVerificationToken(): string {
  const el = document.querySelector<HTMLInputElement>(
    'input[name="__RequestVerificationToken"]'
  )
  return el?.value ?? ''
}

export async function dvQuery(
  entitySet: string,
  query: string
): Promise<Record<string, any>[]> {
  const res = await fetch(`${API_BASE}/${entitySet}?${query}`, {
    headers: {
      'Accept': 'application/json',
      'OData-MaxVersion': '4.0',
      'OData-Version': '4.0',
      'Prefer': 'odata.include-annotations="OData.Community.Display.V1.FormattedValue"'
    },
    credentials: 'same-origin'
  })
  if (!res.ok) {
    throw new Error(`Dataverse API error (${res.status})`)
  }
  const data = await res.json()
  return data.value ?? []
}

/** Create a record via Web API. Returns the created record ID. */
export async function dvCreate(
  entitySet: string,
  data: Record<string, unknown>
): Promise<string> {
  const res = await fetch(`${API_BASE}/${entitySet}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'OData-MaxVersion': '4.0',
      'OData-Version': '4.0',
      '__RequestVerificationToken': getVerificationToken(),
    },
    credentials: 'same-origin',
    body: JSON.stringify(data),
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Create failed (${res.status}): ${err}`)
  }
  const entityId = res.headers.get('OData-EntityId')
  return entityId?.match(/\(([^)]+)\)/)?.[1] ?? ''
}

/** Get the formatted display value of a choice/lookup/date column */
export function fmt(record: Record<string, any>, column: string): string {
  return (
    record[`${column}@OData.Community.Display.V1.FormattedValue`] ??
    String(record[column] ?? '')
  )
}
