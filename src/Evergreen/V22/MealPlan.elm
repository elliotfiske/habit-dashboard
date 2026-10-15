module Evergreen.V22.MealPlan exposing (..)

import Dict


type alias Meal =
    { name : String
    , note : Maybe String
    }


type alias DayMeals =
    { lunch : Maybe Meal
    , dinner : Maybe Meal
    }


type alias MealPlan =
    Dict.Dict String DayMeals
