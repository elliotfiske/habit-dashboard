module Frontend exposing (FrontendApp, Model, UnwrappedFrontendApp, app, app_)

import Browser
import Browser.Navigation
import Calendar
import CalendarDict
import DateFormat
import DateUtils exposing (PointInTime, formatDateForApi)
import Dict exposing (Dict)
import Duration
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera
import Effect.Subscription exposing (Subscription)
import Effect.Task
import Effect.Time
import HabitCalendar exposing (DayEntry, HabitCalendar, HabitCalendarId(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Lamdera as L
import Time
import Time.Extra
import Toggl exposing (TogglProject, TogglWorkspace)
import Types exposing (CreateCalendarModal, FrontendModel, FrontendMsg(..), ModalState(..), RunningEntry(..), ToBackend(..), ToFrontend(..), TogglConnectionStatus(..))
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

                                -- Fetch last 28 days of entries
                                ( startDate, endDate ) =
                                    case model.currentTime of
                                        Just now ->
                                            ( Time.Extra.add Time.Extra.Day -28 Time.utc now
                                                |> formatDateForApi
                                            , formatDateForApi now
                                            )

                                        Nothing ->
                                            ( "2026-01-01", "2026-01-28" )

                                -- Use user's timezone, fallback to UTC if not available
                                userZone : Time.Zone
                                userZone =
                                    Maybe.withDefault Time.utc model.currentZone
                            in
                            ( { model | modalState = ModalClosed }
                            , Effect.Lamdera.sendToBackend
                                (FetchTogglTimeEntries calendarInfo workspace.id project.id startDate endDate userZone)
                            )

                        _ ->
                            ( model, Command.none )

                ModalClosed ->
                    ( model, Command.none )


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

        WebhookDebugEvent entry ->
            -- Keep last 20 webhook events for debugging
            let
                updatedLog : List Types.WebhookDebugEntry
                updatedLog =
                    (entry :: model.webhookDebugLog)
                        |> List.take 20
            in
            ( { model | webhookDebugLog = updatedLog }, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div [ Attr.class "min-h-screen bg-base-200 p-8" ]
            [ Html.div [ Attr.class "max-w-4xl mx-auto" ]
                [ header
                , runningTimerHeader model
                , togglConnectionCard model
                , mainContent model
                , webhookDebugView model
                ]
            ]
        , viewModal model
        ]
    }


header : Html FrontendMsg
header =
    Html.div [ Attr.class "text-center mb-8" ]
        [ Html.h1 [ Attr.class "text-4xl font-bold text-base-content" ]
            [ Html.text "Habit Dashboard" ]
        , Html.p [ Attr.class "text-base-content/60 mt-2" ]
            [ Html.text "Track your daily habits" ]
        ]


{-| Display the current running timer from Toggl at the top of the page.
Shows "No timer running" when there's no active timer.
-}
runningTimerHeader : Model -> Html FrontendMsg
runningTimerHeader model =
    case model.runningEntry of
        NoRunningEntry ->
            Html.div [ Attr.class "card bg-base-200 text-base-content shadow-lg p-4 mb-6" ]
                [ Html.div [ Attr.class "flex items-center justify-center gap-3" ]
                    [ Html.div [ Attr.class "text-center" ]
                        [ Html.div [ Attr.class "font-semibold text-lg opacity-60" ] [ Html.text "No timer running" ]
                        , Html.div [ Attr.class "text-sm opacity-40" ] [ Html.text "Start a timer in Toggl Track" ]
                        ]
                    ]
                ]

        RunningEntry payload ->
            let
                description : String
                description =
                    Maybe.withDefault "(no description)" payload.description

                timerText : String
                timerText =
                    case model.currentTime of
                        Just now ->
                            relativeTimer now payload.start

                        Nothing ->
                            "--:--:--"

                -- Look up the project to get its color
                maybeProject : Maybe TogglProject
                maybeProject =
                    payload.projectId
                        |> Maybe.andThen
                            (\projectId ->
                                List.filter (\p -> p.id == projectId) model.availableProjects
                                    |> List.head
                            )

                -- Use project color if available, otherwise use default primary color
                bgStyle : Html.Attribute FrontendMsg
                bgStyle =
                    case maybeProject of
                        Just project ->
                            Attr.style "background-color" project.color

                        Nothing ->
                            Attr.class "bg-primary"
            in
            Html.div [ Attr.class "card text-primary-content shadow-lg p-4 mb-6", bgStyle ]
                [ Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-3" ]
                        [ Html.span [ Attr.class "loading loading-ring loading-md" ] []
                        , Html.div []
                            [ Html.div [ Attr.class "font-semibold text-lg" ] [ Html.text description ]
                            , Html.div [ Attr.class "text-sm opacity-80" ] [ Html.text "Currently tracking" ]
                            ]
                        ]
                    , Html.div [ Attr.class "text-3xl font-mono font-bold" ]
                        [ Html.text timerText ]
                    ]
                ]


