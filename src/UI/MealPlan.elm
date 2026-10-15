module UI.MealPlan exposing (banner, sidePanel, strip)

{-| This week's lunches and dinners.

Prototype: three layouts, one shown at a time based on `model.mealPlanVariant`
(`?meals=a|b|c`). Each entry point renders nothing unless its layout is the
selected one, so `Frontend.view` can place all three.

-}

import Date exposing (Date)
import Html exposing (Html)
import Html.Attributes as Attr
import MealPlan exposing (DayMeals, Meal)
import Types exposing (FrontendModel, FrontendMsg, MealPlanVariant(..))


{-| Option A: a 7-column week strip above the calendars.
-}
strip : FrontendModel -> Html FrontendMsg
strip model =
    whenVariant MealPlanWeekStrip
        model
        (\today ->
            Html.div
                [ Attr.class "card bg-base-100 shadow-lg p-5 mb-8 max-w-6xl mx-auto"
                , Attr.attribute "data-testid" "meal-plan"
                ]
                [ sectionLabel ("Meals · Week of " ++ Date.format "MMM d" (Date.floor Date.Monday today))
                , Html.div [ Attr.class "grid grid-cols-7 gap-2 mt-3" ]
                    (List.map (stripDay today model) (MealPlan.weekOf today))
                ]
        )


stripDay : Date -> FrontendModel -> Date -> Html FrontendMsg
stripDay today model date =
    let
        meals : DayMeals
        meals =
            MealPlan.forDate date model.mealPlan

        isToday : Bool
        isToday =
            date == today
    in
    Html.div
        [ Attr.class "rounded-xl p-3 flex flex-col gap-2"
        , Attr.classList
            [ ( "bg-primary/20 ring-2 ring-primary", isToday )
            , ( "bg-base-200", not isToday )
            , ( "opacity-40", Date.compare date today == LT )
            ]
        ]
        [ Html.div [ Attr.class "flex items-baseline gap-1.5" ]
            [ Html.span [ Attr.class "text-sm font-bold uppercase tracking-wide" ]
                [ Html.text (dayLabel today date) ]
            , Html.span [ Attr.class "text-sm opacity-50" ] [ Html.text (Date.format "d" date) ]
            ]
        , stripSlot "Lunch" meals.lunch
        , stripSlot "Dinner" meals.dinner
        ]


stripSlot : String -> Maybe Meal -> Html FrontendMsg
stripSlot label maybeMeal =
    Html.div []
        [ Html.div [ Attr.class "text-[10px] uppercase tracking-wider opacity-50" ] [ Html.text label ]
        , mealName "text-sm font-semibold leading-snug" maybeMeal
        ]


{-| Option B: a "Tonight" banner in the banner stack.
-}
banner : FrontendModel -> Html FrontendMsg
banner model =
    whenVariant MealPlanTonightBanner
        model
        (\today ->
            let
                todayMeals : DayMeals
                todayMeals =
                    MealPlan.forDate today model.mealPlan

                tomorrow : Date
                tomorrow =
                    Date.add Date.Days 1 today
            in
            Html.div
                [ Attr.class "card shadow-lg p-4 mb-6 bg-warning text-warning-content"
                , Attr.attribute "data-testid" "meal-plan"
                ]
                [ Html.div [ Attr.class "grid grid-cols-[auto_1fr_auto] items-center gap-4" ]
                    [ Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60 mr-4" ] [ Html.text "Tonight" ]
                    , Html.div []
                        [ mealName "text-2xl font-bold leading-tight" todayMeals.dinner
                        , noteLine todayMeals.dinner
                        ]
                    , Html.div [ Attr.class "text-sm text-right flex flex-col gap-0.5" ]
                        [ bannerAside "Lunch" todayMeals.lunch
                        , bannerAside "Tomorrow" (MealPlan.forDate tomorrow model.mealPlan).dinner
                        ]
                    ]
                , Html.div [ Attr.class "flex gap-2 mt-3 pt-3 border-t border-warning-content/15 text-xs" ]
                    (MealPlan.daysFrom (Date.add Date.Days 2 today) 5
                        |> List.map (bannerUpcoming model)
                    )
                ]
        )


bannerAside : String -> Maybe Meal -> Html FrontendMsg
bannerAside label maybeMeal =
    Html.div []
        [ Html.span [ Attr.class "opacity-60" ] [ Html.text (label ++ " · ") ]
        , Html.span [ Attr.class "font-semibold" ] [ Html.text (maybeMeal |> Maybe.map .name |> Maybe.withDefault "—") ]
        ]


bannerUpcoming : FrontendModel -> Date -> Html FrontendMsg
bannerUpcoming model date =
    Html.div [ Attr.class "flex-1 min-w-0 truncate" ]
        [ Html.span [ Attr.class "opacity-60 uppercase tracking-wide mr-1" ] [ Html.text (Date.format "EEE" date) ]
        , Html.span [ Attr.class "font-medium" ]
            [ Html.text ((MealPlan.forDate date model.mealPlan).dinner |> Maybe.map .name |> Maybe.withDefault "—") ]
        ]


{-| Option C: a Day / Lunch / Dinner table beside the banners.
-}
sidePanel : FrontendModel -> Html FrontendMsg
sidePanel model =
    whenVariant MealPlanSidePanel
        model
        (\today ->
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
                    (List.map (sidePanelRow today model) (MealPlan.weekOf today))
                ]
        )


sidePanelRow : Date -> FrontendModel -> Date -> Html FrontendMsg
sidePanelRow today model date =
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
        ]
        [ Html.div [ Attr.class "text-xs font-bold uppercase tracking-wide" ]
            [ Html.text (dayLabel today date) ]
        , mealName "text-sm font-medium truncate" meals.lunch
        , mealName "text-sm font-semibold truncate" meals.dinner
        ]



-- SHARED


{-| Render `content` with today's date if `variant` is the selected layout and
the clock has loaded; otherwise render nothing.
-}
whenVariant : MealPlanVariant -> FrontendModel -> (Date -> Html FrontendMsg) -> Html FrontendMsg
whenVariant variant model content =
    case ( model.mealPlanVariant == variant, model.currentTime, model.currentZone ) of
        ( True, Just time, Just zone ) ->
            content (Date.fromPosix zone time)

        _ ->
            Html.text ""


sectionLabel : String -> Html FrontendMsg
sectionLabel label =
    Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60" ] [ Html.text label ]


dayLabel : Date -> Date -> String
dayLabel today date =
    if date == today then
        "Today"

    else
        Date.format "EEE" date


mealName : String -> Maybe Meal -> Html FrontendMsg
mealName classes maybeMeal =
    case maybeMeal of
        Just meal ->
            Html.div [ Attr.class classes, Attr.title (Maybe.withDefault meal.name meal.note) ] [ Html.text meal.name ]

        Nothing ->
            Html.div [ Attr.class (classes ++ " opacity-30") ] [ Html.text "—" ]


noteLine : Maybe Meal -> Html FrontendMsg
noteLine maybeMeal =
    case maybeMeal |> Maybe.andThen .note of
        Just note ->
            Html.div [ Attr.class "text-sm opacity-70 mt-0.5" ] [ Html.text note ]

        Nothing ->
            Html.text ""
