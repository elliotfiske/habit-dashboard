module TimerLogic exposing (formatTimeOfDay, relativeTimer)

{-| Time duration calculations and formatting.

This module provides utilities for working with time durations and formatting:

  - Calculating elapsed time between two timestamps
  - Formatting durations as HH:MM:SS
  - Formatting times of day in 12-hour format

-}

import DateFormat
import Time


{-| Format the elapsed time between now and start as HH:MM:SS or D:HH:MM:SS.
-}
relativeTimer : Time.Posix -> Time.Posix -> String
relativeTimer now start =
    let
        diff : Int
        diff =
            (Time.posixToMillis now - Time.posixToMillis start) // 1000
    in
    if diff < 0 then
        "in the future"

    else
        let
            dayNum : Int
            dayNum =
                diff // 60 // 60 // 24

            seconds : String
            seconds =
                String.padLeft 2 '0' (String.fromInt (remainderBy 60 diff))

            minutes : String
            minutes =
                String.padLeft 2 '0' (String.fromInt (remainderBy 60 (diff // 60)))

            hours : String
            hours =
                String.padLeft 2 '0' (String.fromInt (remainderBy 24 (diff // 60 // 60)))

            days : String
            days =
                if dayNum == 0 then
                    ""

                else
                    String.fromInt dayNum ++ ":"
        in
        days ++ hours ++ ":" ++ minutes ++ ":" ++ seconds


{-| Format a time as "10:02 PM" style.
-}
formatTimeOfDay : Time.Zone -> Time.Posix -> String
formatTimeOfDay zone posix =
    DateFormat.format
        [ DateFormat.hourNumber
        , DateFormat.text ":"
        , DateFormat.minuteFixed
        , DateFormat.text " "
        , DateFormat.amPmUppercase
        ]
        zone
        posix
