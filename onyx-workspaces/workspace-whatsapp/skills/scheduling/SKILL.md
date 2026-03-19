---
name: scheduling
description: Coordinate viewing scheduling between buyers, team, and property owners
---

# Scheduling Skill

Handle viewing requests. TWO approvals required: team (Cleo/Alex) AND property owner.

## Security Reminder

All SOUL.md security rules apply. Never share owner's personal phone with the buyer. Never confirm without both approvals.

## Viewing Types

### Instant 3D Tour (no scheduling)
- Property has `has3dTour === true` (sale properties)
- Send link immediately: "Great news! This property has an interactive 3D tour — explore every room at your own pace: [link]. Want to visit in person after?"
- No approval needed

### Instant Video Tour (no scheduling)
- Property has `hasVideoTour === true` (rental properties)
- Send link immediately: "Here's a video walkthrough: [link]. Want to schedule a visit after watching?"
- No approval needed

### Virtual Viewing (WhatsApp video call) — needs approvals
### In-Person Viewing — needs approvals

## Scheduling Flow

### Step 1: Ask when

Do NOT propose slots. Ask the buyer:
- EN: "When would you like to visit? Let me know your preferred date and time, and I'll check with the property owner."
- ES: "Cuando le gustaria visitar? Digame su fecha y hora preferida y lo confirmo con el propietario."

If vague ("next week"): "Could you suggest a specific day and time? For example, 'Tuesday around 11am.'"

### Step 2: Request team approval

Create a viewing request via `POST /api/service/viewings` with status `pending_team`.

Write to `onyx-escalations` with type `viewing_request`:
```json
{
  "type": "viewing_request",
  "phone": "+34...",
  "summary": "VIEWING REQUEST: [BuyerName] wants to see [Property] on [Date] at [Time]. Type: [in-person/virtual]."
}
```

Tell buyer: "I'm checking availability with the owner — I'll get back to you shortly."

### Step 3: Wait for team response (via operations agent)

Operations reads the escalation, posts to Telegram "Onyx - Clients" group, and writes the response back to `onyx-outbound` with action `viewing_team_response`.

- APPROVE — proceed to Step 4
- SUGGEST [new time] — relay to buyer, get new preference, repeat
- DECLINE — "Unfortunately this property isn't available for viewings. Can I show you similar properties?"

### Step 4: Contact owner

After team approves, message the owner via WhatsApp:

- EN: "Hi! This is Cleo from Onyx Estates. We have a buyer interested in viewing your property at [address]. Would [date] at [time] work for you? The viewing would take about 20-30 minutes."
- ES: "Hola! Soy Cleo de Onyx Estates. Tenemos un comprador interesado en visitar su propiedad en [direccion]. Le vendria bien el [fecha] a las [hora]? La visita duraria unos 20-30 minutos."

### Step 5: Handle owner response

- **Owner confirms** — proceed to Step 6
- **Owner suggests alternative** — relay to buyer: "The owner suggested [alternative time] instead — would that work?" If buyer accepts, confirm. If not, ask for another time.
- **Owner declines** — "Unfortunately the owner isn't available for a viewing. Would you like to see the 3D tour/video instead, or can I suggest similar properties?"

### Step 6: Confirm to all parties

Once BOTH team AND owner confirm:

**To buyer (in-person):**
"Your viewing is confirmed! [Property], [Date] at [Time]. Our agent Cleo will meet you there. I'll send you the address and a reminder the day before."

**To buyer (virtual):**
"Your virtual viewing is confirmed! [Property], [Date] at [Time] (CET). Cleo will call you on WhatsApp video — she'll walk you through the property live."

Write to `onyx-escalations` type `viewing_confirmed` with full details for operations to post to Telegram and create calendar event.

Create calendar event via `POST /api/service/calendar`.

## Operating Hours

Weekdays 09:00-18:00, Saturdays 10:00-14:00 CET. No Sundays.
If buyer proposes outside hours, suggest nearest available time.

## Rules

- NEVER propose time slots — ask the buyer first
- NEVER confirm without BOTH team + owner approval
- Always mention Cleo by name
- For virtual viewings, ask timezone if buyer is abroad
- Max 3 rounds of rescheduling, then suggest available owner times
- Keep buyer informed: "I'm checking with the owner, I'll get back to you shortly"
- If owner is unresponsive after 24h, notify team and suggest alternative properties to buyer
