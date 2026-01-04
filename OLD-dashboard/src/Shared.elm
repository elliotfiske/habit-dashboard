module Shared exposing (..)

import Dict exposing (Dict, update)
import Http
import IDict exposing (IDict)
import Id
import Iso8601
import Json.Decode as Decode exposing (..)
import Time
import Types exposing (BackendError(..), DatasourceCredentials(..), DatasourceCredentialsId(..), DatasourceCredentialsState(..), ErrorDetailed(..), HabitCalendar, HabitCalendarId(..), HabitCalendarSpecifics(..), PointInTime, SubmittedDatasourceCredentialsState(..), TogglEntry, TogglEntryId)


decodeTime : Decode.Decoder Time.Posix
decodeTime =
    Decode.string
        |> Decode.andThen
            (\dateString ->
                case Iso8601.toTime dateString of
                    Ok time ->
                        Decode.succeed time

                    Err _ ->
                        Decode.fail <| "Invalid date: " ++ dateString
            )


maybe2 : Maybe a -> Maybe b -> Maybe ( a, b )
maybe2 ma mb =
    case ma of
        Just a ->
            case mb of
                Just b ->
                    Just ( a, b )

                Nothing ->
                    Nothing

        Nothing ->
            Nothing


extractNow : { a | now : Time.Posix, zone : Time.Zone } -> PointInTime
extractNow { now, zone } =
    { posix = now, zone = zone }


getDatasourceCredentialsIdStringFromDatasourceCredentials : DatasourceCredentials -> String
getDatasourceCredentialsIdStringFromDatasourceCredentials credentials =
    case credentials of
        TogglDatasourceCredentials togglData ->
            Id.to togglData.id

        RizeDatasourceCredentials rizeData ->
            Id.to rizeData.id


datasourceCredentialsIdToString : DatasourceCredentialsId -> String
datasourceCredentialsIdToString credentialsId =
    case credentialsId of
        TogglDSCID id ->
            Id.to id

        RizeDSCID id ->
            Id.to id


getDatasourceCredentialsIdFromDatasourceCredentials : DatasourceCredentials -> DatasourceCredentialsId
getDatasourceCredentialsIdFromDatasourceCredentials credentials =
    case credentials of
        TogglDatasourceCredentials togglData ->
            TogglDSCID togglData.id

        RizeDatasourceCredentials rizeData ->
            RizeDSCID rizeData.id


habitCalendarForId : Dict String HabitCalendar -> HabitCalendarId -> Result BackendError HabitCalendar
habitCalendarForId habitCalendars id =
    let
        idString =
            habitCalendarIdToString id
    in
    Dict.get idString habitCalendars
        |> Result.fromMaybe (BadDataShape ("Habit calendar not found for id " ++ idString))


getIdForHabitCalendar : HabitCalendar -> HabitCalendarId
getIdForHabitCalendar habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar specifics ->
            TogglHC specifics.id

        RizeHabitCalendar specifics ->
            RizeHC specifics.id


getStringIdForHabitCalendar : HabitCalendar -> String
getStringIdForHabitCalendar habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar specifics ->
            Id.to specifics.id

        RizeHabitCalendar specifics ->
            Id.to specifics.id


habitCalendarIdToString : HabitCalendarId -> String
habitCalendarIdToString habitCalendarId =
    case habitCalendarId of
        TogglHC id ->
            Id.to id

        RizeHC id ->
            Id.to id


updateHabitCalendarTogglEntriesWipingBetweenTime : Time.Posix -> Time.Posix -> IDict TogglEntryId TogglEntry -> HabitCalendar -> HabitCalendar
updateHabitCalendarTogglEntriesWipingBetweenTime queryStartTime queryEndTime entries habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar specifics ->
            let
                queryStartTimeMillis =
                    Time.posixToMillis queryStartTime

                queryEndTimeMillis =
                    Time.posixToMillis queryEndTime

                -- Remove all entries whose start times are being re-queried
                -- FUTURE BUG: If the results are paged we will delete too much stuff.
                prunedEntries =
                    IDict.filter
                        (\_ entry ->
                            let
                                entryStart =
                                    Time.posixToMillis entry.start
                            in
                            entryStart > queryStartTimeMillis && entryStart < queryEndTimeMillis
                        )
                        entries

                newSpecifics =
                    { specifics | entries = IDict.union entries prunedEntries }
            in
            { habitCalendar | specifics = TogglHabitCalendar newSpecifics }

        RizeHabitCalendar _ ->
            -- TODO: raise alarm bells, invalid data state. Maybe have this function only accept TogglHabitCalendar?
            habitCalendar


