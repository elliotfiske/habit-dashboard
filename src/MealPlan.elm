module MealPlan exposing
    ( DayMeals
    , Meal
    , MealPlan
    , MealUpdate
    , Slot(..)
    , applyUpdates
    , daysFrom
    , empty
    , encode
    , forDate
    , mealUpdatesDecoder
    , planDecoder
    , weekOf
    )

{-| The household meal plan: a lunch and a dinner slot per calendar day.

Days are keyed by ISO date ("2026-10-14") so a plan can be written ahead of
time and the frontend picks whichever week it's showing. The RPC endpoints in
`RPC.elm` read and write this through the JSON codecs below.

-}

import Date exposing (Date)
import Dict exposing (Dict)
import Json.Decode as D
import Json.Encode as E


{-| A planned meal. `note` is free text like "use leftover chicken".
-}
type alias Meal =
    { name : String
    , note : Maybe String
    }


{-| The two slots for one day.
-}
type alias DayMeals =
    { lunch : Maybe Meal
    , dinner : Maybe Meal
    }


{-| Planned meals keyed by ISO date string ("YYYY-MM-DD").
-}
type alias MealPlan =
    Dict String DayMeals


{-| Which meal of the day.
-}
type Slot
    = Lunch
    | Dinner


{-| Set (or clear, when `meal` is Nothing) one slot on one day.
-}
type alias MealUpdate =
    { date : Date
    , slot : Slot
    , meal : Maybe Meal
    }


{-| A plan with nothing in it.
-}
empty : MealPlan
empty =
    Dict.empty


noMeals : DayMeals
noMeals =
    { lunch = Nothing, dinner = Nothing }


{-| The meals planned for a date (both slots empty if nothing is planned).
-}
forDate : Date -> MealPlan -> DayMeals
forDate date plan =
    Dict.get (Date.toIsoString date) plan
        |> Maybe.withDefault noMeals


{-| Apply slot updates in order. Days left with no meals are dropped.
-}
applyUpdates : List MealUpdate -> MealPlan -> MealPlan
applyUpdates updates plan =
    List.foldl applyUpdate plan updates


applyUpdate : MealUpdate -> MealPlan -> MealPlan
applyUpdate update plan =
    let
        key : String
        key =
            Date.toIsoString update.date

        day : DayMeals
        day =
            forDate update.date plan

        newDay : DayMeals
        newDay =
            case update.slot of
                Lunch ->
                    { day | lunch = update.meal }

                Dinner ->
                    { day | dinner = update.meal }
    in
    if newDay == noMeals then
        Dict.remove key plan

    else
        Dict.insert key newDay plan


{-| The Monday-to-Sunday week containing `today`.
-}
weekOf : Date -> List Date
weekOf today =
    daysFrom (Date.floor Date.Monday today) 7


{-| `count` consecutive days starting at `start`.
-}
daysFrom : Date -> Int -> List Date
daysFrom start count =
    List.range 0 (count - 1)
        |> List.map (\offset -> Date.add Date.Days offset start)



-- JSON


{-| Encode the whole plan as `{ "days": [ { "date", "lunch", "dinner" } ] }`,
sorted by date. Empty slots are `null`.
-}
encode : MealPlan -> E.Value
encode plan =
    E.object
        [ ( "days"
          , E.list encodeDay (Dict.toList plan)
          )
        ]


encodeDay : ( String, DayMeals ) -> E.Value
encodeDay ( date, day ) =
    E.object
        [ ( "date", E.string date )
        , ( "lunch", encodeMaybeMeal day.lunch )
        , ( "dinner", encodeMaybeMeal day.dinner )
        ]


encodeMaybeMeal : Maybe Meal -> E.Value
encodeMaybeMeal maybeMeal =
    case maybeMeal of
        Just meal ->
            E.object
                [ ( "name", E.string meal.name )
                , ( "note", Maybe.map E.string meal.note |> Maybe.withDefault E.null )
                ]

        Nothing ->
            E.null


{-| Decode a whole plan in the same shape `encode` produces. Used to replace
the stored plan wholesale.
-}
planDecoder : D.Decoder MealPlan
planDecoder =
    D.field "days" (D.list dayDecoder)
        |> D.map
            (List.filter (\( _, day ) -> day /= noMeals)
                >> Dict.fromList
            )


dayDecoder : D.Decoder ( String, DayMeals )
dayDecoder =
    D.map3 (\date lunch dinner -> ( Date.toIsoString date, { lunch = lunch, dinner = dinner } ))
        (D.field "date" dateDecoder)
        (optionalMealField "lunch")
        (optionalMealField "dinner")


optionalMealField : String -> D.Decoder (Maybe Meal)
optionalMealField field =
    D.maybe (D.field field D.value)
        |> D.andThen
            (\maybeValue ->
                case maybeValue of
                    Nothing ->
                        D.succeed Nothing

                    Just _ ->
                        D.field field (D.nullable mealDecoder)
                            |> D.map (Maybe.andThen identity)
            )


{-| A meal object; a blank name means "no meal".
-}
mealDecoder : D.Decoder (Maybe Meal)
mealDecoder =
    D.map2 toMeal
        (D.field "name" D.string)
        (D.maybe (D.field "note" (D.nullable D.string)) |> D.map (Maybe.andThen identity))


toMeal : String -> Maybe String -> Maybe Meal
toMeal name note =
    if String.isEmpty (String.trim name) then
        Nothing

    else
        Just
            { name = String.trim name
            , note =
                note
                    |> Maybe.map String.trim
                    |> Maybe.andThen nonEmpty
            }


nonEmpty : String -> Maybe String
nonEmpty str =
    if String.isEmpty str then
        Nothing

    else
        Just str


{-| Decode `{ "meals": [ { "date", "slot", "name", "note" } ] }`. A missing,
null or blank `name` clears the slot.
-}
mealUpdatesDecoder : D.Decoder (List MealUpdate)
mealUpdatesDecoder =
    D.field "meals" (D.list mealUpdateDecoder)


mealUpdateDecoder : D.Decoder MealUpdate
mealUpdateDecoder =
    D.map3 MealUpdate
        (D.field "date" dateDecoder)
        (D.field "slot" slotDecoder)
        (D.map2 (\name note -> name |> Maybe.andThen (\n -> toMeal n note))
            (D.maybe (D.field "name" (D.nullable D.string)) |> D.map (Maybe.andThen identity))
            (D.maybe (D.field "note" (D.nullable D.string)) |> D.map (Maybe.andThen identity))
        )


slotDecoder : D.Decoder Slot
slotDecoder =
    D.string
        |> D.andThen
            (\str ->
                case String.toLower str of
                    "lunch" ->
                        D.succeed Lunch

                    "dinner" ->
                        D.succeed Dinner

                    _ ->
                        D.fail ("slot must be \"lunch\" or \"dinner\", got \"" ++ str ++ "\"")
            )


dateDecoder : D.Decoder Date
dateDecoder =
    D.string
        |> D.andThen
            (\str ->
                case Date.fromIsoString str of
                    Ok date ->
                        D.succeed date

                    Err _ ->
                        D.fail ("date must be YYYY-MM-DD, got \"" ++ str ++ "\"")
            )
