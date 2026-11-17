module Evergreen.V25.CalendarDict exposing (..)

import Evergreen.V25.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V25.HabitCalendar.HabitCalendarId Evergreen.V25.HabitCalendar.HabitCalendar
