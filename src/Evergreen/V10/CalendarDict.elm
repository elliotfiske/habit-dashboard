module Evergreen.V10.CalendarDict exposing (..)

import Evergreen.V10.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V10.HabitCalendar.HabitCalendarId Evergreen.V10.HabitCalendar.HabitCalendar
