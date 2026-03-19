---
name: scraping
description: Run our Apify Idealista actor and ingest results into the database
---

# Scraping Skill

You run our custom Apify Idealista actor to scrape property listings from the Axarquia region, then ingest the results into the Onyx Estates database.

## Actor Details

- **Actor ID:** `1zATezufVmJVRUAHf` (our private fork at github.com/csfet9/idealista-actor)
- **API Token:** Use `APIFY_API_KEY` environment variable

## Step 0: Check Firecrawl Credits

Before running the actor, verify Firecrawl has enough credits:

```
GET https://api.firecrawl.dev/v1/team
Authorization: Bearer {FIRECRAWL_API_KEY}
```

Check `credits` in the response. If below 100:
- Post to Telegram Properties group: "⚠️ Firecrawl credits low ({credits} remaining). Skipping scrape."
- Store in Hindsight `onyx-estates` → `firecrawl-credits`: `{ credits: N, checkedAt: ISO }`
- **STOP — do not run the actor.**

If credits are sufficient, proceed.

## Step 1: Run the Actor

```
POST https://api.apify.com/v2/acts/1zATezufVmJVRUAHf/runs?token={APIFY_TOKEN}
Content-Type: application/json

{
  "searchUrls": [
    "https://www.idealista.com/alquiler-viviendas/nerja-malaga/",
    "https://www.idealista.com/alquiler-viviendas/torrox-malaga/",
    "https://www.idealista.com/alquiler-viviendas/torre-del-mar-velez-malaga-malaga/",
    "https://www.idealista.com/alquiler-viviendas/velez-malaga-malaga/",
    "https://www.idealista.com/alquiler-viviendas/frigiliana-malaga/",
    "https://www.idealista.com/alquiler-viviendas/rincon-de-la-victoria-malaga/",
    "https://www.idealista.com/alquiler-viviendas/algarrobo-malaga/",
    "https://www.idealista.com/alquiler-viviendas/competa-malaga/",
    "https://www.idealista.com/venta-viviendas/nerja-malaga/",
    "https://www.idealista.com/venta-viviendas/torrox-malaga/",
    "https://www.idealista.com/venta-viviendas/torre-del-mar-velez-malaga-malaga/",
    "https://www.idealista.com/venta-viviendas/velez-malaga-malaga/",
    "https://www.idealista.com/venta-viviendas/frigiliana-malaga/",
    "https://www.idealista.com/venta-viviendas/rincon-de-la-victoria-malaga/",
    "https://www.idealista.com/venta-viviendas/algarrobo-malaga/",
    "https://www.idealista.com/venta-viviendas/competa-malaga/"
  ],
  "maxPagesPerSearch": 10,
  "firecrawlApiKey": "${FIRECRAWL_API_KEY}",
  "webhookUrl": "https://onyxestates.eu/api/service/scraping/ingest",
  "webhookApiKey": "SERVICE_API_KEY",
  "webhookBatchSize": 50
}
```

**IMPORTANT: The webhook is configured.** The actor will POST results directly to our ingest endpoint as it scrapes. You do NOT need to wait for the run to complete or fetch results manually.

## Step 2: Confirm Run Started (DO NOT WAIT)

After starting the run, extract the `runId` from the response and report to Telegram:
```
📊 Scraping started (run: {runId})
Results will be ingested automatically via webhook.
```

**DO NOT poll or wait for completion.** The actor runs for 10-30 minutes and sends results to the webhook automatically. Move on to other tasks.

To check run status later (if asked):
```
GET https://api.apify.com/v2/actor-runs/{runId}?token={APIFY_TOKEN}
```

## Step 3: Fetch Results (only if webhook failed or when manually checking)

```
GET https://api.apify.com/v2/datasets/{defaultDatasetId}/items?token={APIFY_TOKEN}&limit=200
```

Only use this if the webhook didn't fire or you need to manually re-ingest results.

## Actor Output Format

The actor returns listings already close to our schema:

```json
{
  "externalId": "109490324",
  "source": "idealista",
  "url": "https://www.idealista.com/inmueble/109490324/",
  "title": "Chalet adosado en Calle Arquímedes, Nerja",
  "price": 295000,
  "operation": "sale",
  "propertyType": "house",
  "bedrooms": 2,
  "bathrooms": 1,
  "areaM2": 97,
  "address": "Calle Arquímedes, Avda Pescia, Nerja",
  "municipality": "nerja-malaga",
  "photos": ["https://img4.idealista.com/..."],
  "contactPhone": "+34611222333",
  "contactName": "María García",
  "ownerType": "private",
  "features": ["parking", "price_reduced", "sea_views"],
  "language": "es",
  "scrapedAt": "2026-03-17T16:51:37.421Z"
}
```

## Step 4: Map and Ingest

If fetching from dataset (not webhook), map and send to our API:

- Prefix `externalId` with `idealista-` if not already prefixed
- Normalize `municipality`: strip `-malaga` suffix, capitalize (e.g., `"nerja-malaga"` → `"Nerja"`)
- Ensure `contactPhone` is in +34 format
- Classify `ownerType` if not provided by actor (see classification rules below)

```
POST https://onyxestates.eu/api/service/scraping/ingest
Authorization: Bearer SERVICE_API_KEY
Content-Type: application/json

{ "listings": [ ...mapped properties... ] }
```

## Owner Type Classification

If the actor doesn't provide `ownerType`, classify based on:

- **private:** Listing marked "Particular", simple personal name, informal description
- **agency:** Listing marked "Profesional", name contains "inmobiliaria"/"S.L."/"S.A.", known agency names
- **developer:** Keywords "obra nueva", "promoción", "constructora"
- **bank:** Keywords "banco", "Sareb", "Haya", "Solvia", "Altamira"
- **unknown:** Can't determine (still queue for outreach with lower priority)

## Step 5: Report to Telegram

Post summary to Properties group (`-5117239607`):

```
📊 Scraping Complete

🏠 Total listings: {count}
👤 Private owners: {private_count}
🏢 Agencies: {agency_count}
📱 With phone: {phone_count}
🆕 New: {new_count}
📍 Nerja: {n} | Torrox: {n} | Torre del Mar: {n} | ...
```

## Step 6: Match New Properties Against Existing Leads

After ingesting new properties, check if any existing leads are waiting for matches:

1. **Get all active leads:** `GET https://onyxestates.eu/api/service/leads/lookup?phone=*` (or query Hindsight for stored lead preferences)
2. **For each new property that is published** (`isPublished: true`), check if it matches any lead's criteria (budget, bedrooms, municipality, operation)
3. **If a match is found:**
   - Notify the whatsapp agent via `sessions_send` with:
     ```
     🏠 NEW PROPERTY MATCH FOR EXISTING LEAD

     Buyer: {name} ({phone})
     Budget: {budget}
     Bedrooms: {bedrooms}
     Location: {municipality}

     Matching property:
     Title: {property title}
     Price: {price}
     Bedrooms: {beds}
     Link: https://onyxestates.eu/property/{slug}

     Please send this property to the buyer via WhatsApp.
     ```
   - Also notify Cleo in Telegram Clients group

This ensures that when a new property arrives that matches an existing buyer's criteria, the buyer gets notified automatically.

## Error Handling

- Actor run fails → report to Telegram, retry once
- Firecrawl credits exhausted → report "Firecrawl credits low", alert Alex
- No results → report "0 listings" (don't alert — may be normal)
- Ingest API fails → report error with status code
- Timeout (30min) → kill run, report to Telegram
