module Evergreen.V25.Water exposing (..)

import Time


type alias Drink =
    { id : String
    , at : Time.Posix
    , ml : Float
    }


type alias Log =
    { drinks : List Drink
    , syncedAt : Maybe Time.Posix
    }
