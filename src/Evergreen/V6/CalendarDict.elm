module Evergreen.V6.CalendarDict exposing (..)

import Evergreen.V6.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V6.HabitCalendar.HabitCalendarId Evergreen.V6.HabitCalendar.HabitCalendar
