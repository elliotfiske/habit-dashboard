---
name: lamdera-program-test
description: Use when writing or debugging end-to-end tests with lamdera/program-test for Lamdera applications
---

# lamdera/program-test Documentation

This document contains learnings about using `lamdera/program-test` for end-to-end testing of Lamdera applications.

## Table of Contents

1. [Test Structure](#test-structure)
2. [Frontend Actions](#frontend-actions)
3. [Backend Updates](#backend-updates)
4. [View Testing](#view-testing)
5. [Data Test IDs](#data-test-ids)
6. [Test Timing](#test-timing)
7. [Mock Data Patterns](#mock-data-patterns)
8. [Common Pitfalls](#common-pitfalls)

## Test Structure

### Basic Test Template

Tests are created using `Effect.Test.start`:

```elm
Effect.Test.start
    "Test description"
    (Effect.Time.millisToPosix startTimeMillis)  -- Simulated time
    config
    [ Effect.Test.connectFrontend
        delayMs
        (Effect.Lamdera.sessionIdFromString "sessionId0")
        "/"
        { width = 800, height = 600 }
        (\actions ->
            [ -- List of test actions
            ]
        )
    ]
```

### Time Simulation

The second argument to `Effect.Test.start` sets the simulated start time for the entire test. This affects:
- `Effect.Time.now` calls in your frontend
- `Effect.Time.here` calls for timezone
- Any time-based logic

```elm
-- January 1, 2026 00:00:00 UTC in milliseconds since epoch
january1st2026 : Int
january1st2026 = 1767225600000

Effect.Test.start
    "My test"
    (Effect.Time.millisToPosix january1st2026)
    config
    [ -- ... rest of test
    ]
```

### Config Record

The config tells the test framework how to initialize your app:

```elm
config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = always NetworkErrorResponse  -- Mock HTTP responses
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }
```

## Frontend Actions

### The FrontendActions Record

When you use `Effect.Test.connectFrontend`, the callback receives a `FrontendActions` record:

```elm
Effect.Test.connectFrontend
    1000
    (Effect.Lamdera.sessionIdFromString "sessionId0")
    "/"
    { width = 800, height = 600 }
    (\actions ->
        [ -- actions is a FrontendActions record
          actions.checkView 100 (...)
        , actions.click [ ... ]
        , -- etc
        ]
    )
```

**Important**: The parameter is NOT a tuple or named `client1` - it's a record called `FrontendActions`.

### Available Methods

From reading the source code in `EXTERNAL-lamdera-program-test/src/Effect/Test.elm`, `FrontendActions` provides:

- `actions.checkView : Int -> (Query msg -> Expectation) -> Action`
  - Check the rendered HTML after a delay
  - Takes a delay in milliseconds
  - Takes a Test.Html.Query function

- `actions.clientId : ClientId`
  - The client ID for this frontend connection
  - Useful when triggering backend messages that need to know which client to respond to

- Other methods like `click`, `update`, `sendToBackend` (not fully explored yet)

## Backend Updates

### Triggering Backend Messages Directly

Use `Effect.Test.backendUpdate` to simulate backend events without making real HTTP calls:

```elm
Effect.Test.backendUpdate 100
    (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
```

This is useful for:
- Simulating API responses
- Simulating webhook events
- Testing backend message handlers
- Avoiding rate limits or external dependencies

### Passing Client ID

Many backend messages need to know which client to respond to. Use `actions.clientId`:

```elm
Effect.Test.backendUpdate 100
    (GotTogglTimeEntries
        actions.clientId  -- <-- Pass the client ID
        mockCalendarInfo
        mockWorkspace.id
        mockProject.id
        Time.utc
        (Ok [ mockTimeEntry ])
    )
```

## View Testing

### Using checkView

`checkView` takes two parameters:
1. **Delay in milliseconds**: How long to wait before checking
2. **Query function**: A function that queries and asserts on the HTML

```elm
actions.checkView 200
    (Test.Html.Query.find
        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
        >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
    )
```

### Query Pipeline Pattern

Use the `>>` operator to chain query operations:

```elm
(Test.Html.Query.find [ selector1, selector2 ]  -- Find element
    >> Test.Html.Query.has [ assertion1 ]       -- Assert it has something
)
```

### Common Selectors

```elm
-- By test ID (most reliable)
Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "my-element")

-- By text content
Test.Html.Selector.text "Submit"

-- By tag
Test.Html.Selector.tag "button"

-- By class
Test.Html.Selector.class "btn-primary"

-- Containing text (matches parent elements too - be careful!)
Test.Html.Selector.containing [ Test.Html.Selector.text "some text" ]
```

## Data Test IDs

### Why Use data-testid?

**Problem**: Text-based selectors can match parent elements unintentionally.

For example, `containing [ text "1/2" ]` matches:
- The day cell with "1/2"
- The week row containing that cell
- The calendar containing that row
- The entire page body

If you then check `.has [ text "-" ]`, it might pass because a *different* cell in the same parent contains "-".

**Solution**: Add `data-testid` attributes to elements you need to select in tests.

### Adding data-testid in Elm

```elm
div
    [ attribute "data-testid" "day-2026-01-02"
    , class "day-cell"
    ]
    [ text "1/2" ]
```

### Selecting by data-testid in Tests

```elm
Test.Html.Query.find
    [ Test.Html.Selector.attribute
        (Html.Attributes.attribute "data-testid" "day-2026-01-02")
    ]
```

### Dynamic Test IDs

For collections of similar elements, use dynamic IDs:

```elm
-- In your view code
div [ attribute "data-testid" ("day-" ++ formatIsoDate day) ] [ ... ]
div [ attribute "data-testid" ("project-" ++ String.fromInt projectId) ] [ ... ]
```

## Test Timing

### Understanding Delays

Each action in a test can have a delay:

```elm
[ Effect.Test.backendUpdate 100 (...)  -- Wait 100ms, then trigger
, actions.checkView 200 (...)          -- Wait 200ms after previous action, then check
, Effect.Test.backendUpdate 100 (...)  -- Wait 100ms after previous action
]
```

Delays are cumulative and relative to the previous action.

### Why Delays Matter

- Give time for Cmds to execute
- Give time for the Elm runtime to re-render
- Give time for subscriptions to fire
- Simulate realistic user interaction timing

### Typical Delay Values

- `100ms`: Quick backend update or UI check
- `200ms`: Checking view after multiple updates
- `1000ms`: Initial frontend connection

## Mock Data Patterns

### Creating Mock Types

Create realistic mock data for your Toggl types:

```elm
mockWorkspace : Toggl.TogglWorkspace
mockWorkspace =
    { id = Toggl.TogglWorkspaceId 12345
    , name = "Test Workspace"
    , organizationId = 1
    }

mockProject : Toggl.TogglProject
mockProject =
    { id = Toggl.TogglProjectId 159657524
    , workspaceId = Toggl.TogglWorkspaceId 12345
    , name = "Chores"
    , color = "#9E77ED"
    }
```

### Time-based Mock Data

For time entries, calculate times relative to your test start time:

```elm
mockTimeEntry : Toggl.TimeEntry
mockTimeEntry =
    { id = Toggl.TimeEntryId 999
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , description = Just "Cleaning"
    , start = Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000))  -- 9 AM
    , stop = Just (Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000) + (30 * 60 * 1000)))  -- 9:30 AM
    , duration = 1800  -- 30 minutes in seconds
    }
```

### Creating Test Scenarios

Create multiple variants for testing different scenarios:

```elm
-- Original entry: 30 minutes
mockTimeEntry : Toggl.TimeEntry
mockTimeEntry = { duration = 1800, ... }

-- Second entry: 45 minutes (for testing "created" webhook)
mockTimeEntry2 : Toggl.TimeEntry
mockTimeEntry2 = { duration = 2700, ... }

-- Updated entry: 60 minutes (for testing "updated" webhook)
mockUpdatedTimeEntry : Toggl.TimeEntry
mockUpdatedTimeEntry = { id = Toggl.TimeEntryId 999, duration = 3600, ... }
```

## Common Pitfalls

### Pitfall 1: Wrong Callback Parameter Name

❌ **Wrong**:
```elm
Effect.Test.connectFrontend 1000 sessionId "/" viewport (\client1 -> ...)
```

✅ **Correct**:
```elm
Effect.Test.connectFrontend 1000 sessionId "/" viewport (\actions -> ...)
```

The parameter is a `FrontendActions` record, not a client object.

### Pitfall 2: Missing Constructor Imports

If you get "I cannot find a 'MyMsg' type" errors:

❌ **Wrong**:
```elm
import Types exposing (FrontendMsg, BackendMsg)
```

✅ **Correct**:
```elm
import Types exposing (FrontendMsg(..), BackendMsg(..))
```

You need to import the constructors `(..)` to pattern match or construct messages.

### Pitfall 3: containing Selector Matches Parents

❌ **Unreliable**:
```elm
Test.Html.Query.find [ Test.Html.Selector.containing [ text "1/2" ] ]
    >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
```

This can match a parent element containing both "1/2" and "-" in different child elements.

✅ **Reliable**:
```elm
Test.Html.Query.find
    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-02") ]
    >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
```

### Pitfall 4: Not Passing Required IDs

When your backend message signature changes, update all the test calls:

```elm
-- Before
GotTogglTimeEntries clientId calendarInfo userZone result

-- After (added workspaceId and projectId)
GotTogglTimeEntries clientId calendarInfo workspaceId projectId userZone result

-- Update your test:
Effect.Test.backendUpdate 100
    (GotTogglTimeEntries
        actions.clientId
        mockCalendarInfo
        mockWorkspace.id      -- Don't forget!
        mockProject.id        -- Don't forget!
        Time.utc
        (Ok [ mockTimeEntry ])
    )
```

### Pitfall 5: Insufficient Delays

If your test is flaky or assertions fail unexpectedly, try increasing delays:

```elm
-- Too quick, might not have time to render
actions.checkView 10 (...)

-- Better
actions.checkView 100 (...)

-- Even safer for complex updates
actions.checkView 200 (...)
```

## Testing Patterns

### Pattern: Simulating Webhook Events

Instead of triggering real RPC endpoints, simulate the result:

```elm
-- Simulate "created" webhook: send data with both entries
Effect.Test.backendUpdate 100
    (GotTogglTimeEntries
        actions.clientId
        mockCalendarInfo
        mockWorkspace.id
        mockProject.id
        Time.utc
        (Ok [ mockTimeEntry, mockTimeEntry2 ])  -- Both entries
    )

-- Simulate "updated" webhook: send updated entry
Effect.Test.backendUpdate 100
    (GotTogglTimeEntries
        actions.clientId
        mockCalendarInfo
        mockWorkspace.id
        mockProject.id
        Time.utc
        (Ok [ mockUpdatedTimeEntry ])  -- Modified entry
    )

-- Simulate "deleted" webhook: send remaining entries only
Effect.Test.backendUpdate 100
    (GotTogglTimeEntries
        actions.clientId
        mockCalendarInfo
        mockWorkspace.id
        mockProject.id
        Time.utc
        (Ok [ mockTimeEntry2 ])  -- Only second entry remains
    )
```

### Pattern: Multi-step Test Flow

Build complex scenarios step-by-step:

```elm
(\actions ->
    [ -- Step 1: Initial setup
      Effect.Test.backendUpdate 100
        (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))

    , Effect.Test.backendUpdate 100
        (GotTogglProjects actions.clientId (Ok [ mockProject ]))

    -- Step 2: Load initial data
    , Effect.Test.backendUpdate 100
        (GotTogglTimeEntries actions.clientId mockCalendarInfo mockWorkspace.id mockProject.id Time.utc (Ok [ mockTimeEntry ]))

    -- Step 3: Verify initial state
    , actions.checkView 200
        (Test.Html.Query.find [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
            >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
        )

    -- Step 4: Simulate change
    , Effect.Test.backendUpdate 100
        (GotTogglTimeEntries actions.clientId mockCalendarInfo mockWorkspace.id mockProject.id Time.utc (Ok [ mockTimeEntry, mockTimeEntry2 ]))

    -- Step 5: Verify updated state
    , actions.checkView 200
        (Test.Html.Query.find [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
            >> Test.Html.Query.has [ Test.Html.Selector.text "75" ]
        )
    ]
)
```

## Resources

- Source code: `EXTERNAL-lamdera-program-test/src/Effect/Test.elm`
- Visual test timeline: `http://localhost:8000/tests/SmokeTests.elm`
- Use arrow keys (Left/Right) to step through timeline
- Click "clientId 0" to see frontend client view at each step
