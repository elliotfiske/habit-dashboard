module Evergreen.V16.HabitCalendar exposing (..)

import Dict
import Evergreen.V16.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V16.Toggl.TimeEntryId Evergreen.V16.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V16.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V16.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
