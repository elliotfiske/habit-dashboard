module Config exposing (..)

import Env


cleaningUrl : String
cleaningUrl =
    case Env.mode of
        Env.Production ->
            "https://app.airkit.com/x-effect-proxy/cleaning/"

        Env.Development ->
            "http://localhost:8001/https://app.airkit.com/x-effect-proxy/cleaning/"


elmProjectsUrl : String
elmProjectsUrl =
    case Env.mode of
        Env.Production ->
            "https://app.airkit.com/x-effect-proxy/elm/"

        Env.Development ->
            "http://localhost:8001/https://app.airkit.com/x-effect-proxy/elm/"


garageCleaningUrl : String
garageCleaningUrl =
    case Env.mode of
        Env.Production ->
            "https://app.airkit.com/x-effect-proxy/garage/"

        Env.Development ->
            "http://localhost:8001/https://app.airkit.com/x-effect-proxy/garage/"


urlWithProxy : String -> String
urlWithProxy url =
    case Env.mode of
        Env.Production ->
            url

        Env.Development ->
            "http://localhost:8001/" ++ url
