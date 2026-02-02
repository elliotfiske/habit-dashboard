module Evergreen.V17.HabitCalendar exposing (..)

import Dict
import Evergreen.V17.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V17.Toggl.TimeEntryId Evergreen.V17.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V17.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V17.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
