# Onyx Estates — API & System Access

## Service APIs

Base URL: `https://onyxestates.eu/api/service`
Auth: `Authorization: Bearer SERVICE_API_KEY` (set in environment)

### Properties
- `POST /properties/upsert` — bulk upsert scraped properties (max 200)
- `POST /properties/match` — find properties matching buyer criteria (budgetMin/Max, bedsMin, municipalities, operation)
- `POST /properties/dedup` — run cross-portal deduplication (supports dryRun mode)
- `GET /properties/stats` — summary stats: total, active, published, byMunicipality, byOperation, byOwnerType
- `GET /properties/list` — paginated property listing with filters (municipality, operation, rentalType, isActive, isPublished)
- `GET /properties/price-drops` — detect recent price drops with matching buyers

### Outreach
- `POST /outreach/claim` — claim batch of queued outreach items (default 10, max 50). Returns items with property details + rate limit status.
- `POST /outreach/{id}/complete` — mark outreach as sent
- `POST /outreach/{id}/reply` — log owner reply (body: messageBody, whatsappMessageId, positive)
- `POST /outreach/{id}/follow-up` — send follow-up (3+ days after last attempt)
- `POST /outreach/{id}/cold` — mark as cold (30-day cooldown)
- `GET /outreach/lookup?phone=X` — look up outreach history by owner phone number

### Contacts
- `POST /contacts` — create or upsert contact (phone required, source, language)
- `GET /contacts/lookup?phone=X` — look up contact by phone number (returns id, phone, name, language, optedOut, responseStatus, source, notes)

### Conversations
- `POST /conversations` — log a WhatsApp message (contactId, direction, messageType, messageBody, whatsappMessageId, status)
- `GET /conversations/list?contactId=X&limit=N` — fetch conversation history for a contact (ordered by sentAt desc, default limit 20, max 50)

### Leads
- `POST /leads` — create a qualified buyer lead (buyerPhone, budgetMin/Max, bedsMin, preferredMunicipalities, timeline, leadScore, etc.)
- `GET /leads/lookup?phone=X` — look up lead by buyer phone (returns qualification state, score, preferences)

### Viewings
- `POST /viewings` — create a viewing request (leadId, propertyId, type, scheduledAt)
- `GET /viewings` — list viewings (filters: ?status=X, ?needsReminder=true, ?needsFollowUp=true)
- `PATCH /viewings/{id}` — update viewing status, scheduledAt, calendarEventId, reminderSent, followUpSent

### WhatsApp (via WAHA)

**IMPORTANT: Two-step inbound flow:**
1. First call `GET /whatsapp/poll-inbound` to sync new messages FROM WAHA into the database
2. Then call `GET /whatsapp/inbound?claim=true` to fetch and claim unprocessed messages for handling

Endpoints:
- `POST /whatsapp/send` — send WhatsApp message via WAHA
  - Text: `{ "phone": "+34...", "type": "text", "message": "Hello" }`
  - Template: `{ "phone": "+34...", "type": "template", "templateName": "owner_intro_es", "templateParams": [{"name": "1", "value": "Cleo"}, {"name": "2", "value": "Nerja"}, {"name": "3", "value": "su apartamento"}] }`
  - Media: `{ "phone": "+34...", "type": "media", "mediaUrl": "https://...", "caption": "..." }`
  - Returns: `{ "messageId": "...", "status": "queued" }`
  - Error codes: `opted_out` (never retry), `rate_limited` (retry later), `session_expired` (use template instead), `provider_error` (WAHA issue)
- `GET /whatsapp/poll-inbound` — **MUST call first** to sync new messages from WAHA into the database. Returns `{ newMessages: N, chatsChecked: N }`
- `GET /whatsapp/inbound?claim=true&limit=10` — fetch unprocessed inbound messages (claim=true atomically marks them as processed). Returns messages with contactId, language, responseStatus
- `PATCH /whatsapp/inbound` — manually mark messages as processed. Body: `{ ids: ["..."] }`
- `POST /whatsapp/rate-check` — check if a phone is rate-limited before sending

### Scraping
- `GET /scraping/listings` — query scraped listings with filters (status, ownerType, municipality, scrapedAfter)
- `POST /scraping/ingest` — ingest scraped listings into DB (max 200, handles dedup and owner classification)
- `POST /scraping/expire` — mark listings older than 30 days as stale
- `GET /scraping/stats` — summary stats: total, by status, by ownerType, by municipality, scraped today
- `DELETE /scraping/cleanup` — delete scraped listings. Query params:
  - `source=idealista` — only delete from this source
  - `status=stale` — only delete with this status
  - `before=2026-03-01T00:00:00Z` — only delete scraped before this date
  - `all=true` — delete ALL scraped listings (required if no filter set)
  - Returns: `{ deleted: N }`

### Marketing
- `POST /marketing` — create social post draft (propertyId, platforms, captionVariant)
- `PATCH /marketing/{id}` — update post status (approved/rejected/published), engagement
- `POST /marketing/{id}/publish` — publish approved post to social channels (Ayrshare)
- `GET /marketing/published` — list published posts
- `GET /marketing/stats/weekly` — weekly stats: reach, engagement, top post, best platform, hashtags, A/B test results

