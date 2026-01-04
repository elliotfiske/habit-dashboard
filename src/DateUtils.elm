module DateUtils exposing
    ( DayComparison(..)
    , PointInTime
    , compareDays
    , formatMonthDay
    , mondaysAgo
    , startOfDay
    )

{-| Utilities for working with dates and times in the calendar.
-}

import Time exposing (Posix, Weekday(..), Zone)
import Time.Extra


{-| A point in time with its timezone context.
-}
type alias PointInTime =
    { zone : Zone
    , posix : Posix
    }


{-| Result of comparing two days.
-}
type DayComparison
    = Past
    | Today
    | Future


{-| Convert a weekday to a number (Monday = 0, Sunday = 6).
-}
weekdayToNumber : Weekday -> Int
weekdayToNumber weekday =
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


{-| Get the most recent Monday at the start of day.
-}
mostRecentMonday : PointInTime -> Posix
mostRecentMonday time =
    let
        dayNum : Int
        dayNum =
            time.posix
                |> Time.toWeekday time.zone
                |> weekdayToNumber

        mondayPosix : Posix
        mondayPosix =
            Time.Extra.add Time.Extra.Day -dayNum time.zone time.posix
    in
    Time.Extra.floor Time.Extra.Day time.zone mondayPosix


{-| Get the Monday from N weeks ago.
-}
mondaysAgo : Int -> PointInTime -> PointInTime
mondaysAgo weeksBack time =
    let
        posix : Posix
        posix =
            mostRecentMonday time
                |> Time.Extra.add Time.Extra.Week -weeksBack time.zone
    in
    { time | posix = posix }


{-| Compare two points in time to see if they're the same day, past, or future.
-}
compareDays : PointInTime -> PointInTime -> DayComparison
compareDays reference target =
    let
        daysDiff : Int
        daysDiff =
            Time.Extra.diff Time.Extra.Day reference.zone reference.posix target.posix
    in
    if daysDiff == 0 then
        Today

    else if daysDiff > 0 then
        Future

    else
        Past


{-| Get the start of day in milliseconds for a given point in time.
Useful as a dictionary key.
-}
startOfDay : PointInTime -> Int
startOfDay time =
    Time.Extra.floor Time.Extra.Day time.zone time.posix
        |> Time.posixToMillis


{-| Format a date as "M/D" (e.g., "1/15").
-}
formatMonthDay : PointInTime -> String
formatMonthDay time =
    let
        month : String
        month =
            Time.toMonth time.zone time.posix |> monthToNumber |> String.fromInt

        day : String
        day =
            Time.toDay time.zone time.posix |> String.fromInt
    in
    month ++ "/" ++ day


{-| Convert a Month to its number (1-12).
-}
monthToNumber : Time.Month -> Int
monthToNumber month =
    case month of
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
