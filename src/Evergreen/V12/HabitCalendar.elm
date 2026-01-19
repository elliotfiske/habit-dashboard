module Evergreen.V12.HabitCalendar exposing (..)

import Dict
import Evergreen.V12.Toggl
import SeqDict
import Time


type HabitCalendarId
    = HabitCalendarId String


type alias DayEntry =
    { dayStartMillis : Int
    , totalMinutes : Int
    }


type alias HabitCalendar =
    { id : HabitCalendarId
    , name : String
    , successColor : String
    , nonzeroColor : String
    , weeksShowing : Int
    , entries : Dict.Dict Int DayEntry
    , timeEntries : SeqDict.SeqDict Evergreen.V12.Toggl.TimeEntryId Evergreen.V12.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V12.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V12.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
