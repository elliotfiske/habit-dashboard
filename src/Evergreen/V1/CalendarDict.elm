module Evergreen.V1.CalendarDict exposing (..)

import Evergreen.V1.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V1.HabitCalendar.HabitCalendarId Evergreen.V1.HabitCalendar.HabitCalendar
