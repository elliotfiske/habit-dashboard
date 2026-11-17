# Water API

The dashboard's water card shows today's water against a 70 oz goal as a
flower: happy when the day's drinking is on pace, wilting when it falls behind,
sparkling once the goal is met. The Med Log iPhone app reads drinks from Apple
Health (where the smart bottle writes them) and posts them here.

| Endpoint | Body | Does |
|---|---|---|
| `POST /_r/setWaterDrinks` | `{ "since", "sentAt", "drinks": [ … ] }` | Replaces every stored drink from `since` on |
| `POST /_r/getWater` | `{}` | Returns the stored drinks |

Same conventions as the [meal plan API](meal-plan-api.md): always `POST` JSON,
no auth, and errors come back as HTTP 200 with an `error` key.

## `setWaterDrinks`

```bash
curl -X POST https://habit-dashboard.lamdera.app/_r/setWaterDrinks \
  -H 'Content-Type: application/json' -d '{
  "since": "2026-11-15T08:00:00Z",
  "sentAt": "2026-11-16T21:40:00Z",
  "drinks": [
    { "id": "6F1C…", "at": "2026-11-16T17:02:11Z", "ml": 236.6 }
  ]
}'
```

- `since`: every stored drink at or after this time is replaced by `drinks`, so
  a drink deleted in Health disappears here on the next upload. Med Log sends
  the start of yesterday, in case a late upload crosses midnight.
- `sentAt`: when the phone read Health. An upload older than the last one
  applied is ignored, so uploads that cross on the network can't roll back.
- `id`: Health's sample UUID. `at`: when it was drunk. `ml`: millilitres.
- Drinks older than two weeks are dropped.

## Pace

`Water.progress` spreads the goal evenly from 8 AM to 8 PM in the dashboard's
time zone. The flower stays happy while today's total is within one glass
(8 oz) of that line, and wilts once it falls further behind. The card is hidden
until the first upload arrives.
