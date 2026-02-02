# Monofocus Timer Button Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a button to the Coda Project Banner that starts a Toggl timer with the Monofocus project and the current Coda project name as description.

**Architecture:** Frontend button sends message to backend, backend calls Toggl API to create time entry. Success relies on existing webhook to update UI. Error response sent back to frontend for display.

**Tech Stack:** Elm (Lamdera), Toggl API v9, lamdera/program-test for E2E tests

---

### Task 1: Add Monofocus constants to Coda.elm

**Files:**
- Modify: `src/Coda.elm:1-12`

**Step 1: Add imports for Toggl types**

Add after line 11 (`import Types exposing (CodaProject, CodaStatus(..))`):

```elm
import Toggl exposing (TogglProjectId(..), TogglWorkspaceId(..))
```

**Step 2: Add Monofocus constants**

Add after line 32 (after `apiUrl` definition):

```elm
{-| The Toggl project ID for Monofocus.
-}
monofocusProjectId : Toggl.TogglProjectId
monofocusProjectId =
    TogglProjectId 205793718


{-| The Toggl workspace ID for Monofocus.
-}
monofocusWorkspaceId : Toggl.TogglWorkspaceId
monofocusWorkspaceId =
    TogglWorkspaceId 4150145
```

**Step 3: Update module exports**

Change line 1 from:
```elm
module Coda exposing (apiUrl, decodeCodaResponse, parseCodaStatus)
```
to:
```elm
module Coda exposing (apiUrl, decodeCodaResponse, monofocusProjectId, monofocusWorkspaceId, parseCodaStatus)
```

**Step 4: Run elm-review**

Run: `elm-review`
Expected: PASS (no errors)

**Step 5: Commit**

```bash
git add src/Coda.elm
git commit -m "feat: add Monofocus project/workspace constants to Coda.elm"
```

---

### Task 2: Add Types for start timer feature

**Files:**
- Modify: `src/Types.elm`

**Step 1: Add `startMonofocusTimerError` to FrontendModel**

In `FrontendModel` (around line 44), add after `codaStatus : CodaStatus`:

```elm
    , startMonofocusTimerError : Maybe String
```

**Step 2: Add `StartMonofocusTimer` to FrontendMsg**

In `FrontendMsg` (around line 177), add after `RefreshCodaProject`:

```elm
      -- Start Monofocus timer actions
    | StartMonofocusTimer String -- Coda project name as description
    | DismissStartMonofocusTimerError
```

**Step 3: Add `StartMonofocusTimer` to ToBackend**

In `ToBackend` (around line 190), add after `FetchCodaProject`:

```elm
    | StartMonofocusTimer String -- description
```

**Step 4: Add `StartMonofocusTimerFailed` to ToFrontend**

In `ToFrontend` (around line 228), add after `CodaStatusUpdated CodaStatus`:

```elm
    | StartMonofocusTimerFailed String
```

**Step 5: Add `GotStartTimerResponse` to BackendMsg**

In `BackendMsg` (around line 215), add after `GotCodaResponse (Result Effect.Http.Error String)`:

```elm
    | GotStartTimerResponse Effect.Lamdera.ClientId (Result Toggl.TogglApiError ())
```

**Step 6: Run elm-review**

