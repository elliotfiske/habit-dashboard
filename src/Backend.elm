module Backend exposing (BackendApp, Model, UnwrappedBackendApp, app, app_)

import CalendarDict
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Http
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Env
import HabitCalendar exposing (HabitCalendarId)
import Lamdera as L
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
        ]


init : ( Model, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { calendars = CalendarDict.empty
      , togglWorkspaces = []
      , togglProjects = []
      , runningEntry = Types.NoRunningEntry
      , webhookEvents = []
      }
    , Command.none
    )


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
                        (List.reverse model.webhookEvents) -- Reverse to send oldest first
            in
            ( model
            , Command.batch (calendarsCmd :: workspacesCmd :: projectsCmd :: runningEntryCmd :: webhookEventsCmds)
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
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotTogglProjects clientId result ->
            case result of
                Ok projects ->
                    let
                        -- Append new projects to existing ones (we fetch from multiple workspaces)
                        allProjects : List Toggl.TogglProject
                        allProjects =
                            model.togglProjects ++ projects
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
                        calendarId : HabitCalendarId
                        calendarId =
                            calendarInfo.calendarId

                        calendarName : String
                        calendarName =
                            calendarInfo.calendarName

                        -- Create a calendar from the time entries using the user's timezone
                        newCalendar : HabitCalendar.HabitCalendar
                        newCalendar =
                            HabitCalendar.fromTimeEntries calendarId calendarName userZone workspaceId projectId entries

                        -- Update the calendars dict
                        updatedCalendars : CalendarDict.CalendarDict
                        updatedCalendars =
                            CalendarDict.insert calendarId newCalendar model.calendars
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

        UpdateCalendar _ _ _ _ ->
            -- TODO: Implement in Task 7
            ( model, Command.none )

        DeleteCalendarRequest _ ->
            -- TODO: Implement in Task 7
            ( model, Command.none )
