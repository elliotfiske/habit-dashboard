# Monofocus Timer Button Design

## Overview

Add a button to the Coda Project Banner that starts a new Toggl timer with:
- Project: Monofocus (ID: 205793718)
- Workspace: 4150145
- Description: The current active Coda project name

## Data Flow

1. User clicks "Start Timer" button in Coda Project Banner
2. Frontend sends `StartMonofocusTimer codaProjectName` to backend
3. Backend calls Toggl API: `POST /workspaces/4150145/time_entries` with:
   - `project_id`: 205793718
   - `description`: the Coda project name (e.g., "Q1 Planning")
   - `start`: current time
   - `created_with`: "habit-dashboard"
4. If API fails, backend sends `StartMonofocusTimerFailed errorMessage` to frontend
5. If API succeeds, do nothing - the webhook notifies the app of the new running timer

## Button State Logic

**Disabled when:**
- `codaStatus` is NOT `CodaOneActive` (no valid Coda project)
- OR `runningEntry` has `project_id == 205793718` (already running Monofocus)

**Enabled when:**
- `codaStatus` IS `CodaOneActive`
- AND (no timer running OR running timer is a different project)

If another timer is running, Toggl automatically stops it when the new one starts.

## Error Handling

- API returns 4xx/5xx: Show error with HTTP code, e.g., "Failed to start timer (401): unauthorized"
- Network timeout: Show "Failed to start timer: request timed out"
- Error dismissal: User can dismiss with X button (like `stopTimerError`)

## Files to Modify

| File | Changes |
|------|---------|
| `src/Coda.elm` | Add `monofocusProjectId`, `monofocusWorkspaceId` constants |
| `src/Types.elm` | Add `StartMonofocusTimer` msg, `StartMonofocusTimerFailed` ToFrontend, `startMonofocusTimerError` field |
| `src/Toggl.elm` | Add `startTimeEntry` function |
| `src/Frontend.elm` | Handle `StartMonofocusTimer` msg, send to backend, handle error response |
| `src/Backend.elm` | Handle `StartMonofocusTimer` ToBackend, call Toggl API, send error on failure |
| `src/UI/ProjectBanner.elm` | Add button with disabled logic, show error if present |
| `tests/E2ETests.elm` | Add tests for: button enabled/disabled states, starting timer sends correct request, error display |

## Not Implementing (YAGNI)

- Loading/pending state for button (fire-and-forget, webhook updates UI)
- Retry logic (user can click again)
- Confirmation dialog (action is reversible)
