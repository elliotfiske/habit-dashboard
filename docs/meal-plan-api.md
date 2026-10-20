# Meal plan API

The habit dashboard on the living-room monitor shows this week's lunches and
dinners. This doc is everything a meal-planning agent needs to read and write
that plan.

## Quick reference

| Endpoint | Body | Does |
|---|---|---|
| `POST /_r/getMealPlan` | `{}` | Returns the whole stored plan |
| `POST /_r/setMeals` | `{ "meals": [ … ] }` | Sets or clears individual slots, leaves everything else alone |
| `POST /_r/replaceMealPlan` | `{ "days": [ … ] }` | Replaces the whole stored plan |

- **Base URL:** `https://habit-dashboard.lamdera.app` (local dev:
  `http://localhost:8000`)
- **No auth.**
- **Always `POST`** with a JSON body. Send `{}` when there's nothing to say.
  A `GET` returns the app's HTML page, not data.
- Send `Content-Type: application/json`.
- Every write responds with the full updated plan, and open dashboards update
  within a second, without a reload.

## Errors

**Errors come back as HTTP 200**, with an `error` field instead of `days`:

```json
{ "error": "Unexpected HTTP response: Problem with the value at json.meals[0].slot:\n\n    \"brunch\"\n\nslot must be \"lunch\" or \"dinner\", got \"brunch\"" }
```

So check the body for an `error` key, not the status code. A request with any
invalid entry is rejected as a whole: nothing in it is saved.

## Data model

```json
{
  "days": [
    {
      "date": "2026-10-14",
      "lunch": { "name": "Salmon bowl leftovers", "note": null },
      "dinner": { "name": "Chicken tikka masala", "note": "Thaw chicken thighs this morning" }
    },
    {
      "date": "2026-10-15",
      "lunch": null,
      "dinner": { "name": "Tacos", "note": null }
    }
  ]
}
```

- **`date`**: `YYYY-MM-DD`, the household's local calendar date (US Pacific).
  Anything else is an error.
- **Slots**: only `lunch` and `dinner`. An empty slot is `null`.
- **`name`**: what's shown on the dashboard. Keep it short, under about 35
  characters. It wraps to two lines in a narrow column, and anything longer is
  cut off.
- **`note`**: optional free text, e.g. "Thaw chicken thighs this morning" or
  "Double batch, freeze half". Notes appear on the dashboard only for **today's**
  meals, so put same-day prep reminders there.
- Days are sorted by date. A day appears only if it has at least one meal.
- Nothing is pruned automatically: past days stay stored until a
  `replaceMealPlan` drops them.

## `getMealPlan`

```bash
curl -X POST https://habit-dashboard.lamdera.app/_r/getMealPlan \
  -H 'Content-Type: application/json' -d '{}'
```

Returns every stored day, past and future, in the shape above.

## `setMeals`

Set or clear individual slots. Anything not mentioned is left alone, so this
is the safe default for changes.

```bash
curl -X POST https://habit-dashboard.lamdera.app/_r/setMeals \
  -H 'Content-Type: application/json' -d '{
  "meals": [
    { "date": "2026-10-15", "slot": "dinner", "name": "Tacos" },
    { "date": "2026-10-16", "slot": "dinner", "name": "Pizza night", "note": "Dough from Trader Joe'\''s" },
    { "date": "2026-10-17", "slot": "lunch", "name": null }
  ]
}'
```

- Each entry needs `date` and `slot` (`"lunch"` or `"dinner"`, case-insensitive).
- A `null`, missing or blank `name` **clears** that slot.
- Setting a slot replaces its name *and* note. To keep a note, send it again.
- Entries apply in order, so a later entry for the same slot wins.

## `replaceMealPlan`

Replace everything stored with the body. Same shape as `getMealPlan`'s
response. **Anything not in the body is deleted**, including past days.

```bash
curl -X POST https://habit-dashboard.lamdera.app/_r/replaceMealPlan \
  -H 'Content-Type: application/json' -d '{
  "days": [
    { "date": "2026-10-19", "lunch": { "name": "Leftover chili" }, "dinner": { "name": "Sheet-pan chicken" } },
    { "date": "2026-10-20", "dinner": { "name": "Salmon rice bowls" } }
  ]
}'
```

Missing slots count as empty, and `note` can be left out.

## What the dashboard shows

A Day / Lunch / Dinner table of seven rolling days: two days back, **today
(always the third row)**, and the next four days. Today is highlighted and past
days are dimmed. Days with nothing planned show "—". Meals can be written
ahead of time; they appear once they fall within four days of today.

## Suggested workflow for an agent

1. `getMealPlan` to see what's already planned.
2. Plan the coming days (at least four ahead of today), reusing leftovers for the next day's lunch
   where it makes sense.
3. Write it with **`setMeals`**, one entry per slot. Prefer it over
   `replaceMealPlan`, which wipes anything you didn't include.
4. Check the response for an `error` key. If it's there, nothing was saved:
   fix the entry it names and resend.
5. Put same-day prep reminders (thawing, marinating, soaking beans) in that
   day's `note`.
