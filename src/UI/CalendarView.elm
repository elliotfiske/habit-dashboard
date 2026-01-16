module UI.CalendarView exposing (view)

{-| Calendar rendering and calendar card display.

This module provides UI components for displaying habit calendars,
including the main content area with calendar cards and demo calendar.

-}

import Calendar
import CalendarDict
import CalendarLogic
import DateUtils exposing (PointInTime)
import HabitCalendar exposing (HabitCalendar, HabitCalendarId(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Toggl
import Types exposing (FrontendModel, FrontendMsg(..), RunningEntry)


{-| Main entry point for calendar display area.
Shows "Loading..." if time/zone not available, otherwise displays calendars.
-}
view : FrontendModel -> Html FrontendMsg
view model =
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


{-| Display list of calendar cards.
Shows demo calendar if no calendars exist, otherwise shows all real calendars.
-}
viewCalendars : PointInTime -> FrontendModel -> List (Html FrontendMsg)
viewCalendars now model =
    let
        calendars : List HabitCalendar
        calendars =
            CalendarDict.values model.calendars
    in
    if List.isEmpty calendars then
        [ viewDemoCalendar now model.runningEntry ]

    else
        List.map (viewCalendar now model.runningEntry) calendars


{-| Display demo calendar with sample data.
Shown when user has no real calendars yet.
-}
viewDemoCalendar : PointInTime -> RunningEntry -> Html FrontendMsg
viewDemoCalendar now runningEntry =
    let
        demoCalendar : HabitCalendar
        demoCalendar =
            HabitCalendar.emptyCalendar
                (HabitCalendarId "demo")
                "Example Habit"
                now.zone
                (Toggl.TogglWorkspaceId 0)
                (Toggl.TogglProjectId 0)
                |> CalendarLogic.addDemoEntries now
    in
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6" ]
        [ Calendar.viewWithTitle now runningEntry demoCalendar
        , Html.p [ Attr.class "text-sm text-base-content/50 mt-4 text-center" ]
            [ Html.text "Connect Toggl to see your real data" ]
        ]


{-| Display individual calendar card with action buttons.
-}
viewCalendar : PointInTime -> RunningEntry -> HabitCalendar -> Html FrontendMsg
viewCalendar now runningEntry calendar =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6" ]
        [ Html.div [ Attr.class "flex justify-between items-start mb-4" ]
            [ Html.h3 [ Attr.class "text-lg font-semibold text-base-content" ]
                [ Html.text calendar.name ]
            , Html.div [ Attr.class "flex gap-1" ]
                [ Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick (RefreshCalendar calendar.id calendar.workspaceId calendar.projectId calendar.name)
                    , Attr.title "Refresh calendar data from Toggl"
                    , Attr.attribute "data-testid" ("refresh-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "🔄" ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick (OpenEditCalendarModal calendar)
                    , Attr.title "Edit calendar"
                    , Attr.attribute "data-testid" ("edit-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "✏️" ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost text-error"
                    , Events.onClick (DeleteCalendar calendar.id)
                    , Attr.title "Delete calendar"
                    , Attr.attribute "data-testid" ("delete-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "🗑️" ]
                ]
            ]
        , Calendar.view now runningEntry calendar
        ]
