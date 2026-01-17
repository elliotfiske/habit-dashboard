module HabitCalendar exposing
    ( DayEntry
    , HabitCalendar
    , HabitCalendarId(..)
    , addOrUpdateTimeEntry
    , deleteTimeEntry
    , emptyCalendar
    , fromTimeEntries
    , fromTimeEntriesWithColors
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
import SeqDict exposing (SeqDict)
import Time exposing (Zone)
import Time.Extra
import Toggl exposing (TimeEntry, TimeEntryId, TogglProjectId, TogglWorkspaceId)


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
    , successColor : String
    , nonzeroColor : String
    , weeksShowing : Int
    , entries : Dict Int DayEntry -- Keyed by day (posix millis at start of day)
    , timeEntries : SeqDict TimeEntryId TimeEntry -- All time entries for this calendar
    , timezone : Zone -- User's timezone for aggregating entries by day
    , workspaceId : TogglWorkspaceId -- Toggl workspace this calendar belongs to
    , projectId : TogglProjectId -- Toggl project this calendar tracks
    }


{-| A single day's worth of tracked time.
-}
type alias DayEntry =
    { dayStartMillis : Int
    , totalMinutes : Int
    }


{-| Create an empty calendar with default settings.
-}
emptyCalendar : HabitCalendarId -> String -> Zone -> TogglWorkspaceId -> TogglProjectId -> HabitCalendar
emptyCalendar id name zone workspaceId projectId =
    { id = id
    , name = name
    , successColor = "#805AD5" -- purple-500
    , nonzeroColor = "#D8B4FE" -- purple-300
    , weeksShowing = 4
    , entries = Dict.empty
    , timeEntries = SeqDict.empty
    , timezone = zone
    , workspaceId = workspaceId
    , projectId = projectId
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
fromTimeEntries : HabitCalendarId -> String -> Zone -> TogglWorkspaceId -> TogglProjectId -> List TimeEntry -> HabitCalendar
fromTimeEntries calendarId name zone workspaceId projectId entries =
    let
        -- Store entries in a SeqDict keyed by TimeEntryId
        entriesDict : SeqDict TimeEntryId TimeEntry
        entriesDict =
            List.foldl
                (\entry acc -> SeqDict.insert entry.id entry acc)
                SeqDict.empty
                entries

        -- Aggregate entries by day using the helper function
        aggregatedEntries : Dict Int DayEntry
        aggregatedEntries =
            aggregateEntriesByDay zone (SeqDict.values entriesDict)
    in
    { id = calendarId
    , name = name
    , successColor = "#805AD5" -- purple-500
    , nonzeroColor = "#D8B4FE" -- purple-300
    , weeksShowing = 4
    , entries = aggregatedEntries
    , timeEntries = entriesDict
    , timezone = zone
    , workspaceId = workspaceId
    , projectId = projectId
    }


{-| Create a calendar from time entries with custom colors.
-}
fromTimeEntriesWithColors :
    HabitCalendarId
    -> String
    -> Zone
    -> TogglWorkspaceId
    -> TogglProjectId
    -> String
    -> String
    -> List TimeEntry
    -> HabitCalendar
fromTimeEntriesWithColors calendarId name zone workspaceId projectId successColor nonzeroColor entries =
    let
        entriesDict : SeqDict TimeEntryId TimeEntry
        entriesDict =
            List.foldl
                (\entry acc -> SeqDict.insert entry.id entry acc)
                SeqDict.empty
                entries

        aggregatedEntries : Dict Int DayEntry
        aggregatedEntries =
            aggregateEntriesByDay zone (SeqDict.values entriesDict)
    in
    { id = calendarId
    , name = name
    , successColor = successColor
    , nonzeroColor = nonzeroColor
    , weeksShowing = 4
    , entries = aggregatedEntries
    , timeEntries = entriesDict
    , timezone = zone
    , workspaceId = workspaceId
    , projectId = projectId
    }


{-| Helper function to aggregate time entries by day.
-}
aggregateEntriesByDay : Zone -> List TimeEntry -> Dict Int DayEntry
aggregateEntriesByDay zone entries =
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
    in
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


{-| Add or update a time entry in the calendar.
Re-aggregates all entries after updating.
-}
addOrUpdateTimeEntry : TimeEntry -> HabitCalendar -> HabitCalendar
addOrUpdateTimeEntry entry calendar =
    let
        -- Update the timeEntries SeqDict
        updatedTimeEntries : SeqDict TimeEntryId TimeEntry
        updatedTimeEntries =
            SeqDict.insert entry.id entry calendar.timeEntries

        -- Re-aggregate all entries
        updatedAggregatedEntries : Dict Int DayEntry
        updatedAggregatedEntries =
            aggregateEntriesByDay calendar.timezone (SeqDict.values updatedTimeEntries)
    in
    { calendar
        | timeEntries = updatedTimeEntries
        , entries = updatedAggregatedEntries
    }


{-| Delete a time entry from the calendar.
Re-aggregates all entries after deletion.
-}
deleteTimeEntry : TimeEntryId -> HabitCalendar -> HabitCalendar
deleteTimeEntry entryId calendar =
    let
        -- Remove from the timeEntries SeqDict
        updatedTimeEntries : SeqDict TimeEntryId TimeEntry
        updatedTimeEntries =
            SeqDict.remove entryId calendar.timeEntries

        -- Re-aggregate all entries
        updatedAggregatedEntries : Dict Int DayEntry
        updatedAggregatedEntries =
            aggregateEntriesByDay calendar.timezone (SeqDict.values updatedTimeEntries)
    in
    { calendar
        | timeEntries = updatedTimeEntries
        , entries = updatedAggregatedEntries
    }
