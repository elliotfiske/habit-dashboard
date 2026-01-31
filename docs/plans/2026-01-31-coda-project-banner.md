# Coda Active Project Banner Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display the current active project from Coda in a banner below the timer, with validation for exactly 1 active project and date range warnings.

**Architecture:** Backend polls Coda API every 30 minutes (and on client connect), parses response to determine project status, broadcasts to all frontends. Frontend renders a color-coded banner based on status.

**Tech Stack:** Lamdera (Elm), Coda REST API, Effect.Http for backend requests

---

## Task 1: Add Coda API Key to Env.elm

**Files:**
- Modify: `src/Env.elm`

**Step 1: Add the codaApiKey constant**

```elm
{-| Coda API key for accessing the Coda API.
Get yours from: https://coda.io/account (scroll to "API settings")

This actual value must not be committed to the repo. However, it must be set for the local dev server to work.
-}
codaApiKey : String
codaApiKey =
    "<redacted for git>"
```

Add this after the `togglApiKey` definition. Also update the module exposing list to include `codaApiKey`.

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS (or only unrelated warnings)

**Step 3: Commit**

```bash
git add src/Env.elm
git commit -m "feat: add Coda API key to Env"
```

---

## Task 2: Add Coda Types to Types.elm

**Files:**
- Modify: `src/Types.elm`

**Step 1: Add CodaProject and CodaStatus types**

Add after the `WebhookDebugEntry` type alias (around line 50):

```elm
{-| A project from the Coda "Current Focus!" table.
-}
type alias CodaProject =
    { name : String
    , startDate : Maybe Time.Posix
    , endDate : Maybe Time.Posix
    }


{-| Status of the Coda project integration.
-}
type CodaStatus
    = CodaNotFetched
    | CodaLoading
    | CodaOneActive CodaProject
    | CodaInvalidCount Int -- 0 or 2+ active projects
    | CodaError String
```

**Step 2: Add codaStatus to FrontendModel**

Add to the `FrontendModel` record (after `stopTimerError`):

```elm
    , codaStatus : CodaStatus
```

**Step 3: Add codaStatus to BackendModel**

Add to the `BackendModel` record (after `webhookEvents`):

```elm
    , codaStatus : CodaStatus
```

**Step 4: Add FrontendMsg for refresh**

Add to `FrontendMsg` (after `ClearWebhookEvents`):

```elm
    | RefreshCodaProject
```

**Step 5: Add ToBackend message**

Add to `ToBackend` (after `DeleteCalendarRequest`):

```elm
    | FetchCodaProject
```

**Step 6: Add BackendMsg for API response**

Add to `BackendMsg` (after `BroadcastRunningEntry`):

```elm
    | CodaPollTick Time.Posix
    | GotCodaResponse (Result Http.Error String)
```

**Step 7: Add ToFrontend message**

Add to `ToFrontend` (after `StopTimerFailed`):

```elm
    | CodaStatusUpdated CodaStatus
```

**Step 8: Update module exposing list**

Update the module declaration to expose the new types:

```elm
module Types exposing
    ( ...
    , CodaProject
    , CodaStatus(..)
    ...
    )
```

**Step 9: Run elm-review**

Run: `elm-review`
Expected: May have errors about unused types (will be fixed in later tasks)

**Step 10: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add Coda types to Types.elm"
```

---

## Task 3: Create Coda.elm Module for API Parsing

**Files:**
- Create: `src/Coda.elm`

**Step 1: Create the Coda module**

```elm
module Coda exposing (decodeCodaResponse, parseCodaStatus)

{-| Coda API integration for fetching the active project.

This module handles parsing the Coda API response from the "Current Focus!" table.

-}

import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Time
import Types exposing (CodaProject, CodaStatus(..))


{-| The Coda doc ID (not sensitive, can be hardcoded).
-}
docId : String
docId =
    "N2tIjWdJ-z"


{-| The table ID for "Current Focus!" table.
-}
tableId : String
tableId =
    "table-Z6eycemBOM"


{-| Build the Coda API URL for fetching active projects.
-}
apiUrl : String
apiUrl =
    "https://coda.io/apis/v1/docs/" ++ docId ++ "/tables/" ++ tableId ++ "/rows?useColumnNames=true&sortBy=updatedAt"


