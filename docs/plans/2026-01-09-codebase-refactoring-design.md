# Codebase Refactoring Design

**Date:** 2026-01-09
**Goal:** Refactor and re-architect the codebase to be more readable and modular without changing app behavior

## Overview

This design outlines a comprehensive refactoring of the Lamdera habit dashboard codebase. The primary goal is to improve code organization, readability, and maintainability while maintaining 100% behavioral compatibility. We'll verify no regressions occur by running the existing E2E/smoke tests after each incremental change.

### Current Pain Points

1. **Frontend.elm is too large** (1,268 lines) - Mixed concerns including update logic, view functions, and business logic all in one file
2. **View functions are hard to understand** - Complex nesting, unclear component boundaries
3. **Business logic mixed with UI** - Domain logic scattered across Frontend/Backend/view code instead of dedicated modules

### Success Criteria

✅ All `elm-test` tests pass
✅ All `elm-review` checks pass
✅ `lamdera live` runs without errors
✅ Manual smoke test: create calendar, view timer, stop timer
✅ Frontend.elm reduced to ~350 lines (73% smaller)
✅ 9 new focused modules with clear responsibilities
✅ **Zero behavior changes** - app works exactly the same

---

## Target Architecture

### Current State

- **Frontend.elm**: 1,268 lines - contains all update logic, view functions, helper functions, and business logic
- **Backend.elm**: 289 lines - all backend logic in one file
- **Supporting modules**: HabitCalendar, Toggl, Calendar, DateUtils, CalendarDict
- **Mixed concerns**: UI rendering, business logic, color calculations, and time formatting all intermingled

### New Architecture

**1. UI/ Directory - View Components**

All view functions extracted into dedicated UI modules:
- `UI/TimerBanner.elm` - Running timer display, stop timer error banner
- `UI/ConnectionCard.elm` - Toggl connection status card
- `UI/CalendarView.elm` - Calendar rendering and calendar cards
- `UI/Modal.elm` - Modal dialogs (create calendar modal)
- `UI/WebhookDebug.elm` - Webhook debug log view

**2. Feature-Based Logic Modules**

Business logic extracted from Frontend.elm:
- `ColorLogic.elm` - Color calculations (`isColorDark`, `muteColor`, hex parsing)
- `TimerLogic.elm` - Timer calculations (`relativeTimer`, duration formatting)
- `CalendarLogic.elm` - Calendar operations (demo entries, calendar refresh logic)

**3. Streamlined Frontend.elm**

The main Frontend module becomes a thin orchestration layer:
- `init`, `update`, `updateFromBackend` - dispatch to helpers
- `view` - compose UI components
- Import and wire together UI components and logic modules
- Target: ~300-400 lines (down from 1,268)

**4. Backend.elm**

Backend stays mostly as-is since it's already reasonably sized at 289 lines.

---

## Module Details

### UI/TimerBanner.elm

**Purpose**: Running timer display and error handling UI (~150 lines)

**Exports**:
```elm
view : Model -> Html FrontendMsg
-- Main entry point, shows error banner + timer banner

runningTimerHeader : Model -> Html FrontendMsg
-- The running/no-running timer display

stopTimerErrorBanner : Maybe String -> Html FrontendMsg
-- Error banner for failed stop timer requests
```

**Dependencies**:
- Needs `Model` for state access (runningEntry, currentTime, availableProjects, stopTimerError)
- Needs `ColorLogic` for background colors and contrast
- Needs `TimerLogic` for duration formatting
- Needs `FrontendMsg` types for click handlers

**Why this grouping**: The timer banner and error banner are tightly coupled - they always appear together in the UI and share context about the running timer.

---

### UI/ConnectionCard.elm

**Purpose**: Toggl connection status and "Create Calendar" button (~100 lines)

**Exports**:
```elm
view : Model -> Html FrontendMsg
-- The entire Toggl connection card UI
```

