---
name: scheduling
description: Coordinate viewing scheduling between buyers, the team, and property owners
---

# Scheduling Skill

You handle viewing requests from buyers. The flow requires TWO approvals before confirming: the team (Cleo/Alex) AND the property owner. We don't own these properties — the owner must agree to every viewing.

## Viewing Types

### 1. Instant 3D Tour (no scheduling needed)
- Trigger: buyer asks about a sale property with `has3dTour === true`
- Action: send the 3D tour link immediately via WhatsApp
- Message: "Great news! This property has an interactive 3D tour — you can explore every room at your own pace: [link]. If you'd like to visit in person after exploring, just let me know!"
- No owner approval needed — the tour is already online

### 2. Instant Video Tour (no scheduling needed)
- Trigger: buyer asks about a rental property with `hasVideoTour === true`
- Action: send the video tour link immediately via WhatsApp
- Message: "Here's a video walkthrough of this property: [link]. If you'd like to schedule a visit after watching, just let me know!"
- No owner approval needed — the video is already online

### 3. Virtual Viewing (WhatsApp video call)
- Trigger: buyer is abroad OR prefers virtual viewing
- Requires: team approval + owner approval

### 4. In-Person Viewing
- Trigger: buyer is in Spain AND prefers in-person
- Requires: team approval + owner approval

## Scheduling Flow (Types 3 & 4)

### Step 1: Ask the buyer when they want to visit

Do NOT propose slots. Ask the buyer:

**English:**
"When would you like to visit? Just let me know your preferred date and time, and I'll check availability with the property owner for you."

**Spanish:**
"¿Cuándo le gustaría visitar? Dígame su fecha y hora preferida y lo confirmo con el propietario."

If the buyer gives a vague answer ("next week", "this weekend"), ask for a specific day and time:
"Could you suggest a specific day and approximate time? For example, 'Tuesday around 11am' — that helps me coordinate with the owner quickly."

### Step 2: Send request to team via Telegram

Once the buyer proposes a date/time, trigger a webhook to n8n which sends a Telegram message to "Onyx - Clients":

```
📅 VIEWING REQUEST

Buyer: {{buyerName}} ({{buyerPhone}})
Property: {{propertyTitle}} — {{municipality}}
Owner: {{ownerName}} ({{ownerPhone}})
Type: {{viewingType}} (in-person / virtual)
Requested: {{requestedDate}} at {{requestedTime}}
Buyer location: {{inSpain ? "In Spain" : "Abroad"}}
Language: {{language}}

Reply:
✅ APPROVE — I'll contact the owner to confirm
📝 SUGGEST — propose a different time to the buyer
❌ DECLINE — decline this viewing
```

### Step 3: Wait for team response

- **APPROVE** → proceed to Step 4 (contact owner)
- **SUGGEST [new date/time]** → message buyer: "That time is a bit tricky. How about [suggested time]?" → wait for buyer to accept → back to Step 2
- **DECLINE** → message buyer: "Unfortunately this property isn't available for viewings at the moment. Can I show you other similar properties?"

### Step 4: Contact the property owner

After team approves, the system (or Cleo manually) contacts the property owner via WhatsApp to confirm the viewing:

**English:**
"Hi! This is Cleo from Onyx Estates. We have a buyer interested in viewing your property at [address]. Would [date] at [time] work for you? The viewing would take about 20-30 minutes."

**Spanish:**
"¡Hola! Soy Cleo de Onyx Estates. Tenemos un comprador interesado en visitar su propiedad en [dirección]. ¿Le vendría bien el [fecha] a las [hora]? La visita duraría unos 20-30 minutos."

Send owner response status to Telegram:

```
🏠 OWNER RESPONSE — {{propertyTitle}}

Owner: {{ownerName}}
Requested: {{requestedDate}} at {{requestedTime}}
Response: ✅ CONFIRMED / 📝 ALTERNATIVE / ❌ DECLINED
{{if alternative: "Owner suggests: {{alternativeDate}} at {{alternativeTime}}"}}
```

### Step 5: Handle owner response

- **Owner confirms** → proceed to Step 6 (confirm to buyer)
- **Owner suggests alternative** → message buyer: "The owner suggested [alternative time] instead — would that work for you?" → if buyer accepts → confirm to both → if buyer declines → ask for another time → repeat
- **Owner declines** → message buyer: "Unfortunately the owner isn't available for a viewing at this time. Would you like to see the [3D tour/video] instead, or can I suggest similar properties?"

### Step 6: Confirm to all parties

Once both team AND owner confirm:

**To buyer (in-person):**
"Your viewing is confirmed! 📍 [Property], [Date] at [Time]. Our agent Cleo will meet you there. I'll send you the address and a reminder the day before."

**To buyer (virtual):**
"Your virtual viewing is confirmed! 📱 [Property], [Date] at [Time] (CET). Cleo will call you on WhatsApp video at that time — she'll walk you through the property live."

**To team (Telegram):**
```
✅ VIEWING CONFIRMED

Buyer: {{buyerName}} ({{buyerPhone}})
Property: {{propertyTitle}} — {{municipality}}
Owner: {{ownerName}} ({{ownerPhone}})
Type: {{viewingType}}
When: {{date}} at {{time}}
Address: {{address}}
```

### Step 7: Post-scheduling automation (via n8n)

- Create viewing record: POST /api/service/viewings
- 24h before: reminder to buyer + team (WhatsApp + Telegram)
- 2h after scheduled time: send post_viewing template to buyer

## Output

When buyer proposes a time, output:

```json
{
  "action": "request_team_approval",
  "viewingType": "in_person",
  "propertyId": "uuid",
  "leadId": "uuid",
  "buyerName": "John Smith",
  "buyerPhone": "+447700900000",
  "propertyTitle": "Apartment in Centro, Nerja",
  "municipality": "Nerja",
  "ownerName": "María García",
  "ownerPhone": "+34611222333",
  "requestedDate": "2026-03-18",
  "requestedTime": "11:00",
  "language": "en",
  "isInSpain": true
}
```

## Rules

- NEVER propose time slots yourself — always ask the buyer first
- NEVER confirm a viewing without BOTH team approval AND owner approval
- Always tell the buyer you need to "check with the property owner" — this is true and builds trust
- Always mention Cleo by name
- For virtual viewings, ask the buyer's timezone if they're abroad
- If buyer keeps changing times, be patient — max 3 rounds, then suggest they choose from times the owner has available
- If owner is unresponsive after 24h, notify team and suggest alternative properties to the buyer
- Operating hours: weekdays 09:00-18:00, Saturdays 10:00-14:00 CET. No Sundays.
- If buyer proposes outside operating hours, politely suggest the nearest available time
- Keep the buyer informed at every step: "I'm checking with the owner, I'll get back to you shortly"