{-| Decode a single row from the Coda API response.
-}
rowDecoder : Decoder CodaProject
rowDecoder =
    Decode.map3 CodaProject
        (Decode.at [ "values", "Initiative name" ] Decode.string)
        (Decode.at [ "values", "Start date" ] (Decode.nullable Iso8601.decoder))
        (Decode.at [ "values", "End date" ] (Decode.nullable Iso8601.decoder))


{-| Decode the full API response (list of rows).
-}
decodeCodaResponse : Decoder (List CodaProject)
decodeCodaResponse =
    Decode.field "items" (Decode.list rowDecoder)


{-| Parse a list of projects into a CodaStatus.
Validates that exactly 1 project exists.
-}
parseCodaStatus : List CodaProject -> CodaStatus
parseCodaStatus projects =
    case projects of
        [ project ] ->
            CodaOneActive project

        [] ->
            CodaInvalidCount 0

        multiple ->
            CodaInvalidCount (List.length multiple)
```

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 3: Run elm-test**

Run: `elm-test`
Expected: PASS (existing tests should still work)

**Step 4: Commit**

```bash
git add src/Coda.elm
git commit -m "feat: add Coda module for API parsing"
```

---

## Task 4: Add Backend Coda Fetching Logic

**Files:**
- Modify: `src/Backend.elm`

**Step 1: Add imports**

Add to the imports section:

```elm
import Coda
import Duration
import Effect.Time
import Json.Decode as Decode
```

**Step 2: Initialize codaStatus in init**

Update the `init` function's model to include:

```elm
      , codaStatus = Types.CodaNotFetched
```

And add an initial fetch command:

```elm
    , fetchCodaProject
```

**Step 3: Add fetchCodaProject helper function**

Add after the `init` function:

```elm
{-| Fetch the current active project from Coda.
-}
fetchCodaProject : Command BackendOnly ToFrontend BackendMsg
fetchCodaProject =
    Effect.Http.get
        { url = Coda.apiUrl
        , expect = Effect.Http.expectString GotCodaResponse
        , headers = [ Effect.Http.header "Authorization" ("Bearer " ++ Env.codaApiKey) ]
        }
```

**Step 4: Add subscription for 30-minute polling**

Update the `subscriptions` function:

```elm
subscriptions : Model -> Subscription BackendOnly BackendMsg
subscriptions _ =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        , Effect.Time.every (Duration.minutes 30) CodaPollTick
        ]
```

**Step 5: Handle CodaPollTick in update**

Add to the `update` function's case statement:

```elm
        CodaPollTick _ ->
            ( model, fetchCodaProject )
```

**Step 6: Handle GotCodaResponse in update**

Add to the `update` function's case statement:

```elm
        GotCodaResponse result ->
            case result of
                Ok jsonString ->
                    case Decode.decodeString Coda.decodeCodaResponse jsonString of
                        Ok projects ->
                            let
                                newStatus : Types.CodaStatus
                                newStatus =
                                    Coda.parseCodaStatus projects
                            in
                            ( { model | codaStatus = newStatus }
                            , Effect.Lamdera.broadcast (CodaStatusUpdated newStatus)
                            )

                        Err decodeError ->
                            let
                                errorStatus : Types.CodaStatus
                                errorStatus =
                                    Types.CodaError (Decode.errorToString decodeError)
                            in
                            ( { model | codaStatus = errorStatus }
                            , Effect.Lamdera.broadcast (CodaStatusUpdated errorStatus)
                            )

                Err httpError ->
                    let
                        errorStatus : Types.CodaStatus
                        errorStatus =
                            Types.CodaError (httpErrorToString httpError)
                    in
                    ( { model | codaStatus = errorStatus }
                    , Effect.Lamdera.broadcast (CodaStatusUpdated errorStatus)
                    )
```

**Step 7: Add httpErrorToString helper**

Add after `fetchCodaProject`:

```elm
{-| Convert an HTTP error to a user-friendly string.
-}
httpErrorToString : Effect.Http.Error -> String
httpErrorToString error =
    case error of
        Effect.Http.BadUrl url ->
            "Bad URL: " ++ url

        Effect.Http.Timeout ->
            "Request timed out"

        Effect.Http.NetworkError ->
            "Network error"

        Effect.Http.BadStatus status ->
            "HTTP error: " ++ String.fromInt status

        Effect.Http.BadBody body ->
            "Bad response: " ++ body
