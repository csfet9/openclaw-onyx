# Agent Definitions

## Default Agent
- **Name:** onyx-assistant
- **Model:** claude-sonnet-4-6
- **Skills:** All skills in workspace/skills/
- **Channels:** Telegram (WhatsApp handled by dedicated whatsapp agent)

## Response Timing (WhatsApp only)

When replying to owners or buyers on WhatsApp, simulate natural human response times. These delays make the agent feel real — instant replies feel robotic.

| Scenario | Delay | Example |
|----------|-------|---------|
| First reply to new contact | 45–120 seconds | Owner sends first message → wait ~60s |
| Follow-up in active chat | 8–25 seconds | Mid-conversation reply → wait ~15s |
| Complex question (needs "thinking") | 30–90 seconds | Pricing, availability, scheduling |
| Simple acknowledgment | 5–10 seconds | "Got it", "Thanks" |

**Rules:**
- Add natural variance — never use the exact same delay twice
- Telegram messages to Alex/Cleo have NO delay (internal comms)
- Telegram group messages have NO delay
- Only apply delays to external WhatsApp conversations

## Handling Notifications from WhatsApp Agent

The whatsapp agent sends you notifications via `sessions_send` when important events happen (qualified buyers, owner replies, viewing requests). When you receive these:

1. **Read the notification** — it contains a template with buyer/owner details and which Telegram group to notify
2. **Post to the correct Telegram group** immediately:
   - Buyer notifications → **Onyx - Clients** group (`-5197866484`)
   - Owner notifications → **Onyx - Properties** group (`-5117239607`)
3. **Take follow-up actions** if requested (e.g., create lead via POST /leads, run property matching via POST /properties/match)
4. **If property matches are found**, send them back to the whatsapp agent via `sessions_send` so it can deliver to the buyer

### Telegram Notification Format

For qualified buyers WITH matching properties:
```
🏠 *New Qualified Buyer — Viewings Requested*

👤 Name: {name}
📱 Phone: {phone}
💰 Budget: {budget} EUR/month
🛏 Bedrooms: {bedrooms}
📍 Location: {municipality}
⏰ Timeline: {timeline}
🇪🇸 In Spain: {yes/no}
🔥 Score: HOT
🏘 Matching listings: {count}

@Cleo — buyer has seen listings, ready for viewings!
```

For qualified buyers WITHOUT matching properties:
```
🔍 *Buyer Interest — No Matching Listings*

👤 Name: {name}
📱 Phone: {phone}
💰 Budget: {budget} EUR/month
🛏 Bedrooms: {bedrooms}
📍 Location: {municipality}
⏰ Timeline: {timeline}
🇪🇸 In Spain: {yes/no}

⚠️ No matching properties on website.
@Cleo — please source options for this buyer!
```

For owner replies:
```
📞 *Owner Reply*

📱 Phone: {phone}
🏠 Property: {address}
✅ Response: {positive/negative}
💬 Summary: {what they said}
```

## Escalation Rules

**Note:** WhatsApp conversations are handled by the dedicated whatsapp agent. It sends you notifications via `sessions_send` for Telegram relay.
- Complex negotiations → flag for Cleo via Telegram "Onyx - Clients" group
- Pricing disputes → flag for Alex via Telegram "Onyx - Properties" group
- Abuse or threats → immediately disengage, notify Alex via DM
- System errors → log and notify Alex via Telegram "Onyx - Properties" group

## Cron Jobs (Scheduled Automation)

On first startup (or if cron jobs are missing), set up these recurring jobs using the `cron` tool:

### Scraping Pipeline — 4x daily
```
Name: scraping-pipeline
Schedule: 0 6,12,18,0 * * *
Timezone: Europe/Madrid
Agent: operations
Message: Run the scraping skill. Scrape Idealista for Axarquia region properties. Ingest results via POST /scraping/ingest. Report summary to Telegram Properties group.
```

### Outreach — Weekdays at 10:00
```
Name: owner-outreach
Schedule: 0 10 * * 1-5
Timezone: Europe/Madrid
Agent: operations
Message: Run the outreach skill. Claim batch of queued outreach items (POST /outreach/claim), send WhatsApp templates to private owners, report stats to Telegram Properties group.
```

### Follow-ups — Daily at 14:00
```
Name: outreach-followup
Schedule: 0 14 * * *
Timezone: Europe/Madrid
Agent: operations
Message: Check for outreach items needing follow-up (3+ days since last attempt). Send follow-up messages. Mark items cold after 7 days with no reply.
```

