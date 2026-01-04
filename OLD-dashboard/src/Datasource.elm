module Datasource exposing
    ( addNewCredentialsToRizeDatasource
    , addNewCredentialsToTogglDatasource
    , chooseDatasourceModal
    , editDatasourceModal
    , generateCmdsToQueryRunningEntry
    , generateCmdsToUpdateRizeHabitCalendars
    , generateCmdsToUpdateTogglHabitCalendars
    , getRizeCredentialsId
    , getTogglCredentialsId
    , handleCategoryResult
    , handleWorkspacesResult
    , initialRizeDatasource
    , initialTogglDatasource
    , queryRizeCategories
    , queryRunningEntry
    , queryTogglProjects
    , queryTogglWorkspaces
    )

import Base64
import BaseUI exposing (genericModal)
import Config exposing (urlWithProxy)
import DataDecoders exposing (decodeRunningEntry, entryResultListDecoder, projectDecoder, rizeCategoryResponseDecoder, rizeEntryListDecoder, workspaceDecoder)
import DatasourceIds exposing (RizeDatasourceId(..), TogglDatasourceId(..))
import DateHelpers exposing (dictFormatter)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onSubmit)
import Http exposing (Error(..))
import IDict exposing (IDict)
import Id
import Json.Decode as D
import Json.Encode as E
import Time.Extra
import Types exposing (..)
import W.InputText



-- MARK: PUBLIC


initialTogglDatasource : TogglDatasource
initialTogglDatasource =
    { id = TogglDatasourceIdBrand "toggl"
    , name = "Toggl"
    , workspaces = IDict.empty
    , projects = IDict.empty
    , credentialsId = NotSubmitted
    }


initialRizeDatasource : RizeDatasource
initialRizeDatasource =
    { id = RizeDatasourceIdBrand "rize"
    , name = "Rize"
    , credentialsId = NotSubmitted
    }


{-| Returns the updated datasource and an abritrary workspace (todo: support multiple workspaces).
-}
handleWorkspacesResult : TogglDatasource -> Result Http.Error (List TogglWorkspace) -> ( TogglDatasource, Maybe TogglWorkspaceId )
handleWorkspacesResult datasource workspacesResult =
    let
        updatedDatasource =
            case workspacesResult of
                Ok workspaceList ->
                    { datasource
                        | workspaces =
                            IDict.fromList (List.map (\workspace -> ( workspace.id, workspace )) workspaceList)
                        , credentialsId = updateDatasourceCredentialsState datasource.credentialsId Connected
                    }

                Err error ->
                    { datasource
                        | credentialsId =
                            updateDatasourceCredentialsState
                                datasource.credentialsId
                                (httpErrorToDatasourceCredentialsError error)
                    }

        arbitraryWorkspaceId =
            case workspacesResult of
                Ok workspaceList ->
                    case workspaceList of
                        [] ->
                            Nothing

                        workspace :: _ ->
                            Just workspace.id

                Err _ ->
                    Nothing
    in
    ( updatedDatasource, arbitraryWorkspaceId )


handleCategoryResult : RizeDatasource -> Result Http.Error (List RizeCategory) -> RizeDatasource
handleCategoryResult datasource categoryResult =
    case categoryResult of
        Ok _ ->
            datasource

        Err error ->
            { datasource
                | credentialsId =
                    updateDatasourceCredentialsState
                        datasource.credentialsId
                        (httpErrorToDatasourceCredentialsError error)
            }


{-| TODO: We can just expose `pruneDatasourceCredentials` exposed instead of this
-}
getTogglCredentialsId : TogglDatasource -> Maybe TogglDatasourceCredentialsId
getTogglCredentialsId datasource =
    case datasource.credentialsId of
        Submitted id _ ->
            Just id

        NotSubmitted ->
            Nothing


getRizeCredentialsId : RizeDatasource -> Maybe RizeDatasourceCredentialsId
getRizeCredentialsId datasource =
    case datasource.credentialsId of
        Submitted id _ ->
            Just id

        NotSubmitted ->
            Nothing


addNewCredentialsToTogglDatasource : TogglDatasource -> TogglDatasourceCredentialsId -> TogglDatasource
addNewCredentialsToTogglDatasource datasource credentialsId =
    { datasource | credentialsId = Submitted credentialsId TestingConnection }


