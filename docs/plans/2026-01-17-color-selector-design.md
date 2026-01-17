# Color Selector for Edit/Create Calendar Modal

## Overview

Add color picker inputs to both the Create Calendar and Edit Calendar modals, allowing users to customize the `successColor` and `nonzeroColor` for their calendars.

## Requirements

- Native HTML color picker (`<input type="color">`)
- Color pickers in both Create and Edit modals
- Labels: "Success Color" / "Nonzero Color"
- When a project is selected in Create modal, auto-populate colors from the project's color (success = project color, nonzero = muted version)
- Migrate ColorLogic module to use `escherlies/elm-color` package throughout

## Data Model Changes

### Types.elm

Add `Color` import and update modal types:

```elm
type alias CreateCalendarModal =
    { selectedWorkspace : Maybe TogglWorkspace
    , selectedProject : Maybe TogglProject
    , calendarName : String
    , successColor : Color    -- NEW: defaults to blue, updates when project selected
    , nonzeroColor : Color    -- NEW: defaults to muted blue, updates when project selected
    }

type alias EditCalendarModal =
    { calendarId : HabitCalendar.HabitCalendarId
    , originalProjectId : Toggl.TogglProjectId
    , selectedWorkspace : Toggl.TogglWorkspace
    , selectedProject : Toggl.TogglProject
    , calendarName : String
    , successColor : Color    -- NEW: loaded from calendar
    , nonzeroColor : Color    -- NEW: loaded from calendar
    }
```

### New FrontendMsg variants

```elm
| SuccessColorChanged String      -- hex string from color picker
| NonzeroColorChanged String
| EditSuccessColorChanged String
| EditNonzeroColorChanged String
```

### Updated ToBackend message

```elm
| UpdateCalendar HabitCalendarId String TogglWorkspaceId TogglProjectId Color Color
```

## ColorLogic Migration

Replace hex-string-based functions with `Color`-based ones using `escherlies/elm-color`:

**Remove:**
- `isColorDark : String -> Bool` (use `Color.isLight` from package)
- `muteColor : String -> String`

**Add:**
```elm
colorToHex : Color -> String      -- For HTML color input value attribute
hexToColor : String -> Color      -- Parse color picker input / project colors
muteColorValue : Color -> Color   -- Derive nonzeroColor from successColor
```

## UI Changes

Add color picker section to both modals (after calendar name input):

```
Colors
Success Color       Nonzero Color
[████████]          [████████]
```

Each picker uses `<input type="color">` with:
- `value` set via `colorToHex`
- `onInput` triggering the appropriate color changed message

## Update Logic

### Create Calendar Modal
- Initialize with default blue colors
- `SelectProject`: Update successColor from project.color, derive nonzeroColor via `muteColorValue`
- `SuccessColorChanged`: Parse hex, update successColor
- `NonzeroColorChanged`: Parse hex, update nonzeroColor
- `SubmitCreateCalendar`: Pass colors when creating calendar

### Edit Calendar Modal
- Initialize colors from existing calendar
- `EditCalendarSelectProject`: Update colors from new project
- `EditSuccessColorChanged` / `EditNonzeroColorChanged`: Update colors
- `SubmitEditCalendar`: Pass colors in UpdateCalendar message

## Files to Modify

1. `src/ColorLogic.elm` - Migrate to Color type, add new functions
2. `src/Types.elm` - Add Color import, update modal types, add messages
3. `src/UI/Modal.elm` - Add color picker UI to both modals
4. `src/UI/CalendarView.elm` - Update to use Color.isLight
5. `src/UI/TimerBanner.elm` - Update if using color functions
6. `src/Frontend.elm` - Handle new messages, update modal init, pass colors
7. `src/Backend.elm` - Handle updated UpdateCalendar with colors
8. `src/HabitCalendar.elm` - May need helper for custom colors
9. Tests - Update affected tests
