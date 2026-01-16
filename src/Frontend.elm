module Frontend exposing (FrontendApp, Model, UnwrappedFrontendApp, app, app_)

import Browser
import Browser.Navigation
import CalendarDict
import CalendarLogic
import ColorLogic
import Duration
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera
import Effect.Subscription exposing (Subscription)
import Effect.Task
import Effect.Time
import HabitCalendar exposing (HabitCalendarId(..))
import Html
import Html.Attributes as Attr
import Lamdera as L
import Time
import Toggl
import Types exposing (FrontendModel, FrontendMsg(..), ModalState(..), RunningEntry(..), ToBackend(..), ToFrontend(..), TogglConnectionStatus(..))
import UI.CalendarView
import UI.ConnectionCard
import UI.Modal
import UI.TimerBanner
import UI.WebhookDebug
import Url


type alias Model =
    FrontendModel


app_ : FrontendApp
app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = subscriptions
    , view = view
    }


init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
init _ key =
    ( { key = key
      , currentTime = Nothing
      , currentZone = Nothing
      , calendars = CalendarDict.empty
      , togglStatus = NotConnected -- Will be updated when backend sends cached workspaces
      , modalState = ModalClosed
      , availableProjects = []
      , projectsLoading = False
      , runningEntry = NoRunningEntry
      , webhookDebugLog = []
      , stopTimerError = Nothing
      }
    , Command.batch
        [ Effect.Task.perform GotTime Effect.Time.now
        , Effect.Task.perform GotZone Effect.Time.here
        ]
    )


subscriptions : Model -> Subscription FrontendOnly FrontendMsg
subscriptions _ =
    -- Update every second for the running timer display
    Effect.Time.every (Duration.seconds 1) Tick


{-| Helper to send FetchTogglTimeEntries command with date range and timezone.
Consolidates logic for fetching calendar data that's used by multiple handlers.
-}
sendFetchCalendarCommand : Types.CalendarInfo -> Toggl.TogglWorkspaceId -> Toggl.TogglProjectId -> Model -> Command FrontendOnly ToBackend FrontendMsg
sendFetchCalendarCommand calendarInfo workspaceId projectId model =
    let
        -- Fetch last 28 days of entries
        ( startDate, endDate ) =
            CalendarLogic.calculateDateRange model.currentTime

        -- Use user's timezone, fallback to UTC if not available
        userZone : Time.Zone
        userZone =
            Maybe.withDefault Time.utc model.currentZone
    in
    Effect.Lamdera.sendToBackend
        (FetchTogglTimeEntries calendarInfo workspaceId projectId startDate endDate userZone)


