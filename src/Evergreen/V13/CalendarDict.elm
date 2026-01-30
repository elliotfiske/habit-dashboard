module Evergreen.V13.CalendarDict exposing (..)

import Evergreen.V13.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V13.HabitCalendar.HabitCalendarId Evergreen.V13.HabitCalendar.HabitCalendar
