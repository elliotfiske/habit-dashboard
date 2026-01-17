# lamdera/program-test Documentation

> **Note**: This documentation is also available as a Claude Skill. When using Claude Code, you can invoke it with `/lamdera-program-test` to get assistance with writing tests.

This document contains learnings about using `lamdera/program-test` for end-to-end testing of Lamdera applications.

## Table of Contents

1. [Test Structure](#test-structure)
2. [Frontend Actions](#frontend-actions)
3. [UI Interactions (Click, Input)](#ui-interactions-click-input)
4. [HTTP Request Mocking](#http-request-mocking)
5. [Backend Updates](#backend-updates)
6. [View Testing](#view-testing)
7. [Data Test IDs](#data-test-ids)
8. [Test Timing](#test-timing)
9. [Mock Data Patterns](#mock-data-patterns)
10. [Common Pitfalls](#common-pitfalls)

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

- `actions.click : Int -> HtmlId -> Action`
  - Click on an element by its HTML id
  - Takes a delay in milliseconds
  - Takes an `HtmlId` (created with `Dom.id "element-id"`)

- `actions.input : Int -> HtmlId -> String -> Action`
  - Enter text into an input field
  - Takes a delay in milliseconds
  - Takes an `HtmlId` (created with `Dom.id "element-id"`)
  - Takes the text to enter

- `actions.clientId : ClientId`
  - The client ID for this frontend connection
  - Useful when triggering backend messages that need to know which client to respond to

## UI Interactions (Click, Input)

### Required Import

To use `click` and `input` actions, you need to import `Effect.Browser.Dom`:

```elm
import Effect.Browser.Dom as Dom
```

### Clicking Elements

Use `actions.click` to simulate clicking on an element:

```elm
-- Signature: click : Int -> HtmlId -> Action
actions.click 100 (Dom.id "my-button-id")
```

**Important**: The element must have an `Attr.id` attribute in your view code:

```elm
-- In your view:
Html.button
    [ Attr.id "submit-form"  -- Required for click to find it
    , Attr.class "btn btn-primary"
    , Events.onClick SubmitForm
    ]
    [ Html.text "Submit" ]

-- In your test:
actions.click 100 (Dom.id "submit-form")
```

### Entering Text in Inputs

Use `actions.input` to simulate typing into an input field:

```elm
-- Signature: input : Int -> HtmlId -> String -> Action
actions.input 100 (Dom.id "email-input") "user@example.com"
```

**Important**: The input element must have an `Attr.id` attribute:

```elm
-- In your view:
Html.input
    [ Attr.id "email-input"  -- Required for input to find it
    , Attr.type_ "email"
    , Attr.value model.email
    , Events.onInput EmailChanged
    ]
    []

-- In your test:
actions.input 100 (Dom.id "email-input") "user@example.com"
```

### Complete Example: Form Interaction

```elm
import Effect.Browser.Dom as Dom

-- ... in your test:
(\actions ->
    [ -- Click to open a modal
      actions.click 100 (Dom.id "open-modal-btn")

    -- Enter text in an input field
    , actions.input 100 (Dom.id "name-input") "My Calendar"

    -- Click submit button
    , actions.click 100 (Dom.id "submit-btn")

    -- Verify the result
    , actions.checkView 200
        (Test.Html.Query.has [ Test.Html.Selector.text "My Calendar" ])
    ]
)
```

### id vs data-testid

**For test framework interactions (`click`, `input`)**: Use `Attr.id`
- The test framework's `click` and `input` methods look up elements by HTML `id` attribute
- Use `Dom.id "element-id"` to reference them in tests

**For view assertions (`checkView`)**: Use `data-testid`
- The `Test.Html.Selector.attribute` selector can match any attribute
- `data-testid` is conventional for test-only identifiers that shouldn't affect styling

```elm
-- Element with both (when you need both interactions and assertions):
Html.button
    [ Attr.id "delete-calendar-123"  -- For click/input
    , Attr.attribute "data-testid" "delete-calendar-123"  -- For checkView queries
    , Events.onClick (DeleteCalendar id)
    ]
    [ Html.text "Delete" ]
```

## HTTP Request Mocking

The test framework allows you to intercept and mock HTTP requests made by your backend. This is more realistic than using `backendUpdate` to inject responses directly.

### The handleHttpRequest Config Option

The `config` record includes a `handleHttpRequest` function:

```elm
config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = handleHttpRequest  -- Your custom handler
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }
```

### Handler Signature

```elm
handleHttpRequest : { data : Effect.Test.Data FrontendModel BackendModel, currentRequest : HttpRequest } -> HttpResponse
```

**Parameters:**
- `data` - Current test state (frontend/backend models, time, etc.)
- `currentRequest` - The HTTP request being made

### HttpRequest Type

```elm
type alias HttpRequest =
    { requestedBy : RequestedBy  -- RequestedByFrontend ClientId | RequestedByBackend
    , method : String            -- "GET", "POST", "PATCH", etc.
    , url : String               -- Full URL
    , body : HttpBody            -- EmptyBody, StringBody, JsonBody, etc.
    , headers : List ( String, String )
    , sentAt : Time.Posix
    }
```

### HttpResponse Type

```elm
type HttpResponse
    = BadUrlResponse String
    | TimeoutResponse
    | NetworkErrorResponse
    | BadStatusResponse Effect.Http.Metadata String
    | BytesHttpResponse Effect.Http.Metadata Bytes
    | StringHttpResponse Effect.Http.Metadata String
    | JsonHttpResponse Effect.Http.Metadata Json.Encode.Value
    | TextureHttpResponse Effect.Http.Metadata Effect.WebGL.Texture.Texture
    | UnhandledHttpRequest
```

### Creating Response Metadata

For successful responses, you need to provide `Effect.Http.Metadata`:

```elm
okMetadata : String -> Effect.Http.Metadata
okMetadata url =
    { url = url
    , statusCode = 200
    , statusText = "OK"
    , headers = Dict.empty
    }
```

### Example: Mocking an API

```elm
import Dict
import Effect.Http
import Effect.Test exposing (HttpRequest, HttpResponse(..))
import Json.Encode as E

handleHttpRequest : { data : Effect.Test.Data FrontendModel BackendModel, currentRequest : HttpRequest } -> HttpResponse
handleHttpRequest { currentRequest } =
    let
        url : String
        url =
            currentRequest.url
    in
    if String.contains "api.example.com/workspaces" url then
        -- Return mock workspaces
        JsonHttpResponse
            (okMetadata url)
            (E.list encodeWorkspace [ mockWorkspace ])

    else if String.contains "api.example.com/projects" url then
        -- Return mock projects
        JsonHttpResponse
            (okMetadata url)
            (E.list encodeProject [ mockProject ])

    else
        -- Unhandled request - return network error
        NetworkErrorResponse
```

### Triggering HTTP Requests in Tests

The most realistic approach is to click a button that triggers the HTTP request:

```elm
(\actions ->
    [ -- Click button that triggers HTTP request
      actions.click 100 (Dom.id "connect-toggl-button")

    -- Wait for HTTP response to be processed
    , actions.checkView 500
        (Test.Html.Query.has [ Test.Html.Selector.text "Connected" ])
    ]
)
```

Alternatively, use `actions.sendToBackend` to send a message directly:

```elm
(\actions ->
    [ -- Send message to backend that triggers HTTP request
      actions.sendToBackend 100 FetchTogglWorkspaces

    -- Wait for HTTP response to be processed
    , actions.checkView 500
        (Test.Html.Query.has [ Test.Html.Selector.text "Connected" ])
    ]
)
```

### JSON Encoders for Mock Data

Create encoders that match your API's response format:

```elm
encodeWorkspace : Toggl.TogglWorkspace -> E.Value
encodeWorkspace workspace =
    E.object
        [ ( "id", E.int (Toggl.togglWorkspaceIdToInt workspace.id) )
        , ( "name", E.string workspace.name )
        , ( "organization_id", E.int workspace.organizationId )
        ]
```

### HTTP Mocking vs backendUpdate

| Approach | Use Case |
|----------|----------|
| `handleHttpRequest` | Testing full request/response flow, realistic HTTP behavior |
| `backendUpdate` | Quick setup, bypassing HTTP layer, testing specific backend message handlers |

**Prefer HTTP mocking when:**
- Testing end-to-end flow including HTTP layer
- Verifying correct API URLs are called
- Testing error handling (timeouts, bad status, etc.)

**Prefer backendUpdate when:**
- Setting up initial state quickly
- Testing backend message handlers in isolation
- HTTP mocking would add unnecessary complexity

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

### Pitfall 6: Using String Instead of HtmlId for click/input

The `click` and `input` methods require an `HtmlId` type, not a plain string.

❌ **Wrong**:
```elm
actions.click 100 "my-button"
```

✅ **Correct**:
```elm
import Effect.Browser.Dom as Dom

actions.click 100 (Dom.id "my-button")
```

### Pitfall 7: Missing id Attribute on Elements

The `click` and `input` methods look up elements by HTML `id`, not `data-testid`.

❌ **Wrong** (element only has data-testid):
```elm
-- In view:
Html.button [ Attr.attribute "data-testid" "submit-btn" ] [ Html.text "Submit" ]

-- In test (will fail - can't find element):
actions.click 100 (Dom.id "submit-btn")
```

✅ **Correct** (element has id attribute):
```elm
-- In view:
Html.button [ Attr.id "submit-btn" ] [ Html.text "Submit" ]

-- In test:
actions.click 100 (Dom.id "submit-btn")
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
