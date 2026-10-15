# Meal plan API

The dashboard shows this week's lunches and dinners. An agent reads and writes
the plan through three JSON RPC endpoints. No auth.

- Base URL: `https://habit-dashboard.lamdera.app` (local: `http://localhost:8000`)
- Every call is a `POST` with `Content-Type: application/json` and a JSON body
  (send `{}` when there's nothing to say).
- Dates are `YYYY-MM-DD`. Slots are `"lunch"` or `"dinner"`.
- Writes show up on open dashboards immediately.
- Errors come back as `{ "error": "..." }`.

## Shape

```json
{
  "days": [
    {
      "date": "2026-10-14",
      "lunch": { "name": "Salmon bowl leftovers", "note": null },
      "dinner": { "name": "Chicken tikka masala", "note": "Thaw chicken thighs this morning" }
    }
  ]
}
```

Days are sorted by date. Only days with at least one meal are listed; an empty
slot is `null`. `note` is optional free text, shown under tonight's dinner.

## `getMealPlan`

```bash
curl -X POST $BASE/_r/getMealPlan -H 'Content-Type: application/json' -d '{}'
```

Returns every stored day, past and future, in the shape above.

## `setMeals`

Set or clear individual slots. Everything else is left alone.

```bash
curl -X POST $BASE/_r/setMeals -H 'Content-Type: application/json' -d '{
  "meals": [
    { "date": "2026-10-15", "slot": "dinner", "name": "Tacos" },
    { "date": "2026-10-16", "slot": "dinner", "name": "Pizza night", "note": "Dough from Trader Joe'\''s" },
    { "date": "2026-10-17", "slot": "lunch", "name": null }
  ]
}'
```

A `null`, missing or blank `name` clears the slot. Returns the full updated plan.

## `replaceMealPlan`

Replace the whole stored plan with the body (same shape as `getMealPlan`).
Anything not in the body is deleted.

```bash
curl -X POST $BASE/_r/replaceMealPlan -H 'Content-Type: application/json' -d '{ "days": [ ... ] }'
```

Returns the full updated plan.

## What the dashboard shows

A Day / Lunch / Dinner table for the current Monday–Sunday week, with today
highlighted and past days dimmed. Names wrap to two lines; notes are shown
only for today. Planning next week ahead of time is fine: write those dates now and they
appear when the week starts.
