module UI.MealPlan exposing (view)

{-| This week's lunches and dinners: a Day / Lunch / Dinner table that sits
beside the banners, with today highlighted and past days dimmed.
-}

import Date exposing (Date)
import Html exposing (Html)
import Html.Attributes as Attr
import MealPlan exposing (DayMeals, Meal)
import Types exposing (FrontendModel, FrontendMsg)


{-| Render the meal plan panel. Renders nothing until the clock has loaded.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    case ( model.currentTime, model.currentZone ) of
        ( Just time, Just zone ) ->
            let
                today : Date
                today =
                    Date.fromPosix zone time
            in
            Html.div
                [ Attr.class "card bg-base-100 shadow-lg p-4 mb-6 w-full lg:w-[26rem] shrink-0"
                , Attr.attribute "data-testid" "meal-plan"
                ]
                [ Html.div [ Attr.class "grid grid-cols-[3.5rem_1fr_1fr] gap-x-3 px-2 pb-1" ]
                    [ sectionLabel "Meals"
                    , sectionLabel "Lunch"
                    , sectionLabel "Dinner"
                    ]
                , Html.div [ Attr.class "flex flex-col" ]
                    (List.map (viewDay today model) (MealPlan.weekOf today))
                ]

        _ ->
            Html.text ""


viewDay : Date -> FrontendModel -> Date -> Html FrontendMsg
viewDay today model date =
    let
        meals : DayMeals
        meals =
            MealPlan.forDate date model.mealPlan

        isToday : Bool
        isToday =
            date == today
    in
    Html.div
        [ Attr.class "grid grid-cols-[3.5rem_1fr_1fr] gap-x-3 items-center rounded-lg px-2 py-1.5"
        , Attr.classList
            [ ( "bg-primary/20 ring-2 ring-primary", isToday )
            , ( "opacity-40", Date.compare date today == LT )
            ]
        , Attr.attribute "data-testid" ("meal-plan-" ++ Date.toIsoString date)
        ]
        [ Html.div [ Attr.class "text-xs font-bold uppercase tracking-wide" ]
            [ Html.text (dayLabel today date) ]
        , viewMeal isToday "font-medium" meals.lunch
        , viewMeal isToday "font-semibold" meals.dinner
        ]


sectionLabel : String -> Html FrontendMsg
sectionLabel label =
    Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60" ] [ Html.text label ]


dayLabel : Date -> Date -> String
dayLabel today date =
    if date == today then
        "Today"

    else
        Date.format "EEE" date


{-| A meal name (up to two lines), plus its note when the row is today.
-}
viewMeal : Bool -> String -> Maybe Meal -> Html FrontendMsg
viewMeal isToday weight maybeMeal =
    case maybeMeal of
        Just meal ->
            Html.div [ Attr.class "min-w-0" ]
                [ Html.div [ Attr.class ("text-sm leading-snug line-clamp-2 " ++ weight) ] [ Html.text meal.name ]
                , case ( isToday, meal.note ) of
                    ( True, Just note ) ->
                        Html.div [ Attr.class "text-xs opacity-70 leading-snug mt-0.5" ] [ Html.text note ]

                    _ ->
                        Html.text ""
                ]

        Nothing ->
            Html.div [ Attr.class "text-sm opacity-30" ] [ Html.text "—" ]