update : FrontendMsg -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        UrlClicked _ ->
            ( model, Command.none )

        UrlChanged _ ->
            ( model, Command.none )

        NoOpFrontendMsg ->
            ( model, Command.none )

        GotTime posix ->
            ( { model | currentTime = Just posix }, Command.none )

        GotZone zone ->
            ( { model | currentZone = Just zone }, Command.none )

        Tick posix ->
            -- Update current time for the running timer display
            ( { model | currentTime = Just posix }, Command.none )

        RefreshWorkspaces ->
            ( { model | togglStatus = Connecting }
            , Effect.Lamdera.sendToBackend FetchTogglWorkspaces
            )

        RefreshCalendar calendarId workspaceId projectId calendarName ->
            let
                calendarInfo : Types.CalendarInfo
                calendarInfo =
                    { calendarId = calendarId
                    , calendarName = calendarName
                    }
            in
            ( model
            , sendFetchCalendarCommand calendarInfo workspaceId projectId model
            )

        OpenCreateCalendarModal ->
            ( { model
                | modalState =
                    ModalCreateCalendar
                        { selectedWorkspace = Nothing
                        , selectedProject = Nothing
                        , calendarName = ""
                        }
              }
            , Command.none
            )

        CloseModal ->
            ( { model | modalState = ModalClosed }, Command.none )

        SelectWorkspace workspace ->
            ( { model
                | modalState =
                    ModalCreateCalendar
                        { selectedWorkspace = Just workspace
                        , selectedProject = Nothing
                        , calendarName = ""
                        }
                , availableProjects = []
                , projectsLoading = True
              }
            , Effect.Lamdera.sendToBackend (FetchTogglProjects workspace.id)
            )

        SelectProject project ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalCreateCalendar
                                { modalData
                                    | selectedProject = Just project
                                    , calendarName =
                                        if String.isEmpty modalData.calendarName then
                                            project.name

                                        else
                                            modalData.calendarName
                                }
                      }
                    , Command.none
                    )

                ModalEditCalendar _ ->
                    -- TODO: Handle project selection in edit modal
                    ( model, Command.none )

                ModalClosed ->
                    ( model, Command.none )

        CalendarNameChanged newName ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalCreateCalendar { modalData | calendarName = newName }
                      }
                    , Command.none
                    )

                ModalEditCalendar _ ->
                    -- TODO: Handle name change in edit modal
                    ( model, Command.none )

                ModalClosed ->
                    ( model, Command.none )

        SubmitCreateCalendar ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    case ( modalData.selectedWorkspace, modalData.selectedProject ) of
                        ( Just workspace, Just project ) ->
                            let
                                calendarId : HabitCalendarId
                                calendarId =
                                    HabitCalendarId (Toggl.togglProjectIdToString project.id)

                                calendarInfo : Types.CalendarInfo
                                calendarInfo =
                                    { calendarId = calendarId
                                    , calendarName = modalData.calendarName
                                    }
                            in
                            ( { model | modalState = ModalClosed }
                            , sendFetchCalendarCommand calendarInfo workspace.id project.id model
                            )

                        _ ->
                            ( model, Command.none )

                ModalEditCalendar _ ->
                    -- SubmitCreateCalendar shouldn't be called from edit modal
                    ( model, Command.none )

                ModalClosed ->
                    ( model, Command.none )

        StopRunningTimer ->
            case model.runningEntry of
                NoRunningEntry ->
                    ( model, Command.none )

                RunningEntry payload ->
                    ( { model
                        | runningEntry = NoRunningEntry
                        , stopTimerError = Nothing
                      }
                    , Effect.Lamdera.sendToBackend
                        (StopTogglTimer payload.workspaceId payload.id)
                    )

        DismissStopTimerError ->
            ( { model | stopTimerError = Nothing }, Command.none )

        ClearWebhookEvents ->
            ( model
            , Effect.Lamdera.sendToBackend ClearWebhookEventsRequest
            )

        -- Edit calendar actions
        OpenEditCalendarModal calendar ->
            let
                -- Find the workspace for this calendar
                maybeWorkspace : Maybe Toggl.TogglWorkspace
                maybeWorkspace =
                    case model.togglStatus of
                        Connected workspaces ->
                            List.filter (\ws -> ws.id == calendar.workspaceId) workspaces
                                |> List.head

                        _ ->
                            Nothing

                -- Find the project for this calendar
                maybeProject : Maybe Toggl.TogglProject
                maybeProject =
                    List.filter (\p -> p.id == calendar.projectId) model.availableProjects
                        |> List.head
            in
            case ( maybeWorkspace, maybeProject ) of
                ( Just workspace, Just project ) ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { calendarId = calendar.id
                                , originalProjectId = calendar.projectId
                                , selectedWorkspace = workspace
                                , selectedProject = project
                                , calendarName = calendar.name
                                }
                      }
                    , Command.none
                    )

                _ ->
                    -- Can't edit if we don't have workspace/project info
                    ( model, Command.none )

        EditCalendarSelectWorkspace workspace ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | selectedWorkspace = workspace }
                        , projectsLoading = True
                      }
                    , Effect.Lamdera.sendToBackend (FetchTogglProjects workspace.id)
                    )

                _ ->
                    ( model, Command.none )

        EditCalendarSelectProject project ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | selectedProject = project }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )

        EditCalendarNameChanged newName ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar { modalData | calendarName = newName }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )

        SubmitEditCalendar ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model | modalState = ModalClosed }
                    , Effect.Lamdera.sendToBackend
                        (UpdateCalendar
                            modalData.calendarId
                            modalData.calendarName
                            modalData.selectedWorkspace.id
                            modalData.selectedProject.id
                        )
                    )

                _ ->
                    ( model, Command.none )

        DeleteCalendar calendarId ->
            -- Note: In production, we'd use a port for window.confirm()
            -- For now, just send the delete request directly
            ( model
            , Effect.Lamdera.sendToBackend (DeleteCalendarRequest calendarId)
            )


updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Command.none )

        CalendarsUpdated calendars ->
            ( { model | calendars = calendars }, Command.none )

        TogglWorkspacesReceived result ->
            case result of
                Ok workspaces ->
                    ( { model | togglStatus = Connected workspaces }, Command.none )

                Err errorMsg ->
                    ( { model | togglStatus = ConnectionError errorMsg }, Command.none )

        TogglProjectsReceived result ->
            case result of
                Ok projects ->
                    ( { model | availableProjects = projects, projectsLoading = False }, Command.none )

                Err _ ->
                    ( { model | projectsLoading = False }, Command.none )

        TogglTimeEntriesReceived _ ->
            -- TODO: Handle time entries
            ( model, Command.none )

        RunningEntryUpdated runningEntry ->
            ( { model | runningEntry = runningEntry }, Command.none )

        StopTimerFailed errorMsg runningEntry ->
            ( { model
                | stopTimerError = Just errorMsg
                , runningEntry = runningEntry
              }
            , Command.none
            )

        WebhookDebugEvent entry ->
            -- Keep last 20 webhook events for debugging
            let
                updatedLog : List Types.WebhookDebugEntry
                updatedLog =
                    (entry :: model.webhookDebugLog)
                        |> List.take 20
            in
            ( { model | webhookDebugLog = updatedLog }, Command.none )

        WebhookEventsCleared ->
            -- Clear webhook debug log
            ( { model | webhookDebugLog = [] }, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    let
        -- Get muted background color based on running timer's project
        backgroundStyle : Html.Attribute FrontendMsg
        backgroundStyle =
            case model.runningEntry of
                RunningEntry payload ->
                    payload.projectId
                        |> Maybe.andThen
                            (\projectId ->
                                List.filter (\p -> p.id == projectId) model.availableProjects
                                    |> List.head
                                    |> Maybe.map (\project -> Attr.style "background-color" (ColorLogic.muteColor project.color))
                            )
                        |> Maybe.withDefault (Attr.class "bg-base-200")

                NoRunningEntry ->
                    Attr.class "bg-base-200"
    in
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div [ Attr.class "min-h-screen p-8", backgroundStyle ]
            [ Html.div [ Attr.class "max-w-4xl mx-auto" ]
                (UI.TimerBanner.view model
                    ++ [ UI.ConnectionCard.view model
                       , UI.CalendarView.view model
                       , UI.WebhookDebug.view model
                       ]
                )
            ]
        , UI.Modal.view model
        ]
    }


{-| Type alias for the frontend application configuration record (Effect-wrapped version).
-}
type alias FrontendApp =
    { init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , onUrlRequest : UrlRequest -> FrontendMsg
    , onUrlChange : Url.Url -> FrontendMsg
    , update : FrontendMsg -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , subscriptions : Model -> Subscription FrontendOnly FrontendMsg
    , view : Model -> Effect.Browser.Document FrontendMsg
    }


{-| Type alias for the unwrapped frontend application (uses standard Cmd/Sub).
-}
type alias UnwrappedFrontendApp =
    { init : Url.Url -> Browser.Navigation.Key -> ( Model, Cmd FrontendMsg )
    , view : Model -> Browser.Document FrontendMsg
    , update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
    , updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
    , subscriptions : Model -> Sub FrontendMsg
    , onUrlRequest : Browser.UrlRequest -> FrontendMsg
    , onUrlChange : Url.Url -> FrontendMsg
    }


app : UnwrappedFrontendApp
app =
    Effect.Lamdera.frontend
        L.sendToBackend
        app_
