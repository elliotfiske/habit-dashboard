module Calendar exposing (viewWithTitle)

{-| Calendar UI component for displaying habit data in a weekly grid.
-}

import Color
import DateUtils exposing (DayComparison(..), PointInTime, compareDays, formatMonthDay, mondaysAgo, startOfDay)
import HabitCalendar exposing (HabitCalendar, getMinutesForDay)
import Html exposing (Html, div, h2, text)
import Html.Attributes exposing (class, style)
import Time.Extra


{-| View a calendar with a title header.
-}
viewWithTitle : PointInTime -> HabitCalendar -> Html msg
viewWithTitle now calendar =
    div [ class "flex flex-col gap-2" ]
        [ h2 [ class "text-lg font-semibold text-base-content" ]
            [ text calendar.name ]
        , view now calendar
        ]


{-| View the calendar grid.
-}
view : PointInTime -> HabitCalendar -> Html msg
view now calendar =
    let
        weeks : List Int
        weeks =
            List.range 0 calendar.weeksShowing
                |> List.reverse
    in
    div [ class "flex flex-col gap-1" ]
        (List.map (weekRow now calendar) weeks)


{-| Render a single week row (7 days).
-}
weekRow : PointInTime -> HabitCalendar -> Int -> Html msg
weekRow now calendar weeksBack =
    let
        weekStart : PointInTime
        weekStart =
            mondaysAgo weeksBack now
    in
    div [ class "flex gap-1 justify-center" ]
        (List.range 0 6
            |> List.map
                (\dayOffset ->
                    let
                        day : PointInTime
                        day =
                            { weekStart
                                | posix =
                                    Time.Extra.add Time.Extra.Day dayOffset now.zone weekStart.posix
                            }
                    in
                    dayCell now calendar day
                )
        )


{-| Render a single day cell.
-}
dayCell : PointInTime -> HabitCalendar -> PointInTime -> Html msg
dayCell now calendar day =
    let
        dayMillis : Int
        dayMillis =
            startOfDay day

        minutes : Int
        minutes =
            getMinutesForDay dayMillis calendar

        comparison : DayComparison
        comparison =
            compareDays now day

        ( bgColor, textColor ) =
            cellColors calendar comparison minutes

        borderClass : String
        borderClass =
            case comparison of
                Today ->
                    "ring-2 ring-primary ring-offset-1 ring-offset-base-100"

                _ ->
                    ""

        minuteText : String
        minuteText =
            case comparison of
                Future ->
                    "-"

                _ ->
                    String.fromInt minutes
    in
    div
        [ class ("w-10 h-10 rounded flex flex-col items-center justify-center text-xs " ++ borderClass)
        , style "background-color" bgColor
        , style "color" textColor
        ]
        [ div [ class "text-[10px] opacity-70" ] [ text (formatMonthDay day) ]
        , div [ class "font-medium" ] [ text minuteText ]
        ]


{-| Determine cell colors based on minutes and day comparison.
-}
cellColors : HabitCalendar -> DayComparison -> Int -> ( String, String )
cellColors calendar comparison minutes =
    case comparison of
        Future ->
            ( "oklch(var(--b3))", "oklch(var(--bc) / 0.4)" )

        _ ->
            if minutes >= 30 then
                ( Color.toCssString calendar.successColor, "#fff" )

            else if minutes > 0 then
                ( Color.toCssString calendar.nonzeroColor, "#000" )

            else
                ( "oklch(var(--b3))", "oklch(var(--bc))" )