Run: `elm-review`
Expected: FAIL with unused imports/types (expected, we'll use them next)

**Step 7: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add types for start Monofocus timer feature"
```

---

### Task 3: Add `startTimeEntry` function to Toggl.elm

**Files:**
- Modify: `src/Toggl.elm`

**Step 1: Add `startTimeEntry` to module exports**

Change line 1-32 exports to include `startTimeEntry`:

Find `stopTimeEntry` in the export list and add after it:
```elm
    , startTimeEntry
```

**Step 2: Add `startTimeEntry` function**

Add after `stopTimeEntry` function (around line 480):

```elm
{-| Start a new time entry.
POST https://api.track.toggl.com/api/v9/workspaces/{workspace_id}/time_entries
-}
startTimeEntry :
    ApiKey
    -> TogglWorkspaceId
    -> TogglProjectId
    -> String
    -> Time.Posix
    -> (Result TogglApiError () -> msg)
    -> Effect.Command.Command restriction toMsg msg
startTimeEntry apiKey workspaceId projectId description startTime toMsg =
    let
        url : String
        url =
            "https://api.track.toggl.com/api/v9/workspaces/"
                ++ String.fromInt (togglWorkspaceIdToInt workspaceId)
                ++ "/time_entries"

        body : E.Value
        body =
            E.object
                [ ( "workspace_id", E.int (togglWorkspaceIdToInt workspaceId) )
                , ( "project_id", E.int (togglProjectIdToInt projectId) )
                , ( "description", E.string description )
                , ( "start", E.string (Iso8601.fromTime startTime) )
                , ( "duration", E.int -1 )
                , ( "created_with", E.string "habit-dashboard" )
                ]
    in
    Effect.Http.request
        { method = "POST"
        , headers = [ authHeader apiKey ]
        , url = url
        , body = Effect.Http.jsonBody body
        , expect = Effect.Http.expectStringResponse toMsg (handleResponse (D.succeed ()))
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }
```

**Step 3: Add Time import**

Add to imports (around line 49, after `import Json.Encode as E`):

```elm
import Time
```

**Step 4: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 5: Run tests**

Run: `elm-test`
Expected: PASS

**Step 6: Commit**

```bash
git add src/Toggl.elm
git commit -m "feat: add startTimeEntry function to Toggl API module"
```

---

### Task 4: Handle StartMonofocusTimer in Frontend.elm

**Files:**
- Modify: `src/Frontend.elm`

**Step 1: Add Coda import**

Add after line 4 (`import CalendarDict`):

```elm
import Coda
```

**Step 2: Initialize `startMonofocusTimerError` in init**

In `init` function (around line 62), add after `codaStatus = Types.CodaNotFetched`:

```elm
      , startMonofocusTimerError = Nothing
```

**Step 3: Handle `StartMonofocusTimer` in update**

Add after the `RefreshCodaProject` case (around line 359):

```elm
        StartMonofocusTimer description ->
            ( { model | startMonofocusTimerError = Nothing }
            , Effect.Lamdera.sendToBackend (Types.StartMonofocusTimer description)
            )

        DismissStartMonofocusTimerError ->
            ( { model | startMonofocusTimerError = Nothing }, Command.none )
```

**Step 4: Handle `StartMonofocusTimerFailed` in updateFromBackend**

Add after the `CodaStatusUpdated` case (around line 602):

```elm
        StartMonofocusTimerFailed errorMsg ->
            ( { model | startMonofocusTimerError = Just errorMsg }, Command.none )
```

**Step 5: Run elm-review**

Run: `elm-review`
Expected: May warn about unused Coda import (will be used by UI module)

**Step 6: Commit**

```bash
git add src/Frontend.elm
git commit -m "feat: handle StartMonofocusTimer messages in Frontend"
```

---

### Task 5: Handle StartMonofocusTimer in Backend.elm

**Files:**
- Modify: `src/Backend.elm`

**Step 1: Add Time import**

Add after line 7 (`import Effect.Command as Command exposing (BackendOnly, Command)`):

```elm
import Effect.Time
```

**Step 2: Handle `StartMonofocusTimer` in updateFromFrontend**

Add after the `FetchCodaProject` case (around line 476):

```elm
        Types.StartMonofocusTimer description ->
            ( model
            , Command.batch
                [ Effect.Time.now
                    |> Effect.Task.perform
                        (\now ->
                            Toggl.startTimeEntry Env.togglApiKey
                                Coda.monofocusWorkspaceId
                                Coda.monofocusProjectId
                                description
                                now
                                (GotStartTimerResponse clientId)
                        )
                    |> (\_ ->
                            -- We need to get current time first, then start timer
                            -- This is a workaround since we can't chain tasks easily
                            Toggl.startTimeEntry Env.togglApiKey
                                Coda.monofocusWorkspaceId
                                Coda.monofocusProjectId
                                description
                                (Time.millisToPosix 0)
                                (GotStartTimerResponse clientId)
                       )
                ]
            )
```

Wait - that approach is wrong. Let me fix this. We need to use `Effect.Task` properly.

**Step 2 (corrected): Handle `StartMonofocusTimer` in updateFromFrontend**

Add after the `FetchCodaProject` case (around line 476):

```elm
        Types.StartMonofocusTimer description ->
            ( model
            , Effect.Time.now
                |> Effect.Task.andThen
                    (\now ->
                        Toggl.startTimeEntry Env.togglApiKey
                            Coda.monofocusWorkspaceId
                            Coda.monofocusProjectId
                            description
                            now
                            |> Effect.Task.succeed
                    )
                |> Effect.Task.perform (GotStartTimerResponse clientId)
            )
```

Hmm, that's also not right because `startTimeEntry` returns a `Command`, not a `Task`. Let me look at how other Toggl API calls handle this in the codebase...

Looking at the existing code, `stopTimeEntry` just takes the current time as a parameter and the caller doesn't need to pass time. For `startTimeEntry`, we need to pass the start time. Let me check the Toggl API...

Actually, looking at the Toggl API docs, we can just pass the current time from the backend. The simplest approach is to have the backend get the time and pass it. But since we're in a Command context, we need a different approach.

**Step 2 (final corrected version):** We'll modify the approach - have the backend use a two-step process where we first get the time, then make the API call. Actually, looking at the existing patterns, let's just use the current server time via a Task chain.

Actually, the cleanest solution is to add a new BackendMsg that receives the time, then makes the API call. Let me revise:

**Step 2: Add intermediate message for time-based start**

First, add to `BackendMsg` in Types.elm (we'll do this in Task 2 revision):

In Types.elm BackendMsg, add:
```elm
    | StartTimerWithTime Effect.Lamdera.ClientId String Time.Posix
```

**Step 3: Handle `StartMonofocusTimer` in updateFromFrontend**

```elm
        Types.StartMonofocusTimer description ->
            ( model
            , Effect.Time.now
                |> Effect.Task.perform (StartTimerWithTime clientId description)
            )
```

**Step 4: Handle `StartTimerWithTime` in update**

Add to the `update` function:

```elm
        StartTimerWithTime clientId description now ->
            ( model
            , Toggl.startTimeEntry Env.togglApiKey
                Coda.monofocusWorkspaceId
                Coda.monofocusProjectId
                description
                now
                (GotStartTimerResponse clientId)
            )
```

**Step 5: Handle `GotStartTimerResponse` in update**

Add after `GotCodaResponse` case:

```elm
        GotStartTimerResponse clientId result ->
            case result of
                Ok () ->
                    -- Success: do nothing, webhook will sync state
                    ( model, Command.none )

                Err apiError ->
                    let
                        errorMsg : String
                        errorMsg =
                            case apiError of
                                Toggl.HttpError httpError ->
                                    case httpError of
                                        Effect.Http.BadStatus code ->
                                            "Failed to start timer (" ++ String.fromInt code ++ "): " ++ Toggl.togglApiErrorToString apiError

                                        Effect.Http.NetworkError ->
                                            "Failed to start timer: Network error"

                                        Effect.Http.Timeout ->
                                            "Failed to start timer: Request timed out"

                                        _ ->
                                            "Failed to start timer: " ++ Toggl.togglApiErrorToString apiError

                                Toggl.RateLimited _ ->
                                    "Failed to start timer: " ++ Toggl.togglApiErrorToString apiError
                    in
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId (Types.StartMonofocusTimerFailed errorMsg)
                    )
