module Backend exposing (BackendApp, Model, UnwrappedBackendApp, app, app_)

import CalendarDict
import DateUtils
import Dict
import Duration
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Http
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Effect.Task
import Effect.Time
import Env
import HabitCalendar
import Json.Decode as Decode
import Json.Encode as Encode
import Lamdera as L
import Monofocus
import SeqDict
import Time
import Toggl
import Types exposing (BackendModel, BackendMsg(..), ToBackend(..), ToFrontend(..))


type alias Model =
    BackendModel


{-| Type alias for the Effect-wrapped backend application record.
-}
type alias BackendApp =
    { init : ( Model, Command BackendOnly ToFrontend BackendMsg )
    , update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
    , updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
    , subscriptions : Model -> Subscription BackendOnly BackendMsg
    }


{-| Type alias for the unwrapped backend application (uses standard Cmd/Sub).
-}
type alias UnwrappedBackendApp =
    { init : ( Model, Cmd BackendMsg )
    , update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
    , updateFromFrontend : String -> String -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
    , subscriptions : Model -> Sub BackendMsg
    }


app : UnwrappedBackendApp
app =
    Effect.Lamdera.backend
        L.broadcast
        L.sendToFrontend
        app_


app_ : BackendApp
app_ =
    { init = init
    , update = update
    , updateFromFrontend = updateFromFrontend
    , subscriptions = subscriptions
    }


subscriptions : Model -> Subscription BackendOnly BackendMsg
subscriptions _ =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        , Effect.Time.every (Duration.minutes 30) MonofocusPollTick
        ]


init : ( Model, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { calendars = CalendarDict.empty
      , togglWorkspaces = []
      , togglProjects = []
      , runningEntry = Types.NoRunningEntry
      , webhookEvents = []
      , monofocusStatus = Types.MonofocusNotFetched
      }
      -- Get the current time first so we can tell the Hub our local timezone
      -- offset (see fetchMonofocusProject); the poll tick does the same.
    , Effect.Time.now |> Effect.Task.perform MonofocusPollTick
    )


{-| Fetch the current active project from the Monofocus Hub.

`now` is used to derive the Pacific timezone offset so the Hub picks "today's"
active project in local time rather than UTC.

-}
fetchMonofocusProject : Time.Posix -> Command BackendOnly ToFrontend BackendMsg
fetchMonofocusProject now =
    Effect.Http.request
        { method = "POST"
        , url = Monofocus.activeUrl (DateUtils.pacificTimezoneOffsetMinutes now)
        , headers = []
        , body = Effect.Http.jsonBody (Encode.object [])
        , expect = Effect.Http.expectString GotMonofocusResponse
        , timeout = Nothing
        , tracker = Nothing
        }


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


