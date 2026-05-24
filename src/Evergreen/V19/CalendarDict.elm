module Evergreen.V19.CalendarDict exposing (..)

import Evergreen.V19.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V19.HabitCalendar.HabitCalendarId Evergreen.V19.HabitCalendar.HabitCalendar
