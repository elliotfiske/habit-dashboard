module DataDecoders exposing (..)

import Color exposing (Color)
import Color.Convert
import DatasourceIds exposing (rizeDatasourceIdDecoder, rizeDatasourceIdEncoder, togglDatasourceIdDecoder, togglDatasourceIdEncoder)
import Dict exposing (Dict)
import IDict
import Id
import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Shared exposing (decodeTime)
import Types exposing (..)


workspaceDecoder : Decoder TogglWorkspace
workspaceDecoder =
    D.succeed TogglWorkspace
        |> DP.required "id" (Id.decoder D.int)
        |> DP.required "organization_id" D.int
        |> DP.required "name" D.string
        |> DP.required "logo_url" D.string


decodeColor : Decoder Color
decodeColor =
    D.string
        |> D.andThen
            (\colorString ->
                case Color.Convert.hexToColor colorString of
                    Ok color ->
                        D.succeed color

                    Err err ->
                        D.fail ("Invalid color: " ++ err)
            )


projectDecoder : Decoder TogglProject
projectDecoder =
    D.succeed TogglProject
        |> DP.required "id" (Id.decoder D.int)
        |> DP.required "workspace_id" (Id.decoder D.int)
        |> DP.required "name" D.string
        |> DP.required "color" decodeColor


decodeRunningEntry : Decoder RunningEntry
decodeRunningEntry =
    D.andThen
        (\maybeEntry ->
            case maybeEntry of
                Just entry ->
                    D.succeed (RunningEntry entry)

                Nothing ->
                    D.succeed NoRunningEntry
        )
        (D.nullable togglEntryDecoder)


togglEntryDecoder : Decoder TogglEntry
togglEntryDecoder =
    D.succeed TogglEntry
        |> DP.required "id" (Id.decoder D.int)
        |> DP.optional "project_id" (D.nullable (Id.decoder D.int)) Nothing
        |> DP.optional "description" (D.nullable D.string) Nothing
        |> DP.required "start" decodeTime
        |> DP.optional "stop" (D.nullable decodeTime) Nothing


webhookMetadataDecoder : Decoder TogglWebhookEventMetadata
webhookMetadataDecoder =
    D.succeed TogglWebhookEventMetadata
        |> DP.required "action" D.string


webhookTopLevelDecoder : Decoder TogglWebhookEvent
webhookTopLevelDecoder =
    D.succeed TogglWebhookEvent
        |> DP.required "payload" togglEntryDecoder
        |> DP.required "metadata" webhookMetadataDecoder


entryResultListDecoder : Decoder (List TogglEntryResult)
entryResultListDecoder =
    D.list entryResultDecoder


entryResultDecoder : Decoder TogglEntryResult
entryResultDecoder =
    D.succeed TogglEntryResult
        |> DP.required "time_entries" (D.list togglEntryDecoder)



-- Encode helpers


encodeNullable : (value -> E.Value) -> Maybe value -> E.Value
encodeNullable valueEncoder maybeValue =
    case maybeValue of
        Just value ->
            valueEncoder value

        Nothing ->
            E.null


encodeHabitCalendarSpecifics : HabitCalendarSpecifics -> E.Value
encodeHabitCalendarSpecifics specifics =
    case specifics of
        TogglHabitCalendar togglHabitCalendar ->
            E.object
                [ ( "type", E.string "TogglHabitCalendar" )
                , ( "datasourceId", togglDatasourceIdEncoder togglHabitCalendar.datasourceId )
                , ( "workspaceId", Id.encode E.int togglHabitCalendar.workspaceId )
                , ( "togglProjectId", encodeNullable E.int (Maybe.map Id.to togglHabitCalendar.togglProjectId) )
                , ( "descriptionMatchString", E.string togglHabitCalendar.descriptionMatchString )
                , ( "id", Id.encode E.string togglHabitCalendar.id )
                ]

        RizeHabitCalendar rizeHabitCalendar ->
            E.object
                [ ( "type", E.string "RizeHabitCalendar" )
                , ( "datasourceId", rizeDatasourceIdEncoder rizeHabitCalendar.datasourceId )
                , ( "categoryId", E.string rizeHabitCalendar.categoryKey )
                , ( "id", Id.encode E.string rizeHabitCalendar.id )
                ]


