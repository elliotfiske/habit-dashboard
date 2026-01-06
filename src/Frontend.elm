module Frontend exposing (FrontendApp, Model, UnwrappedFrontendApp, app, app_)

import Browser
import Browser.Navigation
import Calendar
import CalendarDict
import DateUtils exposing (PointInTime, formatDateForApi)
import Dict exposing (Dict)
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera
import Effect.Subscription as Subscription exposing (Subscription)
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
import Types exposing (CreateCalendarModal, FrontendModel, FrontendMsg(..), ModalState(..), ToBackend(..), ToFrontend(..), TogglConnectionStatus(..))
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
      , togglStatus = Connecting
      , modalState = ModalClosed
      , availableProjects = []
      , projectsLoading = False
      }
    , Command.batch
        [ Effect.Task.perform GotTime Effect.Time.now
        , Effect.Task.perform GotZone Effect.Time.here
        , Effect.Lamdera.sendToBackend FetchTogglWorkspaces
        ]
    )


subscriptions : Model -> Subscription FrontendOnly FrontendMsg
subscriptions _ =
    Subscription.none


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
                            in
                            ( { model | modalState = ModalClosed }
                            , Effect.Lamdera.sendToBackend
                                (FetchTogglTimeEntries calendarInfo workspace.id project.id startDate endDate)
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


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div [ Attr.class "min-h-screen bg-base-200 p-8" ]
            [ Html.div [ Attr.class "max-w-4xl mx-auto" ]
                [ header
                , togglConnectionCard model
                , mainContent model
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


togglConnectionCard : Model -> Html FrontendMsg
togglConnectionCard model =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6 mb-8" ]
        [ case model.togglStatus of
            NotConnected ->
                Html.div [ Attr.class "flex items-center gap-2 text-base-content/60" ]
                    [ Html.text "Not connected to Toggl" ]

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
                    , Html.button
                        [ Attr.class "btn btn-primary"
                        , Events.onClick OpenCreateCalendarModal
                        ]
                        [ Html.text "+ New Calendar" ]
                    ]

            ConnectionError errorMsg ->
                if String.startsWith "RATE_LIMIT:" errorMsg then
                    let
                        -- Parse format: "RATE_LIMIT:Xm Ys|message"
                        afterPrefix : String
                        afterPrefix =
                            String.dropLeft 11 errorMsg

                        parts : List String
                        parts =
                            String.split "|" afterPrefix

                        timeRemaining : String
                        timeRemaining =
                            List.head parts |> Maybe.withDefault "unknown"
                    in
                    Html.div [ Attr.class "flex flex-col gap-3" ]
                        [ Html.div [ Attr.class "alert alert-warning" ]
                            [ Html.div [ Attr.class "flex flex-col gap-1" ]
                                [ Html.div [ Attr.class "font-semibold" ]
                                    [ Html.text "⏱️ Toggl API Rate Limit Exceeded" ]
                                , Html.div []
                                    [ Html.text ("You've hit the hourly API limit. Resets in " ++ timeRemaining ++ ".") ]
                                , Html.div [ Attr.class "text-sm opacity-80 mt-2" ]
                                    [ Html.text "Tip: Refresh the page after the timer expires to reconnect." ]
                                ]
                            ]
                        ]

                else
                    Html.div [ Attr.class "alert alert-error" ]
                        [ Html.text ("Connection error: " ++ errorMsg) ]
        ]


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
