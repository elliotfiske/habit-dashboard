module Evergreen.V12.CalendarDict exposing (..)

import Evergreen.V12.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V12.HabitCalendar.HabitCalendarId Evergreen.V12.HabitCalendar.HabitCalendar
