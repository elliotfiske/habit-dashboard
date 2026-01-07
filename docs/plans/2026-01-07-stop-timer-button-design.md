# Stop Timer Button Design

**Date:** 2026-01-07
**Feature:** Add a "Stop Timer" button to the Running Timer view

## Overview

Add a button to the running timer banner that allows users to stop their currently running Toggl timer directly from the habit dashboard, without needing to open Toggl Track.

## User Experience

### Button Behavior
- When clicked, the button immediately hides the running timer (optimistic UI update)
- The app sends a request to the Toggl API to stop the timer
- If successful: The timer remains stopped (webhook will eventually sync the state)
- If failed: The timer reappears with an error banner above it

### Error Handling
- Errors display in a dismissible banner above the running timer
- Only one error banner can be visible at a time
- The error banner includes:
  - Clear error message explaining what went wrong
  - Dismiss button (×) to clear the error
- The timer state is restored immediately when an error occurs

## Architecture

### New Message Types

**FrontendMsg:**
```elm
| StopRunningTimer          -- User clicked the stop button
| DismissStopTimerError     -- User dismissed the error banner
```

**ToBackend:**
```elm
| StopTogglTimer TogglWorkspaceId Int  -- workspaceId, timeEntryId
```

**BackendMsg:**
```elm
| GotStopTimerResponse Effect.Lamdera.ClientId (Result Toggl.TogglApiError ())
```

**ToFrontend:**
```elm
| StopTimerFailed String RunningEntry  -- error message, current timer state
```

### Model Changes

**FrontendModel:**
```elm
{ ...
, stopTimerError : Maybe String  -- Error message if stop timer fails
}
```

### Data Flow

1. User clicks "Stop Timer" button → triggers `StopRunningTimer`
2. Frontend update:
   - Sets `runningEntry = NoRunningEntry` (optimistic)
   - Clears `stopTimerError = Nothing`
   - Sends `StopTogglTimer workspaceId entryId` to backend
3. Backend receives `StopTogglTimer`:
   - Makes PATCH request to Toggl API
   - Triggers `GotStopTimerResponse` with result
4. Backend handles response:
   - **Success**: Do nothing (webhook will sync state)
   - **Failure**: Send `StopTimerFailed errorMsg runningEntry` to frontend
5. Frontend receives `StopTimerFailed`:
   - Restores `runningEntry` from message payload
   - Sets `stopTimerError = Just errorMsg`
6. User clicks dismiss (×) → triggers `DismissStopTimerError`:
   - Clears `stopTimerError = Nothing`

## UI Components

### Stop Button

**Location:** Right side of running timer banner, next to the timer duration display

**Styling:**
- DaisyUI classes: `btn btn-sm btn-ghost`
- Text: "Stop" or icon: "■"
- Test ID: `data-testid="stop-timer-button"`

**Visibility:**
- Only visible when `runningEntry = RunningEntry payload`
- Disappears immediately on click (due to optimistic update)

**Layout (in runningTimerHeader):**
```
┌─────────────────────────────────────────────────────────┐
│ ⭘ Task Description              HH:MM:SS    [Stop]      │
│   Currently tracking                                     │
└─────────────────────────────────────────────────────────┘
```

### Error Banner

**Location:** Above the running timer header

**Styling:**
- DaisyUI classes: `alert alert-error mb-4`
- Includes dismiss button (×) on the right
- Test ID: `data-testid="stop-timer-error"`

**Visibility:**
- Only visible when `stopTimerError = Just errorMsg`
- Dismissed via `DismissStopTimerError` message

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│ ⚠ Failed to stop timer: [error message]            [×] │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ ⭘ Task Description              HH:MM:SS    [Stop]      │
│   Currently tracking                                     │
└─────────────────────────────────────────────────────────┘
```

## Toggl API Integration

### Endpoint

```
PATCH /api/v9/workspaces/{workspace_id}/time_entries/{time_entry_id}/stop
```

### Implementation

Add to Toggl module:
```elm
stopTimeEntry :
    TogglWorkspaceId
    -> Int
    -> (Result TogglApiError () -> msg)
    -> Cmd msg
```

### Required Data

Extract from `RunningEntry` payload:
- `workspace_id` - The workspace where the timer is running
- `time_entry_id` - The ID of the running time entry

### Error Messages

Map API errors to user-friendly messages:

| Error | User Message |
|-------|--------------|
| Network error | "Network error. Check your connection and try again." |
| 404 Not Found | "Timer not found. It may have already been stopped." |
| 401/403 Auth | "Authentication error. Try refreshing your Toggl connection." |
| 402 Rate Limit | Use existing rate limit handling (shows reset time in connection card) |
| Other | "Failed to stop timer: [error details]" |

**Note:** 402 errors should be handled consistently with existing rate limit code in the app.

## Testing Strategy

### Test Cases (in tests/SmokeTests.elm)

1. **Happy path**:
   - Start with running timer
   - Click stop button
   - Verify timer disappears
   - Verify backend receives stop request

2. **Error handling**:
   - Simulate API failure
   - Verify error banner appears
   - Verify timer is restored

3. **Error dismissal**:
   - Show error banner
   - Click dismiss (×)
   - Verify banner disappears

4. **No timer state**:
   - Set `runningEntry = NoRunningEntry`
   - Verify stop button doesn't appear

5. **Visual verification**:
   - Use test viewer at `localhost:8000/tests/SmokeTests.elm`
   - Step through timeline with arrow keys
   - Verify UI states at each step

### Edge Cases

1. **Timer already stopped externally**
   - User stops timer in Toggl app while our stop request is in flight
   - API returns 404 or 200 (both are acceptable)
   - Webhook will sync the correct state
   - No error shown to user

2. **Webhook races API response**
   - Webhook arrives saying timer stopped before API response returns
   - Optimistic update already cleared `runningEntry`
   - Webhook confirms the correct state
   - No special handling needed

3. **Page refresh during stop**
   - User refreshes page while stop request is in flight
   - Request continues on backend
   - Frontend reinitializes
   - Webhook will send correct state on reconnect
   - No special handling needed

4. **Already rate-limited (402)**
   - App already shows rate limit error in connection card
   - Stop button still visible (user might not notice rate limit)
   - Additional 402 from stop request reinforces rate limit state
   - Use existing 402 error handling

5. **Multiple rapid clicks**
   - **This cannot happen** - optimistic update removes button immediately
   - No special handling needed

## Implementation Checklist

- [ ] Add `stopTimerError : Maybe String` to FrontendModel
- [ ] Add new message types to Types.elm
- [ ] Implement `StopRunningTimer` handler in Frontend update
- [ ] Implement `DismissStopTimerError` handler in Frontend update
- [ ] Implement `StopTogglTimer` handler in Backend update
- [ ] Implement `StopTimerFailed` handler in Frontend updateFromBackend
- [ ] Add `stopTimeEntry` function to Toggl module
- [ ] Add Stop button to `runningTimerHeader` view
- [ ] Add error banner view function
- [ ] Add tests to SmokeTests.elm
- [ ] Run `elm-review` to check for linting errors
- [ ] Run `elm-test` to verify all tests pass
- [ ] Manual testing with Lamdera dev server
- [ ] Visual verification with test viewer
