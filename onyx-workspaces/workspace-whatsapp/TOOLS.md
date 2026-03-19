# Onyx Estates — WhatsApp Agent API Reference

## Service APIs

Base URL: `https://onyxestates.eu/api/service`
Auth: `Authorization: Bearer SERVICE_API_KEY`

### WhatsApp Send (primary outbound method)

`POST /whatsapp/send`

Send a WhatsApp message via WAHA (Evolution API). Handles rate-limiting and opt-out checks internally.

**Request (text) — USE THIS FOR ALL OUTREACH:**
```json
{
  "phone": "+34612345678",
  "type": "text",
  "message": "Buenas tardes. Hemos visto su villa en Nerja y tenemos un comprador buscando en esa zona. ¿Sigue a la venta?"
}
```

For owner outreach: always use `type: "text"` with a message you compose from the listing data. Do NOT use templates for outreach.

**Request (template) — only for buyer/viewing/system messages:**
```json
{
  "phone": "+34612345678",
  "type": "template",
  "templateName": "buyer_welcome_es",
  "templateParams": [
    { "name": "name", "value": "Maria" }
  ]
}
```

Available templates (buyer/viewing/system only — NOT for outreach):
- `buyer_welcome_es/en` (bienvenida_comprador): `name`
- `buyer_match_es/en`: `name`, `count`, `municipality`, `property_title`, `price`, `bedrooms`
- `viewing_confirm_es/en`: `name`, `date`, `time`, `address`
- `viewing_reminder_es/en`: `name`, `time`, `address`
- `session_reopener/reabrir_conversacion`: `name`
- `owner_heartbeat/actualizacion_propietario`: `name`, `update`
- `report_weekly_es/en`: `name`

**Request (media):**
```json
{
  "phone": "+34612345678",
  "type": "media",
  "mediaUrl": "https://onyxestates.eu/reports/weekly.pdf",
  "caption": "Your weekly report"
}
```

**Success response (200):**
```json
{ "messageId": "wati-msg-123", "status": "queued" }
```

**Error response (4xx/5xx):**
```json
{ "error": "Description", "code": "opted_out | rate_limited | session_expired | provider_error | validation_error" }
```

Error code handling:
- `opted_out` — contact opted out, do NOT retry, write escalation
- `rate_limited` — hourly/daily limit hit, retry later
- `session_expired` — outside 24h window, must use `type: "template"` instead of `text`
- `provider_error` — WATI API failure (already retried 3x internally), write escalation
- `validation_error` — bad request, fix payload

### Sync Inbound from WAHA (MUST call before polling)

`GET /whatsapp/poll-inbound`

**ALWAYS call this first** before checking inbound messages. This syncs new messages from the WAHA WhatsApp server into the database. Without this call, new messages won't appear in the inbound queue.

**Response:**
```json
{ "newMessages": 2, "chatsChecked": 3 }
```

### Inbound Message Polling (check after poll-inbound)

`GET /whatsapp/inbound?claim=true`

Returns unprocessed inbound WhatsApp messages and atomically marks them as claimed. **Always call `poll-inbound` first** to sync new messages from WAHA.

**Response:**
```json
{
  "messages": [
    {
      "id": "uuid",
      "from": "+40752188647",
      "senderName": "Maria Garcia",
      "message": "Hola, me interesa",
      "messageId": "wamid.xxx",
      "contactId": "uuid",
      "language": "es",
      "responseStatus": "replied",
      "receivedAt": "2026-03-16T14:30:00Z"
    }
  ],
  "count": 1
}
```

If `count: 0`, no new messages — check `onyx-outbound` for pending outbound requests.

Optional: `PATCH /whatsapp/inbound` with `{ "ids": ["uuid1", "uuid2"] }` to mark specific messages as processed (if not using `claim=true`).

### Rate Check (for pre-flight checks only)

`POST /whatsapp/rate-check`

