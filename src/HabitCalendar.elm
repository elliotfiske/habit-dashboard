module HabitCalendar exposing
    ( DayEntry
    , HabitCalendar
    , HabitCalendarId(..)
    , emptyCalendar
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
