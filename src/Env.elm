module Env exposing (Mode(..), dummyConfigItem, mode)

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.


type Mode
    = Development
    | Production


mode : Mode
mode =
    Development


dummyConfigItem : String
dummyConfigItem =
    ""
