module CalendarLogic exposing (addDemoEntries, calculateDateRange)

{-| Calendar-specific business operations.

This module provides utilities for working with habit calendars:

  - Adding demo/sample entries to calendars for demonstration
  - Calculating date ranges for data fetching

-}

import DateUtils exposing (PointInTime, formatDateForApi)
import Dict exposing (Dict)
import HabitCalendar exposing (DayEntry, HabitCalendar)
import Time
import Time.Extra


{-| Add sample entries to a calendar for demo display.
Generates entries at -1, -2, -3, -5, -6, -8, -10 days ago with varying durations.
-}
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


{-| Calculate start and end dates for calendar refresh (last 28 days).
Returns a tuple of (startDate, endDate) formatted as API-compatible strings.
Falls back to a default range if currentTime is not available.
-}
calculateDateRange : Maybe Time.Posix -> ( String, String )
calculateDateRange maybeNow =
    case maybeNow of
        Just now ->
            ( Time.Extra.add Time.Extra.Day -28 Time.utc now
                |> formatDateForApi
            , formatDateForApi now
            )

        Nothing ->
            ( "2026-01-01", "2026-01-28" )