update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Command.none )

        ClientConnected _ clientId ->
            let
                -- Send calendars to the new client
                calendarsCmd : Command BackendOnly ToFrontend BackendMsg
                calendarsCmd =
                    Effect.Lamdera.sendToFrontend clientId (CalendarsUpdated model.calendars)

                -- If we have workspaces, send them too so the frontend knows we're connected
                workspacesCmd : Command BackendOnly ToFrontend BackendMsg
                workspacesCmd =
                    if List.isEmpty model.togglWorkspaces then
                        Command.none

                    else
                        Effect.Lamdera.sendToFrontend clientId (TogglWorkspacesReceived (Ok model.togglWorkspaces))

                -- Send cached projects so frontend can display colors immediately
                projectsCmd : Command BackendOnly ToFrontend BackendMsg
                projectsCmd =
                    if List.isEmpty model.togglProjects then
                        Command.none

                    else
                        Effect.Lamdera.sendToFrontend clientId (TogglProjectsReceived (Ok model.togglProjects))

                -- Send current running entry
                runningEntryCmd : Command BackendOnly ToFrontend BackendMsg
                runningEntryCmd =
                    Effect.Lamdera.sendToFrontend clientId (RunningEntryUpdated model.runningEntry)

                -- Send all stored webhook events for debugging
                webhookEventsCmds : List (Command BackendOnly ToFrontend BackendMsg)
                webhookEventsCmds =
                    List.map
                        (\event -> Effect.Lamdera.sendToFrontend clientId (WebhookDebugEvent event))
                        (List.reverse model.webhookEvents)

                -- Send current Monofocus status
                monofocusStatusCmd : Command BackendOnly ToFrontend BackendMsg
                monofocusStatusCmd =
                    Effect.Lamdera.sendToFrontend clientId (MonofocusStatusUpdated model.monofocusStatus)

                -- Reverse to send oldest first
            in
            ( model
            , Command.batch (calendarsCmd :: workspacesCmd :: projectsCmd :: runningEntryCmd :: monofocusStatusCmd :: webhookEventsCmds)
            )

        ClientDisconnected _ _ ->
            ( model, Command.none )

        GotTogglWorkspaces clientId result ->
            case result of
                Ok workspaces ->
                    let
                        -- Fetch projects for all workspaces
                        fetchProjectsCommands : List (Command BackendOnly ToFrontend BackendMsg)
                        fetchProjectsCommands =
                            List.map
                                (\workspace ->
                                    Toggl.fetchProjects Env.togglApiKey workspace.id (GotTogglProjects clientId)
                                )
                                workspaces
                    in
                    ( { model | togglWorkspaces = workspaces, togglProjects = [] }
                    , Command.batch
                        (Effect.Lamdera.sendToFrontend clientId
                            (TogglWorkspacesReceived (Ok workspaces))
                            :: fetchProjectsCommands
                        )
                    )

                Err apiError ->
                    -- Clear cached workspaces so new clients don't see stale "Connected" state
                    ( { model | togglWorkspaces = [], togglProjects = [] }
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotTogglProjects clientId result ->
            case result of
                Ok projects ->
                    let
                        -- Append new projects and deduplicate by ID
                        -- (same workspace may be fetched multiple times)
                        existingIds : List Toggl.TogglProjectId
                        existingIds =
                            List.map .id model.togglProjects

                        newProjects : List Toggl.TogglProject
                        newProjects =
                            List.filter (\p -> not (List.member p.id existingIds)) projects

                        allProjects : List Toggl.TogglProject
                        allProjects =
                            model.togglProjects ++ newProjects
                    in
                    ( { model | togglProjects = allProjects }
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Ok allProjects))
                    )

                Err apiError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotTogglTimeEntries clientId calendarInfo workspaceId projectId userZone result ->
            case result of
                Ok entries ->
                    let
                        -- Create a calendar from the time entries with custom colors
                        baseCalendar : HabitCalendar.HabitCalendar
                        baseCalendar =
                            HabitCalendar.fromTimeEntriesWithColors
                                calendarInfo.calendarId
                                calendarInfo.calendarName
                                userZone
                                workspaceId
                                projectId
                                calendarInfo.successColor
                                calendarInfo.nonzeroColor
                                entries

                        -- Set the isOrangetheory flag from calendarInfo
                        newCalendar : HabitCalendar.HabitCalendar
                        newCalendar =
                            { baseCalendar | isOrangetheory = calendarInfo.isOrangetheory }

                        -- Update the calendars dict
                        updatedCalendars : CalendarDict.CalendarDict
                        updatedCalendars =
                            CalendarDict.insert calendarInfo.calendarId newCalendar model.calendars
                    in
                    ( { model | calendars = updatedCalendars }
                    , Command.batch
                        [ Effect.Lamdera.sendToFrontend clientId (TogglTimeEntriesReceived (Ok entries))
                        , Effect.Lamdera.sendToFrontend clientId (CalendarsUpdated updatedCalendars)
                        ]
                    )

                Err apiError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglTimeEntriesReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotStopTimerResponse clientId result ->
            case result of
                Ok () ->
                    -- Success: do nothing, webhook will sync state
                    ( model, Command.none )

                Err apiError ->
                    -- Error: send failure message back to frontend with current running entry
                    let
                        errorMsg : String
                        errorMsg =
                            case apiError of
                                Toggl.RateLimited _ ->
                                    -- Let the existing rate limit handler in connection card show the error
                                    Toggl.togglApiErrorToString apiError

                                Toggl.HttpError httpError ->
                                    case httpError of
                                        Effect.Http.BadStatus 404 ->
                                            "Timer not found. It may have already been stopped."

                                        Effect.Http.BadStatus 401 ->
                                            "Authentication error. Try refreshing your Toggl connection."

                                        Effect.Http.BadStatus 403 ->
                                            "Authentication error. Try refreshing your Toggl connection."

                                        Effect.Http.NetworkError ->
                                            "Network error. Check your connection and try again."

                                        Effect.Http.Timeout ->
                                            "Request timed out. Please try again."

                                        _ ->
                                            "Failed to stop timer: " ++ Toggl.togglApiErrorToString apiError
                    in
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (StopTimerFailed errorMsg model.runningEntry)
                    )

        GotWebhookValidation result ->
            -- Log the result but don't need to do anything else
            case result of
                Ok () ->
                    let
                        _ =
                            Debug.log "Webhook validation" "SUCCESS"
                    in
                    ( model, Command.none )

                Err err ->
                    let
                        _ =
                            Debug.log "Webhook validation FAILED" err
                    in
                    ( model, Command.none )

        BroadcastRunningEntry runningEntry ->
            -- Update model and broadcast to all connected clients
            ( { model | runningEntry = runningEntry }
            , Effect.Lamdera.broadcast (RunningEntryUpdated runningEntry)
            )

        MonofocusPollTick now ->
            ( model, fetchMonofocusProject now )

        StartTimerWithTime clientId description now ->
            ( model
            , Toggl.startTimeEntry Env.togglApiKey
                Monofocus.monofocusWorkspaceId
                Monofocus.monofocusProjectId
                description
                now
                (GotStartTimerResponse clientId)
            )

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

        GotMonofocusResponse result ->
            case result of
                Ok jsonString ->
                    case Decode.decodeString Monofocus.decodeActiveResponse jsonString of
                        Ok maybeProject ->
                            let
                                newStatus : Types.MonofocusStatus
                                newStatus =
                                    case maybeProject of
                                        Just project ->
                                            Types.MonofocusOneActive project

                                        Nothing ->
                                            Types.MonofocusNoActive
                            in
                            ( { model | monofocusStatus = newStatus }
                            , Effect.Lamdera.broadcast (MonofocusStatusUpdated newStatus)
                            )

                        Err decodeError ->
                            let
                                errorStatus : Types.MonofocusStatus
                                errorStatus =
                                    Types.MonofocusError (Decode.errorToString decodeError)
                            in
                            ( { model | monofocusStatus = errorStatus }
                            , Effect.Lamdera.broadcast (MonofocusStatusUpdated errorStatus)
                            )

                Err httpError ->
                    let
                        errorStatus : Types.MonofocusStatus
                        errorStatus =
                            Types.MonofocusError (httpErrorToString httpError)
                    in
                    ( { model | monofocusStatus = errorStatus }
                    , Effect.Lamdera.broadcast (MonofocusStatusUpdated errorStatus)
                    )

        GotRpcStartTimerResponse _ ->
            -- RPC timer start completed - we don't need to do anything here
            -- The webhook will update running entry state when the timer actually starts
            ( model, Command.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontend _ clientId msg model =
    case msg of
        NoOpToBackend ->
            ( model, Command.none )

        RequestCalendars ->
            ( model
            , Effect.Lamdera.sendToFrontend clientId (CalendarsUpdated model.calendars)
            )

        FetchTogglWorkspaces ->
            ( model
            , Toggl.fetchWorkspaces Env.togglApiKey (GotTogglWorkspaces clientId)
            )

        FetchTogglProjects workspaceId ->
            ( model
            , Toggl.fetchProjects Env.togglApiKey workspaceId (GotTogglProjects clientId)
            )

        FetchTogglTimeEntries calendarInfo workspaceId projectId startDate endDate userZone ->
            ( model
            , Toggl.fetchTimeEntries Env.togglApiKey
                workspaceId
                { startDate = startDate
                , endDate = endDate
                , description = Nothing
                , projectId = Just projectId
                }
                (GotTogglTimeEntries clientId calendarInfo workspaceId projectId userZone)
            )

        StopTogglTimer workspaceId timeEntryId ->
            ( model
            , Toggl.stopTimeEntry Env.togglApiKey
                workspaceId
                timeEntryId
                (GotStopTimerResponse clientId)
            )

        ClearWebhookEventsRequest ->
            ( { model | webhookEvents = [] }
            , Effect.Lamdera.broadcast WebhookEventsCleared
            )

        UpdateCalendar calendarId newName newWorkspaceId newProjectId newSuccessColor newNonzeroColor newIsOrangetheory ->
            case CalendarDict.get calendarId model.calendars of
                Just existingCalendar ->
                    let
                        projectChanged : Bool
                        projectChanged =
                            existingCalendar.projectId /= newProjectId

                        -- Update calendar with new values
                        updatedCalendar : HabitCalendar.HabitCalendar
                        updatedCalendar =
                            { existingCalendar
                                | name = newName
                                , workspaceId = newWorkspaceId
                                , projectId = newProjectId
                                , successColor = newSuccessColor
                                , nonzeroColor = newNonzeroColor
                                , isOrangetheory = newIsOrangetheory
                            }

                        -- If project changed, clear entries (will re-fetch)
                        calendarToSave : HabitCalendar.HabitCalendar
                        calendarToSave =
                            if projectChanged then
                                { updatedCalendar
                                    | entries = Dict.empty
                                    , timeEntries = SeqDict.empty
                                }

                            else
                                updatedCalendar

                        updatedCalendars : CalendarDict.CalendarDict
                        updatedCalendars =
                            CalendarDict.insert calendarId calendarToSave model.calendars
                    in
                    ( { model | calendars = updatedCalendars }
                    , Effect.Lamdera.broadcast (CalendarsUpdated updatedCalendars)
                    )

                Nothing ->
                    ( model, Command.none )

        DeleteCalendarRequest calendarId ->
            let
                updatedCalendars : CalendarDict.CalendarDict
                updatedCalendars =
                    CalendarDict.remove calendarId model.calendars
            in
            ( { model | calendars = updatedCalendars }
            , Effect.Lamdera.broadcast (CalendarsUpdated updatedCalendars)
            )

        FetchMonofocusProject ->
            -- Get the current time first so the Hub fetch carries our timezone
            -- offset; MonofocusPollTick performs the actual fetch.
            ( model, Effect.Time.now |> Effect.Task.perform MonofocusPollTick )

        StartMonofocusTimerRequest description ->
            ( model
            , Effect.Time.now
                |> Effect.Task.perform (StartTimerWithTime clientId description)
            )
