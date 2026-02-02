module Coda exposing (apiUrl, decodeCodaResponse, monofocusProjectId, monofocusWorkspaceId, parseCodaStatus)

{-| Coda API integration for fetching the active project.

This module handles parsing the Coda API response from the "Current Focus!" table.

-}

import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Toggl exposing (TogglProjectId(..), TogglWorkspaceId(..))
import Types exposing (CodaProject, CodaStatus(..))


{-| The Coda doc ID (not sensitive, can be hardcoded).
-}
docId : String
docId =
    "N2tIjWdJ-z"


{-| The table ID for "Current Focus!" table.
-}
tableId : String
tableId =
    "table-Z6eycemBOM"


{-| Build the Coda API URL for fetching active projects.
-}
apiUrl : String
apiUrl =
    "https://coda.io/apis/v1/docs/" ++ docId ++ "/tables/" ++ tableId ++ "/rows?useColumnNames=true&sortBy=updatedAt"


{-| The Toggl project ID for Monofocus.
-}
monofocusProjectId : Toggl.TogglProjectId
monofocusProjectId =
    TogglProjectId 205793718


{-| The Toggl workspace ID for Monofocus.
-}
monofocusWorkspaceId : Toggl.TogglWorkspaceId
monofocusWorkspaceId =
    TogglWorkspaceId 4150145


{-| Decode a single row from the Coda API response.
-}
rowDecoder : Decoder CodaProject
rowDecoder =
    Decode.map3 CodaProject
        (Decode.at [ "values", "Initiative name" ] Decode.string)
        (Decode.at [ "values", "Start date" ] (Decode.nullable Iso8601.decoder))
        (Decode.at [ "values", "End date" ] (Decode.nullable Iso8601.decoder))


{-| Decode the full API response (list of rows).
-}
decodeCodaResponse : Decoder (List CodaProject)
decodeCodaResponse =
    Decode.field "items" (Decode.list rowDecoder)


{-| Parse a list of projects into a CodaStatus.
Validates that exactly 1 project exists.
-}
parseCodaStatus : List CodaProject -> CodaStatus
parseCodaStatus projects =
    case projects of
        [ project ] ->
            CodaOneActive project

        [] ->
            CodaInvalidCount 0

        multiple ->
            CodaInvalidCount (List.length multiple)