**Dependencies**:
- Needs `Model` for togglStatus, projectsLoading state
- Handles displaying connection status (NotConnected, Connecting, Connected, Error)
- Contains the "Create Calendar" button that opens the modal

**Why this grouping**: This is a distinct visual card component with clear boundaries. All Toggl connection UI lives here.

---

### UI/CalendarView.elm

**Purpose**: Calendar rendering and calendar card display (~120 lines)

**Exports**:
```elm
viewMain : Model -> Html FrontendMsg
-- Main entry point for calendar display area

viewCalendars : PointInTime -> Model -> List (Html FrontendMsg)
-- Returns list of calendar cards

viewCalendar : PointInTime -> RunningEntry -> HabitCalendar -> Html FrontendMsg
-- Individual calendar card with refresh button

viewDemoCalendar : PointInTime -> RunningEntry -> Html FrontendMsg
-- Demo calendar shown when no real calendars exist
```

**Dependencies**:
- Uses `Calendar.view` (existing module) for the actual calendar grid
- Needs `CalendarLogic.addDemoEntries` for demo data
- Needs `Model` to access calendars dictionary and runningEntry

**Why this grouping**: All calendar display logic in one place. These functions work together to show the main content area.

---

### UI/Modal.elm

**Purpose**: All modal dialog UI (~220 lines)

**Exports**:
```elm
view : Model -> Html FrontendMsg
-- Main entry - renders modal overlay or nothing

viewCreateCalendar : Model -> CreateCalendarModal -> Html FrontendMsg
-- The create calendar modal content

-- Helper view functions:
viewWorkspaceSelector : Model -> CreateCalendarModal -> Html FrontendMsg
viewProjectSelector : Model -> CreateCalendarModal -> Html FrontendMsg
viewCalendarNameInput : CreateCalendarModal -> Html FrontendMsg

-- Helper functions:
canSubmitCalendar : CreateCalendarModal -> Bool
workspaceButton : Maybe TogglWorkspace -> TogglWorkspace -> Html FrontendMsg
projectButton : Maybe TogglProject -> TogglProject -> Html FrontendMsg
```

**Dependencies**:
- Needs `Model` for availableProjects, projectsLoading state
- Uses `CreateCalendarModal` record from Types
- All modal-related click handlers (OpenCreateCalendarModal, CloseModal, SelectWorkspace, etc.)

**Why this grouping**: The modal is a complete, self-contained UI feature with ~200 lines of view code. All workspace selection, project selection, and form validation logic lives here.

**Internal organization**: The modal has three major sections (workspace selector, project selector, name input) that remain as internal helpers within the Modal module.

---

### UI/WebhookDebug.elm

**Purpose**: Debugging UI for webhook events (~70 lines)

**Exports**:
```elm
view : Model -> Html FrontendMsg
-- Main entry - renders debug log or nothing if empty

viewEntry : WebhookDebugEntry -> Html FrontendMsg
-- Individual webhook event display
```

**Dependencies**:
- Needs `Model.webhookDebugLog` (List WebhookDebugEntry)
- Uses `WebhookDebugEntry` type from Types
- Formats timestamps and displays raw JSON payloads

**Why this grouping**: This is debug/development UI that's completely separate from the core app functionality. Easy to disable or remove later if needed.

**Note**: This module is view-only with no complex logic. It's essentially a pretty-printer for webhook events.

---

### ColorLogic.elm

**Purpose**: Color manipulation and contrast calculations (~130 lines)

**Exports**:
```elm
isColorDark : String -> Bool
-- Determines if a hex color is dark (needs white text for readability)
-- Uses relative luminance: L = 0.2126*R + 0.7152*G + 0.0722*B

muteColor : String -> String
-- Takes a hex color and returns a muted/desaturated version
-- Currently reduces saturation to 20% for subtle backgrounds

parseHexColor : String -> Maybe (Int, Int, Int)
-- Helper: Parse hex string to RGB tuple
-- Internal helper that might be exposed for testing
```

