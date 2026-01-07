module Calendar exposing (view, viewWithTitle)

{-| Calendar UI component for displaying habit data in a weekly grid.
-}

import Color
import DateUtils exposing (DayComparison(..), PointInTime, compareDays, formatMonthDay, mondaysAgo, startOfDay)
import HabitCalendar exposing (HabitCalendar, getMinutesForDay)
import Html exposing (Html, div, h2, text)
import Html.Attributes exposing (attribute, class, style)
import Time
import Time.Extra
import Types exposing (RunningEntry(..))


{-| View a calendar with a title header.
-}
viewWithTitle : PointInTime -> RunningEntry -> HabitCalendar -> Html msg
viewWithTitle now runningEntry calendar =
    div [ class "flex flex-col gap-2" ]
        [ h2 [ class "text-lg font-semibold text-base-content" ]
            [ text calendar.name ]
        , view now runningEntry calendar
        ]


{-| View the calendar grid.
-}
view : PointInTime -> RunningEntry -> HabitCalendar -> Html msg
view now runningEntry calendar =
    let
        weeks : List Int
        weeks =
            List.range 0 calendar.weeksShowing
                |> List.reverse
    in
    div [ class "flex flex-col gap-1" ]
        (List.map (weekRow now runningEntry calendar) weeks)


{-| Render a single week row (7 days).
-}
weekRow : PointInTime -> RunningEntry -> HabitCalendar -> Int -> Html msg
weekRow now runningEntry calendar weeksBack =
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
                    dayCell now runningEntry calendar day
                )
        )


{-| Render a single day cell.
-}
dayCell : PointInTime -> RunningEntry -> HabitCalendar -> PointInTime -> Html msg
dayCell now runningEntry calendar day =
    let
        dayMillis : Int
        dayMillis =
            startOfDay day

        baseMinutes : Int
        baseMinutes =
            getMinutesForDay dayMillis calendar

        comparison : DayComparison
        comparison =
            compareDays now day

        -- Calculate additional minutes from running timer if applicable
        runningMinutes : Int
        runningMinutes =
            case ( runningEntry, comparison ) of
                ( RunningEntry payload, Today ) ->
                    -- Check if the running timer is for this calendar's project
                    case payload.projectId of
                        Just projectId ->
                            if projectId == calendar.projectId then
                                -- Calculate duration in minutes from start to now
                                let
                                    durationSeconds : Int
                                    durationSeconds =
                                        (Time.posixToMillis now.posix - Time.posixToMillis payload.start) // 1000
                                in
                                durationSeconds // 60

                            else
                                0

                        Nothing ->
                            0

                _ ->
                    0

        -- Total minutes including running timer
        minutes : Int
        minutes =
            baseMinutes + runningMinutes

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

        testId : String
        testId =
            "day-" ++ formatIsoDate day
    in
    div
        [ class ("w-10 h-10 rounded flex flex-col items-center justify-center text-xs " ++ borderClass)
        , style "background-color" bgColor
        , style "color" textColor
        , attribute "data-testid" testId
        ]
        [ div [ class "text-[10px] opacity-70" ] [ text (formatMonthDay day) ]
        , div [ class "font-medium" ] [ text minuteText ]
        ]


{-| Format a date as YYYY-MM-DD for test IDs.
-}
formatIsoDate : PointInTime -> String
formatIsoDate time =
    let
        year : String
        year =
            Time.toYear time.zone time.posix |> String.fromInt

        month : String
        month =
            Time.toMonth time.zone time.posix |> monthToNumber |> String.fromInt |> String.padLeft 2 '0'

        day : String
        day =
            Time.toDay time.zone time.posix |> String.fromInt |> String.padLeft 2 '0'
    in
    year ++ "-" ++ month ++ "-" ++ day


{-| Convert a Month to its number (1-12).
-}
monthToNumber : Time.Month -> Int
monthToNumber m =
    case m of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


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
