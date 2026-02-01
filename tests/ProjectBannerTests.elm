module ProjectBannerTests exposing (suite)

{-| Unit tests for UI.ProjectBanner logic.
-}

import Expect
import Test exposing (Test, describe, test)
import Time
import Types exposing (CodaProject)
import UI.ProjectBanner


{-| January 1, 2026 00:00:00 UTC in milliseconds since epoch.
-}
january1st2026 : Int
january1st2026 =
    1767225600000


{-| One day in milliseconds.
-}
oneDay : Int
oneDay =
    24 * 60 * 60 * 1000


suite : Test
suite =
    describe "UI.ProjectBanner.isDateOutOfRange"
        [ test "returns False when current time is before end date" <|
            \_ ->
                let
                    project : CodaProject
                    project =
                        { name = "Test Project"
                        , startDate = Just (Time.millisToPosix january1st2026)
                        , endDate = Just (Time.millisToPosix (january1st2026 + (2 * oneDay)))
                        }

                    -- Jan 2 at noon (before Jan 3 end date)
                    now : Time.Posix
                    now =
                        Time.millisToPosix (january1st2026 + oneDay + (12 * 60 * 60 * 1000))
                in
                UI.ProjectBanner.isDateOutOfRange (Just now) project
                    |> Expect.equal False
        , test "returns False on final day at noon (end date is inclusive)" <|
            \_ ->
                let
                    -- Project ends Jan 3, 2026 (stored as midnight: 00:00:00)
                    project : CodaProject
                    project =
                        { name = "Test Project"
                        , startDate = Just (Time.millisToPosix january1st2026)
                        , endDate = Just (Time.millisToPosix (january1st2026 + (2 * oneDay)))
                        }

                    -- Jan 3 at noon - this is DURING the final day
                    -- The end date is Jan 3 00:00:00, but noon is 12 hours later
                    -- Bug: noon > midnight, so it's marked as "out of range"
                    now : Time.Posix
                    now =
                        Time.millisToPosix (january1st2026 + (2 * oneDay) + (12 * 60 * 60 * 1000))
                in
                UI.ProjectBanner.isDateOutOfRange (Just now) project
                    |> Expect.equal False
        , test "returns True when current time is after end date (next day)" <|
            \_ ->
                let
                    project : CodaProject
                    project =
                        { name = "Test Project"
                        , startDate = Just (Time.millisToPosix january1st2026)
                        , endDate = Just (Time.millisToPosix (january1st2026 + (2 * oneDay)))
                        }

                    -- Jan 4 at noon (after Jan 3 end date)
                    now : Time.Posix
                    now =
                        Time.millisToPosix (january1st2026 + (3 * oneDay) + (12 * 60 * 60 * 1000))
                in
                UI.ProjectBanner.isDateOutOfRange (Just now) project
                    |> Expect.equal True
        , test "returns False when no current time" <|
            \_ ->
                let
                    project : CodaProject
                    project =
                        { name = "Test Project"
                        , startDate = Just (Time.millisToPosix january1st2026)
                        , endDate = Just (Time.millisToPosix (january1st2026 + (2 * oneDay)))
                        }
                in
                UI.ProjectBanner.isDateOutOfRange Nothing project
                    |> Expect.equal False
        , test "returns True when current time is before start date" <|
            \_ ->
                let
                    project : CodaProject
                    project =
                        { name = "Test Project"
                        , startDate = Just (Time.millisToPosix (january1st2026 + (5 * oneDay)))
                        , endDate = Just (Time.millisToPosix (january1st2026 + (10 * oneDay)))
                        }

                    -- Jan 1 (before Jan 6 start date)
                    now : Time.Posix
                    now =
                        Time.millisToPosix january1st2026
                in
                UI.ProjectBanner.isDateOutOfRange (Just now) project
                    |> Expect.equal True
        ]