**Dependencies**: None - pure functions operating on String inputs

**Why this module**: Color logic is currently ~122 lines in Frontend.elm with manual hex parsing. It's completely independent domain logic that has nothing to do with UI or state management. Perfect candidate for extraction.

**Benefits**:
- Testable in isolation (unit tests for color calculations)
- Reusable across the app (backend could use it for webhooks, etc.)
- Clear single responsibility

---

### TimerLogic.elm

**Purpose**: Time duration calculations and formatting (~60 lines)

**Exports**:
```elm
relativeTimer : Time.Posix -> Time.Posix -> String
-- Calculate duration between two times, format as "HH:MM:SS"
-- Used for running timer display

formatElapsedTime : Int -> String
-- Format seconds/minutes as "HH:MM:SS"
-- Extracted helper from relativeTimer

formatTimeOfDay : Time.Zone -> Time.Posix -> String
-- Format time as "h:mm AM/PM"
-- Currently in Frontend as formatTime function
```

**Dependencies**:
- `Time` module for Posix and Zone types
- `Duration` (possibly) for time calculations

**Why this module**: Timer formatting logic is scattered across Frontend.elm (~40 lines). These are pure calculations that should be separate from UI concerns. Having them in a dedicated module makes them easier to test and reason about.

**Benefits**:
- Unit testable with specific time inputs
- Clear separation: "how to calculate durations" vs "how to display them"
- Could be extended with more time utilities as needed

---

### CalendarLogic.elm

**Purpose**: Calendar-specific business operations (~80 lines)

**Exports**:
```elm
addDemoEntries : PointInTime -> HabitCalendar -> HabitCalendar
-- Add sample entries to a calendar for demo display
-- Currently generates entries at -1, -2, -3, -5, -6, -8, -10 days ago

createDemoCalendar : PointInTime -> HabitCalendar
-- Create a complete demo calendar with sample data
-- Combines emptyCalendar + addDemoEntries

calculateDateRange : Maybe Posix -> (String, String)
-- Calculate start/end dates for calendar refresh (last 28 days)
-- Currently inline logic in Frontend update function
```

**Dependencies**:
- `HabitCalendar` module for calendar operations
- `DateUtils` for date calculations
- `Time.Extra` for date arithmetic
- `Dict` for entries

**Why this module**: The demo calendar logic (~50 lines) is UI-adjacent business logic. The "last 28 days" calculation appears in the update function and could be extracted. This module captures "how to work with calendar data" separate from "how to display it."

**Benefits**:
- Centralizes calendar data manipulation
- Makes it easy to change demo data generation
- The `calculateDateRange` function eliminates duplication and magic numbers

---

## Restructured Frontend.elm

### What Stays in Frontend.elm

**Core responsibilities** (target: ~300-400 lines):
1. **Module definition and type aliases** (~20 lines)
2. **App configuration** - `app_`, `app` records (~20 lines)
3. **Init function** - Initial model and commands (~20 lines)
4. **Subscriptions** - Timer tick subscription (~10 lines)
5. **Update function** - Message routing and orchestration (~120 lines)
6. **UpdateFromBackend function** - Backend message handling (~40 lines)
7. **View function** - High-level composition (~30 lines)
8. **Update helper functions** - Complex update logic extracted (~80 lines)

### Import Organization

```elm
module Frontend exposing (...)

-- Core Elm and Effect modules
import Browser
import Effect.Browser.Navigation
import Effect.Command as Command
import Effect.Lamdera
import Effect.Time
-- ... other Effect imports

-- Domain types and data structures
import Types exposing (..)
import HabitCalendar exposing (HabitCalendar, HabitCalendarId(..))
import Toggl exposing (TogglProject, TogglWorkspace)
import CalendarDict
import DateUtils exposing (PointInTime)

-- Business logic modules (NEW)
import ColorLogic
import TimerLogic
import CalendarLogic

-- UI modules (NEW)
import UI.TimerBanner
import UI.ConnectionCard
import UI.CalendarView
import UI.Modal
import UI.WebhookDebug
```

