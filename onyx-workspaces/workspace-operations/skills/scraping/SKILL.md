---
name: scraping
description: Run Apify Idealista actor and ingest results into the database
---

# Scraping Skill

Run the dz_omar/idealista-scraper-api actor on Apify to scrape Idealista listings for the Axarquia region, then ingest into the database.

## Actor Details

- **Actor:** `dz_omar/idealista-scraper-api` on Apify
- **API Token:** Use `APIFY_API_KEY` environment variable
- **No Firecrawl needed** — this actor uses Idealista's internal API directly
- **Returns:** full contactInfo with phone numbers and userType

## Step 1: Run the Actor

```
POST https://api.apify.com/v2/acts/dz_omar~idealista-scraper-api/runs?token=${APIFY_API_KEY}
Content-Type: application/json

{
  "startUrls": [
    {"url": "https://www.idealista.com/alquiler-viviendas/nerja-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/torrox-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/torre-del-mar-velez-malaga-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/velez-malaga-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/frigiliana-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/rincon-de-la-victoria-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/algarrobo-malaga/"},
    {"url": "https://www.idealista.com/alquiler-viviendas/competa-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/nerja-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/torrox-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/torre-del-mar-velez-malaga-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/velez-malaga-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/frigiliana-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/rincon-de-la-victoria-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/algarrobo-malaga/"},
    {"url": "https://www.idealista.com/venta-viviendas/competa-malaga/"}
  ],
  "maxItems": 200
}
```

## Step 2: Confirm Run Started (DO NOT WAIT)

Extract `runId` from the response and report to Telegram:
```
📊 Scraping started (run: {runId})
Actor will take 10-30 minutes. Results will be fetched when complete.
```

**DO NOT poll or wait.** Move on. Check back later.

## Step 3: Fetch and Ingest Results

When status is `SUCCEEDED`:
```
GET https://api.apify.com/v2/datasets/{defaultDatasetId}/items?token=${APIFY_API_KEY}&limit=200
```

## Step 4: Map Actor Output to Onyx Schema

| Actor Field | Onyx Field | Notes |
|------------|-----------|-------|
| `propertyCode` or `adid` | `externalId` | |
| `"idealista"` | `source` | Always |
| `url` or `detailWebLink` | `url` | |
| `description` (first 80 chars) or `address` | `title` | |
| `price` or `priceInfo.price.amount` | `price` | |
| `operation` | `operation` | "sale" or "rent" |
| `propertyType` or `extendedPropertyType` | `propertyType` | flat→apartment, chalet→house |
| `rooms` or `moreCharacteristics.roomNumber` | `bedrooms` | |
| `bathrooms` or `moreCharacteristics.bathroomNumber` | `bathrooms` | |
| `size` or `moreCharacteristics.constructedArea` | `areaM2` | |
| `municipality` | `municipality` | |
| `address` | `address` | |
| `latitude` or `ubication.latitude` | `latitude` | |
| `longitude` or `ubication.longitude` | `longitude` | |
| `multimedia.images[].url` | `photos` | Array of image URLs |
| `contactInfo.phone1.phoneNumberForMobileDialing` | `phone` | **The phone number** |
| `contactInfo.commercialName` or `contactInfo.contactName` | `agencyName` | |
| `contactInfo.userType` | `advertiserType` | "professional" or "private" |
| `description` or `propertyComment` | `description` | Full text |
| current time ISO | `scrapedAt` | |

### Owner Type from contactInfo.userType

- `"private"` or `"particular"` → private owner (WE OUTREACH)
- `"professional"` → agency (skip outreach)

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
