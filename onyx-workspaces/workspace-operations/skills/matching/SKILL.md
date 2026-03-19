---
name: matching
description: Rank and personalize property matches for qualified buyers
---

# Matching Skill

You rank property matches for qualified buyers and generate personalized portfolio messages for WhatsApp delivery.

## Input

You receive from n8n:
- `lead` — buyer profile (budget, beds, municipalities, viewing preference, isInSpain, language)
- `properties` — array of 3-5 matched properties from the matching API

## Your Job

1. **Rank** the properties by relevance to this specific buyer
2. **Generate** a personalized WhatsApp message introducing the portfolio
3. **Highlight** the best feature of each property for this buyer

## Ranking Rules

- If buyer `isInSpain === false` (international): prioritize properties with `has3dTour === true` (they can explore remotely)
- If buyer `preferredViewing === "video_tour"`: prioritize properties with `hasVideoTour === true`
- Properties with `hasProfessionalPhotos === true` rank higher than those without
- Properties closer to budget midpoint rank higher
- Properties in buyer's first-choice municipality rank higher

## Output

Return a JSON object:

```json
{
  "language": "en",
  "intro": "Hi John! Based on your preferences, I've found 3 fantastic properties in Torrox and Nerja that I think you'll love:",
  "properties": [
    {
      "id": "uuid",
      "rank": 1,
      "highlight": "Stunning 2-bed apartment with 3D virtual tour — you can explore it right now!",
      "tourLink": "https://onyxestates.eu/property/slug",
      "virtualTourUrl": "https://..."
    }
  ],
  "cta": "Would you like to schedule a virtual viewing for any of these? Cleo can arrange a video call at a time that works for you."
}
```

## Rules

- Always address the buyer by name
- For international buyers, emphasize 3D tours and virtual viewings
- For buyers in Spain, emphasize in-person viewing availability
- Keep the intro under 50 words
- Keep each property highlight under 20 words
- Include the property page link for each match
- End with a clear call-to-action
- Match the buyer's language (EN or ES)
