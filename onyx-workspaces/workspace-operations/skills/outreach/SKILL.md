---
name: outreach
description: Send personalized owner outreach via WhatsApp freeform messages through WAHA
---

# Outreach Skill

You send personalized WhatsApp messages to property owners whose listings were scraped from Idealista/Fotocasa. Messages are sent as freeform text via WAHA (not templates — WAHA WEBJS can message any number directly).

## Process

1. **Claim outreach batch:** `POST https://onyxestates.eu/api/service/outreach/claim`
   - Returns up to 10 items with property details + owner phone
   - Each item has: `id`, `phone`, `propertyTitle`, `municipality`, `price`, `bedrooms`, `source`, `language`

2. **For each item**, generate a personalized message and send it:

   a. Detect language from the property listing (title + description)
   b. Craft a natural freeform message (see templates below)
   c. Create or look up the contact: `GET /contacts/lookup?phone={phone}` or `POST /contacts`
   d. Send via WAHA: `POST https://onyxestates.eu/api/service/whatsapp/send`
      ```json
      { "phone": "+34...", "type": "text", "message": "Your personalized message" }
      ```
   e. Mark outreach as sent: `POST /outreach/{id}/complete`
   f. Log the conversation: `POST /conversations`

3. **Report summary** to Telegram Properties group: "Outreach: sent X messages (Y Spanish, Z English)"

## Message Templates (freeform — adapt naturally, don't copy verbatim)

### Initial Outreach — Spanish
```
Hola, buenas tardes. Somos Onyx Estates, una agencia inmobiliaria especializada en la zona de Axarquia. Hemos visto {property_snippet} en {municipality} y nos gustaría saber si sigue disponible. Trabajamos con compradores/inquilinos solventes y preseleccionados. Nuestra agente Cleo gestiona todas las visitas personalmente. ¿Le interesaría que le informemos de nuestros servicios? Sin compromiso.
```

### Initial Outreach — English
```
Hi there. We're Onyx Estates, a real estate agency specializing in the Axarquia region. We noticed {property_snippet} in {municipality} and wondered if it's still available. We work with pre-qualified, solvent buyers and tenants. Our agent Cleo handles all viewings personally. Would you like to hear more about our services? No obligation.
```

### Follow-up (3+ days, no reply) — Spanish
```
Hola de nuevo. Le escribimos hace unos días sobre {property_snippet} en {municipality}. Solo queríamos confirmar si recibió nuestro mensaje. Seguimos con interesados en la zona y estaríamos encantados de ayudarle. Un saludo, Onyx Estates.
```

### Follow-up (3+ days, no reply) — English
```
Hi again. We reached out a few days ago about {property_snippet} in {municipality}. Just wanted to check if you received our message. We still have interested clients in the area and would love to help. Best, Onyx Estates.
```

## Property Description Snippets

Generate `{property_snippet}` — a natural, short description (max 10 words):
- "su apartamento de 2 dormitorios con terraza"
- "your renovated 3-bedroom villa with pool"
- "su ático con vistas al mar"
- "your beachfront townhouse"

Base it on: property type (from title), key features (from description), bedroom count.

## Language Detection

Detect from property title + description:
- Spanish keywords: habitación, dormitorio, salón, cocina, terraza, piscina, playa, vistas, reformado → Spanish
- English text → English
- Unclear → default to Spanish

## Rate Limiting (CRITICAL — violating these WILL get the number banned)

WAHA uses WEBJS (personal WhatsApp, not Business API). WhatsApp monitors sending patterns aggressively. These limits are non-negotiable:

### Per-Run Limits
- **Max 5 NEW contacts per outreach run** (initial messages to people who never messaged us)
- **Max 3 follow-ups per run** (to contacts we already messaged)
- **Total max 8 messages per run**

### Timing Between Messages
- **Minimum 60-90 seconds between each message** (random, never exact same gap)
- **Never send 2 messages within 30 seconds**
- Add a `sleep` or `wait` tool call between sends

### Daily Limits
- **Max 15 new contacts per day** across all runs (3 runs × 5 = 15 max)
- **Max 30 total outbound messages per day** (including replies, follow-ups, everything)
- Track daily count in Hindsight bank `onyx-rate-limits` with key `outbound-{date}`
- Before each send, check the daily count. If at limit, stop and report.

### Weekly Warm-Up (first 2 weeks of a new number)
If the WhatsApp number is less than 2 weeks old:
- **Week 1:** Max 5 new contacts per day, max 10 total messages/day
- **Week 2:** Max 10 new contacts per day, max 20 total messages/day
- **Week 3+:** Normal limits (15 new, 30 total)

### Message Patterns That Trigger Bans
NEVER do these:
- Send identical messages to multiple contacts (always vary wording)
- Send messages with URLs or links in the first message to a new contact
- Send to numbers that don't exist or aren't on WhatsApp
- Send messages during sleeping hours (before 9:00 or after 21:00 local time)
- Send more than 2 messages to a contact with no reply (mark as cold instead)

### What To Do If Rate Limited
If the send endpoint returns `rate_limited`:
1. Stop the entire outreach run immediately
2. Report to Telegram Properties group: "⚠️ Rate limit hit — stopping outreach for today"
3. Do NOT retry for at least 6 hours

### Tracking
Before every outreach run:
1. Read `onyx-rate-limits` → `outbound-{YYYY-MM-DD}` from Hindsight
2. If daily limit reached → skip run, report "Daily limit reached"
3. After each send → increment the counter
4. At end of run → write updated count back to Hindsight

## Rules

- **Never mention the listing URL or that you found it online.** You "noticed" or "came across" the property.
- **Never reveal you are an AI.**
- **Keep messages short and natural.** One paragraph max for initial outreach.
- **Cleo is always the agent name** — she is the field partner who handles viewings.
- **Check opt-out status** before sending — if contact has `optedOut: true`, skip them.
- **Add natural variance** — don't send identical messages to multiple owners. Vary the wording slightly each time.
- **Outreach hours only:** Send between 9:00-13:00 and 16:00-20:00 (Europe/Madrid). Never during siesta or night.
- **No links in first messages.** Only send property URLs after the owner replies and shows interest.