The send endpoint calls this internally. Use this only if you need to check rate limits before deciding whether to send.

**Request:**
```json
{ "phone": "+34612345678" }
```

**Response:**
```json
{
  "allowed": true,
  "hourCount": 12,
  "dayCount": 45,
  "reason": null
}
```

If `allowed: false`, follow the rules in SOUL.md Layer 4.

### Property Matching

`POST /properties/match`

Find properties matching buyer criteria.

**Request:**
```json
{
  "budgetMin": 150000,
  "budgetMax": 300000,
  "bedsMin": 2,
  "municipalities": ["Nerja", "Torrox"],
  "listingType": "sale"
}
```

### Leads

`POST /leads`

Create a qualified buyer lead after completing the qualification flow.

**Request:**
```json
{
  "phone": "+447700900000",
  "name": "John Smith",
  "budgetMin": 150000,
  "budgetMax": 250000,
  "bedsMin": 2,
  "preferredMunicipalities": ["Torrox", "Nerja"],
  "timeline": "1-3months",
  "isInSpain": false,
  "preferredViewing": "virtual",
  "leadScore": "hot",
  "language": "en",
  "notes": "Retired couple from UK, looking for winter residence"
}
```

### Contacts

`POST /contacts` — create or update a contact record (upsert by phone)

**Request:**
```json
{ "phone": "+34612345678", "name": "Maria Garcia", "language": "es" }
```

Use this to register a new contact on first interaction if rate-check returns `contactId: null`.

`PATCH /contacts/{contactId}` — update contact (e.g., opt-out)

Use the `contactId` from rate-check response.

**Request:**
```json
{ "optedOut": true }
```

### Viewings

`POST /viewings` — create a viewing request
`GET /viewings` — check viewing status (filter: `?propertyId=X` or `?leadId=X`)
`PATCH /viewings/{id}` — update viewing status

### Conversations (logging)

`POST /conversations`

Log WhatsApp messages to the database.

**Request:**
```json
{
  "contactId": "uuid",
  "direction": "inbound",
  "messageType": "freeform",
  "messageBody": "Customer message text",
  "status": "delivered"
}
```

### Calendar

`POST /calendar` — create a Google Calendar event (for confirmed viewings)
`PATCH /calendar` — update an event
`DELETE /calendar?calendarId=X&eventId=Y` — delete an event

## Hindsight Memory

Base URL: `${HINDSIGHT_BASE_URL}`
API prefix: `/v1/default/banks/{bank_id}`

### API Endpoints

- `POST /v1/default/banks/{bank_id}/memories` — store facts: `{ "items": [{ "content": "fact text", "context": "category" }] }`
- `GET /v1/default/banks/{bank_id}/memories/list` — list all memories in a bank
- `POST /v1/default/banks/{bank_id}/memories/recall` — search memories: `{ "query": "search text" }`

### Customer Memory (isolated per customer)

Bank: `onyx-customer-{sha256_of_phone_e164}`

Store: `POST /v1/default/banks/onyx-customer-abc123/memories` with `{ "items": [{ "content": "Prefers sea views, budget 200-300k" }] }`
Search: `POST /v1/default/banks/onyx-customer-abc123/memories/recall` with `{ "query": "budget preferences" }`

### Shared Namespaces

**onyx-outbound** — pending outbound message requests from operations agent
- Poll on each invocation for `status: "pending"` entries
- After processing via `POST /whatsapp/send`, update status to `claimed` then `sent` (or `failed`/`opted_out`)

**onyx-escalations** (WRITE only) — escalation messages for operations agent
- Write when: API errors, rate limits hit, opt-outs, suspicious input, complex questions
- Format: `{ "phone": "+34...", "type": "api_error|rate_limit|opt_out|suspicious_input|negotiation|abuse|complex_question", "summary": "Brief description" }`

## Website

Public URL: https://onyxestates.eu
Property pages: https://onyxestates.eu/property/{slug}