```

**Step 8: Handle FetchCodaProject in updateFromFrontend**

Add to `updateFromFrontend`:

```elm
        FetchCodaProject ->
            ( model, fetchCodaProject )
```

**Step 9: Send codaStatus on client connect**

In the `ClientConnected` branch, add a command to send the current coda status:

```elm
                codaStatusCmd : Command BackendOnly ToFrontend BackendMsg
                codaStatusCmd =
                    Effect.Lamdera.sendToFrontend clientId (CodaStatusUpdated model.codaStatus)
```

And add `codaStatusCmd` to the `Command.batch` list.

**Step 10: Run elm-review**

Run: `elm-review`
Expected: PASS (or fixable warnings)

**Step 11: Commit**

```bash
git add src/Backend.elm
git commit -m "feat: add backend Coda fetching and polling"
```

---

## Task 5: Add Frontend Coda State Handling

**Files:**
- Modify: `src/Frontend.elm`

**Step 1: Initialize codaStatus in init**

Update the `init` function's model to include:

```elm
      , codaStatus = Types.CodaNotFetched
```

**Step 2: Handle RefreshCodaProject in update**

Add to the `update` function's case statement:

```elm
        RefreshCodaProject ->
            ( { model | codaStatus = Types.CodaLoading }
            , Effect.Lamdera.sendToBackend FetchCodaProject
            )
```

**Step 3: Handle CodaStatusUpdated in updateFromBackend**

Add to `updateFromBackend`:

```elm
        CodaStatusUpdated codaStatus ->
            ( { model | codaStatus = codaStatus }, Command.none )
```

**Step 4: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 5: Commit**

```bash
git add src/Frontend.elm
git commit -m "feat: add frontend Coda state handling"
```

---

## Task 6: Create UI.ProjectBanner Module

**Files:**
- Create: `src/UI/ProjectBanner.elm`

**Step 1: Create the ProjectBanner module**

```elm
module UI.ProjectBanner exposing (view)

{-| Active project banner UI.

Displays the current active project from Coda with status indicators
and a refresh button.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Time
import Types exposing (CodaProject, CodaStatus(..), FrontendModel, FrontendMsg(..))


{-| Render the active project banner.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    case model.codaStatus of
        CodaNotFetched ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base opacity-60" ] [ Html.text "Loading..." ]
                , refreshButton False
                ]

        CodaLoading ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , Html.span [ Attr.class "text-base opacity-60" ] [ Html.text "Refreshing..." ]
                    ]
                , refreshButton True
                ]

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
                , refreshButton False
                ]

        CodaInvalidCount count ->
            let
                message : String
                message =
                    if count == 0 then
                        "No active project in Coda"

                    else
                        "Multiple active projects (" ++ String.fromInt count ++ ") - fix in Coda"
            in
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base font-semibold" ] [ Html.text message ]
                , refreshButton False
                ]

        CodaError errorMsg ->
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base" ] [ Html.text ("Coda error: " ++ errorMsg) ]
                , refreshButton False
                ]


{-| Common banner container.
-}
viewBanner : String -> String -> List (Html FrontendMsg) -> Html FrontendMsg
viewBanner bgColor textColor content =
    Html.div
        [ Attr.class ("card shadow-lg p-4 mb-6 " ++ bgColor ++ " " ++ textColor)
        , Attr.attribute "data-testid" "project-banner"
        ]
        [ Html.div [ Attr.class "flex items-center justify-between" ]
            content
        ]


{-| The "Active Project" header label.
-}
viewHeader : Html FrontendMsg
viewHeader =
    Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60 mr-4" ]
        [ Html.text "Active Project" ]


{-| Refresh button with optional disabled state during loading.
-}
refreshButton : Bool -> Html FrontendMsg
refreshButton isLoading =
    Html.button
        [ Attr.class "btn btn-sm btn-ghost"
        , Attr.disabled isLoading
        , Events.onClick RefreshCodaProject
        , Attr.attribute "data-testid" "refresh-coda-button"
        ]
        [ Html.text "↻" ]


