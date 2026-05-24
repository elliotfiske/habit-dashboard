module Monofocus exposing (activeUrl, decodeActiveResponse, monofocusProjectId, monofocusWorkspaceId)

{-| Monofocus Hub integration for fetching the active project.

The Monofocus Hub is a separate Lamdera app at <https://monofocus-hub.lamdera.app>
that owns the list of focus projects and picks which one is "active" today.

-}

import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Toggl exposing (TogglProjectId(..), TogglWorkspaceId(..))
import Types exposing (MonofocusProject)


{-| RPC endpoint that returns the single project whose date range contains today,
or `null` if none.
-}
activeUrl : String
activeUrl =
    "https://monofocus-hub.lamdera.app/_r/active"


{-| The Toggl project ID for Monofocus. Used when starting a Monofocus timer.
-}
monofocusProjectId : Toggl.TogglProjectId
monofocusProjectId =
    TogglProjectId 205793718


{-| The Toggl workspace ID for Monofocus.
-}
monofocusWorkspaceId : Toggl.TogglWorkspaceId
monofocusWorkspaceId =
    TogglWorkspaceId 4150145


projectDecoder : Decoder MonofocusProject
projectDecoder =
    Decode.map3 MonofocusProject
        (Decode.field "title" Decode.string)
        (Decode.field "start" Iso8601.decoder)
        (Decode.field "end" Iso8601.decoder)


{-| Decode the /\_r/active response: `{ "project": Project | null }`.
-}
decodeActiveResponse : Decoder (Maybe MonofocusProject)
decodeActiveResponse =
    Decode.field "project" (Decode.nullable projectDecoder)
