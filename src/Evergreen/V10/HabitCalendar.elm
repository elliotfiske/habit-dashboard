module Evergreen.V10.HabitCalendar exposing (..)

import Dict
import Evergreen.V10.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V10.Toggl.TimeEntryId Evergreen.V10.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V10.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V10.Toggl.TogglProjectId
    }
