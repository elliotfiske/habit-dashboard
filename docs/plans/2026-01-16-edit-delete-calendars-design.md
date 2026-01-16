# Edit and Delete Habit Calendars

## Overview

Add edit and delete functionality for habit calendars, allowing users to modify calendar settings or remove calendars entirely.

## UI Changes

### Calendar Card Header

Add edit and delete buttons to the card header in `UI.CalendarView`, next to the existing refresh button:

```
┌─────────────────────────────────────────┐
│ My Habit          🔄  ✏️  🗑️            │
│                                         │
│  [Calendar grid...]                     │
│                                         │
└─────────────────────────────────────────┘
```

- **Edit (✏️)** - Opens edit modal pre-populated with current values
- **Delete (🗑️)** - Shows `window.confirm()`, deletes on confirmation

## Edit Modal

The edit modal mirrors the create modal structure but pre-populated with current values.

### Fields

- Workspace selector (pre-selected with current workspace)
- Project selector (pre-selected with current project, projects pre-loaded)
- Calendar name input (pre-filled with current name)

### Buttons

- Cancel - closes modal
- Save - saves changes

### Behavior on Save

- If project changed: update calendar, clear entries, fetch new data from Toggl
- If only name changed: just update the name (no re-fetch needed)

### Future Enhancement

Color picker for success/nonzero colors will be added later.

## Types

### New Modal State

```elm
type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
    | ModalEditCalendar EditCalendarModal  -- NEW

type alias EditCalendarModal =
    { calendarId : HabitCalendarId
    , originalProjectId : TogglProjectId  -- To detect if project changed
    , selectedWorkspace : TogglWorkspace
    , selectedProject : TogglProject
    , calendarName : String
    }
```

### New Messages

```elm
-- Frontend messages
| OpenEditCalendarModal HabitCalendar
| SubmitEditCalendar
| DeleteCalendar HabitCalendarId

-- ToBackend
| UpdateCalendar HabitCalendarId String TogglWorkspaceId TogglProjectId
| DeleteCalendarRequest HabitCalendarId

-- ToFrontend (reuse existing)
| CalendarsUpdated CalendarDict  -- Already exists, handles updates/deletes
```

## Data Flow

### Edit Flow

1. User clicks ✏️ on calendar card
2. `OpenEditCalendarModal` message fired with calendar data
3. Modal opens pre-populated with current workspace, project, and name
4. User modifies fields and clicks Save
5. `SubmitEditCalendar` message fired
6. Frontend sends `UpdateCalendar` to backend
7. Backend updates calendar in `CalendarDict`
8. If project changed, backend clears entries and fetches new data from Toggl
9. Backend broadcasts `CalendarsUpdated` to all clients

### Delete Flow

1. User clicks 🗑️ on calendar card
2. Browser `confirm()` dialog shown: "Are you sure you want to delete [name]?"
3. If confirmed, `DeleteCalendar` message fired
4. Frontend sends `DeleteCalendarRequest` to backend
5. Backend removes calendar from `CalendarDict`
6. Backend broadcasts `CalendarsUpdated` to all clients

## E2E Tests

Add tests to `tests/SmokeTests.elm` covering:

### Edit Happy Path

1. Create a calendar (using existing flow)
2. Click edit button on the calendar card
3. Verify modal opens with pre-populated values (name input has current name)
4. Change the calendar name
5. Click Save
6. Verify modal closes
7. Verify calendar card shows updated name

### Edit Validation

1. Open edit modal for an existing calendar
2. Clear the calendar name (empty string)
3. Verify Save button is disabled
4. Enter a new name
5. Verify Save button becomes enabled

### Delete Happy Path

1. Create a calendar
2. Verify calendar card is visible
3. Click delete button (test will simulate confirm returning true)
4. Verify calendar card is removed from the view

### Delete Cancellation

1. Create a calendar
2. Click delete button (test will simulate confirm returning false)
3. Verify calendar card is still visible

**Note:** Browser `confirm()` in tests will need to be handled via Effect.Browser or similar test infrastructure.

## Files to Modify

- `src/Types.elm` - Add new types and messages
- `src/UI/CalendarView.elm` - Add edit/delete buttons to card header
- `src/UI/Modal.elm` - Add edit modal rendering
- `src/Frontend.elm` - Handle new messages
- `src/Backend.elm` - Handle update/delete requests
- `tests/SmokeTests.elm` - Add E2E tests for edit/delete
