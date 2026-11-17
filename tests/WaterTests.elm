module WaterTests exposing (suite)

import Expect
import Json.Decode as D
import Test exposing (Test, describe, test)
import Time exposing (Posix)
import Water exposing (Pace(..))


{-| Monday, November 16, 2026 00:00 UTC. Tests use UTC as "local" time.
-}
midnight : Int
midnight =
    1794787200000


at : Float -> Posix
at hour =
    Time.millisToPosix (midnight + round (hour * 60 * 60 * 1000))


oz : Float -> Float
oz ounces =
    ounces * 29.5735


drink : String -> Float -> Float -> Water.Drink
drink id hour ounces =
    { id = id, at = at hour, ml = oz ounces }


logOf : List Water.Drink -> Water.Log
logOf drinks =
    { drinks = drinks, syncedAt = Just (at 0) }


paceAt : Float -> List Water.Drink -> Pace
paceAt hour drinks =
    (Water.progress Time.utc (at hour) (logOf drinks)).pace


suite : Test
suite =
    describe "Water"
        [ describe "progress"
            [ test "nothing is expected before 8 AM" <|
                \_ -> paceAt 7.5 [] |> Expect.equal OnPace
            , test "half the goal is expected at 2 PM" <|
                \_ ->
                    (Water.progress Time.utc (at 14) (logOf [])).expectedOz
                        |> Expect.within (Expect.Absolute 0.001) 35
            , test "on pace within a glass of the expected amount" <|
                \_ -> paceAt 14 [ drink "a" 9 28 ] |> Expect.equal OnPace
            , test "wilts when more than a glass behind" <|
                \_ ->
                    case paceAt 14 [ drink "a" 9 20 ] of
                        Behind behind ->
                            behind |> Expect.within (Expect.Absolute 0.01) 15

                        other ->
                            Expect.fail ("Expected Behind, got " ++ Debug.toString other)
            , test "only today's drinks count" <|
                \_ ->
                    (Water.progress Time.utc (at 10) (logOf [ drink "yesterday" -2 50, drink "today" 9 12 ])).totalOz
                        |> Expect.within (Expect.Absolute 0.001) 12
            , test "the goal is met at 70 oz" <|
                \_ -> paceAt 12 [ drink "a" 9 40, drink "b" 11 30 ] |> Expect.equal GoalMet
            ]
        , describe "applyUpload"
            [ test "replaces drinks from since on, keeping older ones" <|
                \_ ->
                    logOf [ drink "old" -5 10, drink "deleted" 9 8 ]
                        |> Water.applyUpload { since = at 0, sentAt = at 12, drinks = [ drink "new" 10 16 ] }
                        |> .drinks
                        |> List.map .id
                        |> Expect.equal [ "old", "new" ]
            , test "ignores an upload sent before the last one applied" <|
                \_ ->
                    { drinks = [ drink "latest" 10 16 ], syncedAt = Just (at 12) }
                        |> Water.applyUpload { since = at 0, sentAt = at 11, drinks = [] }
                        |> .drinks
                        |> List.map .id
                        |> Expect.equal [ "latest" ]
            , test "drops drinks older than two weeks" <|
                \_ ->
                    logOf [ drink "ancient" (-15 * 24) 10, drink "recent" -5 10 ]
                        |> Water.applyUpload { since = at 0, sentAt = at 12, drinks = [] }
                        |> .drinks
                        |> List.map .id
                        |> Expect.equal [ "recent" ]
            ]
        , describe "uploadDecoder"
            [ test "decodes what Med Log sends" <|
                \_ ->
                    """{"since":"2026-11-15T00:00:00Z","sentAt":"2026-11-16T12:00:00Z","drinks":[{"id":"A1","at":"2026-11-16T09:00:00Z","ml":236.6}]}"""
                        |> D.decodeString Water.uploadDecoder
                        |> Result.map (\upload -> ( upload.since, List.map .id upload.drinks ))
                        |> Expect.equal (Ok ( at -24, [ "A1" ] ))
            , test "rounds amounts to whole millilitres" <|
                \_ ->
                    """{"since":"2026-11-15T00:00:00Z","sentAt":"2026-11-16T12:00:00Z","drinks":[{"id":"A1","at":"2026-11-16T09:00:00Z","ml":238.18334985133794}]}"""
                        |> D.decodeString Water.uploadDecoder
                        |> Result.map (.drinks >> List.map .ml)
                        |> Expect.equal (Ok [ 238 ])
            , test "rejects negative amounts" <|
                \_ ->
                    """{"since":"2026-11-15T00:00:00Z","sentAt":"2026-11-16T12:00:00Z","drinks":[{"id":"A1","at":"2026-11-16T09:00:00Z","ml":-5}]}"""
                        |> D.decodeString Water.uploadDecoder
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        ]
