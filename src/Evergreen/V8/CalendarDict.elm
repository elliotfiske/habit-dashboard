module Evergreen.V8.CalendarDict exposing (..)

import Evergreen.V8.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V8.HabitCalendar.HabitCalendarId Evergreen.V8.HabitCalendar.HabitCalendar
