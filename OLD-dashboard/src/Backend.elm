module Backend exposing (app, sendNewStateToFrontend, subscriptions, updateTogglHabitCalendarWithWebhookEvent)

import Datasource as MDatasource
import DatasourceIds exposing (RizeDatasourceId, TogglDatasourceId)
import Dict exposing (Dict)
import Http
import IDict
import Id
import Lamdera exposing (ClientId, SessionId, broadcast)
import List.FlatMap exposing (flatMap)
import SDict
import Shared exposing (extractNow, getStringIdForHabitCalendar, habitCalendarForId, habitCalendarIdToString, stringifyHttpError, togglEntryMatchesHabitCalendar, updateHabitCalendarTogglEntries, updateHabitCalendarTogglEntriesWipingBetweenTime)
import Task
import Time
import Types exposing (..)


app =
    Lamdera.backend
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = subscriptions
        }


subscriptions : a -> Sub BackendMsg
subscriptions _ =
    Sub.batch
        [ Lamdera.onConnect ClientConnected
        , Time.every 30000 WipeDebounceStates
--        , Time.every 30000 UpdateRunningEntry
        , Time.every 60000 FetchCurrentTimeBackend
        ]


init : ( BackendModel, Cmd BackendMsg )
init =
    ( { habitCalendars = Dict.empty
      , connectedClients = []
      , runningEntry = TogglNotConnected
      , rizeDatasource = MDatasource.initialRizeDatasource
      , togglDatasource = MDatasource.initialTogglDatasource
      , datasourceCredentials = Dict.empty
      , togglProjects = IDict.empty
      , rizeCategories = SDict.empty
      , zone = Time.utc
      , now = Time.millisToPosix 0
      }
    , Task.map2 PointInTime Time.here Time.now
        |> Task.perform GotTime
    )


update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Cmd.none )

        GotTime time ->
            ( { model | zone = time.zone, now = time.posix }, Cmd.none )

        FetchCurrentTimeBackend time ->
            ( { model | now = time }, Cmd.none )

        ClientConnected sessionId clientId ->
            let
                ( newModel, cmd ) =
                    fetchAllHabitCalendarData model

                newClients =
                    model.connectedClients |> List.append [ ( sessionId, clientId ) ]
            in
            ( { newModel | connectedClients = newClients }
            , Cmd.batch
                [ cmd
                , sendNewStateToFrontend newModel
                ]
            )

        ClientDisconnected sessionId clientId ->
            let
                newClients =
                    model.connectedClients |> List.filter (\( s, c ) -> s /= sessionId || c /= clientId)
            in
            ( { model | connectedClients = newClients }, Cmd.none )

        WipeDebounceStates _ ->
            ( model, Cmd.none )

        GotWorkspaceData datasourceId togglCredentials workspacesResult ->
            let
                ( updatedDatasource, arbitraryWorkspaceId ) =
                    MDatasource.handleWorkspacesResult model.togglDatasource workspacesResult

                newModel =
                    { model | togglDatasource = updatedDatasource }
            in
            ( newModel
            , Cmd.batch
                [ MDatasource.queryTogglProjects togglCredentials arbitraryWorkspaceId
                , sendNewStateToFrontend newModel
                ]
            )

        GotProjectsData _ maybeProjects ->
            case maybeProjects of
                Err err ->
                    ( model, broadcast (ReportError (HttpFailure err)) )

                Ok projects ->
                    let
                        projectDict =
                            projects
                                |> List.map (\project -> ( project.id, project ))
                                |> IDict.fromList

                        newModel =
                            { model
                                | togglProjects = projectDict
                            }
                    in
                    ( newModel, sendNewStateToFrontend newModel )

        GotTogglEntries habitCalendarId queryStartTime queryEndTime result ->
            handleTogglEntriesResult habitCalendarId model result queryStartTime queryEndTime

        UpdateRunningEntry _ ->
            getRunningEntry model

        GotRunningEntry result ->
            case result of
                Err err ->
                    let
                        newModel =
                            { model | runningEntry = ErrorGettingRunningEntry (stringifyHttpError err) }
                    in
                    ( newModel, sendNewStateToFrontend newModel )

                Ok newRunningEntry ->
                    let
                        newModel =
                            { model | runningEntry = newRunningEntry }
                    in
                    ( newModel, sendNewStateToFrontend newModel )

        GotRizeCategoriesData rizeDatasourceId result ->
            handleGotRizeCategoryList rizeDatasourceId result model

        GotRizeEntries calendarId result ->
            handleRizeEntriesResult calendarId model result


