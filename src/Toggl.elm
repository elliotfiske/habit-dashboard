module Toggl exposing
    ( ApiKey
    , TimeEntry
    , TimeEntryId(..)
    , TogglProject
    , TogglProjectId(..)
    , TogglWorkspace
    , TogglWorkspaceId(..)
    , authHeader
    , fetchProjects
    , fetchTimeEntries
    , fetchWorkspaces
    , projectDecoder
    , timeEntriesSearchDecoder
    , timeEntryIdToInt
    , togglProjectIdToInt
    , togglWorkspaceIdToInt
    , workspaceDecoder
    )

{-| Toggl API types and decoders.

Toggl Track API docs: <https://developers.track.toggl.com/docs/>

-}

import Base64
import Duration
import Effect.Command
import Effect.Http
import Iso8601
import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Time exposing (Posix)



-- TAGGED ID TYPES


{-| Tagged ID for Toggl workspaces.
-}
type TogglWorkspaceId
    = TogglWorkspaceId Int


togglWorkspaceIdToInt : TogglWorkspaceId -> Int
togglWorkspaceIdToInt (TogglWorkspaceId id) =
    id


{-| Tagged ID for Toggl projects.
-}
type TogglProjectId
    = TogglProjectId Int


togglProjectIdToInt : TogglProjectId -> Int
togglProjectIdToInt (TogglProjectId id) =
    id


{-| Tagged ID for Toggl time entries.
-}
type TimeEntryId
    = TimeEntryId Int


timeEntryIdToInt : TimeEntryId -> Int
timeEntryIdToInt (TimeEntryId id) =
    id



-- API KEY


{-| Toggl API key (opaque type for safety).
-}
type alias ApiKey =
    String


{-| Create the Authorization header for Toggl API requests.
Toggl uses Basic auth with the API key as username and "api\_token" as password.
-}
authHeader : ApiKey -> Effect.Http.Header
authHeader apiKey =
    Effect.Http.header "Authorization"
        ("Basic " ++ Base64.encode (apiKey ++ ":api_token"))



-- WORKSPACE


{-| A Toggl workspace.
-}
type alias TogglWorkspace =
    { id : TogglWorkspaceId
    , name : String
    , organizationId : Int
    }


workspaceDecoder : Decoder TogglWorkspace
workspaceDecoder =
    D.succeed TogglWorkspace
        |> DP.required "id" (D.map TogglWorkspaceId D.int)
        |> DP.required "name" D.string
        |> DP.required "organization_id" D.int



-- PROJECT


{-| A Toggl project within a workspace.
-}
type alias TogglProject =
    { id : TogglProjectId
    , workspaceId : TogglWorkspaceId
    , name : String
    , color : String
    }


projectDecoder : Decoder TogglProject
projectDecoder =
    D.succeed TogglProject
        |> DP.required "id" (D.map TogglProjectId D.int)
        |> DP.required "workspace_id" (D.map TogglWorkspaceId D.int)
        |> DP.required "name" D.string
        |> DP.required "color" D.string



-- TIME ENTRY


{-| A Toggl time entry.
-}
type alias TimeEntry =
    { id : TimeEntryId
    , projectId : Maybe TogglProjectId
    , description : Maybe String
    , start : Posix
    , stop : Maybe Posix
    , duration : Int -- Duration in seconds (-1 if running)
    }


timeEntryDecoder : Decoder TimeEntry
timeEntryDecoder =
    D.succeed TimeEntry
        |> DP.required "id" (D.map TimeEntryId D.int)
        |> DP.optional "project_id" (D.nullable (D.map TogglProjectId D.int)) Nothing
        |> DP.optional "description" (D.nullable D.string) Nothing
        |> DP.required "start" iso8601Decoder
        |> DP.optional "stop" (D.nullable iso8601Decoder) Nothing
        |> DP.required "duration" D.int


{-| Decode ISO8601 datetime string to Posix.
Uses the rtfeldman/elm-iso8601-date-strings package.
-}
iso8601Decoder : Decoder Posix
iso8601Decoder =
    D.string
        |> D.andThen
            (\dateString ->
                case Iso8601.toTime dateString of
                    Ok time ->
                        D.succeed time

                    Err _ ->
                        D.fail ("Invalid ISO8601 date: " ++ dateString)
            )



