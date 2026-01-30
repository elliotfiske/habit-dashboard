module Evergreen.V13.HabitCalendar exposing (..)

import Dict
import Evergreen.V13.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V13.Toggl.TimeEntryId Evergreen.V13.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V13.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V13.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