### Simplified View Function

**After refactoring** (~30 lines, composition-focused):
```elm
view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div
            [ Attr.class "min-h-screen p-8"
            , viewBackgroundStyle model
            ]
            [ Html.div [ Attr.class "max-w-4xl mx-auto" ]
                [ UI.TimerBanner.view model
                , UI.ConnectionCard.view model
                , UI.CalendarView.viewMain model
                , UI.WebhookDebug.view model
                ]
            ]
        , UI.Modal.view model
        ]
    }

-- Helper for background color logic
viewBackgroundStyle : Model -> Html.Attribute FrontendMsg
viewBackgroundStyle model =
    case model.runningEntry of
        RunningEntry payload ->
            payload.projectId
                |> Maybe.andThen (\pid ->
                    List.filter (\p -> p.id == pid) model.availableProjects
                        |> List.head
                )
                |> Maybe.map (\project ->
                    Attr.style "background-color" (ColorLogic.muteColor project.color)
                )
                |> Maybe.withDefault (Attr.class "bg-base-200")

        NoRunningEntry ->
            Attr.class "bg-base-200"
```

### Update Function Structure

**Strategy**: Keep the main `update` function as a dispatcher, extract complex logic to helper functions

**After refactoring** (~120 lines, delegating to helpers):
```elm
update : FrontendMsg -> Model -> ( Model, Command ... )
update msg model =
    case msg of
        -- Simple cases stay inline
        UrlClicked _ ->
            ( model, Command.none )

        GotTime posix ->
            ( { model | currentTime = Just posix }, Command.none )

        Tick posix ->
            ( { model | currentTime = Just posix }, Command.none )

        -- Complex cases delegate to helpers
        CreateCalendar ->
            handleCreateCalendar model

        RefreshCalendar calendarId workspaceId projectId calendarName ->
            handleRefreshCalendar model calendarId workspaceId projectId calendarName

        SelectWorkspace workspace ->
            handleSelectWorkspace model workspace

        StopRunningTimer ->
            handleStopTimer model

        -- ... other messages

-- Helper functions below main update
handleCreateCalendar : Model -> ( Model, Command ... )
handleCreateCalendar model =
    case model.modalState of
        ModalCreateCalendar modalData ->
            case ( modalData.selectedWorkspace, modalData.selectedProject ) of
                ( Just workspace, Just project ) ->
                    let
                        calendarId = HabitCalendarId (Toggl.togglProjectIdToString project.id)
                        calendarInfo = { calendarId = calendarId, calendarName = modalData.calendarName }
                        (startDate, endDate) = CalendarLogic.calculateDateRange model.currentTime
                        userZone = Maybe.withDefault Time.utc model.currentZone
                    in
                    ( { model | modalState = ModalClosed }
                    , Effect.Lamdera.sendToBackend
                        (FetchTogglTimeEntries calendarInfo workspace.id project.id startDate endDate userZone)
                    )

                _ ->
                    ( model, Command.none )

        ModalClosed ->
            ( model, Command.none )

handleSelectWorkspace : Model -> TogglWorkspace -> ( Model, Command ... )
handleSelectWorkspace model workspace =
    -- Extracted workspace selection logic
    ...

handleStopTimer : Model -> ( Model, Command ... )
handleStopTimer model =
    -- Extracted stop timer logic
    ...
```

### Helper Function Guidelines

**Extract to helpers when**:
- Update case is >10 lines
- Contains nested case statements
- Has complex let bindings
- Involves multiple model updates

**Keep inline when**:
- Simple 1-line model updates
- No complex logic
- Direct Command.none returns

---

## Final File Structure

