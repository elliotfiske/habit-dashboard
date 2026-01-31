module Evergreen.V14.CalendarDict exposing (..)

import Evergreen.V14.HabitCalendar
import SeqDict


type alias CalendarDict =
    SeqDict.SeqDict Evergreen.V14.HabitCalendar.HabitCalendarId Evergreen.V14.HabitCalendar.HabitCalendar
