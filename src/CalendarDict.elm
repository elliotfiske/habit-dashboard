module CalendarDict exposing
    ( CalendarDict
    , empty
    , fromList
    , get
    , insert
    , remove
    , toList
    , values
    )

{-| A Dict wrapper for HabitCalendarId keys.
Uses lamdera/containers SeqDict for a Dict that works with any equatable key type.
-}

import HabitCalendar exposing (HabitCalendar, HabitCalendarId)
import SeqDict exposing (SeqDict)


{-| A dictionary keyed by HabitCalendarId.
-}
type alias CalendarDict =
    SeqDict HabitCalendarId HabitCalendar


{-| Create an empty CalendarDict.
-}
empty : CalendarDict
empty =
    SeqDict.empty


{-| Get a calendar by its ID.
-}
get : HabitCalendarId -> CalendarDict -> Maybe HabitCalendar
get =
    SeqDict.get


{-| Insert a calendar into the dict.
-}
insert : HabitCalendarId -> HabitCalendar -> CalendarDict -> CalendarDict
insert =
    SeqDict.insert


{-| Remove a calendar from the dict.
-}
remove : HabitCalendarId -> CalendarDict -> CalendarDict
remove =
    SeqDict.remove


{-| Get all calendars as a list.
-}
values : CalendarDict -> List HabitCalendar
values =
    SeqDict.values


{-| Convert a list of (id, calendar) pairs to a CalendarDict.
-}
fromList : List ( HabitCalendarId, HabitCalendar ) -> CalendarDict
fromList =
    SeqDict.fromList


{-| Convert to a list of (id, calendar) pairs.
-}
toList : CalendarDict -> List ( HabitCalendarId, HabitCalendar )
toList =
    SeqDict.toList