```
src/
├── Backend.elm                 (289 lines - unchanged)
├── Frontend.elm                (300-400 lines - restructured)
├── Types.elm                   (151 lines - unchanged)
│
├── UI/                         (NEW directory)
│   ├── TimerBanner.elm        (~150 lines)
│   ├── ConnectionCard.elm     (~100 lines)
│   ├── CalendarView.elm       (~120 lines)
│   ├── Modal.elm              (~220 lines)
│   └── WebhookDebug.elm       (~70 lines)
│
├── ColorLogic.elm             (~130 lines - NEW)
├── TimerLogic.elm             (~60 lines - NEW)
├── CalendarLogic.elm          (~80 lines - NEW)
│
├── Calendar.elm               (existing)
├── CalendarDict.elm           (existing)
├── DateUtils.elm              (existing)
├── HabitCalendar.elm          (existing)
├── Toggl.elm                  (existing)
├── RPC.elm                    (existing)
├── LamderaRPC.elm             (existing)
└── Env.elm                    (existing)
```

**Total line count**: ~1,680 lines (similar to current, but better organized)
- 9 new modules created
- Frontend.elm reduced from 1,268 → ~350 lines (73% reduction!)

---

## Migration Strategy

**Key principle**: Extract and verify incrementally. Run `elm-test` after EACH step to ensure no regressions.

### Phase 1: Extract Pure Logic (No UI Dependencies)

These modules are pure functions with no HTML dependencies - safest to extract first.

#### Step 1.1: Extract ColorLogic.elm (~30 mins)
- Create `src/ColorLogic.elm`
- Copy `isColorDark`, `muteColor`, and hex parsing logic
- Add explicit type signatures
- Update Frontend.elm to import and use `ColorLogic.isColorDark`, `ColorLogic.muteColor`
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 1.2: Extract TimerLogic.elm (~20 mins)
- Create `src/TimerLogic.elm`
- Copy `relativeTimer`, `formatTime` functions
- Update Frontend.elm imports
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 1.3: Extract CalendarLogic.elm (~30 mins)
- Create `src/CalendarLogic.elm`
- Copy `addDemoEntries` function
- Add `createDemoCalendar` helper
- Add `calculateDateRange` helper (extract from update function)
- Update Frontend.elm imports and usages
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

**Checkpoint**: At this point, Frontend.elm is ~1,000 lines (down from 1,268). All pure business logic extracted.

---

### Phase 2: Extract UI Modules (Has HTML Dependencies)

Extract view functions into UI/ modules. These have FrontendMsg dependencies.

#### Step 2.1: Create UI/ directory
```bash
mkdir src/UI
```

#### Step 2.2: Extract UI/WebhookDebug.elm (~20 mins)
- Simplest UI module - good warm-up
- Create `src/UI/WebhookDebug.elm`
- Copy `webhookDebugView` and `viewWebhookDebugEntry`
- Rename to just `view` and `viewEntry` (module provides namespace)
- Update Frontend.elm: `import UI.WebhookDebug` and call `UI.WebhookDebug.view model`
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 2.3: Extract UI/TimerBanner.elm (~40 mins)
- Create `src/UI/TimerBanner.elm`
- Copy `runningTimerHeader`, `stopTimerErrorBanner`
- Add main `view` function that combines both
- Update to use `ColorLogic` and `TimerLogic` imports
- Update Frontend.elm to use `UI.TimerBanner.view model`
- Run `elm-review` and `elm-test`
- Verify smoke tests pass (especially stop timer tests!)