handleGotRizeCategoryList : RizeDatasourceId -> Result Http.Error (List RizeCategory) -> BackendModel -> ( BackendModel, Cmd BackendMsg )
handleGotRizeCategoryList _ result model =
    let
        updatedDatasources =
            MDatasource.handleCategoryResult model.rizeDatasource result

        resultCategoryDict =
            Result.map
                (\categories ->
                    categories
                        |> List.map (\category -> ( category.id, category ))
                        |> SDict.fromList
                )
                result

        modelWithNewDatasources =
            { model | rizeDatasource = updatedDatasources }

        modelWithNewCategories =
            Result.map
                (updateModelWithNewRizeCategories modelWithNewDatasources)
                resultCategoryDict
    in
    case modelWithNewCategories of
        Err _ ->
            updateModelAndSendToFrontend modelWithNewDatasources

        Ok updatedModel ->
            updateModelAndSendToFrontend updatedModel


updateModelWithNewRizeCategories : BackendModel -> SDict.SDict RizeCategoryId RizeCategory -> BackendModel
updateModelWithNewRizeCategories model categories =
    { model | rizeCategories = categories }


handleRizeEntriesResult : RizeHabitCalendarId -> BackendModel -> Result Http.Error (List RizeEntry) -> ( BackendModel, Cmd BackendMsg )
handleRizeEntriesResult calendarId model networkResult =
    let
        existingHabitCalendar =
            habitCalendarForId model.habitCalendars (RizeHC calendarId)

        newSpecifics =
            existingHabitCalendar
                |> Result.andThen (updateRizeCalendarFromEntryNetworkResult networkResult)

        updatedHabitCalendar =
            Result.map2
                (\hc specifics -> { hc | specifics = RizeHabitCalendar specifics, networkStatus = Success })
                existingHabitCalendar
                newSpecifics

        newModel =
            Result.map (updateModelWithHabitCalendar model) updatedHabitCalendar
    in
    case newModel of
        Err err ->
            ( model, broadcast (ReportError err) )

        Ok updatedModel ->
            ( updatedModel, sendNewStateToFrontend updatedModel )


updateModelWithHabitCalendar : BackendModel -> HabitCalendar -> BackendModel
updateModelWithHabitCalendar model calendar =
    { model | habitCalendars = Dict.insert (getStringIdForHabitCalendar calendar) calendar model.habitCalendars }


updateRizeCalendarFromEntryNetworkResult : Result Http.Error (List RizeEntry) -> HabitCalendar -> Result BackendError RizeHabitCalendarSpecifics
updateRizeCalendarFromEntryNetworkResult networkResult calendar =
    Result.map2 updateRizeCalendarWithEntries
        (getRizeCalendarFromCalendar calendar)
        (Result.mapError HttpFailure networkResult)


getRizeCalendarFromCalendar : HabitCalendar -> Result BackendError RizeHabitCalendarSpecifics
getRizeCalendarFromCalendar calendar =
    case calendar.specifics of
        RizeHabitCalendar rizeCalendar ->
            Ok rizeCalendar

        TogglHabitCalendar _ ->
            Err (BadDataShape "Tried to get Rize calendar from a Toggl calendar")