### Pipelines
- `POST /pipelines` — start pipeline execution log
- `PATCH /pipelines` — complete pipeline (status, stats, error)

### Calendar
- `POST /calendar` — create Google Calendar event (title, startTime, durationMinutes, location, attendeeEmails)
- `PATCH /calendar` — update event (eventId, title, startTime, etc.)
- `DELETE /calendar?calendarId=X&eventId=Y` — delete event

### Reports
- `POST /reports/cron` — generate and deliver owner reports (email + WhatsApp)
- `GET /reports/heartbeat` — heartbeat stats for exclusive owners (matchedBuyers, viewings, social posts)

### Inquiries
- `POST /inquiries/expire` — mark rental inquiries older than 72h as expired

## Website

- Public site: https://onyxestates.eu
- Property detail pages: https://onyxestates.eu/property/{slug}
- Buy listings: https://onyxestates.eu/buy
- Rent listings: https://onyxestates.eu/rent
- Location pages: https://onyxestates.eu/buy/{municipality}

When sending property links to buyers, use the full property page URL with the slug field.

## Hindsight (Persistent Memory)

URL: `http://k0csg8ok48ko4wwow80owsg4-111048903702:8888`
Bank: `onyx-estates`

- `GET /health` — health check
- `POST /memory` — store a memory
- `GET /memory/search?q=...&bank=onyx-estates` — search memories
- `GET /memory?bank=onyx-estates` — list all memories

**Memory banks:**
- `onyx-estates` — global facts, shared business context
- `onyx-customer-{sha256_of_phone_e164}` — per-customer memory (preferences, budget, past interactions)
- `onyx-outbound` — pending outbound message requests
- `onyx-escalations` — escalation history

Use Hindsight to remember context across conversations — owner preferences, buyer details, property notes, past interactions. Always update customer memory after meaningful conversations.

## Telegram Groups

| Group | Chat ID | Purpose |
|-------|---------|---------|
| Onyx - Properties | `-5117239607` | Scraping summaries, owner replies, outreach stats, system alerts, code fix approvals |
| Onyx - Clients | `-5197866484` | New leads, viewing requests, viewing confirmations, buyer escalations |
| Onyx - Marketing | `-5119769440` | Draft posts for approval (Approve/Edit/Reject), published confirmations |

## Sending WhatsApp Messages

```bash
POST https://onyxestates.eu/api/service/whatsapp/send
Authorization: Bearer SERVICE_API_KEY
Content-Type: application/json
```

**Text message (within 24h session window):**
```json
{
  "phone": "+34612345678",
  "type": "text",
  "message": "Thanks for your interest! Cleo will be in touch."
}
```

**Template message (works anytime, no session window needed):**
```json
{
  "phone": "+34612345678",
  "type": "template",
  "templateName": "owner_intro_es",
  "templateParams": [
    {"name": "1", "value": "Cleo"},
    {"name": "2", "value": "su villa"},
    {"name": "3", "value": "Nerja"}
  ]
}
```

**Success:** `{ "messageId": "...", "status": "queued" }`
**Error:** `{ "error": "...", "code": "opted_out|rate_limited|session_expired|provider_error" }`

Handle error codes:
- `session_expired` — use template instead of text (outside 24h window)
- `opted_out` — do NOT retry, contact opted out permanently
- `rate_limited` — retry later
- `provider_error` — WAHA issue, retry once then alert Properties group

## Processing Inbound WhatsApp Messages

**CRITICAL: Always follow this two-step process:**

1. **Sync from WAHA:** `GET /whatsapp/poll-inbound` — fetches new messages from the WAHA WhatsApp gateway into the database
2. **Claim messages:** `GET /whatsapp/inbound?claim=true&limit=10` — fetches unprocessed messages and atomically marks them as claimed

For each claimed message:
1. Look up contact: `GET /contacts/lookup?phone={from}`
2. Get conversation history: `GET /conversations/list?contactId={id}&limit=20`
3. Check outreach history: `GET /outreach/lookup?phone={from}`
4. Check lead status: `GET /leads/lookup?phone={from}`
5. Identify message type: owner reply (has outreach history) / existing buyer (has lead) / new buyer
6. Apply appropriate skill (outreach / qualification / scheduling)
7. Send response: `POST /whatsapp/send`
8. Log response: `POST /conversations`

## Reading Escalations

Poll Hindsight bank `onyx-escalations` for new entries. Process based on type:
- `viewing_request` — post to Telegram "Onyx - Clients" group
- `new_lead` — post to Telegram "Onyx - Clients" group
- `negotiation`, `complex_question` — post to Telegram "Onyx - Clients" group (for Cleo)
- `api_error`, `suspicious_input`, `abuse` — post to Telegram "Onyx - Properties" group (for Alex)
- `rate_limit`, `opt_out` — log only

## Viewing Team Responses

After team approves/declines a viewing in Telegram, send WhatsApp confirmation:
```json
{
  "phone": "+34612345678",
  "type": "template",
  "templateName": "viewing_confirm_es",
  "templateParams": [
    {"name": "1", "value": "Maria"},
    {"name": "2", "value": "Calle Sol 15"},
    {"name": "3", "value": "20 marzo"},
    {"name": "4", "value": "10:30"}
  ]
}
```
