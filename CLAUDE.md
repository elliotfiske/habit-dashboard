# Lamdera Project Rules

## Codebase Architecture

### Frontend Module Organization

This codebase follows a strict separation of concerns. **ALWAYS maintain this structure:**

**src/Frontend.elm** - Orchestration layer ONLY
- Keep this file minimal (~360 lines)
- Contains: `init`, `update`, `updateFromBackend`, `subscriptions`, `view`
- The `view` function should ONLY compose UI modules, not contain HTML
- The `update` function should delegate to helper functions for complex logic
- **DO NOT add view logic here** - put it in UI/ modules
- **DO NOT add business logic here** - put it in logic modules

**src/UI/** - UI Components
- Each module renders one logical UI component
- Modules expose a `view` function that takes `FrontendModel` and returns `Html FrontendMsg`
- **UI modules should NOT contain business logic** (calculations, data transformations)
- **UI modules CAN use logic modules** (ColorLogic, TimerLogic, etc.) for display purposes
- Current modules:
  - `UI.TimerBanner` - Running timer display and error handling
  - `UI.ConnectionCard` - Toggl connection status
  - `UI.CalendarView` - Calendar grid rendering
  - `UI.Modal` - Modal dialogs
  - `UI.WebhookDebug` - Debug log display

**Business Logic Modules** - Pure functions ONLY
- `ColorLogic` - Color manipulation (hex parsing, contrast, muting)
- `TimerLogic` - Time formatting and duration calculations
- `CalendarLogic` - Calendar operations (date ranges, demo data)
- These modules should:
  - Have NO Html dependencies
  - Be pure functions (same input = same output)
  - Be easily testable in isolation
  - Have comprehensive type annotations

### When Adding New Features

**Adding UI elements?**
1. Determine which existing UI module it belongs to
2. If it's a new major component, create a new UI/ module
3. Update Frontend.elm's `view` to include it
4. Keep the new UI module focused on presentation only

**Adding business logic?**
1. Check if it belongs in an existing logic module
2. If it's a new domain, create a new logic module (e.g., `StatisticsLogic`)
3. Make it a pure function with explicit type annotations
4. Import and use it from Frontend.elm or UI modules

**Adding to the update function?**
1. Keep handlers simple and declarative
2. Extract complex logic into helper functions (like `sendFetchCalendarCommand`)
3. If logic is reused, extract it to a helper function in Frontend.elm
4. If logic is pure and domain-specific, extract it to a logic module

**Example: Adding a "Streak Counter" Feature**

Good approach:
```elm
-- 1. Create src/StreakLogic.elm for calculations
module StreakLogic exposing (calculateStreak, formatStreak)

calculateStreak : List DayEntry -> Int
-- Pure function, no dependencies

-- 2. Create src/UI/StreakDisplay.elm for rendering
module UI.StreakDisplay exposing (view)

view : FrontendModel -> Html FrontendMsg
view model =
    let
        streak = StreakLogic.calculateStreak model.entries
    in
    Html.div [] [ Html.text (StreakLogic.formatStreak streak) ]

-- 3. Update Frontend.elm's view to include it
view model =
    { title = "Habit Dashboard"
    , body =
        [ ...
        , UI.StreakDisplay.view model  -- Just compose it
        , ...
        ]
    }
```

Bad approach:
```elm
-- DON'T do this - business logic in Frontend.elm view
view model =
    let
        streak = List.foldl (\entry count -> ...) 0 model.entries  -- NO!
    in
    { title = "Habit Dashboard"
    , body = [ Html.div [] [ Html.text (String.fromInt streak) ] ]  -- NO!
    }
```

### Module Size Guidelines

- **Frontend.elm**: Keep under 400 lines
- **UI modules**: Keep under 250 lines each (Modal is at the limit)
- **Logic modules**: Keep under 300 lines each
- If a module grows too large, split it into focused sub-modules

### Refactoring Guidelines

**When to refactor:**
- Frontend.elm exceeds 400 lines
- A UI module exceeds 250 lines
- Duplicate logic appears in multiple update handlers
- Business logic is mixed with UI rendering
- A function is doing multiple unrelated things

**How to refactor:**
1. **Always** run `elm-review` and `elm-test` before starting
2. Make ONE extraction at a time (don't batch multiple changes)
3. Run `elm-review` and `elm-test` after EACH extraction
4. Use `yes | elm-review --fix` to auto-fix unused imports
5. Commit after completing a logical set of extractions
6. **NEVER** change behavior during refactoring - only move code

**Extraction checklist:**
- [ ] Identify duplicate or complex code
- [ ] Determine correct module (UI/ vs logic vs Frontend helper)
- [ ] Extract with exact copy-paste (no modifications)
- [ ] Update imports in both old and new locations
- [ ] Run `elm-review` and fix any issues
- [ ] Run `elm-test` to verify no regressions
- [ ] Commit with descriptive message

**Common mistakes to avoid:**
- ❌ Modifying logic while extracting (do these separately)
- ❌ Batching multiple extractions before testing
- ❌ Putting business logic in UI modules
- ❌ Putting HTML rendering in logic modules
- ❌ Skipping tests after "small" changes
- ❌ Forgetting to add type annotations to extracted functions

## Development Server (`npm start`)

`npm start` runs [scripts/run.js](scripts/run.js), which babysits the local dev
stack: it picks a free port (8000, 8002, … — lamdera also reserves port+1), does
a one-shot `build:css`, starts the Tailwind and cachebust watchers, pre-warms
`elm-stuff`, and launches `lamdera live` (auto-restarting it on a crash or a
known bad-state pattern). Force a port with `LAMDERA_PORT=8004 npm start`.

For screenshots and frontend debugging use the Claude in Chrome tools against
that port. Each worktree should run its own `lamdera live` on its own port.

## Inspecting the BackendModel (`lamdera backend`)

For reading **backend state**, use `lamdera backend` — it evaluates an Elm
expression against the live `lamdera live` BackendModel and prints the result.
It's read-only, needs no browser, and falls back to the last saved
BackendModel if `lamdera live` isn't running.

```bash
lamdera backend --no-colors --eval='model.mealPlan'          # focused query
lamdera backend --no-colors --import='import Set' --eval='…' # extra imports
lamdera backend --port 8002 --no-colors --eval='…'           # other worktree
```

- `model : Types.BackendModel` is in scope; `Dict` is imported by default.
- Prefer a focused `--eval`; the full model (calendars, webhook log) is large.
- The expression compiles against the *current directory's* code but reads the
  model from the server on `--port` (default 8000). With several worktrees,
  pass the matching `--port`.
- To *write* backend state, go through the app: drive the UI, or POST to an
  RPC endpoint (`curl -X POST localhost:8000/_r/<endpoint> -d '{…}'`).

## Git hooks, Tailwind and deploys

- `npm install` sets `core.hooksPath` to `.githooks`.
- `public/output.css` is committed (Lamdera serves `public/` from git). The
  pre-commit hook rebuilds it when `.elm`/CSS inputs are staged and restamps
  the `/output.css?dev=<hash>` cache-buster in `src/Frontend.elm`
  ([scripts/cachebust.js](scripts/cachebust.js)).
- The pre-commit hook also blocks committing `src/Env.elm` unless it matches
  `Env-Clean.elm` (keeps the Toggl key out of git).
- The pre-push hook runs `lamdera check` when Elm source changed, so a missing
  Evergreen migration is caught at PR time. Bypass with `git push --no-verify`.
- `npm run deploy` ([scripts/deploy.sh](scripts/deploy.sh)) deploys `main`
  from the primary checkout. See the `lamdera-deploy` skill.
- `elm-review` runs after every `.elm` edit via a `PostToolUse` hook in
  [.claude/settings.json](.claude/settings.json).

## Documentation
- Lamdera REPL docs: https://dashboard.lamdera.app/docs/repl
- Lamdera general docs: https://dashboard.lamdera.app/docs

## Linting and Testing
- After making code changes to `*.elm` files, run `elm-review` to check for linting errors
- Also run `npm test` to ensure all tests still pass (plain `elm-test` doesn't work here; it needs the lamdera compiler)
- Fix any elm-review errors and test failures before considering the task complete
- Common elm-review rules in this project:
  - `NoExposingEverything` - Use explicit exports instead of `exposing (..)`
  - `NoImportingEverything` - Use explicit imports instead of `import X exposing (..)`
  - `NoMissingTypeAnnotation` - All top-level definitions need type annotations
  - `NoUnused.*` - Remove unused code (variables, imports, dependencies, etc.)

## Testing with lamdera/program-test

- Run tests: `npm test` (`elm-test-rs --compiler $(which lamdera)`)
- Tests location: `tests/E2ETests.elm`
- Visual debugger: `http://localhost:8000/tests/E2ETests.elm` (use arrow keys to step through)

### Testing Skills (invoke as needed)
- `/testing-quick-ref` - Common patterns, start here
- `/testing-http-mocking` - Mocking API requests
- `/testing-user-interaction` - Click, input, forms
- `/testing-view-assertions` - checkView, selectors, data-testid
- `/testing-timing` - Delays and time simulation
- `/testing-pitfalls` - Common mistakes and fixes