updateRizeCalendarWithEntries : RizeHabitCalendarSpecifics -> List RizeEntry -> RizeHabitCalendarSpecifics
updateRizeCalendarWithEntries calendar entries =
    let
        newEntryDict =
            entries
                |> List.map (\entry -> ( Time.posixToMillis entry.start, entry ))
                |> Dict.fromList
    in
    { calendar | entries = Dict.union newEntryDict calendar.entries }


handleTogglEntriesResult : TogglHabitCalendarId -> BackendModel -> Result Http.Error (List TogglEntryResult) -> Time.Posix -> Time.Posix -> ( BackendModel, Cmd BackendMsg )
handleTogglEntriesResult habitCalendarId model result queryStartTime queryEndTime =
    let
        maybeHabitCalendar =
            Dict.get (Id.to habitCalendarId) model.habitCalendars
    in
    case maybeHabitCalendar of
        Nothing ->
            -- PROBLEM: no habit calendar found for ID. Alert client of error, send to firebase as well.
            ( model, broadcast (ReportError (BadDataShape ("Received entries for missing calendar with id " ++ Id.to habitCalendarId))) )

        Just habitCalendar ->
            case result of
                Err err ->
                    let
                        updatedHabitCalendar =
                            { habitCalendar | networkStatus = Error err }
                    in
                    ( { model
                        | habitCalendars =
                            Dict.insert
                                (Id.to habitCalendarId)
                                updatedHabitCalendar
                                model.habitCalendars
                      }
                    , sendNewStateToFrontend model
                    )

                -- todo: bring back paging from metadata (if we end up with more than 1000 entries, which is possible)
                Ok entryResults ->
                    let
                        entries : IDict.IDict TogglEntryId TogglEntry
                        entries =
                            entryResults
                                |> flatMap (\entryResult -> entryResult.timeEntries)
                                |> List.map (\entry -> ( entry.id, entry ))
                                |> IDict.fromList

                        updatedHabitCalendar =
                            { habitCalendar | networkStatus = Success }
                                |> updateHabitCalendarTogglEntriesWipingBetweenTime queryStartTime queryEndTime entries

                        newModel =
                            { model
                                | habitCalendars =
                                    Dict.insert
                                        (Id.to habitCalendarId)
                                        updatedHabitCalendar
                                        model.habitCalendars
                            }
                    in
                    ( newModel, Cmd.batch [ sendNewStateToFrontend newModel ] )