{-| Format the elapsed time between now and start as HH:MM:SS or D:HH:MM:SS.
-}
relativeTimer : Time.Posix -> Time.Posix -> String
relativeTimer now start =
    let
        diff : Int
        diff =
            (Time.posixToMillis now - Time.posixToMillis start) // 1000
    in
    if diff < 0 then
        "in the future"

    else
        let
            dayNum : Int
            dayNum =
                diff // 60 // 60 // 24

            seconds : String
            seconds =
                String.padLeft 2 '0' (String.fromInt (remainderBy 60 diff))

            minutes : String
            minutes =
                String.padLeft 2 '0' (String.fromInt (remainderBy 60 (diff // 60)))

            hours : String
            hours =
                String.padLeft 2 '0' (String.fromInt (remainderBy 24 (diff // 60 // 60)))

            days : String
            days =
                if dayNum == 0 then
                    ""

                else
                    String.fromInt dayNum ++ ":"
        in
        days ++ hours ++ ":" ++ minutes ++ ":" ++ seconds


togglConnectionCard : Model -> Html FrontendMsg
togglConnectionCard model =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6 mb-8" ]
        [ case model.togglStatus of
            NotConnected ->
                Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-2 text-base-content/60" ]
                        [ Html.text "Not connected to Toggl" ]
                    , Html.button
                        [ Attr.class "btn btn-outline btn-sm"
                        , Events.onClick RefreshWorkspaces
                        ]
                        [ Html.text "Connect to Toggl" ]
                    ]

            Connecting ->
                Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , Html.text "Connecting to Toggl..."
                    ]

            Connected workspaces ->
                Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-2 text-success" ]
                        [ Html.span [ Attr.class "text-lg" ] [ Html.text "✓" ]
                        , Html.text ("Connected · " ++ String.fromInt (List.length workspaces) ++ " workspace(s)")
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.button
                            [ Attr.class "btn btn-ghost btn-sm"
                            , Events.onClick RefreshWorkspaces
                            , Attr.title "Refresh workspaces from Toggl"
                            ]
                            [ Html.text "🔄" ]
                        , Html.button
                            [ Attr.class "btn btn-primary"
                            , Events.onClick OpenCreateCalendarModal
                            ]
                            [ Html.text "+ New Calendar" ]
                        ]
                    ]

            ConnectionError errorMsg ->
                if String.startsWith "RATE_LIMIT:" errorMsg then
                    let
                        resetTimeStr : String
                        resetTimeStr =
                            case ( model.currentTime, model.currentZone ) of
                                ( Just now, Just zone ) ->
                                    let
                                        -- Parse format: "RATE_LIMIT:seconds|message"
                                        afterPrefix : String
                                        afterPrefix =
                                            String.dropLeft 11 errorMsg

                                        parts : List String
                                        parts =
                                            String.split "|" afterPrefix

                                        secondsStr : String
                                        secondsStr =
                                            List.head parts |> Maybe.withDefault "0"

                                        seconds : Int
                                        seconds =
                                            String.toInt secondsStr |> Maybe.withDefault 3600

                                        resetPosix : Time.Posix
                                        resetPosix =
                                            Time.millisToPosix (Time.posixToMillis now + seconds * 1000)
                                    in
                                    formatTime zone resetPosix

                                _ ->
                                    "soon"
                    in
                    Html.div [ Attr.class "flex flex-col gap-3" ]
                        [ Html.div [ Attr.class "alert alert-warning" ]
                            [ Html.div [ Attr.class "flex flex-col gap-1" ]
                                [ Html.div [ Attr.class "font-semibold" ]
                                    [ Html.text "⏱️ Toggl API Rate Limit Exceeded" ]
                                , Html.div []
                                    [ Html.text ("You've hit the hourly API limit. Resets at " ++ resetTimeStr ++ ".") ]
                                , Html.div [ Attr.class "text-sm opacity-80 mt-2" ]
                                    [ Html.text "Tip: Refresh the page after that time to reconnect." ]
                                ]
                            ]
                        ]

                else
                    Html.div [ Attr.class "alert alert-error" ]
                        [ Html.text ("Connection error: " ++ errorMsg) ]
        ]


{-| Format a time as "10:02 PM" style.
-}
formatTime : Time.Zone -> Time.Posix -> String
formatTime zone posix =
    DateFormat.format
        [ DateFormat.hourNumber
        , DateFormat.text ":"
        , DateFormat.minuteFixed
        , DateFormat.text " "
        , DateFormat.amPmUppercase
        ]
        zone
        posix


mainContent : Model -> Html FrontendMsg
mainContent model =
    case ( model.currentTime, model.currentZone ) of
        ( Just time, Just zone ) ->
            let
                now : PointInTime
                now =
                    { zone = zone, posix = time }
            in
            Html.div [ Attr.class "flex flex-wrap gap-8 justify-center" ]
                (viewCalendars now model)

        _ ->
            Html.div [ Attr.class "text-center text-base-content/60" ]
                [ Html.text "Loading..." ]


viewCalendars : PointInTime -> Model -> List (Html FrontendMsg)
viewCalendars now model =
    let
        calendars : List HabitCalendar
        calendars =
            CalendarDict.values model.calendars
    in
    if List.isEmpty calendars then
        [ viewDemoCalendar now ]

    else
        List.map (viewCalendar now) calendars


viewDemoCalendar : PointInTime -> Html FrontendMsg
viewDemoCalendar now =
    let
        demoCalendar : HabitCalendar
        demoCalendar =
            HabitCalendar.emptyCalendar (HabitCalendarId "demo") "Example Habit"
                |> addDemoEntries now
    in
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6" ]
        [ Calendar.viewWithTitle now demoCalendar
        , Html.p [ Attr.class "text-sm text-base-content/50 mt-4 text-center" ]
            [ Html.text "Connect Toggl to see your real data" ]
        ]


addDemoEntries : PointInTime -> HabitCalendar -> HabitCalendar
addDemoEntries now calendar =
    let
        entries : Dict Int DayEntry
        entries =
            [ ( -1, 45 ), ( -2, 30 ), ( -3, 15 ), ( -5, 60 ), ( -6, 25 ), ( -8, 35 ), ( -10, 50 ) ]
                |> List.map
                    (\( daysAgo, minutes ) ->
                        let
                            dayMillis : Int
                            dayMillis =
                                DateUtils.mondaysAgo 0 now
                                    |> (\pt -> { pt | posix = Time.Extra.add Time.Extra.Day daysAgo now.zone pt.posix })
                                    |> DateUtils.startOfDay
                        in
                        ( dayMillis
                        , { dayStartMillis = dayMillis, totalMinutes = minutes }
                        )
                    )
                |> Dict.fromList
    in
    HabitCalendar.setEntries entries calendar


viewCalendar : PointInTime -> HabitCalendar -> Html FrontendMsg
viewCalendar now calendar =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6" ]
        [ Calendar.viewWithTitle now calendar ]


{-| Display webhook debug log for troubleshooting webhook events.
-}
webhookDebugView : Model -> Html FrontendMsg
webhookDebugView model =
    if List.isEmpty model.webhookDebugLog then
        Html.text ""

    else
        Html.div [ Attr.class "mt-8" ]
            [ Html.div [ Attr.class "card bg-base-100 shadow-lg" ]
                [ Html.div [ Attr.class "card-body" ]
                    [ Html.h2 [ Attr.class "card-title text-base-content" ]
                        [ Html.text "Webhook Debug Log"
                        , Html.span [ Attr.class "badge badge-info" ]
                            [ Html.text (String.fromInt (List.length model.webhookDebugLog)) ]
                        ]
                    , Html.div [ Attr.class "space-y-2 max-h-96 overflow-y-auto" ]
                        (List.map viewWebhookDebugEntry model.webhookDebugLog)
                    ]
                ]
            ]


{-| View a single webhook debug entry.
-}
viewWebhookDebugEntry : Types.WebhookDebugEntry -> Html FrontendMsg
viewWebhookDebugEntry entry =
    let
        badgeClass : String
        badgeClass =
            case entry.eventType of
                "validation" ->
                    "badge-success"

                "event" ->
                    "badge-info"

                "error" ->
                    "badge-error"

                _ ->
                    "badge-ghost"
    in
    Html.div [ Attr.class "collapse collapse-arrow bg-base-200" ]
        [ Html.input [ Attr.type_ "checkbox", Attr.class "peer" ] []
        , Html.div [ Attr.class "collapse-title font-medium flex items-center gap-2" ]
            [ Html.span [ Attr.class ("badge " ++ badgeClass) ]
                [ Html.text entry.eventType ]
            , Html.text entry.description
            ]
        , Html.div [ Attr.class "collapse-content" ]
            [ Html.pre [ Attr.class "bg-base-300 p-3 rounded text-xs overflow-x-auto" ]
                [ Html.text entry.rawJson ]
            ]
        ]


{-| View the modal overlay if a modal is open.
-}
viewModal : Model -> Html FrontendMsg
viewModal model =
    case model.modalState of
        ModalClosed ->
            Html.text ""

        ModalCreateCalendar modalData ->
            viewCreateCalendarModal model modalData


{-| View the "Create Calendar" modal.
-}
viewCreateCalendarModal : Model -> CreateCalendarModal -> Html FrontendMsg
viewCreateCalendarModal model modalData =
    Html.div [ Attr.class "fixed inset-0 z-50 flex items-center justify-center" ]
        [ -- Backdrop
          Html.div
            [ Attr.class "absolute inset-0 bg-black/50"
            , Events.onClick CloseModal
            ]
            []
        , -- Modal box
          Html.div [ Attr.class "relative z-10 bg-base-100 rounded-lg shadow-xl p-6 max-w-md w-full mx-4" ]
            [ Html.h3 [ Attr.class "font-bold text-lg mb-4" ]
                [ Html.text "Create New Calendar" ]
            , viewWorkspaceSelector model modalData
            , viewProjectSelector model modalData
            , viewCalendarNameInput modalData
            , Html.div [ Attr.class "flex justify-end gap-2 mt-6" ]
                [ Html.button
                    [ Attr.class "btn"
                    , Events.onClick CloseModal
                    ]
                    [ Html.text "Cancel" ]
                , Html.button
                    [ Attr.class "btn btn-primary"
                    , Attr.disabled (not (canSubmitCalendar modalData))
                    , Events.onClick SubmitCreateCalendar
                    ]
                    [ Html.text "Create" ]
                ]
            ]
        ]


{-| Check if the modal has enough data to submit.
-}
canSubmitCalendar : CreateCalendarModal -> Bool
canSubmitCalendar modalData =
    case ( modalData.selectedWorkspace, modalData.selectedProject ) of
        ( Just _, Just _ ) ->
            not (String.isEmpty modalData.calendarName)

        _ ->
            False


{-| View the workspace selector dropdown.
-}
viewWorkspaceSelector : Model -> CreateCalendarModal -> Html FrontendMsg
viewWorkspaceSelector model modalData =
    let
        workspaces : List TogglWorkspace
        workspaces =
            case model.togglStatus of
                Connected ws ->
                    ws

                _ ->
                    []
    in
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Workspace" ] ]
        , Html.div [ Attr.class "flex flex-wrap gap-2" ]
            (List.map (workspaceButton modalData.selectedWorkspace) workspaces)
        ]


{-| Button for selecting a workspace.
-}
workspaceButton : Maybe TogglWorkspace -> TogglWorkspace -> Html FrontendMsg
workspaceButton selectedWorkspace workspace =
    let
        isSelected : Bool
        isSelected =
            case selectedWorkspace of
                Just ws ->
                    ws.id == workspace.id

                Nothing ->
                    False
    in
    Html.button
        [ Attr.class
            ("btn btn-sm "
                ++ (if isSelected then
                        "btn-primary"

                    else
                        "btn-outline"
                   )
            )
        , Events.onClick (SelectWorkspace workspace)
        ]
        [ Html.text workspace.name ]


{-| View the project selector dropdown.
-}
viewProjectSelector : Model -> CreateCalendarModal -> Html FrontendMsg
viewProjectSelector model modalData =
    case modalData.selectedWorkspace of
        Nothing ->
            Html.div [ Attr.class "form-control mb-4 opacity-50" ]
                [ Html.label [ Attr.class "label" ]
                    [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Project" ] ]
                , Html.p [ Attr.class "text-sm text-base-content/60" ]
                    [ Html.text "Select a workspace first" ]
                ]

        Just _ ->
            Html.div [ Attr.class "form-control mb-4" ]
                [ Html.label [ Attr.class "label" ]
                    [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Project" ] ]
                , if model.projectsLoading then
                    Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                        , Html.text "Loading projects..."
                        ]

                  else if List.isEmpty model.availableProjects then
                    Html.p [ Attr.class "text-sm text-base-content/60" ]
                        [ Html.text "No projects found in this workspace" ]

                  else
                    Html.div [ Attr.class "flex flex-wrap gap-2 max-h-48 overflow-y-auto" ]
                        (List.map (projectButton modalData.selectedProject) model.availableProjects)
                ]


{-| Button for selecting a project.
-}
projectButton : Maybe TogglProject -> TogglProject -> Html FrontendMsg
projectButton selectedProject project =
    let
        isSelected : Bool
        isSelected =
            case selectedProject of
                Just p ->
                    p.id == project.id

                Nothing ->
                    False
    in
    Html.button
        [ Attr.class
            ("btn btn-sm "
                ++ (if isSelected then
                        "btn-primary"

                    else
                        "btn-outline"
                   )
            )
        , Events.onClick (SelectProject project)
        ]
        [ Html.text project.name ]


{-| View the calendar name input field.
-}
viewCalendarNameInput : CreateCalendarModal -> Html FrontendMsg
viewCalendarNameInput modalData =
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Calendar Name" ] ]
        , Html.input
            [ Attr.type_ "text"
            , Attr.placeholder "Enter a name for this calendar"
            , Attr.value modalData.calendarName
            , Attr.class "input input-bordered"
            , Events.onInput CalendarNameChanged
            ]
            []
        ]


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