updateHabitCalendarTogglEntries : IDict TogglEntryId TogglEntry -> HabitCalendar -> HabitCalendar
updateHabitCalendarTogglEntries entries habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar specifics ->
            let
                newSpecifics =
                    { specifics | entries = IDict.union entries specifics.entries }
            in
            { habitCalendar | specifics = TogglHabitCalendar newSpecifics }

        RizeHabitCalendar _ ->
            -- TODO: invalid data state!
            habitCalendar


togglEntryMatchesHabitCalendar : TogglEntry -> HabitCalendar -> Bool
togglEntryMatchesHabitCalendar entry habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar specifics ->
            case entry.description of
                Nothing ->
                    False

                Just entryDescription ->
                    String.contains (lowerTrim specifics.descriptionMatchString) (lowerTrim entryDescription)
                        && specifics.togglProjectId
                        == entry.projectId

        RizeHabitCalendar _ ->
            False


secondsForTogglEntry : TogglEntry -> Int
secondsForTogglEntry entry =
    case entry.stop of
        Nothing ->
            0

        Just end ->
            (Time.posixToMillis end - Time.posixToMillis entry.start) // 1000


updateHabitCalendarWithId :
    Dict String HabitCalendar
    -> (HabitCalendar -> HabitCalendar)
    -> HabitCalendarId
    -> Dict String HabitCalendar
updateHabitCalendarWithId habitCalendars update id =
    case Dict.get (habitCalendarIdToString id) habitCalendars of
        Just habitCalendar ->
            Dict.insert (habitCalendarIdToString id) (update habitCalendar) habitCalendars

        Nothing ->
            habitCalendars



-- utils


lowerTrim : String -> String
lowerTrim =
    String.toLower >> String.trim


stringifyHttpError : Http.Error -> String
stringifyHttpError err =
    case err of
        Http.BadUrl string ->
            "Bad URL: " ++ string

        Http.Timeout ->
            "Request timed out."

        Http.NetworkError ->
            "Network error. Are you online?"

        Http.BadStatus int ->
            "Bad status: " ++ String.fromInt int

        Http.BadBody string ->
            "Bad body: " ++ string


stringifyBackendError : BackendError -> String
stringifyBackendError err =
    case err of
        BadDataShape string ->
            "Bad data shape: " ++ string

        HttpFailure httpErr ->
            "Network error: " ++ stringifyHttpError httpErr

        Unimplemented ->
            "Not implemented yet!"


stringifyErrorDetailed : ErrorDetailed String -> String
stringifyErrorDetailed err =
    case err of
        BadUrl url ->
            "Bad URL: " ++ url

        Timeout ->
            "Timeout"

        NetworkError ->
            "Network error"

        BadStatus metadata body ->
            "Bad status: " ++ String.fromInt metadata.statusCode ++ " " ++ body

        BadBody metadata body rawBody ->
            "Bad body: " ++ String.fromInt metadata.statusCode ++ " " ++ body ++ " " ++ rawBody


expectJsonDetailed : (Result (ErrorDetailed String) ( Http.Metadata, a ) -> msg) -> Decode.Decoder a -> Http.Expect msg
expectJsonDetailed msg decoder =
    Http.expectStringResponse msg (convertResponseStringToJson decoder)


convertResponseStringToJson : Decode.Decoder a -> Http.Response String -> Result (ErrorDetailed String) ( Http.Metadata, a )
convertResponseStringToJson decoder httpResponse =
    case httpResponse of
        Http.BadUrl_ url ->
            Err (BadUrl url)

        Http.Timeout_ ->
            Err Timeout

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body ->
            Err (BadStatus metadata body)

        Http.GoodStatus_ metadata body ->
            Result.mapError (BadBody metadata body) <|
                Result.mapError Decode.errorToString
                    (Decode.decodeString (Decode.map (\res -> ( metadata, res )) decoder) body)
