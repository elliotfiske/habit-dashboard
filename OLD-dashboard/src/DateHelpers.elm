module DateHelpers exposing (..)

import DateFormat
import String exposing (padLeft)
import Time exposing (Posix, Weekday(..), posixToMillis)
import Time.Extra
import Types exposing (DayComparison(..), PointInTime)


formatMonthDay : PointInTime -> String
formatMonthDay time =
    DateFormat.format
        [ DateFormat.monthNumber
        , DateFormat.text "/"
        , DateFormat.dayOfMonthNumber
        ]
        time.zone
        time.posix


convertWeekdayToNumber : Time.Weekday -> Int
convertWeekdayToNumber weekday =
    case weekday of
        Mon ->
            0

        Tue ->
            1

        Wed ->
            2

        Thu ->
            3

        Fri ->
            4

        Sat ->
            5

        Sun ->
            6



-- Used to format the date to match my Airkit-created dictionary


dictFormatter : PointInTime -> String
dictFormatter time =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthFixed
        , DateFormat.text "-"
        , DateFormat.dayOfMonthFixed
        ]
        time.zone
        time.posix


relativeTimer : Posix -> Posix -> String
relativeTimer now start =
    let
        diff =
            (posixToMillis now - posixToMillis start) // 1000

        dayNum =
            diff // 60 // 60 // 24

        seconds =
            padLeft 2 '0' (String.fromInt (remainderBy 60 diff))

        minutes =
            padLeft 2 '0' (String.fromInt (remainderBy 60 (diff // 60)))

        hours =
            padLeft 2 '0' (String.fromInt (remainderBy 24 (diff // 60 // 60)))

        days =
            if dayNum == 0 then
                ""

            else
                padLeft 2 '0' (String.fromInt dayNum ++ ":")
    in
    if diff < 0 then
        "in the future"

    else
        days
            ++ hours
            ++ ":"
            ++ minutes
            ++ ":"
            ++ seconds


mostRecentMonday : PointInTime -> Posix
mostRecentMonday time =
    let
        dayNum =
            time.posix
                |> Time.toWeekday time.zone
                |> convertWeekdayToNumber
    in
    Time.Extra.add Time.Extra.Day -dayNum time.zone time.posix


mondaysAgo : Int -> PointInTime -> PointInTime
mondaysAgo num time =
    let
        posix =
            mostRecentMonday time |> Time.Extra.add Time.Extra.Week -num time.zone
    in
    { time | posix = posix }


compareDays : PointInTime -> PointInTime -> DayComparison
compareDays time1 time2 =
    let
        integerComparison =
            Time.Extra.diff Time.Extra.Day time1.zone time1.posix time2.posix
    in
    if integerComparison == 0 then
        Today

    else if integerComparison > 0 then
        Future

    else
        Past


sameDay : PointInTime -> PointInTime -> Bool
sameDay time1 time2 =
    DateFormat.format [ DateFormat.dayOfYearNumber ] time1.zone time1.posix
        == DateFormat.format [ DateFormat.dayOfYearNumber ] time2.zone time2.posix
