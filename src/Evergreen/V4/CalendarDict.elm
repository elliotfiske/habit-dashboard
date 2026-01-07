module Evergreen.V4.CalendarDict exposing (..)

import Evergreen.V4.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V4.HabitCalendar.HabitCalendarId Evergreen.V4.HabitCalendar.HabitCalendar