#### Step 2.4: Extract UI/ConnectionCard.elm (~30 mins)
- Create `src/UI/ConnectionCard.elm`
- Copy `togglConnectionCard` function
- Rename to `view`
- Update Frontend.elm imports
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 2.5: Extract UI/CalendarView.elm (~40 mins)
- Create `src/UI/CalendarView.elm`
- Copy `viewCalendars`, `viewCalendar`, `viewDemoCalendar`
- Add `viewMain : Model -> Html FrontendMsg` as entry point
- Uses `CalendarLogic.addDemoEntries` for demo data
- Update Frontend.elm imports
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 2.6: Extract UI/Modal.elm (~50 mins)
- Create `src/UI/Modal.elm`
- Copy all modal-related functions:
  - `viewModal`, `viewCreateCalendarModal`
  - `viewWorkspaceSelector`, `viewProjectSelector`, `viewCalendarNameInput`
  - `workspaceButton`, `projectButton`
  - `canSubmitCalendar`
- Rename `viewModal` to `view`
- Update Frontend.elm imports
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

**Checkpoint**: At this point, Frontend.elm is ~500 lines. All view functions extracted.

---

### Phase 3: Restructure Frontend.elm Update Function

#### Step 3.1: Extract update helpers (~60 mins)
- Within Frontend.elm, create helper functions:
  - `handleCreateCalendar`
  - `handleRefreshCalendar`
  - `handleSelectWorkspace`
  - `handleSelectProject`
  - `handleStopTimer`
- Refactor update function to delegate to helpers
- No external changes - just internal reorganization
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

#### Step 3.2: Simplify view function (~20 mins)
- Extract `viewBackgroundStyle` helper
- Simplify main view to pure composition
- Run `elm-review` and `elm-test`
- Verify smoke tests pass

**Final checkpoint**: Frontend.elm is now ~350 lines. Clean, focused, maintainable!

---

## Migration Verification Strategy

**After EVERY step**:
1. `elm-review` - must pass with no errors
2. `elm-test` - all smoke tests must pass
3. Visual check: `lamdera live` and click through the UI

**Key test scenarios** (from existing smoke tests):
- Calendar displays correctly with dates
- Running timer shows with correct format
- Stop timer button works (optimistic update)
- Modal opens and closes
- Workspace/project selection works
- Demo calendar appears when no calendars exist

**If a step breaks tests**:
- Don't proceed to next step
- Fix the issue immediately
- Re-run tests until green
- Then continue

---

## Risk Assessment

### Low Risk
- Extracting pure logic (Phase 1) - no UI dependencies
- Extracting simple view modules (WebhookDebug, ConnectionCard)

### Medium Risk
- Extracting complex view modules (Modal, CalendarView) - many message types
- Restructuring update function - easy to miss a case

### Mitigation Strategies

1. **One step at a time** - never combine extractions
2. **Test after every step** - catch issues immediately
3. **Keep git history clean** - one commit per extraction step
4. **Use exact copy-paste** - don't refactor while extracting
5. **Verify imports** - elm-review will catch missing imports

---

## Implementation Notes

- The refactoring should be done in a git worktree or feature branch
- Each phase should be a separate commit for easy rollback if needed
- The design prioritizes safety over speed - incremental verification prevents bugs
- No behavioral changes means users see zero difference in the app
- The test suite is our safety net - it must always be green

---

## Benefits of This Refactoring

1. **Improved Readability**: Each module has a clear, focused purpose
2. **Better Testability**: Pure logic modules can be unit tested in isolation
3. **Easier Navigation**: Finding code is straightforward with clear module names
4. **Reduced Cognitive Load**: Frontend.elm is 73% smaller and easier to understand
5. **Better Reusability**: Logic modules can be used across frontend and backend
6. **Clearer Dependencies**: Import statements tell the story of module relationships
7. **Easier Onboarding**: New developers can understand the architecture quickly
8. **Future-Proof**: Adding new features becomes easier with clear patterns

---

## Future Considerations

After this refactoring is complete, potential next steps:
1. Add unit tests for ColorLogic, TimerLogic, CalendarLogic modules
2. Consider extracting Backend Toggl API logic if it grows
3. Evaluate if Types.elm should be split into domain-specific type modules
4. Consider adding a UI/Common.elm for shared UI utilities
5. Explore extracting update logic into Update/ modules if complexity grows