```

**Step 6: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 7: Run tests**

Run: `elm-test`
Expected: PASS

**Step 8: Commit**

```bash
git add src/Backend.elm src/Types.elm
git commit -m "feat: handle StartMonofocusTimer in Backend with time fetch"
```

---

### Task 6: Update Types.elm with StartTimerWithTime message

**Files:**
- Modify: `src/Types.elm`

**Step 1: Add Time import**

Ensure `Time` is imported (should already be there via `Time exposing (Posix, Zone)`).

**Step 2: Add `StartTimerWithTime` to BackendMsg**

In `BackendMsg` (around line 215), add:

```elm
    | StartTimerWithTime Effect.Lamdera.ClientId String Time.Posix
```

**Step 3: Run elm-review**

Run: `elm-review`
Expected: PASS (or warnings about unused - will be used by Backend)

**Step 4: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add StartTimerWithTime backend message"
```

---

### Task 7: Add Start Timer button to UI/ProjectBanner.elm

**Files:**
- Modify: `src/UI/ProjectBanner.elm`

**Step 1: Add Coda import**

Add after line 14 (`import Types exposing (CodaProject, CodaStatus(..), FrontendModel, FrontendMsg(..))`):

```elm
import Coda
import Toggl
```

**Step 2: Update imports from Types**

Change line 14 to include `RunningEntry`:

```elm
import Types exposing (CodaProject, CodaStatus(..), FrontendModel, FrontendMsg(..), RunningEntry(..))
```

**Step 3: Add helper function to check if Monofocus is running**

Add after `isDateOutOfRange` function (around line 168):

```elm
{-| Check if the currently running timer is for the Monofocus project.
-}
isMonofocusRunning : FrontendModel -> Bool
isMonofocusRunning model =
    case model.runningEntry of
        NoRunningEntry ->
            False

        RunningEntry payload ->
            payload.projectId == Just Coda.monofocusProjectId
```

**Step 4: Add start timer button to CodaOneActive case**

In the `CodaOneActive project` case (around line 39-64), modify to add the button. Replace the content list in `viewBanner`:

```elm
        CodaOneActive project ->
            let
                dateWarning : Bool
                dateWarning =
                    isDateOutOfRange model.currentTime project

                ( bgColor, textColor ) =
                    if dateWarning then
                        ( "bg-warning", "text-warning-content" )

                    else
                        ( "bg-success", "text-success-content" )

                buttonDisabled : Bool
                buttonDisabled =
                    isMonofocusRunning model
            in
            viewBanner bgColor textColor
                [ viewHeader
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "text-lg font-semibold" ] [ Html.text project.name ]
                    , Html.span [ Attr.class "text-base opacity-80" ] [ Html.text (formatDateRange project) ]
                    , if dateWarning then
                        Html.span [ Attr.class "badge badge-warning badge-sm" ] [ Html.text "Dates out of range" ]

                      else
                        Html.text ""
                    ]
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ startTimerButton buttonDisabled project.name
                    , refreshButton False
                    ]
                ]
```

**Step 5: Add startTimerButton helper function**

Add after `refreshButton` function (around line 122):

```elm
{-| Start timer button with disabled state.
-}
startTimerButton : Bool -> String -> Html FrontendMsg
startTimerButton isDisabled projectName =
    Html.button
        [ Attr.class "btn btn-sm btn-primary"
        , Attr.disabled isDisabled
        , Events.onClick (StartMonofocusTimer projectName)
        , Attr.attribute "data-testid" "start-monofocus-button"
        ]
        [ Html.text "Start Timer" ]
```

**Step 6: Add error display**

Modify `view` function to show error if present. Wrap the entire view in a container:

At the start of `view` function, add error display logic. The simplest approach is to add error display at the end of each banner case. Let's add a helper:

Add after `startTimerButton`:

```elm
{-| Error banner for start timer failures.
-}
viewStartTimerError : Maybe String -> Html FrontendMsg
viewStartTimerError maybeError =
    case maybeError of
        Nothing ->
            Html.text ""

        Just errorMsg ->
            Html.div
                [ Attr.class "alert alert-error mt-2"
                , Attr.attribute "data-testid" "start-timer-error"
                ]
                [ Html.span [] [ Html.text errorMsg ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick DismissStartMonofocusTimerError
                    , Attr.id "dismiss-start-timer-error"
                    ]
                    [ Html.text "✕" ]
                ]
```

**Step 7: Update view to include error display**

Modify the `view` function to return a container with both banner and error. Change the function signature and implementation:

```elm
view : FrontendModel -> Html FrontendMsg
view model =
    Html.div []
        [ viewBannerContent model
        , viewStartTimerError model.startMonofocusTimerError
        ]


{-| Internal: render the banner content based on Coda status.
-}
viewBannerContent : FrontendModel -> Html FrontendMsg
viewBannerContent model =
    case model.codaStatus of
        -- ... rest of the original view function cases ...
```

Actually, this refactoring is getting complex. Let me simplify - just add the error div after each viewBanner call within the existing structure.

**Step 7 (simplified): Add error display within each case**

For the `CodaOneActive` case, wrap the return in a div:

```elm
        CodaOneActive project ->
            let
                dateWarning : Bool
                dateWarning =
                    isDateOutOfRange model.currentTime project

                ( bgColor, textColor ) =
                    if dateWarning then
                        ( "bg-warning", "text-warning-content" )

                    else
                        ( "bg-success", "text-success-content" )

                buttonDisabled : Bool
                buttonDisabled =
                    isMonofocusRunning model
            in
            Html.div []
                [ viewBanner bgColor textColor
                    [ viewHeader
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.span [ Attr.class "text-lg font-semibold" ] [ Html.text project.name ]
                        , Html.span [ Attr.class "text-base opacity-80" ] [ Html.text (formatDateRange project) ]
                        , if dateWarning then
                            Html.span [ Attr.class "badge badge-warning badge-sm" ] [ Html.text "Dates out of range" ]

                          else
                            Html.text ""
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ startTimerButton buttonDisabled project.name
                        , refreshButton False
                        ]
                    ]
                , viewStartTimerError model.startMonofocusTimerError
                ]
```

For other cases that don't have the start button, we still want to show error if somehow it got set, so wrap them too:

For `CodaNotFetched`:
```elm
        CodaNotFetched ->
            Html.div []
                [ viewBanner "bg-base-300" "text-base-content"
                    [ viewHeader
                    , Html.div [ Attr.class "text-base opacity-60" ] [ Html.text "Loading..." ]
                    , refreshButton False
                    ]
                , viewStartTimerError model.startMonofocusTimerError
                ]
```

And similarly for other cases.

**Step 8: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 9: Run tests**

Run: `elm-test`
Expected: Some tests may fail if they check exact HTML structure

**Step 10: Commit**

