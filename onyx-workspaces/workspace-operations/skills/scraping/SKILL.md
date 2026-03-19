---
name: scraping
description: Run Apify Idealista actor and ingest results into the database
---

# Scraping Skill

Run the igolaizola/idealista-scraper Apify actor to scrape Idealista listings for the Axarquia region, then ingest results into the database.

## Actor Details

- **Actor:** `igolaizola/idealista-scraper` on Apify
- **API Token:** Use `APIFY_API_KEY` environment variable
- **No Firecrawl needed** — this actor uses Idealista's internal API directly

## Step 1: Run the Actor

```
POST https://api.apify.com/v2/acts/igolaizola~idealista-scraper/runs?token=${APIFY_API_KEY}
Content-Type: application/json

{
  "country": "es",
  "operation": "rent",
  "province": "Málaga",
  "municipalities": ["Nerja", "Torrox", "Torre del Mar", "Vélez-Málaga", "Frigiliana", "Rincón de la Victoria", "Algarrobo", "Cómpeta"],
  "maxItems": 200
}
```

Run TWICE — once for `"operation": "rent"` and once for `"operation": "sale"`.

## Step 2: Confirm Run Started (DO NOT WAIT)

Extract the `runId` from the response and report to Telegram:
```
📊 Scraping started (run: {runId})
Actor will take 10-30 minutes. Results will be fetched when complete.
```

**DO NOT poll or wait.** Move on to other tasks. Check back later.

To check status:
```
GET https://api.apify.com/v2/actor-runs/{runId}?token=${APIFY_API_KEY}
```

## Step 3: Fetch and Ingest Results

When status is `SUCCEEDED`, fetch results:
```
GET https://api.apify.com/v2/datasets/{defaultDatasetId}/items?token=${APIFY_API_KEY}&limit=200
```

## Step 4: Map Actor Output to Onyx Schema

| Actor Field | Onyx Field | Notes |
|------------|-----------|-------|
| `propertyCode` | `externalId` | |
| `"idealista"` | `source` | Always |
| `url` | `url` | |
| `description` (first 80 chars) or address | `title` | |
| `price` or `priceInfo.price.amount` | `price` | |
| `operation` | `operation` | "sale" or "rent" |
| `propertyType` | `propertyType` | flat→apartment, chalet→house |
| `rooms` | `bedrooms` | |
| `bathrooms` | `bathrooms` | |
| `size` | `areaM2` | |
| `municipality` | `municipality` | |
| `address` | `address` | |
| `latitude` | `latitude` | |
| `longitude` | `longitude` | |
| `multimedia.images[].url` | `photos` | Array of image URLs |
| `contactInfo.phone1.phoneNumberForMobileDialing` | `phone` | **The phone number** |
| `contactInfo.commercialName` or `contactInfo.contactName` | `agencyName` | |
| `contactInfo.userType` | `advertiserType` | "professional" or "private" |
| `description` | `description` | Full text |
| current time ISO | `scrapedAt` | |

### Owner Type

- `contactInfo.userType: "private"` → private owner (WE OUTREACH)
- `contactInfo.userType: "professional"` → agency (skip outreach)

## Step 5: Send to Ingest API

Batches of 50:
```
POST https://onyxestates.eu/api/service/scraping/ingest
Authorization: Bearer SERVICE_API_KEY
Content-Type: application/json

{ "listings": [ ...mapped properties... ] }
```

## Step 6: Match Against Existing Leads

After ingesting, check if any leads match new properties. Notify whatsapp agent via `sessions_send` for each match.

## Step 7: Report to Telegram

Post to Properties group (`-5117239607`):
```
📊 Scraping Complete

🏠 Total listings: {count}
👤 Private owners: {private_count}
🏢 Agencies: {agency_count}
📱 With phone: {phone_count}
🆕 New: {new_count}
📍 Nerja: {n} | Torrox: {n} | Torre del Mar: {n} | ...
```

## Error Handling

- Actor run fails → report to Telegram, retry once
- No results → report "0 listings" (normal)
- Ingest API fails → report error with status code
