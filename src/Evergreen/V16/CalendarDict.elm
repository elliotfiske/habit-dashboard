module Evergreen.V16.CalendarDict exposing (..)

import Evergreen.V16.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V16.HabitCalendar.HabitCalendarId Evergreen.V16.HabitCalendar.HabitCalendar
