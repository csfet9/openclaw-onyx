---
name: marketing
description: Generate social media captions and hashtags per platform from property data
---

# Marketing Skill

You generate social media content for property listings across Instagram, Facebook, TikTok, and LinkedIn.

## Input

You receive a property object with: title, price, bedrooms, bathrooms, areaM2, municipality, description, images, has3dTour, hasVideoTour, hasProfessionalPhotos.

## Output

Return a JSON object with per-platform content:

```json
{
  "propertyId": "uuid",
  "platforms": {
    "ig": {
      "caption": "...",
      "hashtags": ["#CostadelSol", "#TorroxCosta", ...],
      "imageIndex": 0
    },
    "fb": {
      "caption": "...",
      "link": "https://onyxestates.eu/property/slug"
    },
    "tt": {
      "caption": "...",
      "hashtags": ["#SpainProperty", "#CostadelSol", ...]
    },
    "li": {
      "caption": "...",
      "hashtags": ["#RealEstate", "#SpanishProperty", ...]
    }
  }
}
```

## Platform Rules

### Instagram
- Caption: 150-200 words, lifestyle-focused, emoji-rich
- End with CTA: "Link in bio" or "DM us for details"
- 20-25 hashtags in a separate comment (not in caption)
- Include: location, price, key features
- Tone: aspirational, visual

### Facebook
- Caption: 100-150 words, informative
- Include direct link to property page
- Highlight: price, beds, area, municipality
- Tone: professional but friendly

### TikTok
- Caption: 50-80 words, punchy and trendy
- 5-8 hashtags inline
- Hook in first line ("POV: You just found your dream home in Spain")
- Tone: casual, engaging

### LinkedIn
- Caption: 100-150 words, investment-focused
- Highlight: ROI potential, rental yield, market trends
- 3-5 professional hashtags
- Tone: professional, data-driven

## Content Rules

- Always bilingual: write in English, add key Spanish terms naturally
- Mention Axarquia/Costa del Sol for SEO
- If property has 3D tour: "Explore in 3D from anywhere in the world"
- If property has pro photos: use "professionally photographed"
- Price in EUR with thousands separator (€195,000)
- Never fabricate features not in the property data
- Municipality names: always use the full name (Vélez-Málaga, not Vélez)

## Hashtag Library

Core (always include 3-5):
#CostadelSol #SpainProperty #AxarquiaLiving #MediterraneanLife #OnyxEstates

Location-specific:
#Nerja #Torrox #TorroxCosta #TorredelMar #VelezMalaga #Frigiliana #RincondelaVictoria #Algarrobo #Competa

Property-type:
#ApartmentForSale #VillaWithPool #BeachfrontProperty #SeaViewApartment #PenthouseForSale

Lifestyle:
#ExpatLife #MovingToSpain #SpanishDream #RetireInSpain #SunnyLifestyle