addNewCredentialsToRizeDatasource : RizeDatasource -> RizeDatasourceCredentialsId -> RizeDatasource
addNewCredentialsToRizeDatasource datasource credentialsId =
    { datasource | credentialsId = Submitted credentialsId TestingConnection }


queryTogglWorkspaces : TogglDatasourceId -> TogglDatasourceCredentialsData -> Cmd BackendMsg
queryTogglWorkspaces datasourceId credentialsData =
    workspaceDecoder
        |> D.list
        |> Http.expectJson (GotWorkspaceData datasourceId credentialsData)
        |> baseTogglGetRequest credentialsData.apiKey "https://api.track.toggl.com/api/v9/workspaces"


queryTogglProjects : TogglDatasourceCredentialsData -> Maybe TogglWorkspaceId -> Cmd BackendMsg
queryTogglProjects credentialsData maybeWorkspaceId =
    case maybeWorkspaceId of
        Nothing ->
            Cmd.none

        Just workspaceId ->
            let
                workspaceIdStr =
                    workspaceId
                        |> Id.to
                        |> String.fromInt

                url =
                    "https://api.track.toggl.com/api/v9/workspaces/" ++ workspaceIdStr ++ "/projects"
            in
            projectDecoder
                |> D.list
                |> Http.expectJson (GotProjectsData workspaceId)
                |> baseTogglGetRequest credentialsData.apiKey url


queryRizeCategories : RizeDatasourceId -> RizeDatasourceCredentialsData -> Cmd BackendMsg
queryRizeCategories datasourceId credentialsData =
    rizeCategoryResponseDecoder
        |> Http.expectJson (GotRizeCategoriesData datasourceId)
        |> baseRizeRequest credentialsData rizeCategoryQuery


generateCmdsToQueryRunningEntry : TogglDatasource -> Dict String DatasourceCredentials -> PointInTime -> Result TogglDatasource (Cmd BackendMsg)
generateCmdsToQueryRunningEntry datasource creds now =
    getTogglCredentials datasource creds
        |> Result.map queryRunningEntry


{-| If there was an error, Result will be `Err togglDatasourceMarkedAsFailed`
-}
generateCmdsToUpdateTogglHabitCalendars : TogglDatasource -> Dict String DatasourceCredentials -> PointInTime -> List TogglHabitCalendarSpecifics -> Result TogglDatasource (Cmd BackendMsg)
generateCmdsToUpdateTogglHabitCalendars datasource creds now calendars =
    getTogglCredentials datasource creds
        |> Result.map
            (\credsData ->
                Cmd.batch (List.map (generateCmdToUpdateTogglHabitCalendar credsData now) calendars)
            )


getTogglCredentials : TogglDatasource -> Dict String DatasourceCredentials -> Result TogglDatasource TogglDatasourceCredentialsData
getTogglCredentials datasource creds =
    case getTogglCredentialsId datasource of
        Nothing ->
            Err { datasource | credentialsId = NotSubmitted }

        Just credsId ->
            getTogglCredentialsById creds credsId
                |> Result.mapError
                    (\error ->
                        { datasource
                            | credentialsId =
                                updateDatasourceCredentialsState datasource.credentialsId error
                        }
                    )


generateCmdsToUpdateRizeHabitCalendars : RizeDatasource -> Dict String DatasourceCredentials -> PointInTime -> List RizeHabitCalendarSpecifics -> Result RizeDatasource (Cmd BackendMsg)
generateCmdsToUpdateRizeHabitCalendars datasource creds now calendars =
    case getRizeCredentialsId datasource of
        Nothing ->
            Err { datasource | credentialsId = NotSubmitted }

        Just credsId ->
            case getRizeCredentialsById creds credsId of
                Err error ->
                    Err { datasource | credentialsId = updateDatasourceCredentialsState datasource.credentialsId error }

                Ok credsData ->
                    Ok (Cmd.batch (List.map (generateCmdToUpdateRizeHabitCalendar credsData now) calendars))



-- MARK: Public UI


