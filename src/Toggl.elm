module Toggl exposing
    ( ApiKey
    , TimeEntry
    , TimeEntryId(..)
    , TogglApiError(..)
    , TogglProject
    , TogglProjectId(..)
    , TogglWorkspace
    , TogglWorkspaceId(..)
    , WebhookAction(..)
    , WebhookEvent
    , WebhookMetadata
    , WebhookPayload
    , authHeader
    , encodeValidationResponse
    , fetchProjects
    , fetchTimeEntries
    , fetchWorkspaces
    , projectDecoder
    , timeEntriesSearchDecoder
    , timeEntryIdToInt
    , togglApiErrorToString
    , togglProjectIdToInt
    , togglProjectIdToString
    , togglWorkspaceIdToInt
    , validateWebhookSubscription
    , validationCodeDecoder
    , webhookEventDecoder
    , workspaceDecoder
    )

{-| Toggl API types and decoders.

Toggl Track API docs: <https://developers.track.toggl.com/docs/>

-}

import Base64
import Duration
import Effect.Command
import Effect.Http
import Http
import Iso8601
import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Time exposing (Posix)


{-| Custom error type for Toggl API errors that includes rate limit details.
-}
type TogglApiError
    = HttpError Effect.Http.Error
    | RateLimited { secondsUntilReset : Int, message : String }



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


togglProjectIdToString : TogglProjectId -> String
togglProjectIdToString =
    togglProjectIdToInt >> String.fromInt


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


{-| Convert a TogglApiError to a user-friendly string.
-}
togglApiErrorToString : TogglApiError -> String
togglApiErrorToString error =
    case error of
        RateLimited { secondsUntilReset, message } ->
            -- Pass raw seconds so Frontend can calculate the absolute reset time
            "RATE_LIMIT:" ++ String.fromInt secondsUntilReset ++ "|" ++ message

        HttpError httpError ->
            case httpError of
                Effect.Http.BadUrl url ->
                    "Bad URL: " ++ url

                Effect.Http.Timeout ->
                    "Request timed out"

                Effect.Http.NetworkError ->
                    "Network error - check your connection"

                Effect.Http.BadStatus status ->
                    case status of
                        401 ->
                            "Invalid API key (401 Unauthorized)"

                        403 ->
                            "Access forbidden (403)"

                        _ ->
                            "HTTP error: " ++ String.fromInt status

                Effect.Http.BadBody body ->
                    "Invalid response: " ++ body


{-| Parse the rate limit error body to extract seconds until reset.
Example body: "Your hourly limit of API requests was reached. Please try again in 2174 seconds."
-}
parseRateLimitBody : String -> { secondsUntilReset : Int, message : String }
parseRateLimitBody body =
    let
        -- Try to extract the number of seconds from the message
        -- Look for "in X seconds" pattern
        maybeSeconds : Maybe Int
        maybeSeconds =
            body
                |> String.words
                |> findSecondsInWords
    in
    { secondsUntilReset = Maybe.withDefault 3600 maybeSeconds
    , message = body
    }


{-| Find the number before "seconds" in a list of words.
-}
findSecondsInWords : List String -> Maybe Int
findSecondsInWords words =
    case words of
        [] ->
            Nothing

        num :: "seconds" :: _ ->
            String.toInt num

        num :: "seconds." :: _ ->
            String.toInt num

        _ :: rest ->
            findSecondsInWords rest


{-| Handle HTTP response, checking for rate limit errors.
-}
handleResponse : Decoder a -> Effect.Http.Response String -> Result TogglApiError a
handleResponse decoder response =
    case response of
        Effect.Http.BadUrl_ url ->
            Err (HttpError (Effect.Http.BadUrl url))

        Effect.Http.Timeout_ ->
            Err (HttpError Effect.Http.Timeout)

        Effect.Http.NetworkError_ ->
            Err (HttpError Effect.Http.NetworkError)

        Effect.Http.BadStatus_ metadata body ->
            if metadata.statusCode == 402 then
                Err (RateLimited (parseRateLimitBody body))

            else
                Err (HttpError (Effect.Http.BadStatus metadata.statusCode))

        Effect.Http.GoodStatus_ _ body ->
            case D.decodeString decoder body of
                Ok value ->
                    Ok value

                Err decodeError ->
                    Err (HttpError (Effect.Http.BadBody (D.errorToString decodeError)))


{-| Fetch all workspaces for the authenticated user.
GET <https://api.track.toggl.com/api/v9/workspaces>
-}
fetchWorkspaces : ApiKey -> (Result TogglApiError (List TogglWorkspace) -> msg) -> Effect.Command.Command restriction toMsg msg
fetchWorkspaces apiKey toMsg =
    Effect.Http.request
        { method = "GET"
        , headers = [ authHeader apiKey ]
        , url = "https://api.track.toggl.com/api/v9/workspaces"
        , body = Effect.Http.emptyBody
        , expect = Effect.Http.expectStringResponse toMsg (handleResponse (D.list workspaceDecoder))
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }


{-| Fetch all projects in a workspace.
GET <https://api.track.toggl.com/api/v9/workspaces/{workspace_id}/projects>
-}
fetchProjects : ApiKey -> TogglWorkspaceId -> (Result TogglApiError (List TogglProject) -> msg) -> Effect.Command.Command restriction toMsg msg
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
        , expect = Effect.Http.expectStringResponse toMsg (handleResponse (D.list projectDecoder))
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
    -> (Result TogglApiError (List TimeEntry) -> msg)
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
        , expect = Effect.Http.expectStringResponse toMsg (handleResponse timeEntriesSearchDecoder)
        , timeout = Just (Duration.seconds 10)
        , tracker = Nothing
        }



-- WEBHOOK TYPES


{-| A webhook event from Toggl.
Toggl sends these when time entries are created, updated, or deleted.
-}
type alias WebhookEvent =
    { payload : WebhookPayload
    , metadata : WebhookMetadata
    }


{-| The payload of a webhook event - represents a time entry.
-}
type alias WebhookPayload =
    { id : TimeEntryId
    , projectId : Maybe TogglProjectId
    , workspaceId : TogglWorkspaceId
    , description : Maybe String
    , start : Posix
    , stop : Maybe Posix
    , duration : Int -- seconds, -1 if running
    }


{-| Metadata about the webhook event (what action triggered it).
-}
type alias WebhookMetadata =
    { action : WebhookAction
    }


{-| The type of action that triggered the webhook.
-}
type WebhookAction
    = Created
    | Updated
    | Deleted



-- WEBHOOK DECODERS


{-| Decoder for the top-level webhook event.
-}
webhookEventDecoder : Decoder WebhookEvent
webhookEventDecoder =
    D.succeed WebhookEvent
        |> DP.required "payload" webhookPayloadDecoder
        |> DP.required "metadata" webhookMetadataDecoder


{-| Decoder for the webhook payload (time entry data).
-}
webhookPayloadDecoder : Decoder WebhookPayload
webhookPayloadDecoder =
    D.succeed WebhookPayload
        |> DP.required "id" (D.map TimeEntryId D.int)
        |> DP.optional "project_id" (D.nullable (D.map TogglProjectId D.int)) Nothing
        |> DP.required "workspace_id" (D.map TogglWorkspaceId D.int)
        |> DP.optional "description" (D.nullable D.string) Nothing
        |> DP.required "start" Iso8601.decoder
        |> DP.optional "stop" (D.nullable Iso8601.decoder) Nothing
        |> DP.required "duration" D.int


{-| Decoder for the webhook metadata.
-}
webhookMetadataDecoder : Decoder WebhookMetadata
webhookMetadataDecoder =
    D.succeed WebhookMetadata
        |> DP.required "action" webhookActionDecoder


{-| Decoder for the webhook action string.
-}
webhookActionDecoder : Decoder WebhookAction
webhookActionDecoder =
    D.string
        |> D.andThen
            (\actionStr ->
                case String.toLower actionStr of
                    "created" ->
                        D.succeed Created

                    "updated" ->
                        D.succeed Updated

                    "deleted" ->
                        D.succeed Deleted

                    other ->
                        D.fail ("Unknown webhook action: " ++ other)
            )


{-| Decoder for the validation ping request.
Toggl sends this to verify the webhook endpoint.
-}
validationCodeDecoder : Decoder String
validationCodeDecoder =
    D.field "validation_code" D.string


{-| Encode a validation response to send back to Toggl.
-}
encodeValidationResponse : String -> E.Value
encodeValidationResponse code =
    E.object [ ( "validation_code", E.string code ) ]


{-| Validate a webhook subscription with Toggl.
This must be called when we receive a validation ping from Toggl.
Makes a GET request to confirm the subscription is valid.

<https://developers.track.toggl.com/docs/webhooks#validate-subscription>

-}
validateWebhookSubscription :
    ApiKey
    -> { workspaceId : Int, subscriptionId : Int, validationCode : String }
    -> (Result Http.Error () -> msg)
    -> Cmd msg
validateWebhookSubscription apiKey options toMsg =
    let
        url : String
        url =
            "https://api.track.toggl.com/webhooks/api/v1/validate/"
                ++ String.fromInt options.workspaceId
                ++ "/"
                ++ String.fromInt options.subscriptionId
                ++ "/"
                ++ options.validationCode
    in
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" (apiKeyToAuthHeader apiKey) ]
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Just 10000
        , tracker = Nothing
        }


{-| Convert API key to Basic Auth header value.
-}
apiKeyToAuthHeader : ApiKey -> String
apiKeyToAuthHeader apiKey =
    "Basic " ++ Base64.encode (apiKey ++ ":api_token")
