module Evergreen.V8.HabitCalendar exposing (..)

import Color
import Dict
import Evergreen.V8.Toggl
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
    , successColor : Color.Color
    , nonzeroColor : Color.Color
    , weeksShowing : Int
    , entries : Dict.Dict Int DayEntry
    , timeEntries : SeqDict.SeqDict Evergreen.V8.Toggl.TimeEntryId Evergreen.V8.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V8.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V8.Toggl.TogglProjectId
    }