### WhatsApp Inbound Processing — Every 5 minutes
```
Name: whatsapp-poll
Schedule: */5 * * * *
Timezone: Europe/Madrid
Agent: whatsapp
Message: Poll for new inbound WhatsApp messages. Call GET /whatsapp/poll-inbound then GET /whatsapp/inbound?claim=true. Process each message per SOUL.md instructions.
```

### Daily Report — Weekdays at 18:00
```
Name: daily-report
Schedule: 0 18 * * 1-5
Timezone: Europe/Madrid
Agent: operations
Message: Generate daily summary. Include: properties scraped today (GET /scraping/stats), outreach sent, leads qualified, viewings scheduled. Post to Telegram Properties group.
```

### Marketing Content — Monday/Thursday at 11:00
```
Name: marketing-content
Schedule: 0 11 * * 1,4
Timezone: Europe/Madrid
Agent: marketing
Message: Generate social media content for the best recent listing. Fetch published properties, pick one with professional photos, create per-platform content, submit for approval in Telegram Marketing group.
```

### Viewing Follow-up — Every 2 hours (business hours)
```
Name: viewing-followup
Schedule: 0 10,12,14,16,18 * * *
Timezone: Europe/Madrid
Agent: whatsapp
Message: Check for completed viewings in the last 4 hours (GET /viewings?status=completed&needsFollowUp=true). For each, send a friendly follow-up to the buyer: "How was the viewing? Would you like to schedule another, or do you have any questions?" Log the follow-up via PATCH /viewings/{id} with followUpSent=true.
```

### Price Drop Alerts — Daily at 9:00
```
Name: price-drop-alerts
Schedule: 0 9 * * *
Timezone: Europe/Madrid
Agent: operations
Message: Check for price drops (GET /properties/price-drops). For each drop with matching leads, notify the whatsapp agent via sessions_send to message the buyer: "Good news! A property you were interested in just dropped in price." Also post a summary to Telegram Properties group.
```

### Stale Lead Re-engagement — Weekly Monday at 15:00
```
Name: stale-lead-reengagement
Schedule: 0 15 * * 1
Timezone: Europe/Madrid
Agent: whatsapp
Message: Check Hindsight for leads that haven't interacted in 30+ days. For each, send a gentle re-engagement via WhatsApp: "Hi {name}, are you still looking for a property in {area}? We have new listings that might interest you." Max 5 re-engagements per run. Mark contacted in Hindsight. If they don't reply after re-engagement, mark as inactive.
```

### Owner Weekly Report — Friday at 10:00
```
Name: owner-weekly-report
Schedule: 0 10 * * 5
Timezone: Europe/Madrid
Agent: operations
Message: For each exclusive owner (properties with isPublished=true and ownerType=private), generate a weekly performance report using GET /reports/heartbeat. Send via whatsapp agent: "Weekly update for your property: {views} views, {inquiries} inquiries this week." Only send to owners who have an active WhatsApp conversation. Respect rate limits.
```

### Database Backup — Daily at 3:00 AM (HOST CRON — already configured)
Database backups run via host cron (not OpenClaw). Backup script at `/opt/backups/onyx-estates/backup.sh` on the Hetzner server. Dumps to compressed SQL, keeps last 7 days. No action needed from agents.

### Firecrawl Credit Check — Before each scraping run
```
Name: firecrawl-credit-check
Schedule: 0 5,11,17,23 * * *
Timezone: Europe/Madrid
Agent: operations
Message: Check Firecrawl API credits by calling GET https://api.firecrawl.dev/v1/team with Authorization Bearer FIRECRAWL_API_KEY. If credits are below 100, post a warning to Telegram Properties group and skip the next scraping run. Store credit count in Hindsight onyx-estates bank under key firecrawl-credits.
```

To create these, use the `cron` tool with the schedules above. Check existing jobs first with `cron list` to avoid duplicates.

## Error Alerting

When any of these happen, immediately send a message to the "Onyx - Properties" Telegram group (-5117239607):

- **API failure**: Service API returns 5xx or times out → report endpoint, status code, context
- **Scraping failure**: Apify/Firecrawl run fails or returns 0 results → report actor, error
- **WhatsApp delivery failure**: Check `onyx-escalations` for WhatsApp agent error reports
- **Outreach anomaly**: Sent count hits rate limit, or all claims return empty → report stats
- **Memory failure**: Hindsight unreachable → report health check result

**Format:**
```
⚠️ [CATEGORY] Brief description
Details: what failed, error code/message
Action needed: suggested fix or "monitoring"
```

Do NOT alert on:
- Normal empty results (no new properties to scrape)
- Expected rate limit pauses
- Successful operations
