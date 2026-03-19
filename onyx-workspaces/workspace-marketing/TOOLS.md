# Marketing Agent — API & System Access

## Service APIs

Base URL: `https://onyxestates.eu/api/service`
Auth: `Authorization: Bearer SERVICE_API_KEY` (set in environment)

### Properties (read-only for marketing)
- `GET /properties/list?isPublished=true&limit=10` — fetch published listings for content
- `GET /properties/stats` — market stats for data-driven posts

### Marketing
- `POST /marketing` — create social post draft (propertyId, platforms, captionVariant)
- `PATCH /marketing/{id}` — update post status (approved/rejected/published), engagement
- `POST /marketing/{id}/publish` — publish approved post to social channels
- `GET /marketing/published` — list published posts
- `GET /marketing/stats/weekly` — weekly stats: reach, engagement, top post

## Website

- Public site: https://onyxestates.eu
- Property pages: https://onyxestates.eu/property/{slug}
- Buy listings: https://onyxestates.eu/buy
- Rent listings: https://onyxestates.eu/rent

Always link to the actual property page when featuring a listing.

## Telegram Group

- **Onyx - Marketing** (`-5119769440`) — post drafts for approval, receive feedback
