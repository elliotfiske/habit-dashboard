module Evergreen.V22.HabitCalendar exposing (..)

import Dict
import Evergreen.V22.Toggl
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
    , timeEntries : SeqDict.SeqDict Evergreen.V22.Toggl.TimeEntryId Evergreen.V22.Toggl.TimeEntry
    , timezone : Time.Zone
    , workspaceId : Evergreen.V22.Toggl.TogglWorkspaceId
    , projectId : Evergreen.V22.Toggl.TogglProjectId
    , isOrangetheory : Bool
    }