exportedHabitCalendars : Dict String HabitCalendar -> String
exportedHabitCalendars calendars =
    E.encode 2 (E.dict identity encodeHabitCalendar calendars)


encodeHabitCalendar : HabitCalendar -> E.Value
encodeHabitCalendar calendar =
    E.object
        [ ( "name", E.string calendar.name )
        , ( "successColor", E.string (Color.Convert.colorToHex calendar.successColor) )
        , ( "nonzeroColor", E.string (Color.Convert.colorToHex calendar.nonzeroColor) )
        , ( "weeksShowing", E.int calendar.weeksShowing )
        , ( "specifics", encodeHabitCalendarSpecifics calendar.specifics )
        ]


decodeHabitCalendarDict : Decoder (Dict String HabitCalendar)
decodeHabitCalendarDict =
    D.dict decodeHabitCalendar


decodeHabitCalendar : Decoder HabitCalendar
decodeHabitCalendar =
    D.succeed HabitCalendar
        |> DP.required "name" D.string
        |> DP.required "nonzeroColor" decodeColor
        |> DP.required "successColor" decodeColor
        |> DP.required "weeksShowing" D.int
        |> DP.hardcoded Loading
        |> DP.required "specifics" habitCalendarSpecificsDecoder


habitCalendarSpecificsDecoder : Decoder HabitCalendarSpecifics
habitCalendarSpecificsDecoder =
    D.field "type" D.string
        |> D.andThen
            (\type_ ->
                case type_ of
                    "TogglHabitCalendar" ->
                        D.map TogglHabitCalendar togglHabitCalendarSpecificDecoder

                    "RizeHabitCalendar" ->
                        D.map RizeHabitCalendar rizeHabitCalendarSpecificDecoder

                    _ ->
                        D.fail ("Unknown habit calendar type: " ++ type_)
            )


togglHabitCalendarSpecificDecoder : Decoder TogglHabitCalendarSpecifics
togglHabitCalendarSpecificDecoder =
    D.map6 TogglHabitCalendarSpecifics
        (D.field "id" (Id.decoder D.string))
        (D.field "datasourceId" togglDatasourceIdDecoder)
        (D.field "workspaceId" (Id.decoder D.int))
        (D.field "togglProjectId" (D.nullable (Id.decoder D.int)))
        (D.field "descriptionMatchString" D.string)
        (D.succeed IDict.empty)


rizeHabitCalendarSpecificDecoder : Decoder RizeHabitCalendarSpecifics
rizeHabitCalendarSpecificDecoder =
    D.map4 RizeHabitCalendarSpecifics
        (D.field "id" (Id.decoder D.string))
        (D.field "categoryKey" D.string)
        (D.field "datasourceId" rizeDatasourceIdDecoder)
        (D.succeed Dict.empty)



-- Rize stuff


rizeCategoryResponseDecoder : Decoder (List RizeCategory)
rizeCategoryResponseDecoder =
    D.field "data" (D.field "categoryModels" (D.list rizeCategoryDecoder))


rizeCategoryDecoder : Decoder RizeCategory
rizeCategoryDecoder =
    D.succeed RizeCategory
        |> DP.required "id" (Id.decoder D.string)
        |> DP.required "name" D.string
        |> DP.required "key" D.string


rizeEntryDecoder : Decoder RizeEntry
rizeEntryDecoder =
    D.map2 RizeEntry
        (D.field "value" D.int)
        (D.field "startTime" decodeTime)


rizeEntryListDecoder : Decoder (List RizeEntry)
rizeEntryListDecoder =
    D.field "data" (D.field "trackedTimeHistogram" (D.list rizeEntryDecoder))