```bash
git add src/UI/ProjectBanner.elm
git commit -m "feat: add Start Timer button to Project Banner"
```

---

### Task 8: Write E2E tests for start timer feature

**Files:**
- Modify: `tests/E2ETests.elm`

**Step 1: Add mock for Monofocus project**

Add after `mockProjectReading` (around line 72):

```elm
{-| Mock Monofocus project (matches Coda.monofocusProjectId).
-}
mockMonofocusProject : Toggl.TogglProject
mockMonofocusProject =
    { id = Toggl.TogglProjectId 205793718
    , workspaceId = Toggl.TogglWorkspaceId 4150145
    , name = "Monofocus"
    , color = "#e36a00"
    }
```

**Step 2: Add mock running entry for Monofocus**

Add after `mockRunningEntry` (around line 179):

```elm
{-| Mock running timer for Monofocus project.
-}
mockMonofocusRunningEntry : Toggl.WebhookPayload
mockMonofocusRunningEntry =
    { id = Toggl.TimeEntryId 889
    , projectId = Just (Toggl.TogglProjectId 205793718)
    , workspaceId = Toggl.TogglWorkspaceId 4150145
    , description = Just "Kitchen organization"
    , start = Time.millisToPosix january1st2026
    , stop = Nothing
    , duration = -1
    }
```

**Step 3: Add test for button visible when Coda project active**

Add to `tests` list:

```elm
    , standardTest "Start timer button visible when Coda project is active"
        (\actions ->
            [ -- Wait for Coda API mock response
              actions.checkView 500
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-monofocus-button") ]
                )
            ]
        )
```

**Step 4: Add test for button disabled when Monofocus timer already running**

```elm
    , standardTest "Start timer button disabled when Monofocus timer already running"
        (\actions ->
            [ -- Broadcast Monofocus running entry
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockMonofocusRunningEntry))
            , -- Verify button is disabled
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-monofocus-button") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled True ]
                )
            ]
        )
```

**Step 5: Add test for button enabled when different timer running**

```elm
    , standardTest "Start timer button enabled when different project timer running"
        (\actions ->
            [ -- Broadcast non-Monofocus running entry (mockRunningEntry uses project 159657524)
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockRunningEntry))
            , -- Verify button is enabled
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-monofocus-button") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled False ]
                )
            ]
        )
```

**Step 6: Add test for button not visible when no active Coda project**

```elm
    , standardTest "Start timer button not visible when no active Coda project"
        (\actions ->
            [ -- Simulate no active projects
              Effect.Test.backendUpdate 100
                (GotCodaResponse (Ok "{\"items\":[]}"))
            , -- Verify button is not present
              actions.checkView 200
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-monofocus-button") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
```

**Step 7: Add test for error display**

```elm
    , standardTest "Start timer error shows in banner and can be dismissed"
        (\actions ->
            [ -- Simulate backend error response
              Effect.Test.backendUpdate 100
                (GotStartTimerResponse actions.clientId (Err (Toggl.HttpError (Effect.Http.BadStatus 401))))
            , -- Verify error appears
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-timer-error") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "401" ]
                )
            , -- Dismiss error
              actions.click 100 (Dom.id "dismiss-start-timer-error")
            , -- Verify error is gone
              actions.checkView 200
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "start-timer-error") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
```

**Step 8: Update handleHttpRequest to mock start timer API**

Add to `handleHttpRequest` function, before the `else` catch-all:

```elm
    else if String.contains "api.track.toggl.com/api/v9/workspaces" url && currentRequest.method == "POST" && String.contains "/time_entries" url && not (String.contains "/stop" url) then
        -- POST /api/v9/workspaces/{id}/time_entries - Start time entry
        JsonHttpResponse
            (okMetadata url)
            (E.object [ ( "id", E.int 12345 ) ])
```

**Step 9: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 10: Run tests**

Run: `elm-test`
Expected: All tests PASS

**Step 11: Commit**

```bash
git add tests/E2ETests.elm
git commit -m "test: add E2E tests for start Monofocus timer feature"
```

---

### Task 9: Final verification and cleanup

**Step 1: Run full test suite**

Run: `elm-test`
Expected: All tests PASS

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 3: Manual testing (if dev server available)**

Run: `lamdera live`
1. Verify button appears in Project Banner when Coda project is active
2. Verify button is disabled when Monofocus timer is running
3. Verify button is enabled when different timer is running
4. Click button and verify timer starts (via Toggl or webhook)

**Step 4: Final commit if any cleanup needed**

```bash
git status
# If any uncommitted changes:
git add -A
git commit -m "chore: cleanup after start timer implementation"
```