chooseDatasourceModal : FrontendModel -> Html.Html FrontendMsg
chooseDatasourceModal model =
    let
        anyConnectedDatasource =
            [ hasConnectedCredentials model.togglDatasource
            , hasConnectedCredentials model.rizeDatasource
            ]
                |> List.any identity
    in
    if not anyConnectedDatasource then
        div []
            [ text "No datasources."
            , button [ class "btn btn-primary", onClick (SetModalState (DatasourceModal ListDatasources)) ]
                [ text "Add one?" ]
            ]

    else
        div []
            [ createHabitCalendarFromTogglDatasourceButton model.togglDatasource
            , createHabitCalendarFromRizeDatasourceButton model.rizeDatasource
            ]


editDatasourceModal : FrontendModel -> DatasourceModalState -> Html.Html FrontendMsg
editDatasourceModal model modalState =
    case modalState of
        ListDatasources ->
            genericModal "Datasources" (datasourceList model)

        EditTogglDatasourceCredentials datasourceId credentialsId ->
            genericModal "Add API Key"
                (togglDatasourceCredentialsEditor model datasourceId credentialsId)

        EditRizeDatasourceCredentials datasourceId credentialsId ->
            genericModal "Add Credential Information"
                (rizeDatasourceCredentialsEditor model datasourceId credentialsId)

        LoadingDatasourceCredentials ->
            genericModal "Add Credentials" (text "Loading...")



-- MARK: PRIVATE


datasourceName : { a | name : String } -> String
datasourceName datasource =
    datasource.name


baseTogglGetRequest : String -> String -> Http.Expect BackendMsg -> Cmd BackendMsg
baseTogglGetRequest apiKey url expectation =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Authorization"
                ("Basic " ++ Base64.encode (apiKey ++ ":" ++ "api_token"))
            ]
        , url = urlWithProxy url
        , expect = expectation
        , body = Http.emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


baseTogglPostRequest : String -> String -> E.Value -> Http.Expect BackendMsg -> Cmd BackendMsg
baseTogglPostRequest apiKey url body expectation =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization"
                ("Basic " ++ Base64.encode (apiKey ++ ":" ++ "api_token"))
            , Http.header "Access-Control-Request-Headers" "X-Next-Row-Number"
            ]
        , url = urlWithProxy url
        , expect = expectation
        , body = Http.jsonBody body
        , timeout = Nothing
        , tracker = Nothing
        }


baseRizeRequest : RizeDatasourceCredentialsData -> E.Value -> Http.Expect BackendMsg -> Cmd BackendMsg
baseRizeRequest credentialsData graphQLBody expectation =
    Http.request
        { method = "POST"
        , url = urlWithProxy "https://api.rize.io/v1/graphql"
        , body = Http.jsonBody graphQLBody
        , headers =
            [ Http.header "access-token" credentialsData.accessToken
            , Http.header "client" credentialsData.clientId
            , Http.header "uid" credentialsData.uid
            ]
        , expect = expectation
        , timeout = Just 60000
        , tracker = Nothing
        }


rizeCategoryQuery : E.Value
rizeCategoryQuery =
    E.object
        [ ( "query", E.string "{ categoryModels { id name key } }" )
        ]


queryRunningEntry : TogglDatasourceCredentialsData -> Cmd BackendMsg
queryRunningEntry credentialsData =
    decodeRunningEntry
        |> Http.expectJson GotRunningEntry
        |> baseTogglGetRequest credentialsData.apiKey "https://api.track.toggl.com/api/v9/me/time_entries/current"


httpErrorToDatasourceCredentialsError : Http.Error -> SubmittedDatasourceCredentialsState
httpErrorToDatasourceCredentialsError error =
    case error of
        Http.BadUrl url ->
            UnrecoverableError (NotFound ("Bad URL: " ++ url))

        Http.Timeout ->
            RecoverableError (RecoverableNetworkError "Request timed out")

        Http.NetworkError ->
            -- I've seen "Network Error" come down from bad data. You would think it would be an error for bad internet,
            -- but that doesn't always seem to be the case. So, careful with this one.
            RecoverableError (RecoverableNetworkError "Network error. Check internet connection and CORS.")

        Http.BadStatus statusCode ->
            case statusCode of
                429 ->
                    RecoverableError RateLimited

                401 ->
                    UnrecoverableError InvalidCredentials

                403 ->
                    UnrecoverableError InvalidCredentials

                _ ->
                    if statusCode >= 500 then
                        -- Note this might be unrecoverable if WE'RE crashing the server with bad input.
                        RecoverableError (ServerError statusCode)

                    else
                        UnrecoverableError (BadHttpStatus statusCode)

        Http.BadBody body ->
            UnrecoverableError (BadHttpBody body)


