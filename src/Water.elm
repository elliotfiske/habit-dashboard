module Water exposing
    ( Drink
    , Log
    , Pace(..)
    , Progress
    , Upload
    , applyUpload
    , empty
    , encode
    , goalOz
    , progress
    , uploadDecoder
    )

{-| Water drunk from the smart bottle, as Apple Health recorded it.

The Med Log iPhone app reads the drinks from Health and posts them to the
`setWaterDrinks` RPC endpoint (see `docs/water-api.md`). Each upload replaces
every stored drink from its `since` time on, so drinks deleted in Health
disappear here too. Which day a drink counts toward is worked out on the
frontend, in the dashboard's own time zone.

-}

import Iso8601
import Json.Decode as D
import Json.Encode as E
import Time exposing (Posix, Zone)


{-| One drink: Health's sample ID, when it was drunk, and how much.
-}
type alias Drink =
    { id : String
    , at : Posix
    , ml : Float
    }


{-| Recent drinks, oldest first, and when the phone last sent them.
-}
type alias Log =
    { drinks : List Drink
    , syncedAt : Maybe Posix
    }


{-| What the phone sends: every drink from `since` on.
-}
type alias Upload =
    { since : Posix
    , sentAt : Posix
    , drinks : List Drink
    }


{-| How today is going, for the flower.
-}
type alias Progress =
    { totalOz : Float
    , expectedOz : Float
    , pace : Pace
    }


type Pace
    = OnPace
    | Behind Float -- ounces behind
    | GoalMet


{-| The daily goal, in US fluid ounces.
-}
goalOz : Float
goalOz =
    70


{-| The goal is spread evenly over the waking day: none is expected before
8 AM, all of it by 8 PM.
-}
dayStartMinute : Float
dayStartMinute =
    8 * 60


dayEndMinute : Float
dayEndMinute =
    20 * 60


{-| How far behind still counts as on pace: about one glass. Keeps the flower
from wilting the moment the morning starts.
-}
graceOz : Float
graceOz =
    8


{-| Drinks older than this are dropped when an upload arrives.
-}
retentionMillis : Int
retentionMillis =
    14 * 24 * 60 * 60 * 1000


mlPerOz : Float
mlPerOz =
    29.5735


empty : Log
empty =
    { drinks = [], syncedAt = Nothing }


{-| Replace every stored drink from `upload.since` on with the upload's.

An upload sent before the last one applied is ignored, so two uploads that
cross on the network can't roll the log back.

-}
applyUpload : Upload -> Log -> Log
applyUpload upload log =
    let
        isStale : Bool
        isStale =
            case log.syncedAt of
                Just syncedAt ->
                    Time.posixToMillis upload.sentAt < Time.posixToMillis syncedAt

                Nothing ->
                    False
    in
    if isStale then
        log

    else
        let
            since : Int
            since =
                Time.posixToMillis upload.since

            kept : List Drink
            kept =
                List.filter
                    (\drink ->
                        let
                            at : Int
                            at =
                                Time.posixToMillis drink.at
                        in
                        at < since && at >= since - retentionMillis
                    )
                    log.drinks
        in
        { drinks = List.sortBy (.at >> Time.posixToMillis) (kept ++ upload.drinks)
        , syncedAt = Just upload.sentAt
        }


{-| Today's total against how much should have been drunk by `now`.
-}
progress : Zone -> Posix -> Log -> Progress
progress zone now log =
    let
        today : ( Int, Time.Month, Int )
        today =
            dayOf zone now

        totalOz : Float
        totalOz =
            log.drinks
                |> List.filter (\drink -> dayOf zone drink.at == today)
                |> List.map .ml
                |> List.sum
                |> (\ml -> ml / mlPerOz)

        minuteOfDay : Float
        minuteOfDay =
            toFloat (Time.toHour zone now * 60 + Time.toMinute zone now)

        expectedOz : Float
        expectedOz =
            goalOz * clamp 0 1 ((minuteOfDay - dayStartMinute) / (dayEndMinute - dayStartMinute))

        pace : Pace
        pace =
            if totalOz >= goalOz then
                GoalMet

            else if totalOz + graceOz >= expectedOz then
                OnPace

            else
                Behind (expectedOz - totalOz)
    in
    { totalOz = totalOz, expectedOz = expectedOz, pace = pace }


dayOf : Zone -> Posix -> ( Int, Time.Month, Int )
dayOf zone time =
    ( Time.toYear zone time, Time.toMonth zone time, Time.toDay zone time )



-- JSON


{-| `{ "since": ISO-8601, "sentAt": ISO-8601, "drinks": [ { "id", "at", "ml" } ] }`
-}
uploadDecoder : D.Decoder Upload
uploadDecoder =
    D.map3 Upload
        (D.field "since" Iso8601.decoder)
        (D.field "sentAt" Iso8601.decoder)
        (D.field "drinks" (D.list drinkDecoder))


{-| Amounts are rounded to whole millilitres. Besides being plenty precise,
this matters: Lamdera fails to relay an RPC response that contains a
non-integer number ("rpc response decoding failed"), and every response echoes
the stored drinks.
-}
drinkDecoder : D.Decoder Drink
drinkDecoder =
    D.map3 Drink
        (D.field "id" D.string)
        (D.field "at" Iso8601.decoder)
        (D.field "ml" D.float
            |> D.andThen
                (\ml ->
                    if ml < 0 then
                        D.fail "ml can't be negative"

                    else
                        D.succeed (toFloat (round ml))
                )
        )


{-| The stored log, in the same shape as an upload's drinks.
-}
encode : Log -> E.Value
encode log =
    E.object
        [ ( "syncedAt", Maybe.map Iso8601.encode log.syncedAt |> Maybe.withDefault E.null )
        , ( "drinks"
          , E.list
                (\drink ->
                    E.object
                        [ ( "id", E.string drink.id )
                        , ( "at", Iso8601.encode drink.at )
                        , ( "ml", E.float drink.ml )
                        ]
                )
                log.drinks
          )
        ]
