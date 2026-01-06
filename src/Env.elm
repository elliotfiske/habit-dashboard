module Env exposing (Mode(..), mode, togglApiKey)

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.


type Mode
    = Development
    | Production


mode : Mode
mode =
    Development


{-| Toggl API key for accessing the Toggl Track API.
Get yours from: <https://track.toggl.com/profile> (scroll to "API Token")
-}
togglApiKey : String
togglApiKey =
    ""
