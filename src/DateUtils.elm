module DateUtils exposing
    ( DayComparison(..)
    , PointInTime
    , compareDays
    , formatDateForApi
    , formatMonthDay
    , mondaysAgo
    , pacificTimezoneOffsetMinutes
    , startOfDay
    )

{-| Utilities for working with dates and times in the calendar.
-}

import DateFormat
import Time exposing (Month(..), Posix, Weekday(..), Zone)
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
        -- Floor both to start of day to compare calendar dates, not exact times
        refStartOfDay : Int
        refStartOfDay =
            startOfDay reference

        targetStartOfDay : Int
        targetStartOfDay =
            startOfDay target
    in
    if targetStartOfDay == refStartOfDay then
        Today

    else if targetStartOfDay > refStartOfDay then
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
    DateFormat.format
        [ DateFormat.monthNumber
        , DateFormat.text "/"
        , DateFormat.dayOfMonthNumber
        ]
        time.zone
        time.posix


{-| US Pacific time's offset from UTC, in minutes, using the ISO-8601 / UTC-offset
convention (minutes to add to UTC to get local time, so negative when behind UTC).

  - PST (standard) = -480 (UTC-8)
  - PDT (daylight) = -420 (UTC-7)

DST runs from the second Sunday of March to the first Sunday of November. The
DST decision is made from the UTC date, which is correct except for the few
hours around each transition - good enough for picking the local calendar day.

This is sent to the Monofocus Hub as `offset_minutes` so it picks "today's"
active project in Pacific time rather than UTC.

-}
pacificTimezoneOffsetMinutes : Posix -> Int
pacificTimezoneOffsetMinutes posix =
    if isUsPacificDst posix then
        -420

    else
        -480


{-| Whether the given instant falls within US daylight saving time.
-}
isUsPacificDst : Posix -> Bool
isUsPacificDst posix =
    let
        day : Int
        day =
            Time.toDay Time.utc posix

        weekday : Int
        weekday =
            sundayBasedWeekday (Time.toWeekday Time.utc posix)

        -- Weekday of the 1st of this month (Sun = 0 .. Sat = 6).
        firstOfMonthWeekday : Int
        firstOfMonthWeekday =
            modBy 7 (weekday - modBy 7 (day - 1) + 7)

        -- Day-of-month of the first Sunday this month.
        firstSunday : Int
        firstSunday =
            if firstOfMonthWeekday == 0 then
                1

            else
                8 - firstOfMonthWeekday
    in
    case Time.toMonth Time.utc posix of
        Jan ->
            False

        Feb ->
            False

        Mar ->
            -- DST starts on the second Sunday of March.
            day >= firstSunday + 7

        Apr ->
            True

        May ->
            True

        Jun ->
            True

        Jul ->
            True

        Aug ->
            True

        Sep ->
            True

        Oct ->
            True

        Nov ->
            -- DST ends on the first Sunday of November.
            day < firstSunday

        Dec ->
            False


{-| Weekday as a number with Sunday = 0 .. Saturday = 6.
-}
sundayBasedWeekday : Weekday -> Int
sundayBasedWeekday weekday =
    case weekday of
        Sun ->
            0

        Mon ->
            1

        Tue ->
            2

        Wed ->
            3

        Thu ->
            4

        Fri ->
            5

        Sat ->
            6


{-| Format a Posix time as YYYY-MM-DD for APIs.
-}
formatDateForApi : Posix -> String
formatDateForApi posix =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthFixed
        , DateFormat.text "-"
        , DateFormat.dayOfMonthFixed
        ]
        Time.utc
        posix
