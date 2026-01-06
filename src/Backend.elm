module Backend exposing (BackendApp, Model, UnwrappedBackendApp, app, app_)

import CalendarDict
import Effect.Command as Command exposing (BackendOnly, Command)
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

                -- Send current running entry
                runningEntryCmd : Command BackendOnly ToFrontend BackendMsg
                runningEntryCmd =
                    Effect.Lamdera.sendToFrontend clientId (RunningEntryUpdated model.runningEntry)
            in
            ( model
            , Command.batch [ calendarsCmd, workspacesCmd, runningEntryCmd ]
            )

        ClientDisconnected _ _ ->
            ( model, Command.none )

        GotTogglWorkspaces clientId result ->
            case result of
                Ok workspaces ->
                    ( { model | togglWorkspaces = workspaces }
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Ok workspaces))
                    )

                Err apiError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotTogglProjects clientId result ->
            case result of
                Ok projects ->
                    ( { model | togglProjects = projects }
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Ok projects))
                    )

                Err apiError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Err (Toggl.togglApiErrorToString apiError)))
                    )

        GotTogglTimeEntries clientId calendarInfo userZone result ->
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
                            HabitCalendar.fromTimeEntries calendarId calendarName userZone entries

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
                (GotTogglTimeEntries clientId calendarInfo userZone)
            )