{-| Check if the current date is outside the project's date range.
-}
isDateOutOfRange : Maybe Time.Posix -> CodaProject -> Bool
isDateOutOfRange maybeNow project =
    case maybeNow of
        Nothing ->
            False

        Just now ->
            let
                nowMillis : Int
                nowMillis =
                    Time.posixToMillis now

                beforeStart : Bool
                beforeStart =
                    case project.startDate of
                        Just start ->
                            nowMillis < Time.posixToMillis start

                        Nothing ->
                            False

                afterEnd : Bool
                afterEnd =
                    case project.endDate of
                        Just end ->
                            nowMillis > Time.posixToMillis end

                        Nothing ->
                            False
            in
            beforeStart || afterEnd


{-| Format the date range for display.
-}
formatDateRange : CodaProject -> String
formatDateRange project =
    let
        formatDate : Time.Posix -> String
        formatDate posix =
            let
                -- Use UTC for simplicity; could use user's zone if passed in
                month : Time.Month
                month =
                    Time.toMonth Time.utc posix

                day : Int
                day =
                    Time.toDay Time.utc posix

                monthStr : String
                monthStr =
                    case month of
                        Time.Jan -> "Jan"
                        Time.Feb -> "Feb"
                        Time.Mar -> "Mar"
                        Time.Apr -> "Apr"
                        Time.May -> "May"
                        Time.Jun -> "Jun"
                        Time.Jul -> "Jul"
                        Time.Aug -> "Aug"
                        Time.Sep -> "Sep"
                        Time.Oct -> "Oct"
                        Time.Nov -> "Nov"
                        Time.Dec -> "Dec"
            in
            monthStr ++ " " ++ String.fromInt day

        startStr : String
        startStr =
            Maybe.map formatDate project.startDate
                |> Maybe.withDefault "?"

        endStr : String
        endStr =
            Maybe.map formatDate project.endDate
                |> Maybe.withDefault "?"
    in
    "(" ++ startStr ++ " - " ++ endStr ++ ")"
```

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 3: Commit**

```bash
git add src/UI/ProjectBanner.elm
git commit -m "feat: add ProjectBanner UI component"
```

---

## Task 7: Integrate ProjectBanner into Frontend View

**Files:**
- Modify: `src/Frontend.elm`

**Step 1: Add import**

Add to imports:

```elm
import UI.ProjectBanner
```

**Step 2: Add ProjectBanner to view**

Update the view function to include the project banner after the timer banner. Change:

```elm
                (UI.TimerBanner.view model
                    ++ [ UI.ConnectionCard.view model
```

To:

```elm
                (UI.TimerBanner.view model
                    ++ [ UI.ProjectBanner.view model
                       , UI.ConnectionCard.view model
```

**Step 3: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 4: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 5: Commit**

```bash
git add src/Frontend.elm
git commit -m "feat: integrate ProjectBanner into Frontend view"
```

---

## Task 8: Add Lamdera Migration

**Files:**
- Create: `src/Evergreen/Migrate/V14.elm` (or next version)
- Create: `src/Evergreen/V14/Types.elm` (or next version)

**Step 1: Check current version**

Look at the latest version number in `src/Evergreen/` to determine the next version number. The migration needs to:
- Add `codaStatus` to both `FrontendModel` and `BackendModel`
- Initialize to `CodaNotFetched`

**Step 2: Run `lamdera live`**

Run: `lamdera live`
Expected: Lamdera will prompt to create migration files if needed.

**Step 3: Commit migration**

```bash
git add src/Evergreen/
git commit -m "feat: add V14 migration for Coda integration"
```

---

## Task 9: Manual Testing

**Step 1: Start the dev server**

Run: `lamdera live`

**Step 2: Verify happy path**

- Load the app at http://localhost:8000
- Verify the project banner appears below the timer banner
- Verify it shows "Kitchen organization (Jan 29 - Jan 30)" with green background
- Click the refresh button and verify it updates

**Step 3: Verify date warning**

- If the current date is outside Jan 29-30, verify yellow background with "Dates out of range" badge

**Step 4: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete Coda project banner integration"
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add Coda API key to Env.elm |
| 2 | Add Coda types to Types.elm |
| 3 | Create Coda.elm module for API parsing |
| 4 | Add backend Coda fetching logic |
| 5 | Add frontend Coda state handling |
| 6 | Create UI.ProjectBanner module |
| 7 | Integrate ProjectBanner into Frontend view |
| 8 | Add Lamdera migration |
| 9 | Manual testing |
