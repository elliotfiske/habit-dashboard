module RPC exposing (lamdera_handleEndpoints)

{-| RPC endpoint handlers for external HTTP POST requests.

This module handles webhooks from Toggl Track, which notify us
when time entries are created, updated, or deleted.

-}

import Http
import Json.Decode as D
import Json.Encode as E
import Lamdera
import LamderaRPC exposing (RPCArgs, RPCResult(..))
import Time
import Toggl
import Types exposing (BackendModel, BackendMsg, ToFrontend(..), WebhookDebugEntry)


{-| Main entry point for all RPC endpoints.
Lamdera automatically routes POST requests to /\_r/{endpoint} here.
-}
lamdera_handleEndpoints : RPCArgs -> BackendModel -> ( RPCResult, BackendModel, Cmd BackendMsg )
lamdera_handleEndpoints args model =
    case args.endpoint of
        "togglWebhook" ->
            LamderaRPC.handleEndpointJson handleTogglWebhook args model

        _ ->
            ( ResultJson (E.object [ ( "error", E.string ("Unknown endpoint: " ++ args.endpoint) ) ])
            , model
            , Cmd.none
            )


{-| Handle incoming Toggl webhook requests.

Toggl sends two types of requests:

1.  Validation ping: { "validation\_code": "..." } - we must echo it back
2.  Event notification: { "payload": ..., "metadata": { "action": "..." } }

-}
handleTogglWebhook : Lamdera.SessionId -> BackendModel -> E.Value -> ( Result Http.Error E.Value, BackendModel, Cmd BackendMsg )
handleTogglWebhook _ model jsonArg =
    -- First, check for "ping" validation (payload: "ping")
    case D.decodeValue Toggl.pingValidationDecoder jsonArg of
        Ok True ->
            -- This is a ping validation - just respond with success
            let
                debugEntry : WebhookDebugEntry
                debugEntry =
                    { timestamp = Time.millisToPosix 0 -- Placeholder timestamp
                    , eventType = "validation"
                    , description = "Ping validation"
                    , rawJson = E.encode 2 jsonArg
                    }

                debugCmd : Cmd BackendMsg
                debugCmd =
                    Lamdera.broadcast (WebhookDebugEvent debugEntry)
            in
            ( Ok (E.object [ ( "status", E.string "ok" ) ])
            , model
            , debugCmd
            )

        _ ->
            -- Not a ping validation, try validation_code format
            case D.decodeValue Toggl.validationCodeDecoder jsonArg of
                Ok validationCode ->
                    -- This is a validation request - just echo the code back
                    let
                        debugEntry : WebhookDebugEntry
                        debugEntry =
                            { timestamp = Time.millisToPosix 0 -- Placeholder timestamp
                            , eventType = "validation"
                            , description = "Validation ping: " ++ validationCode
                            , rawJson = E.encode 2 jsonArg
                            }

                        debugCmd : Cmd BackendMsg
                        debugCmd =
                            Lamdera.broadcast (WebhookDebugEvent debugEntry)
                    in
                    ( Ok (Toggl.encodeValidationResponse validationCode)
                    , model
                    , debugCmd
                    )

                Err _ ->
                    -- Not a validation request, try to decode as a webhook event
                    handleTogglEvent model jsonArg


{-| Handle an actual Toggl webhook event (created/updated/deleted).
-}
handleTogglEvent : BackendModel -> E.Value -> ( Result Http.Error E.Value, BackendModel, Cmd BackendMsg )
handleTogglEvent model jsonArg =
    case D.decodeValue Toggl.webhookEventDecoder jsonArg of
        Ok webhookEvent ->
            let
                -- Calculate the new running entry state
                newRunningEntry : Types.RunningEntry
                newRunningEntry =
                    calculateNewRunningEntry webhookEvent model.runningEntry

                -- Update model with new running entry
                updatedModel : BackendModel
                updatedModel =
                    { model | runningEntry = newRunningEntry }

                -- Create debug entry
                debugEntry : WebhookDebugEntry
                debugEntry =
                    { timestamp = Time.millisToPosix 0 -- Placeholder timestamp
                    , eventType = "event"
                    , description =
                        "Action: "
                            ++ actionToString webhookEvent.metadata.action
                            ++ ", Description: "
                            ++ Maybe.withDefault "(none)" webhookEvent.payload.description
                    , rawJson = E.encode 2 jsonArg
                    }

                -- Broadcast commands
                broadcastCmds : Cmd BackendMsg
                broadcastCmds =
                    Cmd.batch
                        [ Lamdera.broadcast (RunningEntryUpdated newRunningEntry)
                        , Lamdera.broadcast (WebhookDebugEvent debugEntry)
                        ]

                _ =
                    Debug.log "Webhook event processed" webhookEvent
            in
            ( Ok (E.object [ ( "status", E.string "ok" ) ])
            , updatedModel
            , broadcastCmds
            )

        Err decodeError ->
            let
                debugEntry : WebhookDebugEntry
                debugEntry =
                    { timestamp = Time.millisToPosix 0
                    , eventType = "error"
                    , description = "Failed to decode: " ++ D.errorToString decodeError
                    , rawJson = E.encode 2 jsonArg
                    }
            in
            ( Err (Http.BadBody ("Failed to decode webhook event: " ++ D.errorToString decodeError))
            , model
            , Lamdera.broadcast (WebhookDebugEvent debugEntry)
            )


{-| Convert webhook action to string for display.
-}
actionToString : Toggl.WebhookAction -> String
actionToString action =
    case action of
        Toggl.Created ->
            "created"

        Toggl.Updated ->
            "updated"

        Toggl.Deleted ->
            "deleted"


{-| Calculate the new running entry state based on a webhook event.

Logic:

  - If action is "created" and the entry has no stop time -> new running entry
  - If action is "deleted" and it matches the current running entry -> no running entry
  - If action is "updated" and the current running entry now has a stop time -> stopped
  - Otherwise -> keep the current running entry

-}
calculateNewRunningEntry : Toggl.WebhookEvent -> Types.RunningEntry -> Types.RunningEntry
calculateNewRunningEntry event previousRunningEntry =
    let
        payload : Toggl.WebhookPayload
        payload =
            event.payload

        action : Toggl.WebhookAction
        action =
            event.metadata.action

        entryId : Toggl.TimeEntryId
        entryId =
            payload.id

        isRunning : Bool
        isRunning =
            payload.stop == Nothing

        currentRunningId : Maybe Toggl.TimeEntryId
        currentRunningId =
            case previousRunningEntry of
                Types.RunningEntry runningPayload ->
                    Just runningPayload.id

                Types.NoRunningEntry ->
                    Nothing
    in
    case action of
        Toggl.Created ->
            if isRunning then
                -- New running entry
                Types.RunningEntry payload

            else
                -- Created but already stopped - no change
                previousRunningEntry

        Toggl.Deleted ->
            if currentRunningId == Just entryId then
                -- Current running entry was deleted
                Types.NoRunningEntry

            else
                -- Some other entry was deleted - no change
                previousRunningEntry

        Toggl.Updated ->
            if currentRunningId == Just entryId && not isRunning then
                -- Current running entry was stopped
                Types.NoRunningEntry

            else if isRunning then
                -- An entry was updated to be running (resumed or new)
                Types.RunningEntry payload

            else
                -- Some other update - no change
                previousRunningEntry