-- TIME ENTRIES SEARCH RESPONSE


{-| Response from the Toggl Reports API time entries search.
The API returns a list of results, each containing a list of time entries.
-}
type alias TimeEntriesSearchResult =
    { timeEntries : List TimeEntry
    }


timeEntriesSearchResultDecoder : Decoder TimeEntriesSearchResult
timeEntriesSearchResultDecoder =
    D.succeed TimeEntriesSearchResult
        |> DP.required "time_entries" (D.list timeEntryDecoder)


{-| Decode the full response from time entries search.
Returns a flat list of all time entries.
-}
timeEntriesSearchDecoder : Decoder (List TimeEntry)
timeEntriesSearchDecoder =
    D.list timeEntriesSearchResultDecoder
        |> D.map (List.concatMap .timeEntries)



-- API REQUESTS


{-| Fetch all workspaces for the authenticated user.
GET <https://api.track.toggl.com/api/v9/workspaces>
-}
fetchWorkspaces : ApiKey -> (Result Effect.Http.Error (List TogglWorkspace) -> msg) -> Effect.Command.Command restriction toMsg msg
fetchWorkspaces apiKey toMsg =
    Effect.Http.request
        { method = "GET"
        , headers = [ authHeader apiKey ]
        , url = "https://api.track.toggl.com/api/v9/workspaces"
        , body = Effect.Http.emptyBody
        , expect = Effect.Http.expectJson toMsg (D.list workspaceDecoder)
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }


{-| Fetch all projects in a workspace.
GET <https://api.track.toggl.com/api/v9/workspaces/{workspace_id}/projects>
-}
fetchProjects : ApiKey -> TogglWorkspaceId -> (Result Effect.Http.Error (List TogglProject) -> msg) -> Effect.Command.Command restriction toMsg msg
fetchProjects apiKey workspaceId toMsg =
    let
        url : String
        url =
            "https://api.track.toggl.com/api/v9/workspaces/"
                ++ String.fromInt (togglWorkspaceIdToInt workspaceId)
                ++ "/projects"
    in
    Effect.Http.request
        { method = "GET"
        , headers = [ authHeader apiKey ]
        , url = url
        , body = Effect.Http.emptyBody
        , expect = Effect.Http.expectJson toMsg (D.list projectDecoder)
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }


{-| Fetch time entries for a workspace within a date range.
POST <https://api.track.toggl.com/reports/api/v3/workspace/{workspace_id}/search/time_entries>
-}
fetchTimeEntries :
    ApiKey
    -> TogglWorkspaceId
    -> { startDate : String, endDate : String, description : Maybe String, projectId : Maybe TogglProjectId }
    -> (Result Effect.Http.Error (List TimeEntry) -> msg)
    -> Effect.Command.Command restriction toMsg msg
fetchTimeEntries apiKey workspaceId options toMsg =
    let
        url : String
        url =
            "https://api.track.toggl.com/reports/api/v3/workspace/"
                ++ String.fromInt (togglWorkspaceIdToInt workspaceId)
                ++ "/search/time_entries"

        projectIdField : List ( String, E.Value )
        projectIdField =
            case options.projectId of
                Just pid ->
                    [ ( "project_ids", E.list E.int [ togglProjectIdToInt pid ] ) ]

                Nothing ->
                    []

        descriptionField : List ( String, E.Value )
        descriptionField =
            case options.description of
                Just desc ->
                    [ ( "description", E.string desc ) ]

                Nothing ->
                    []

        body : E.Value
        body =
            E.object
                ([ ( "start_date", E.string options.startDate )
                 , ( "end_date", E.string options.endDate )
                 , ( "page_size", E.int 1000 )
                 ]
                    ++ projectIdField
                    ++ descriptionField
                )
    in
    Effect.Http.request
        { method = "POST"
        , headers = [ authHeader apiKey ]
        , url = url
        , body = Effect.Http.jsonBody body
        , expect = Effect.Http.expectJson toMsg timeEntriesSearchDecoder
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }
