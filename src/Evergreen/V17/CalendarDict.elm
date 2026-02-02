module Evergreen.V17.CalendarDict exposing (..)

import Evergreen.V17.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V17.HabitCalendar.HabitCalendarId Evergreen.V17.HabitCalendar.HabitCalendar