updateDatasourceCredentialsState : DatasourceCredentialsState id -> SubmittedDatasourceCredentialsState -> DatasourceCredentialsState id
updateDatasourceCredentialsState credentialsState state =
    case credentialsState of
        -- It should be very hard to get here, but not impossible. The user would need multiple tabs open
        -- and a slow network connection.
        NotSubmitted ->
            NotSubmitted

        Submitted id _ ->
            Submitted id state


getTogglCredentialsById : Dict String DatasourceCredentials -> TogglDatasourceCredentialsId -> Result SubmittedDatasourceCredentialsState TogglDatasourceCredentialsData
getTogglCredentialsById dict key =
    Dict.get (Id.to key) dict
        |> Result.fromMaybe (UnrecoverableError (BadAppDataShape ("Couldn't find credentials for ID " ++ Id.to key)))
        |> Result.andThen
            (\credentials ->
                case credentials of
                    TogglDatasourceCredentials creds ->
                        Ok creds

                    _ ->
                        Err (UnrecoverableError (BadAppDataShape "Tried to get Toggl credentials from a non-Toggl datasource"))
            )


getRizeCredentialsById : Dict String DatasourceCredentials -> RizeDatasourceCredentialsId -> Result SubmittedDatasourceCredentialsState RizeDatasourceCredentialsData
getRizeCredentialsById dict key =
    Dict.get (Id.to key) dict
        |> Result.fromMaybe (UnrecoverableError (BadAppDataShape ("Couldn't find credentials for ID " ++ Id.to key)))
        |> Result.andThen
            (\credentials ->
                case credentials of
                    RizeDatasourceCredentials creds ->
                        Ok creds

                    _ ->
                        Err (UnrecoverableError (BadAppDataShape "Tried to get Rize credentials from a non-Rize datasource"))
            )


generateCmdToUpdateTogglHabitCalendar : TogglDatasourceCredentialsData -> PointInTime -> TogglHabitCalendarSpecifics -> Cmd BackendMsg
generateCmdToUpdateTogglHabitCalendar credsData now calendar =
    let
        url =
            "https://api.track.toggl.com/reports/api/v3/workspace/"
                ++ String.fromInt (Id.to calendar.workspaceId)
                ++ "/search/time_entries"

        tomorrow =
            Time.Extra.add Time.Extra.Day 1 now.zone now.posix

        tomorrowString =
            tomorrow
                |> PointInTime now.zone
                |> dictFormatter

        twoMonthsAgo =
            Time.Extra.add Time.Extra.Month -2 now.zone now.posix

        twoMonthsAgoString =
            twoMonthsAgo
                |> PointInTime now.zone
                |> dictFormatter

        projectIdEntry =
            case calendar.togglProjectId of
                Nothing ->
                    []

                Just projectIdInt ->
                    [ ( "project_ids", E.list E.int [ Id.to projectIdInt ] ) ]

        body =
            E.object
                ([ ( "start_date", E.string twoMonthsAgoString )
                 , ( "end_date", E.string tomorrowString )
                 , ( "description", E.string calendar.descriptionMatchString )
                 , ( "page_size", E.int 1000 )
                 ]
                    ++ projectIdEntry
                )
    in
    baseTogglPostRequest
        credsData.apiKey
        url
        body
        (Http.expectJson (GotTogglEntries calendar.id twoMonthsAgo tomorrow) entryResultListDecoder)


generateCmdToUpdateRizeHabitCalendar : RizeDatasourceCredentialsData -> PointInTime -> RizeHabitCalendarSpecifics -> Cmd BackendMsg
generateCmdToUpdateRizeHabitCalendar credsData now calendar =
    let
        tomorrow =
            Time.Extra.add Time.Extra.Day 1 now.zone now.posix

        tomorrowString =
            tomorrow
                |> PointInTime now.zone
                |> dictFormatter

        twoMonthsAgo =
            Time.Extra.add Time.Extra.Month -2 now.zone now.posix

        twoMonthsAgoString =
            twoMonthsAgo
                |> PointInTime now.zone
                |> dictFormatter

        body =
            E.object
                [ ( "query", E.string rizeGraphQlQuery )
                , ( "variables"
                  , E.object
                        [ ( "startTime", E.string twoMonthsAgoString )
                        , ( "endTime", E.string tomorrowString )
                        , ( "bucketSize", E.string "DAY" )
                        , ( "categories", E.list E.string [ calendar.categoryKey ] )
                        , ( "trackingRuleHostKeys", E.list E.string [] )
                        ]
                  )
                ]
    in
    baseRizeRequest credsData body (Http.expectJson (GotRizeEntries calendar.id) rizeEntryListDecoder)