getRunningEntry : BackendModel -> ( BackendModel, Cmd BackendMsg )
getRunningEntry model =
    case model.togglDatasource.credentialsId of
        Submitted credentialsId credsState ->
            case credsState of
                Connected ->
                    case MDatasource.generateCmdsToQueryRunningEntry model.togglDatasource model.datasourceCredentials (extractNow model) of
                        Ok cmds ->
                            ( model, cmds )

                        Err erroredDatasource ->
                            ( { model | runningEntry = TogglNotConnected, togglDatasource = erroredDatasource }, Cmd.none )

                _ ->
                    ( { model | runningEntry = TogglNotConnected }, Cmd.none )

        NotSubmitted ->
            ( { model | runningEntry = TogglNotConnected }, Cmd.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend _ _ msg model =
    case msg of
        NoOpToBackend ->
            ( model, Cmd.none )

        FrontendWantsUpdate ->
            fetchAllHabitCalendarData model

        UpdateHabitCalendar source ->
            let
                newHabitCalendars =
                    Dict.insert (getStringIdForHabitCalendar source) source model.habitCalendars

                newModel =
                    { model | habitCalendars = newHabitCalendars }
            in
            fetchAllHabitCalendarData newModel

        UpdateRizeDatasourceCredentials rizeDatasourceId datasourceCredentials ->
            let
                -- Remove the old credentials if they exist
                maybeCredentialIdToRemove : Maybe RizeDatasourceCredentialsId
                maybeCredentialIdToRemove =
                    MDatasource.getRizeCredentialsId model.rizeDatasource

                prunedCredentials =
                    case maybeCredentialIdToRemove of
                        Nothing ->
                            model.datasourceCredentials

                        Just credentialIdToRemove ->
                            Dict.remove (Id.to credentialIdToRemove) model.datasourceCredentials

                newDatasourceCredentialsDict : Dict String DatasourceCredentials
                newDatasourceCredentialsDict =
                    Dict.insert (Id.to datasourceCredentials.id)
                        (RizeDatasourceCredentials datasourceCredentials)
                        prunedCredentials
            in
            ( { model
                | datasourceCredentials = newDatasourceCredentialsDict
                , rizeDatasource = MDatasource.addNewCredentialsToRizeDatasource model.rizeDatasource datasourceCredentials.id
              }
            , MDatasource.queryRizeCategories rizeDatasourceId datasourceCredentials
            )

        UpdateTogglDatasourceCredentials datasourceId datasourceCredentials ->
            let
                -- Remove the old credentials if they exist
                maybeCredentialIdToRemove : Maybe TogglDatasourceCredentialsId
                maybeCredentialIdToRemove =
                    MDatasource.getTogglCredentialsId model.togglDatasource

                prunedCredentials =
                    case maybeCredentialIdToRemove of
                        Nothing ->
                            model.datasourceCredentials

                        Just credentialIdToRemove ->
                            Dict.remove (Id.to credentialIdToRemove) model.datasourceCredentials

                newDatasourceCredentialsDict : Dict String DatasourceCredentials
                newDatasourceCredentialsDict =
                    Dict.insert (Id.to datasourceCredentials.id)
                        (TogglDatasourceCredentials datasourceCredentials)
                        prunedCredentials
            in
            ( { model
                | datasourceCredentials = newDatasourceCredentialsDict
                , togglDatasource = MDatasource.addNewCredentialsToTogglDatasource model.togglDatasource datasourceCredentials.id
              }
            , MDatasource.queryTogglWorkspaces model.togglDatasource.id datasourceCredentials
            )

        TellBackendToDeleteHabitCalendar habitCalendarId ->
            let
                newModel =
                    { model | habitCalendars = Dict.remove (habitCalendarIdToString habitCalendarId) model.habitCalendars }
            in
            ( newModel, sendNewStateToFrontend newModel )


fetchAllHabitCalendarData : BackendModel -> ( BackendModel, Cmd BackendMsg )
fetchAllHabitCalendarData model =
    let
        ( togglModel, togglCmds ) =
            fetchTogglHabitCalendars model

        ( rizeModel, rizeCmds ) =
            fetchRizeHabitCalendars togglModel
    in
    ( rizeModel, Cmd.batch [ rizeCmds, togglCmds ] )


fetchTogglHabitCalendars : BackendModel -> ( BackendModel, Cmd BackendMsg )
fetchTogglHabitCalendars model =
    let
        result =
            model.habitCalendars
                |> Dict.values
                |> List.filterMap
                    (\calendar ->
                        case calendar.specifics of
                            RizeHabitCalendar _ ->
                                Nothing

                            TogglHabitCalendar togglCalendarSpecifics ->
                                Just togglCalendarSpecifics
                    )
                |> MDatasource.generateCmdsToUpdateTogglHabitCalendars model.togglDatasource model.datasourceCredentials { zone = model.zone, posix = model.now }
    in
    case result of
        Err erroredDatasource ->
            updateModelAndSendToFrontend { model | togglDatasource = erroredDatasource }

        Ok cmd ->
            ( model, cmd )


fetchRizeHabitCalendars : BackendModel -> ( BackendModel, Cmd BackendMsg )
fetchRizeHabitCalendars model =
    let
        result =
            model.habitCalendars
                |> Dict.values
                |> List.filterMap
                    (\calendar ->
                        case calendar.specifics of
                            RizeHabitCalendar rizeCalendarSpecifics ->
                                Just rizeCalendarSpecifics

                            TogglHabitCalendar _ ->
                                Nothing
                    )
                |> MDatasource.generateCmdsToUpdateRizeHabitCalendars
                    model.rizeDatasource
                    model.datasourceCredentials
                    { zone = model.zone, posix = model.now }
    in
    case result of
        Err erroredDatasource ->
            updateModelAndSendToFrontend { model | rizeDatasource = erroredDatasource }

        Ok cmd ->
            ( model, cmd )


findHabitCalendarFromEntry : BackendModel -> TogglEntry -> Maybe HabitCalendar
findHabitCalendarFromEntry model entry =
    model.habitCalendars
        |> Dict.values
        |> List.filter (togglEntryMatchesHabitCalendar entry)
        |> List.head


updateHabitCalendarFromWebhookEvent : TogglWebhookEvent -> HabitCalendar -> HabitCalendar
updateHabitCalendarFromWebhookEvent event calendar =
    case calendar.specifics of
        RizeHabitCalendar _ ->
            calendar

        TogglHabitCalendar togglCalendarSpecifics ->
            case String.toLower event.metadata.action of
                "created" ->
                    let
                        updatedEntries =
                            IDict.insert event.payload.id event.payload togglCalendarSpecifics.entries
                    in
                    updateHabitCalendarTogglEntries updatedEntries calendar

                "updated" ->
                    let
                        updatedEntries =
                            IDict.insert event.payload.id event.payload togglCalendarSpecifics.entries
                    in
                    updateHabitCalendarTogglEntries updatedEntries calendar

                "deleted" ->
                    let
                        updatedEntries =
                            IDict.remove event.payload.id togglCalendarSpecifics.entries
                    in
                    updateHabitCalendarTogglEntries updatedEntries calendar

                _ ->
                    calendar


findAndUpdateHabitCalendarFromWebhookEvent : BackendModel -> TogglWebhookEvent -> Maybe HabitCalendar
findAndUpdateHabitCalendarFromWebhookEvent model event =
    Maybe.map (updateHabitCalendarFromWebhookEvent event) (findHabitCalendarFromEntry model event.payload)


updateTogglHabitCalendarWithWebhookEvent : BackendModel -> TogglWebhookEvent -> ( BackendModel, Cmd BackendMsg )
updateTogglHabitCalendarWithWebhookEvent model event =
    let
        updatedCalendar =
            findAndUpdateHabitCalendarFromWebhookEvent model event
    in
    case updatedCalendar of
        Nothing ->
            ( model, Cmd.none )

        Just calendar ->
            let
                newCalendars =
                    Dict.insert (getStringIdForHabitCalendar calendar) calendar model.habitCalendars

                newModel =
                    { model | habitCalendars = newCalendars }
            in
            ( newModel, Cmd.batch [ sendNewStateToFrontend newModel ] )



--groupHabitCalendarsByDatasource : Dict String HabitCalendar -> Dict String (List HabitCalendar)
--groupHabitCalendarsByDatasource calendars =
--    List.foldl addHabitCalendarToDict Dict.empty (Dict.values calendars)
--
--
--addHabitCalendarToDict : HabitCalendar -> Dict String (List HabitCalendar) -> Dict String (List HabitCalendar)
--addHabitCalendarToDict calendar dict =
--    let
--        key =
--            case calendar.specifics of
--                RizeHabitCalendar _ ->
--                    "Rize"
--
--                TogglHabitCalendar _ ->
--                    "Toggl"
--    in
--    case Dict.get key dict of
--        Nothing ->
--            Dict.insert key [ calendar ] dict
--
--        Just calendars ->
--            Dict.insert key (calendar :: calendars) dict


sendNewStateToFrontend : BackendModel -> Cmd BackendMsg
sendNewStateToFrontend model =
    broadcast (BackendUpdated model.habitCalendars model.rizeDatasource model.togglDatasource model.togglProjects model.rizeCategories model.runningEntry)


updateModelAndSendToFrontend : BackendModel -> ( BackendModel, Cmd BackendMsg )
updateModelAndSendToFrontend model =
    ( model, sendNewStateToFrontend model )
