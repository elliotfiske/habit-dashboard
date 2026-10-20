module MealPlanTests exposing (suite)

import Date
import Dict
import Expect
import Json.Decode as D
import Json.Encode as E
import MealPlan exposing (Slot(..))
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "MealPlan"
        [ describe "setMeals"
            [ test "sets a slot and leaves the other empty" <|
                \_ ->
                    """{ "meals": [ { "date": "2026-10-14", "slot": "dinner", "name": "Tacos", "note": "use leftover chicken" } ] }"""
                        |> D.decodeString MealPlan.mealUpdatesDecoder
                        |> Result.map (\updates -> MealPlan.applyUpdates updates MealPlan.empty)
                        |> Result.map (MealPlan.encode >> E.encode 0)
                        |> Expect.equal (Ok """{"days":[{"date":"2026-10-14","lunch":null,"dinner":{"name":"Tacos","note":"use leftover chicken"}}]}""")
            , test "a null name clears the slot and drops the empty day" <|
                \_ ->
                    """{ "meals": [ { "date": "2026-10-14", "slot": "DINNER", "name": null } ] }"""
                        |> D.decodeString MealPlan.mealUpdatesDecoder
                        |> Result.map
                            (\updates ->
                                let
                                    withTacos : MealPlan.MealPlan
                                    withTacos =
                                        MealPlan.applyUpdates
                                            [ { date = Date.fromCalendarDate 2026 Time.Oct 14, slot = Dinner, meal = Just { name = "Tacos", note = Nothing } } ]
                                            MealPlan.empty
                                in
                                MealPlan.applyUpdates updates withTacos
                            )
                        |> Result.map Dict.isEmpty
                        |> Expect.equal (Ok True)
            , test "rejects an unknown slot" <|
                \_ ->
                    """{ "meals": [ { "date": "2026-10-14", "slot": "brunch", "name": "Eggs" } ] }"""
                        |> D.decodeString MealPlan.mealUpdatesDecoder
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "rejects a non-ISO date" <|
                \_ ->
                    """{ "meals": [ { "date": "10/14", "slot": "lunch", "name": "Eggs" } ] }"""
                        |> D.decodeString MealPlan.mealUpdatesDecoder
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , describe "replaceMealPlan"
            [ test "round-trips the getMealPlan shape" <|
                \_ ->
                    let
                        json : String
                        json =
                            """{"days":[{"date":"2026-10-12","lunch":{"name":"Salad","note":null},"dinner":null},{"date":"2026-10-13","lunch":null,"dinner":{"name":"Curry","note":"double batch"}}]}"""
                    in
                    json
                        |> D.decodeString MealPlan.planDecoder
                        |> Result.map (MealPlan.encode >> E.encode 0)
                        |> Expect.equal (Ok json)
            , test "missing slots and blank names count as empty" <|
                \_ ->
                    """{ "days": [ { "date": "2026-10-12" }, { "date": "2026-10-13", "lunch": { "name": "  " } } ] }"""
                        |> D.decodeString MealPlan.planDecoder
                        |> Result.map Dict.isEmpty
                        |> Expect.equal (Ok True)
            ]
        , test "window puts today third from the top, even on a Sunday" <|
            \_ ->
                MealPlan.window (Date.fromCalendarDate 2026 Time.Oct 18)
                    |> List.map Date.toIsoString
                    |> Expect.equal
                        [ "2026-10-16", "2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22" ]
        ]
