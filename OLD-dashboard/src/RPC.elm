module RPC exposing (..)

import Backend exposing (sendNewStateToFrontend, updateTogglHabitCalendarWithWebhookEvent)
import DataDecoders exposing (webhookTopLevelDecoder)
import Http
import Json.Decode as D
import Json.Decode.Pipeline exposing (required)
import Json.Encode as E
import Lamdera exposing (SessionId, broadcast)
import LamderaRPC exposing (RPC(..), RPCResult(..))
import Types exposing (..)



-- Things that should be auto-generated in future


lamdera_handleEndpoints : LamderaRPC.RPCArgs -> BackendModel -> ( LamderaRPC.RPCResult, BackendModel, Cmd BackendMsg )
lamdera_handleEndpoints args model =
    case args.endpoint of
        "togglWebhook" ->
            LamderaRPC.handleEndpointJson handleTogglPing args model

        _ ->
            ( LamderaRPC.ResultFailure <| Http.BadBody <| "Unknown endpoint " ++ args.endpoint, model, Cmd.none )


encodePong value =
    E.object
        [ ( "validation_code", E.string value ) ]


handleTogglPing : SessionId -> BackendModel -> E.Value -> ( Result Http.Error E.Value, BackendModel, Cmd BackendMsg )
handleTogglPing _ model jsonArg =
    let
        decoder =
            D.succeed identity
                |> required "validation_code" D.string
    in
    case D.decodeValue decoder jsonArg of
        Ok validationCode ->
            ( Ok <| encodePong validationCode
            , model
            , Cmd.none
            )

        Err _ ->
            handleTogglEvent model jsonArg


calculateNewRunningEntry : TogglWebhookEvent -> RunningEntry -> RunningEntry
calculateNewRunningEntry modifiedEntry previousRunningEntry =
    let
        normalizedAction =
            String.toLower modifiedEntry.metadata.action
    in
    if
        normalizedAction
            == "created"
            && modifiedEntry.payload.stop
            == Nothing
    then
        -- New running entry
        RunningEntry modifiedEntry.payload

    else if
        normalizedAction
            == "deleted"
            && (case previousRunningEntry of
                    RunningEntry runningEntry ->
                        runningEntry.id == modifiedEntry.payload.id

                    _ ->
                        False
               )
    then
        -- Current running entry was deleted
        NoRunningEntry

    else if
        -- Current running entry was updated
        normalizedAction
            == "updated"
            && (case previousRunningEntry of
                    RunningEntry runningEntry ->
                        runningEntry.id
                            == modifiedEntry.payload.id
                            && modifiedEntry.payload.stop
                            /= Nothing

                    _ ->
                        False
               )
    then
        -- Current running entry was STOPPED
        NoRunningEntry

    else
        -- Current running entry is unchanged
        previousRunningEntry


handleTogglEvent : BackendModel -> E.Value -> ( Result Http.Error E.Value, BackendModel, Cmd BackendMsg )
handleTogglEvent model jsonArg =
    case D.decodeValue webhookTopLevelDecoder jsonArg of
        Ok togglEvent ->
            let
                parsedRunningEntry =
                    calculateNewRunningEntry togglEvent model.runningEntry

                nextModelAndCommands =
                    updateTogglHabitCalendarWithWebhookEvent model togglEvent

                nextModel =
                    Tuple.first nextModelAndCommands

                finalModel =
                    { nextModel | runningEntry = parsedRunningEntry }
            in
            ( Ok <| E.string "holla holla"
            , finalModel
            , Cmd.batch
                [ broadcast (AddDebugRequest (E.encode 2 jsonArg))
                , sendNewStateToFrontend finalModel
                ]
            )

        Err err ->
            ( Err <|
                Http.BadBody <|
                    "Failed to decode arg for [json] "
                        ++ "exampleJson "
                        ++ D.errorToString err
            , model
            , broadcast (AddDebugRequest (D.errorToString err))
            )
