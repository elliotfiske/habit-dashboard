module OrangetheoryLogic exposing (countWorkoutsInPeriod, goal)

{-| Logic for Orangetheory workout tracking.

Counts workouts in the current billing period (13th to 12th).
Only counts time entries with "Orangetheory" in the description.

-}

import DateUtils exposing (PointInTime)
import HabitCalendar exposing (HabitCalendar)
import SeqDict
import Set exposing (Set)
import Time exposing (Posix)
import Time.Extra
import Toggl exposing (TimeEntry)


{-| The monthly workout goal.
-}
goal : Int
goal =
    8


{-| Count days with Orangetheory entries in the current billing period.
-}
countWorkoutsInPeriod : PointInTime -> HabitCalendar -> Int
countWorkoutsInPeriod now calendar =
    let
        ( periodStart, periodEnd ) =
            getCurrentPeriod now

        periodStartMillis : Int
        periodStartMillis =
            Time.posixToMillis periodStart

        periodEndMillis : Int
        periodEndMillis =
            Time.posixToMillis periodEnd

        -- Filter entries that have "Orangetheory" in description (case-insensitive)
        orangetheoryEntries : List TimeEntry
        orangetheoryEntries =
            SeqDict.values calendar.timeEntries
                |> List.filter hasOrangetheoryDescription

        -- Get unique days (as start-of-day millis) within the billing period
        uniqueDays : Set Int
        uniqueDays =
            orangetheoryEntries
                |> List.filterMap (entryToDayIfInPeriod now.zone periodStartMillis periodEndMillis)
                |> Set.fromList
    in
    Set.size uniqueDays


{-| Check if entry description contains "Orangetheory" (case-insensitive).
-}
hasOrangetheoryDescription : TimeEntry -> Bool
hasOrangetheoryDescription entry =
    case entry.description of
        Just desc ->
            String.contains "orangetheory" (String.toLower desc)

        Nothing ->
            False


{-| Get the day (as start-of-day millis) if entry falls within the period.
-}
entryToDayIfInPeriod : Time.Zone -> Int -> Int -> TimeEntry -> Maybe Int
entryToDayIfInPeriod zone periodStartMillis periodEndMillis entry =
    let
        entryMillis : Int
        entryMillis =
            Time.posixToMillis entry.start
    in
    if entryMillis >= periodStartMillis && entryMillis <= periodEndMillis then
        Just
            (Time.Extra.floor Time.Extra.Day zone entry.start
                |> Time.posixToMillis
            )

    else
        Nothing


{-| Get the current billing period (13th to 12th).

If today is before the 13th, period is prev month 13th to this month 12th.
If today is on or after the 13th, period is this month 13th to next month 12th.

-}
getCurrentPeriod : PointInTime -> ( Posix, Posix )
getCurrentPeriod now =
    let
        currentDay : Int
        currentDay =
            Time.toDay now.zone now.posix

        currentYear : Int
        currentYear =
            Time.toYear now.zone now.posix

        currentMonth : Time.Month
        currentMonth =
            Time.toMonth now.zone now.posix

        -- If before 13th, go back one month for start
        ( startYear, startMonth ) =
            if currentDay < 13 then
                prevMonth currentYear currentMonth

            else
                ( currentYear, currentMonth )

        -- End is always one month after start
        ( endYear, endMonth ) =
            nextMonth startYear startMonth

        -- Start is 13th at 00:00:00
        periodStart : Posix
        periodStart =
            Time.Extra.partsToPosix now.zone
                { year = startYear
                , month = startMonth
                , day = 13
                , hour = 0
                , minute = 0
                , second = 0
                , millisecond = 0
                }

        -- End is 12th at 23:59:59
        periodEnd : Posix
        periodEnd =
            Time.Extra.partsToPosix now.zone
                { year = endYear
                , month = endMonth
                , day = 12
                , hour = 23
                , minute = 59
                , second = 59
                , millisecond = 999
                }
    in
    ( periodStart, periodEnd )


{-| Get the previous month (handles year boundary).
-}
prevMonth : Int -> Time.Month -> ( Int, Time.Month )
prevMonth year month =
    case month of
        Time.Jan ->
            ( year - 1, Time.Dec )

        Time.Feb ->
            ( year, Time.Jan )

        Time.Mar ->
            ( year, Time.Feb )

        Time.Apr ->
            ( year, Time.Mar )

        Time.May ->
            ( year, Time.Apr )

        Time.Jun ->
            ( year, Time.May )

        Time.Jul ->
            ( year, Time.Jun )

        Time.Aug ->
            ( year, Time.Jul )

        Time.Sep ->
            ( year, Time.Aug )

        Time.Oct ->
            ( year, Time.Sep )

        Time.Nov ->
            ( year, Time.Oct )

        Time.Dec ->
            ( year, Time.Nov )


{-| Get the next month (handles year boundary).
-}
nextMonth : Int -> Time.Month -> ( Int, Time.Month )
nextMonth year month =
    case month of
        Time.Jan ->
            ( year, Time.Feb )

        Time.Feb ->
            ( year, Time.Mar )

        Time.Mar ->
            ( year, Time.Apr )

        Time.Apr ->
            ( year, Time.May )

        Time.May ->
            ( year, Time.Jun )

        Time.Jun ->
            ( year, Time.Jul )

        Time.Jul ->
            ( year, Time.Aug )

        Time.Aug ->
            ( year, Time.Sep )

        Time.Sep ->
            ( year, Time.Oct )

        Time.Oct ->
            ( year, Time.Nov )

        Time.Nov ->
            ( year, Time.Dec )

        Time.Dec ->
            ( year + 1, Time.Jan )