rizeGraphQlQuery =
    """
query TrackedTimeHistogram($startTime: ISO8601DateTime!, $endTime: ISO8601DateTime!, $bucketSize: String!, $categories: [String!], $trackingRuleHostKeys: [String!]) {
  trackedTimeHistogram(
    startTime: $startTime
    endTime: $endTime
    bucketSize: $bucketSize
    categories: $categories
    trackingRuleHostKeys: $trackingRuleHostKeys
  ) {
    value
    startTime
    endTime
  }
}
"""



-- MARK: PRIVATE UI


rizeDatasourceCredentialsEditor : FrontendModel -> RizeDatasourceId -> RizeDatasourceCredentialsId -> Html.Html FrontendMsg
rizeDatasourceCredentialsEditor model datasourceId credentialsId =
    case Dict.get (Id.to credentialsId) model.pendingDatasourceCredentials of
        Nothing ->
            text ("Something went horribly wrong. No datasource credentials with id " ++ Id.to credentialsId ++ " found.")

        Just credentials ->
            case credentials of
                TogglDatasourceCredentials _ ->
                    text
                        ("Found Toggl Credentials for Rize Datasource. Bad credentials ID: "
                            ++ Id.to credentialsId
                        )

                RizeDatasourceCredentials rizeCreds ->
                    Html.form
                        [ onSubmit (SubmitPendingRizeDatasourceCredentials datasourceId rizeCreds) ]
                        (formEntriesForRizeDatasourceCredentials
                            rizeCreds
                            ++ [ button [ type_ "submit", class "btn btn-primary" ] [ text "Save" ] ]
                        )


togglDatasourceCredentialsEditor : FrontendModel -> TogglDatasourceId -> TogglDatasourceCredentialsId -> Html.Html FrontendMsg
togglDatasourceCredentialsEditor model datasourceId credentialsId =
    case Dict.get (Id.to credentialsId) model.pendingDatasourceCredentials of
        Nothing ->
            text ("Something went horribly wrong. No datasource credentials with id " ++ Id.to credentialsId ++ " found.")

        Just credentials ->
            case credentials of
                RizeDatasourceCredentials _ ->
                    text
                        ("Found Rize Credentials for Toggl Datasource. Bad credentials ID: "
                            ++ Id.to credentialsId
                        )

                TogglDatasourceCredentials togglCreds ->
                    Html.form
                        [ onSubmit (SubmitPendingTogglDatasourceCredentials datasourceId togglCreds) ]
                        (formEntriesForTogglDatasourceCredentials
                            togglCreds
                            ++ [ button [ type_ "submit", class "btn btn-primary" ] [ text "Save" ] ]
                        )


formEntriesForTogglDatasourceCredentials : TogglDatasourceCredentialsData -> List (Html.Html FrontendMsg)
formEntriesForTogglDatasourceCredentials credentials =
    [ label [ class "text-black" ]
        [ text "API Key"
        , W.InputText.view [ W.InputText.password, W.InputText.placeholder "Enter your API Key" ]
            { onInput = \s -> ModifyPendingDatasourceCredentials (TogglDatasourceCredentials { credentials | apiKey = s })
            , value = credentials.apiKey
            }
        ]
    ]


formEntriesForRizeDatasourceCredentials : RizeDatasourceCredentialsData -> List (Html.Html FrontendMsg)
formEntriesForRizeDatasourceCredentials credentials =
    -- Access Token, client Id, and UID
    [ label [ class "text-black" ]
        [ text "Access Token"
        , W.InputText.view [ W.InputText.placeholder "Enter your access token" ]
            { onInput = \s -> ModifyPendingDatasourceCredentials (RizeDatasourceCredentials { credentials | accessToken = s })
            , value = credentials.accessToken
            }
        ]
    , label [ class "text-black" ]
        [ text "Client ID"
        , W.InputText.view [ W.InputText.placeholder "Enter your Client ID" ]
            { onInput = \s -> ModifyPendingDatasourceCredentials (RizeDatasourceCredentials { credentials | clientId = s })
            , value = credentials.clientId
            }
        ]
    , label [ class "text-black" ]
        [ text "UID"
        , W.InputText.view [ W.InputText.placeholder "Enter your UID" ]
            { onInput = \s -> ModifyPendingDatasourceCredentials (RizeDatasourceCredentials { credentials | uid = s })
            , value = credentials.uid
            }
        ]
    ]


