module Evergreen.V1.HabitCalendar exposing (..)

import Color
import Dict


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
    }
