module Evergreen.V19.HabitCalendar exposing (..)

import Dict
import Evergreen.V19.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V19.Toggl.TimeEntryId Evergreen.V19.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V19.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V19.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
