module Evergreen.V22.CalendarDict exposing (..)

import Evergreen.V22.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V22.HabitCalendar.HabitCalendarId Evergreen.V22.HabitCalendar.HabitCalendar