datasourceList : FrontendModel -> Html.Html FrontendMsg
datasourceList model =
    div []
        [ togglDatasourceButton model.togglDatasource, rizeDatasourceButton model.rizeDatasource ]


hasConnectedCredentials : { credentialsHaver | credentialsId : DatasourceCredentialsState foo } -> Bool
hasConnectedCredentials source =
    case source.credentialsId of
        NotSubmitted ->
            False

        Submitted _ state ->
            case state of
                Connected ->
                    True

                _ ->
                    False


createHabitCalendarFromTogglDatasourceButton : TogglDatasource -> Html.Html FrontendMsg
createHabitCalendarFromTogglDatasourceButton source =
    div []
        [ text (datasourceName source)
        , button
            [ class "btn btn-primary"
            , onClick
                (CreateAndStartEditingTogglHabitCalendar
                    source.id
                )
            ]
            [ text "Add Habit" ]
        ]


createHabitCalendarFromRizeDatasourceButton : RizeDatasource -> Html.Html FrontendMsg
createHabitCalendarFromRizeDatasourceButton source =
    div []
        [ text (datasourceName source)
        , button
            [ class "btn btn-primary"
            , onClick
                (CreateAndStartEditingRizeHabitCalendar
                    source.id
                )
            ]
            [ text "Add Habit" ]
        ]


togglDatasourceButton : TogglDatasource -> Html.Html FrontendMsg
togglDatasourceButton datasource =
    div []
        [ text "Toggl"
        , button
            [ class "btn btn-primary"
            , onClick (CreateAndStartEditingTogglDatasourceCredentials datasource.id)
            ]
            [ text (buttonTextForCredentialsState datasource.credentialsId) ]
        ]


rizeDatasourceButton : RizeDatasource -> Html.Html FrontendMsg
rizeDatasourceButton datasource =
    div []
        [ text "Rize"
        , button
            [ class "btn btn-primary"
            , onClick (CreateAndStartEditingRizeDatasourceCredentials datasource.id)
            ]
            [ text (buttonTextForCredentialsState datasource.credentialsId)
            , text (detailTextForCredentialsState datasource.credentialsId)
            ]
        ]


buttonTextForCredentialsState : DatasourceCredentialsState foo -> String
buttonTextForCredentialsState state =
    case state of
        NotSubmitted ->
            "Connect"

        Submitted _ submittedState ->
            case submittedState of
                TestingConnection ->
                    "Testing Connection..."

                Connected ->
                    "Reconnect"

                RecoverableError recoverableErrorDetail ->
                    "Reconnect"

                UnrecoverableError unrecoverableErrorDetail ->
                    "Reconnect"


detailTextForCredentialsState : DatasourceCredentialsState foo -> String
detailTextForCredentialsState state =
    case state of
        NotSubmitted ->
            ""

        Submitted _ submittedDatasourceCredentialsState ->
            case submittedDatasourceCredentialsState of
                Connected ->
                    "Connected!"

                TestingConnection ->
                    ""

                RecoverableError recoverableErrorDetail ->
                    case recoverableErrorDetail of
                        RateLimited ->
                            "Rate limited"

                        ServerError statusCode ->
                            "Server error " ++ String.fromInt statusCode

                        RecoverableNetworkError networkErrorDetail ->
                            "Network error: " ++ networkErrorDetail

                UnrecoverableError unrecoverableErrorDetail ->
                    case unrecoverableErrorDetail of
                        BadAppDataShape message ->
                            "Bad app data shape: " ++ message

                        BadHttpStatus statusCode ->
                            "Bad HTTP status: " ++ String.fromInt statusCode

                        BadHttpBody body ->
                            "Bad HTTP body: " ++ body

                        InvalidCredentials ->
                            "Invalid credentials"

                        NotFound message ->
                            "Not found: " ++ message
