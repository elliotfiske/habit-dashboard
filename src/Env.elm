module Env exposing (Mode(..), mode, togglApiKey, togglWebhookWorkspaceId)

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

This actual value must not be committed to the repo. However, it must be set for the local dev server to work.

-}
togglApiKey : String
togglApiKey =
    ""


{-| Toggl workspace ID for webhook subscription.
Find this in your Toggl workspace settings or in the webhook subscription URL.
-}
togglWebhookWorkspaceId : Int
togglWebhookWorkspaceId =
    4150145
