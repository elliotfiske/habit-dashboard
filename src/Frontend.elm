module Frontend exposing (FrontendApp, Model, UnwrappedFrontendApp, app, app_)

import Browser
import Browser.Navigation
import Calendar
import CalendarDict
import DateUtils exposing (PointInTime)
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
import Lamdera as L
import Time.Extra
import Types exposing (FrontendModel, FrontendMsg(..), ToBackend, ToFrontend(..))
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
      }
    , Command.batch
        [ Effect.Task.perform GotTime Effect.Time.now
        , Effect.Task.perform GotZone Effect.Time.here
        ]
    )


subscriptions : Model -> Subscription FrontendOnly FrontendMsg
subscriptions _ =
    -- Time subscription disabled for now (requires Duration import workaround)
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


updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Command.none )

        CalendarsUpdated calendars ->
            ( { model | calendars = calendars }, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div [ Attr.class "min-h-screen bg-base-200 p-8" ]
            [ Html.div [ Attr.class "max-w-4xl mx-auto" ]
                [ header
                , mainContent model
                ]
            ]
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
