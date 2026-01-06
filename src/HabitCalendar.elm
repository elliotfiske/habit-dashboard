module HabitCalendar exposing
    ( DayEntry
    , HabitCalendar
    , HabitCalendarId(..)
    , emptyCalendar
    , fromTimeEntries
    , getMinutesForDay
    , habitCalendarIdToString
    , setEntries
    )

{-| Domain types for habit calendars.

A HabitCalendar displays aggregated time data over a period of weeks,
with each day showing the total minutes tracked for a specific habit.

-}

import Color exposing (Color)
import Dict exposing (Dict)
import Time exposing (Zone)
import Time.Extra
import Toggl exposing (TimeEntry)


{-| Tagged ID type for habit calendars.
-}
type HabitCalendarId
    = HabitCalendarId String


{-| Convert a HabitCalendarId to a String for Dict keys.
-}
habitCalendarIdToString : HabitCalendarId -> String
habitCalendarIdToString (HabitCalendarId id) =
    id


{-| A habit calendar configuration and its data.
-}
type alias HabitCalendar =
    { id : HabitCalendarId
    , name : String
    , successColor : Color
    , nonzeroColor : Color
    , weeksShowing : Int
    , entries : Dict Int DayEntry -- Keyed by day (posix millis at start of day)
    }


{-| A single day's worth of tracked time.
-}
type alias DayEntry =
    { dayStartMillis : Int
    , totalMinutes : Int
    }


{-| Create an empty calendar with default settings.
-}
emptyCalendar : HabitCalendarId -> String -> HabitCalendar
emptyCalendar id name =
    { id = id
    , name = name
    , successColor = Color.rgb255 34 197 94 -- green-500
    , nonzeroColor = Color.rgb255 134 239 172 -- green-300
    , weeksShowing = 4
    , entries = Dict.empty
    }


{-| Get the total minutes for a specific day.
Returns 0 if no entry exists for that day.
-}
getMinutesForDay : Int -> HabitCalendar -> Int
getMinutesForDay dayMillis calendar =
    Dict.get dayMillis calendar.entries
        |> Maybe.map .totalMinutes
        |> Maybe.withDefault 0


{-| Set entries for a calendar.
-}
setEntries : Dict Int DayEntry -> HabitCalendar -> HabitCalendar
setEntries entries calendar =
    { calendar | entries = entries }


{-| Create a calendar from a list of Toggl time entries.
Aggregates entries by day, summing up durations.
-}
fromTimeEntries : HabitCalendarId -> String -> Zone -> List TimeEntry -> HabitCalendar
fromTimeEntries calendarId name zone entries =
    let
        -- Calculate day start millis for an entry
        entryToDayMillis : TimeEntry -> Int
        entryToDayMillis entry =
            Time.Extra.floor Time.Extra.Day zone entry.start
                |> Time.posixToMillis

        -- Get duration in minutes (duration is in seconds, -1 means running)
        entryMinutes : TimeEntry -> Int
        entryMinutes entry =
            if entry.duration < 0 then
                -- Running entry - calculate from start to now (we don't have "now" here, so use 0)
                0

            else
                entry.duration // 60

        -- Aggregate entries by day
        aggregatedEntries : Dict Int DayEntry
        aggregatedEntries =
            List.foldl
                (\entry acc ->
                    let
                        dayMillis : Int
                        dayMillis =
                            entryToDayMillis entry

                        minutes : Int
                        minutes =
                            entryMinutes entry

                        existingMinutes : Int
                        existingMinutes =
                            Dict.get dayMillis acc
                                |> Maybe.map .totalMinutes
                                |> Maybe.withDefault 0

                        newEntry : DayEntry
                        newEntry =
                            { dayStartMillis = dayMillis
                            , totalMinutes = existingMinutes + minutes
                            }
                    in
                    Dict.insert dayMillis newEntry acc
                )
                Dict.empty
                entries
    in
    { id = calendarId
    , name = name
    , successColor = Color.rgb255 34 197 94 -- green-500
    , nonzeroColor = Color.rgb255 134 239 172 -- green-300
    , weeksShowing = 4
    , entries = aggregatedEntries
    }
