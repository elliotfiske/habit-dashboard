module Backend exposing (BackendApp, Model, UnwrappedBackendApp, app, app_)

import CalendarDict
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Http
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import HabitCalendar exposing (HabitCalendarId)
import Lamdera as L
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
        ]


init : ( Model, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { calendars = CalendarDict.empty
      , togglApiKey = Nothing
      , togglWorkspaces = []
      , togglProjects = []
      }
    , Command.none
    )


update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Command.none )

        ClientConnected _ clientId ->
            ( model
            , Effect.Lamdera.sendToFrontend clientId (CalendarsUpdated model.calendars)
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

                Err httpError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Err (httpErrorToString httpError)))
                    )

        GotTogglProjects clientId result ->
            case result of
                Ok projects ->
                    ( { model | togglProjects = projects }
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Ok projects))
                    )

                Err httpError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Err (httpErrorToString httpError)))
                    )

        GotTogglTimeEntries clientId calendarInfo result ->
            case result of
                Ok entries ->
                    let
                        -- Use UTC zone for aggregation
                        utcZone : Time.Zone
                        utcZone =
                            Time.utc

                        calendarId : HabitCalendarId
                        calendarId =
                            calendarInfo.calendarId

                        calendarName : String
                        calendarName =
                            calendarInfo.calendarName

                        -- Create a calendar from the time entries
                        newCalendar : HabitCalendar.HabitCalendar
                        newCalendar =
                            HabitCalendar.fromTimeEntries calendarId calendarName utcZone entries

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

                Err httpError ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglTimeEntriesReceived (Err (httpErrorToString httpError)))
                    )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontend _ clientId msg model =
    case msg of
        NoOpToBackend ->
            ( model, Command.none )

        RequestCalendars ->
            ( model
            , Effect.Lamdera.sendToFrontend clientId (CalendarsUpdated model.calendars)
            )

        SetTogglApiKey apiKey ->
            ( { model | togglApiKey = Just apiKey }
            , Toggl.fetchWorkspaces apiKey (GotTogglWorkspaces clientId)
            )

        FetchTogglWorkspaces ->
            case model.togglApiKey of
                Just apiKey ->
                    ( model
                    , Toggl.fetchWorkspaces apiKey (GotTogglWorkspaces clientId)
                    )

                Nothing ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglWorkspacesReceived (Err "No API key configured"))
                    )

        FetchTogglProjects workspaceId ->
            case model.togglApiKey of
                Just apiKey ->
                    ( model
                    , Toggl.fetchProjects apiKey workspaceId (GotTogglProjects clientId)
                    )

                Nothing ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglProjectsReceived (Err "No API key configured"))
                    )

        FetchTogglTimeEntries calendarInfo workspaceId startDate endDate ->
            case model.togglApiKey of
                Just apiKey ->
                    ( model
                    , Toggl.fetchTimeEntries apiKey
                        workspaceId
                        { startDate = startDate
                        , endDate = endDate
                        , description = Nothing
                        , projectId = Nothing
                        }
                        (GotTogglTimeEntries clientId calendarInfo)
                    )

                Nothing ->
                    ( model
                    , Effect.Lamdera.sendToFrontend clientId
                        (TogglTimeEntriesReceived (Err "No API key configured"))
                    )


{-| Convert an HTTP error to a human-readable string.
-}
httpErrorToString : Effect.Http.Error -> String
httpErrorToString error =
    case error of
        Effect.Http.BadUrl url ->
            "Bad URL: " ++ url

        Effect.Http.Timeout ->
            "Request timed out"

        Effect.Http.NetworkError ->
            "Network error - check your connection"

        Effect.Http.BadStatus status ->
            case status of
                401 ->
                    "Invalid API key (401 Unauthorized)"

                403 ->
                    "Access forbidden (403)"

                429 ->
                    "Rate limited - try again later"

                _ ->
                    "HTTP error: " ++ String.fromInt status

        Effect.Http.BadBody body ->
            "Invalid response: " ++ body
