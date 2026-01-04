module Frontend exposing (..)

import Base64
import BaseUI exposing (genericModal)
import Browser exposing (UrlRequest(..))
import Browser.Events exposing (onKeyDown)
import Browser.Navigation as Nav
import Color exposing (Color)
import Color.Manipulate
import DataDecoders exposing (decodeHabitCalendarDict, exportedHabitCalendars)
import Datasource as MDatasource exposing (chooseDatasourceModal, editDatasourceModal)
import DateHelpers exposing (compareDays, formatMonthDay, mondaysAgo, relativeTimer, sameDay)
import Dict
import Html exposing (..)
import Html.Attributes exposing (class, download, href, rel, style, type_)
import Html.Events exposing (onClick, onSubmit)
import Html.Lazy
import IDict
import Id
import Json.Decode as Decode
import Lamdera exposing (sendToBackend)
import Random
import SDict
import Shared exposing (getDatasourceCredentialsIdFromDatasourceCredentials, getDatasourceCredentialsIdStringFromDatasourceCredentials, getIdForHabitCalendar, getStringIdForHabitCalendar, habitCalendarIdToString, maybe2, secondsForTogglEntry, stringifyBackendError, stringifyHttpError, togglEntryMatchesHabitCalendar)
import String
import Task
import Time exposing (Posix, Weekday(..), Zone)
import Time.Extra
import Types exposing (..)
import UUID
import Url
import W.Button
import W.InputColor
import W.InputInt exposing (toInt)
import W.InputText
import W.Styles


type alias Model =
    FrontendModel


app =
    Lamdera.frontend
        { init = init
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , update = update
        , updateFromBackend = updateFromBackend
        , subscriptions = subscriptions
        , view = view
        }


subscriptions _ =
    Sub.batch
        [ Time.every 1000 FetchCurrentTime
        , onKeyDown keyDecoder
        ]


keyDecoder : Decode.Decoder FrontendMsg
keyDecoder =
    Decode.map toKey (Decode.field "key" Decode.string)


toKey : String -> FrontendMsg
toKey str =
    case str of
        "Escape" ->
            SetModalState Closed

        _ ->
            NoOpFrontendMsg


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init _ key =
    ( { key = key
      , currentTime = Nothing
      , currentZone = Nothing
      , habitCalendars = Dict.empty
      , modalState = Closed
      , debugRequests = []
      , runningEntry = TogglNotConnected
      , error = Nothing
      , togglDatasource = MDatasource.initialTogglDatasource
      , rizeDatasource = MDatasource.initialRizeDatasource
      , togglProjects = IDict.empty
      , rizeCategories = SDict.empty
      , pendingDatasourceCredentials = Dict.empty
      , allEntries = Dict.empty
      , togglProjectSearchString = ""
      }
    , Cmd.batch
        [ Task.perform FetchCurrentTime Time.now
        , Task.perform
            FetchCurrentZone
            Time.here
        ]
    )


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Nav.load url
                    )

        UrlChanged _ ->
            ( model, Cmd.none )

        NoOpFrontendMsg ->
            ( model, Cmd.none )

        FetchCurrentTime result ->
            ( { model | currentTime = Just result }, Cmd.none )

        FetchCurrentZone zone ->
            ( { model | currentZone = Just zone }, Cmd.none )

        FetchTimeEntries ->
            ( model, sendToBackend FrontendWantsUpdate )

        SubmitHabitCalendar calendar ->
            ( { model
                | habitCalendars = Dict.insert (getStringIdForHabitCalendar calendar) calendar model.habitCalendars
                , modalState = Closed
              }
            , sendToBackend (UpdateHabitCalendar calendar)
            )

        ModifyPendingDatasourceCredentials credentials ->
            ( { model
                | pendingDatasourceCredentials =
                    Dict.insert
                        (getDatasourceCredentialsIdStringFromDatasourceCredentials credentials)
                        credentials
                        model.pendingDatasourceCredentials
              }
            , Cmd.none
            )

        SubmitPendingRizeDatasourceCredentials datasourceId credentials ->
            ( { model
                | pendingDatasourceCredentials =
                    Dict.remove
                        (Id.to credentials.id)
                        model.pendingDatasourceCredentials
                , modalState = DatasourceModal ListDatasources
              }
            , sendToBackend (UpdateRizeDatasourceCredentials datasourceId credentials)
            )

        SubmitPendingTogglDatasourceCredentials togglDatasourceId togglDatasourceCredentialsData ->
            ( { model
                | pendingDatasourceCredentials =
                    Dict.remove
                        (Id.to togglDatasourceCredentialsData.id)
                        model.pendingDatasourceCredentials
                , modalState = DatasourceModal ListDatasources
              }
            , sendToBackend (UpdateTogglDatasourceCredentials togglDatasourceId togglDatasourceCredentialsData)
            )

        CreateAndStartEditingRizeHabitCalendar rizeDatasourceId ->
            ( { model | modalState = EditCalendarModalOpen LoadingUUID }
            , Random.generate (GotRandomUUIDForNewRizeHabitCalendar rizeDatasourceId) UUID.generator
            )

        -- TODO: combine this with the above SubmitDatasource via Task.andThen
        CreateAndStartEditingTogglHabitCalendar datasourceId ->
            ( { model | modalState = EditCalendarModalOpen LoadingUUID }
            , Random.generate (GotRandomUUIDForNewTogglHabitCalendar datasourceId) UUID.generator
            )

        GotRandomUUIDForNewRizeHabitCalendar rizeDatasourceId uuid ->
            let
                specifics =
                    RizeHabitCalendar
                        { id = Id.from (UUID.toString uuid)
                        , categoryKey = ""
                        , datasourceId = rizeDatasourceId
                        , entries = Dict.empty
                        }

                habitCalendar =
                    { name = ""
                    , successColor = Color.darkGreen
                    , nonzeroColor = Color.lightGreen
                    , weeksShowing = 4
                    , networkStatus = Loading
                    , specifics = specifics
                    }
            in
            ( { model
                | modalState =
                    EditCalendarModalOpen
                        (GotUUID habitCalendar)
              }
            , Cmd.none
            )

        GotRandomUUIDForNewTogglHabitCalendar datasourceId uuid ->
            let
                specifics =
                    TogglHabitCalendar
                        { id = Id.from (UUID.toString uuid)
                        , datasourceId = datasourceId

                        -- TODO: Un-hardcode this.
                        , workspaceId = Id.from 4150145
                        , togglProjectId = Nothing
                        , descriptionMatchString = ""
                        , entries = IDict.empty
                        }

                habitCalendar =
                    { name = ""
                    , successColor = Color.darkGreen
                    , nonzeroColor = Color.lightGreen
                    , weeksShowing = 4
                    , networkStatus = Loading
                    , specifics = specifics
                    }
            in
            ( { model
                | modalState =
                    EditCalendarModalOpen
                        (GotUUID habitCalendar)
              }
            , Cmd.none
            )

        CreateAndStartEditingTogglDatasourceCredentials datasourceId ->
            ( { model | modalState = DatasourceModal LoadingDatasourceCredentials }
            , Random.generate (GotRandomUUIDForNewTogglDatasourceCredentials datasourceId) UUID.generator
            )

        CreateAndStartEditingRizeDatasourceCredentials datasourceId ->
            ( { model | modalState = DatasourceModal LoadingDatasourceCredentials }
            , Random.generate (GotRandomUUIDForNewRizeDatasourceCredentials datasourceId) UUID.generator
            )

        GotRandomUUIDForNewTogglDatasourceCredentials datasourceId uuid ->
            let
                newId =
                    Id.from (UUID.toString uuid)

                newCredentials =
                    TogglDatasourceCredentials
                        { id = newId
                        , apiKey = ""
                        }
            in
            ( { model
                | modalState = DatasourceModal (EditTogglDatasourceCredentials datasourceId newId)
                , pendingDatasourceCredentials =
                    Dict.insert (getDatasourceCredentialsIdStringFromDatasourceCredentials newCredentials)
                        newCredentials
                        model.pendingDatasourceCredentials
              }
            , Cmd.none
            )

        GotRandomUUIDForNewRizeDatasourceCredentials rizeDatasourceId uuid ->
            let
                newId =
                    Id.from (UUID.toString uuid)

                newCredentials =
                    RizeDatasourceCredentials
                        { id = newId
                        , accessToken = ""
                        , clientId = ""
                        , uid = ""
                        }
            in
            ( { model
                | modalState = DatasourceModal (EditRizeDatasourceCredentials rizeDatasourceId newId)
                , pendingDatasourceCredentials =
                    Dict.insert (getDatasourceCredentialsIdStringFromDatasourceCredentials newCredentials)
                        newCredentials
                        model.pendingDatasourceCredentials
              }
            , Cmd.none
            )

        SetModalState modalState ->
            ( { model | modalState = modalState }, Cmd.none )

        ModifyClientHabitCalendar newlyCreatedCalendarSource ->
            ( { model | modalState = EditCalendarModalOpen (GotUUID newlyCreatedCalendarSource) }, Cmd.none )

        SetTogglProjectSearchString string ->
            ( { model | togglProjectSearchString = string }, Cmd.none )

        DeleteHabitCalendar habitCalendarId ->
            ( { model
                | habitCalendars = Dict.remove (habitCalendarIdToString habitCalendarId) model.habitCalendars
                , modalState = Closed
              }
            , sendToBackend (TellBackendToDeleteHabitCalendar habitCalendarId)
            )

        SetImportDataString string ->
            ( { model | modalState = ImportingData string }, Cmd.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        BackendUpdated habitCalendars rizeDatasource togglDatasource togglProjects rizeCategories runningEntry ->
            ( { model
                | habitCalendars = habitCalendars
                , rizeDatasource = rizeDatasource
                , togglDatasource = togglDatasource
                , togglProjects = togglProjects
                , rizeCategories = rizeCategories
                , runningEntry = runningEntry
              }
            , Cmd.none
            )

        AddDebugRequest str ->
            ( { model | debugRequests = model.debugRequests ++ [ str ] }, Cmd.none )

        ReportError backendError ->
            ( { model | error = Just backendError }, Cmd.none )


view : Model -> Browser.Document FrontendMsg
view model =
    { title = "Hello Lamdera"
    , body =
        background model
    }


renderDebugStrings : List String -> Html FrontendMsg
renderDebugStrings strings =
    div [] (List.map (\str -> div [] [ text str ]) strings)


background : Model -> List (Html.Html FrontendMsg)
background model =
    [ Html.node "link" [ rel "stylesheet", href "/output.css" ] []
    , calendarsAndTimer model
    , renderDebugStrings model.debugRequests
    , W.Styles.globalStyles
    , W.Styles.baseTheme
    , modals model
    ]



-- MODALS STUFF


modals : FrontendModel -> Html.Html FrontendMsg
modals model =
    case model.modalState of
        Closed ->
            text ""

        DatasourceModal state ->
            editDatasourceModal model state

        ImportingData data ->
            genericModal "Import Data" (importDataModal model data)

        EditCalendarModalOpen editCalendarModalState ->
            case editCalendarModalState of
                ChoosingDatasource ->
                    genericModal "Which Datasource?" (chooseDatasourceModal model)

                LoadingUUID ->
                    text "Loading..."

                GotUUID newSource ->
                    genericModal "New Calendar" (editCalendarSourceModal model newSource)


importDataModal : FrontendModel -> String -> Html.Html FrontendMsg
importDataModal model dataImport =
    div []
        [ W.InputText.view []
            { onInput =
                \newImportValue -> SetImportDataString newImportValue
            , value = dataImport
            }
        , calendarImportButtons model dataImport
        ]


calendarImportButtons : FrontendModel -> String -> Html.Html FrontendMsg
calendarImportButtons model dataImport =
    let
        maybeCalendars =
            Decode.decodeString decodeHabitCalendarDict dataImport
    in
    case maybeCalendars of
        Ok calendars ->
            div []
                [ text "Here are the calendars to import:"
                , div []
                    (calendars
                        |> Dict.values
                        |> List.map
                            (\calendar ->
                                div []
                                    [ text (calendar.name ++ " (" ++ getStringIdForHabitCalendar calendar ++ ")")
                                    , importCalendarButton model calendar
                                    ]
                            )
                    )
                ]

        Err err ->
            div []
                [ text ("There's a problem with your data: " ++ Decode.errorToString err) ]


{-| We need to wire up the habit calendar to a datasource, because imported calendars don't have a datasource.
-}
importCalendarButton : FrontendModel -> HabitCalendar -> Html.Html FrontendMsg
importCalendarButton model calendar =
    case calendar.specifics of
        TogglHabitCalendar togglSpecifics ->
            let
                fixedSpecifics =
                    { togglSpecifics | datasourceId = model.togglDatasource.id }
            in
            button
                [ class "btn btn-primary"
                , onClick
                    (SubmitHabitCalendar
                        { calendar
                            | specifics = TogglHabitCalendar fixedSpecifics
                        }
                    )
                ]
                [ text "Import" ]

        RizeHabitCalendar rizeSpecifics ->
            let
                fixedSpecifics =
                    { rizeSpecifics | datasourceId = model.rizeDatasource.id }
            in
            button
                [ class "btn btn-primary"
                , onClick
                    (SubmitHabitCalendar
                        { calendar
                            | specifics = RizeHabitCalendar fixedSpecifics
                        }
                    )
                ]
                [ text "Import" ]


attemptSubmittingCalendarSource : HabitCalendar -> FrontendMsg
attemptSubmittingCalendarSource calendar =
    case calendar.specifics of
        TogglHabitCalendar togglData ->
            if togglData.descriptionMatchString == "" then
                -- TODO: Show error message
                NoOpFrontendMsg

            else
                SubmitHabitCalendar calendar

        RizeHabitCalendar _ ->
            SubmitHabitCalendar
                calendar


formEntriesForAllDatasources : HabitCalendar -> List (Html.Html FrontendMsg)
formEntriesForAllDatasources calendar =
    [ label [ class "text-black" ]
        [ text "Habit Name"
        , W.InputText.view []
            { onInput =
                \newName -> ModifyClientHabitCalendar { calendar | name = newName }
            , value = calendar.name
            }
        ]
    , label [ class "text-black flex items-center gap-2" ]
        [ text "Success Color"
        , W.InputColor.view []
            { onInput =
                \newColor -> ModifyClientHabitCalendar { calendar | successColor = newColor }
            , value = calendar.successColor
            }
        ]
    , label [ class "text-black flex items-center gap-2" ]
        [ text "Nonzero Color"
        , W.InputColor.view []
            { onInput =
                \newColor -> ModifyClientHabitCalendar { calendar | nonzeroColor = newColor }
            , value = calendar.nonzeroColor
            }
        ]
    , label [ class "text-black" ]
        [ text "Weeks Showing"
        , W.InputInt.view []
            { onInput =
                \i ->
                    case toInt i of
                        Nothing ->
                            NoOpFrontendMsg

                        Just num ->
                            ModifyClientHabitCalendar
                                { calendar | weeksShowing = num }
            , value = W.InputInt.init (Just calendar.weeksShowing)
            }
        ]
    ]


projectsFilteredBySearch : FrontendModel -> List TogglProject
projectsFilteredBySearch model =
    let
        searchString =
            model.togglProjectSearchString
                |> String.toLower
                |> String.trim
    in
    model.togglProjects
        |> IDict.values
        |> List.filter
            (\project ->
                String.contains searchString (String.toLower project.name)
            )


projectRow : HabitCalendar -> TogglHabitCalendarSpecifics -> TogglProject -> Html.Html FrontendMsg
projectRow habitCalendar togglSpecifics project =
    let
        buttonType =
            if togglSpecifics.togglProjectId == Just project.id then
                "btn-primary"

            else
                "btn-outline"

        newSpecifics =
            { togglSpecifics | togglProjectId = Just project.id }
    in
    button
        [ class ("btn btn-neutral btn-sm " ++ buttonType)
        , type_ "button"
        , onClick
            (ModifyClientHabitCalendar
                { habitCalendar
                    | specifics = TogglHabitCalendar newSpecifics
                    , successColor = project.color
                    , nonzeroColor = project.color |> Color.Manipulate.desaturate 0.5 |> Color.Manipulate.lighten 0.5
                }
            )
        ]
        [ text project.name ]


projectListDisplay : FrontendModel -> HabitCalendar -> TogglHabitCalendarSpecifics -> Html.Html FrontendMsg
projectListDisplay model habitCalendar togglSpecifics =
    div [ class "flex flex-col overflow-y-auto h-52 my-4 border-2 border-slate-300 rounded" ]
        (model
            |> projectsFilteredBySearch
            |> List.map (projectRow habitCalendar togglSpecifics)
        )


searchableProjectList : FrontendModel -> HabitCalendar -> Html.Html FrontendMsg
searchableProjectList model habitCalendar =
    case habitCalendar.specifics of
        RizeHabitCalendar _ ->
            text ("Found Rize calendar when expecting Toggl. Id = " ++ getStringIdForHabitCalendar habitCalendar)

        TogglHabitCalendar togglSpecifics ->
            div []
                [ W.InputText.view [ W.InputText.placeholder "Find Project" ]
                    { onInput = SetTogglProjectSearchString
                    , value = model.togglProjectSearchString
                    }
                , projectListDisplay model habitCalendar togglSpecifics
                ]


searchableCategoryList : FrontendModel -> HabitCalendar -> Html.Html FrontendMsg
searchableCategoryList model habitCalendar =
    case habitCalendar.specifics of
        TogglHabitCalendar _ ->
            text ("Found Toggl calendar when expecting Rize. Id = " ++ getStringIdForHabitCalendar habitCalendar)

        RizeHabitCalendar rizeSpecifics ->
            div []
                [ W.InputText.view [ W.InputText.placeholder "Find Category" ]
                    { onInput = SetTogglProjectSearchString
                    , value = model.togglProjectSearchString
                    }
                , categoryListDisplay model habitCalendar rizeSpecifics
                ]


categoryListDisplay : FrontendModel -> HabitCalendar -> RizeHabitCalendarSpecifics -> Html.Html FrontendMsg
categoryListDisplay model habitCalendar rizeSpecifics =
    div [ class "flex flex-col overflow-y-auto h-52 my-4 border-2 border-slate-300 rounded" ]
        (model
            |> categoriesFilteredBySearch
            |> List.map (categoryRow habitCalendar rizeSpecifics)
        )


categoriesFilteredBySearch : FrontendModel -> List RizeCategory
categoriesFilteredBySearch model =
    let
        searchString =
            model.togglProjectSearchString
                |> String.toLower
                |> String.trim
    in
    model.rizeCategories
        |> SDict.values
        |> List.filter
            (\category ->
                String.contains searchString (String.toLower category.name)
            )


categoryRow : HabitCalendar -> RizeHabitCalendarSpecifics -> RizeCategory -> Html.Html FrontendMsg
categoryRow habitCalendar rizeSpecifics category =
    let
        buttonType =
            if rizeSpecifics.categoryKey == category.key then
                "btn-primary"

            else
                "btn-outline"

        newSpecifics =
            { rizeSpecifics | categoryKey = category.key }
    in
    button
        [ class ("btn btn-neutral btn-sm " ++ buttonType)
        , type_ "button"
        , onClick
            (ModifyClientHabitCalendar
                { habitCalendar
                    | specifics = RizeHabitCalendar newSpecifics
                }
            )
        ]
        [ text category.name ]


descriptionEntry : HabitCalendar -> Html.Html FrontendMsg
descriptionEntry habitCalendar =
    case habitCalendar.specifics of
        RizeHabitCalendar _ ->
            text ("Error: Found Rize Habit Calendar when expecting Toggl calendar. ID = " ++ getStringIdForHabitCalendar habitCalendar)

        TogglHabitCalendar togglSpecifics ->
            div []
                [ W.InputText.view [ W.InputText.placeholder "Description (Optional)" ]
                    { onInput =
                        \s ->
                            let
                                newSpecifics =
                                    { togglSpecifics | descriptionMatchString = s }

                                newHabitCalendar =
                                    { habitCalendar | specifics = TogglHabitCalendar newSpecifics }
                            in
                            ModifyClientHabitCalendar
                                newHabitCalendar
                    , value = togglSpecifics.descriptionMatchString
                    }
                ]


togglFormEntries : FrontendModel -> HabitCalendar -> List (Html.Html FrontendMsg)
togglFormEntries model habitCalendar =
    [ searchableProjectList model habitCalendar
    , descriptionEntry habitCalendar
    ]


rizeFormEntries : FrontendModel -> HabitCalendar -> List (Html.Html FrontendMsg)
rizeFormEntries model habitCalendar =
    [ searchableCategoryList model habitCalendar ]


editCalendarSourceModal : FrontendModel -> HabitCalendar -> Html.Html FrontendMsg
editCalendarSourceModal model calendar =
    form [ onSubmit (attemptSubmittingCalendarSource calendar), class "flex flex-col gap-4" ]
        (List.concat
            [ -- specificFormEntries model calendar
              formEntriesForAllDatasources calendar
            , [ button [ type_ "submit", class "btn btn-primary" ] [ text "Save" ] ]
            , [ button [ type_ "button", class "btn btn-error", onClick (DeleteHabitCalendar (getIdForHabitCalendar calendar)) ] [ text "Delete" ] ]
            ]
        )



-- CALENDAR STUFF


calendarsAndTimer : Model -> Html.Html FrontendMsg
calendarsAndTimer model =
    let
        maybed =
            maybe2 model.currentZone model.currentTime

        inert =
            if model.modalState == Closed then
                []

            else
                [ Html.Attributes.attribute "inert" "true" ]
    in
    case maybed of
        Nothing ->
            text "Loading..."

        Just ( zone, time ) ->
            div
                (class "flex flex-col" :: inert)
                [ errorHeader model.error
                , runningTimerHeader model.runningEntry time
                , calendarSourceList model { zone = zone, posix = time }
                , sourceEditorButtons model
                ]


errorHeader : Maybe BackendError -> Html.Html FrontendMsg
errorHeader maybeError =
    case maybeError of
        Nothing ->
            text ""

        Just err ->
            text (stringifyBackendError err)


runningTimerHeader : RunningEntry -> Posix -> Html.Html FrontendMsg
runningTimerHeader event now =
    let
        timerText =
            case event of
                NoRunningEntry ->
                    "No time entry running"

                RunningEntry entry ->
                    textFromWebhookEvent entry
                        ++ " "
                        ++ timerTextFromWebhookEvent entry now

                TogglNotConnected ->
                    "Toggl not connected"

                ErrorGettingRunningEntry err ->
                    "Error getting running entry: " ++ err
    in
    h1 [ class "text-3xl font-bold" ]
        [ text timerText ]


textFromWebhookEvent : TogglEntry -> String
textFromWebhookEvent event =
    Maybe.withDefault "(no description)" event.description


timerTextFromWebhookEvent : TogglEntry -> Posix -> String
timerTextFromWebhookEvent event now =
    relativeTimer now event.start


sourceEditorButtons : FrontendModel -> Html.Html FrontendMsg
sourceEditorButtons model =
    div []
        [ button [ class "btn btn-primary", onClick (SetModalState (DatasourceModal ListDatasources)) ]
            [ text "Edit Datasources" ]
        , button
            [ class "btn btn-primary", onClick (SetModalState (EditCalendarModalOpen ChoosingDatasource)) ]
            [ text "Add Habit Calendar" ]
        , a
            [ class "btn btn-primary"
            , href ("data:text/json;base64," ++ Base64.encode (exportedHabitCalendars model.habitCalendars))
            , download "calendar-data.json"
            ]
            [ text "Export Data" ]
        , button
            [ class "btn btn-primary", onClick (SetModalState (ImportingData "")) ]
            [ text "Import Data" ]
        ]


calendarSourceList : Model -> PointInTime -> Html.Html FrontendMsg
calendarSourceList model time =
    div [ class "flex flex-wrap gap-8 justify-center" ]
        (model.habitCalendars
            |> Dict.values
            |> List.map (calendarSourceView time.zone time.posix model.runningEntry)
        )


calendarSourceView : Zone -> Posix -> RunningEntry -> HabitCalendar -> Html.Html FrontendMsg
calendarSourceView zone time runningEntry calendar =
    div [ class "flex flex-col" ]
        [ gridWithTitle
            calendar.name
            calendar.networkStatus
            (lazyGrid calendar zone time runningEntry)
        , calendarSourceEditor calendar
        ]


calendarSourceEditor : HabitCalendar -> Html.Html FrontendMsg
calendarSourceEditor calendar =
    W.Button.view []
        { onClick =
            calendar
                |> GotUUID
                |> EditCalendarModalOpen
                |> SetModalState
        , label = [ text "Edit" ]
        }


dayCell : DayComparison -> PointInTime -> Color -> Color -> Int -> Html.Html FrontendMsg
dayCell dayComparison time successColor nonzeroColor minutesCleaned =
    let
        minuteDependentStyles =
            if minutesCleaned == 0 then
                "bg-blue-200"

            else if minutesCleaned >= 30 then
                "text-white"

            else
                ""

        dayDependentStyles =
            case dayComparison of
                Future ->
                    "bg-gray-200 text-gray-500"

                Today ->
                    "outline outline-blue-500 outline-2"

                _ ->
                    ""

        backgroundColor =
            if minutesCleaned >= 30 then
                Color.toCssString successColor

            else if minutesCleaned > 0 then
                Color.toCssString nonzeroColor

            else
                ""

        minuteString =
            case dayComparison of
                Future ->
                    "-"

                _ ->
                    String.fromInt minutesCleaned
    in
    div
        [ class
            (String.join
                " "
                [ "p-0.5 w-9 h-9 rounded text-black"
                , minuteDependentStyles
                , dayDependentStyles
                ]
            )
        , style "background" backgroundColor
        ]
        [ div
            [ class "flex flex-col justify-start text-center leading-4" ]
            [ div [] [ text (formatMonthDay time) ]
            , div [] [ text minuteString ]
            ]
        ]


completedSecondsFromRunningEntry : RunningEntry -> HabitCalendar -> PointInTime -> Int
completedSecondsFromRunningEntry runningEntry calendar time =
    case runningEntry of
        NoRunningEntry ->
            0

        RunningEntry entry ->
            if
                sameDay time { posix = entry.start, zone = time.zone }
                    && togglEntryMatchesHabitCalendar entry calendar
            then
                (Time.posixToMillis time.posix - Time.posixToMillis entry.start) // 1000

            else
                0

        TogglNotConnected ->
            0

        ErrorGettingRunningEntry _ ->
            0


completedMinutesForDay : HabitCalendar -> RunningEntry -> PointInTime -> Int
completedMinutesForDay calendar runningEntry time =
    case calendar.specifics of
        TogglHabitCalendar togglHabitCalendar ->
            togglHabitCalendar.entries
                |> IDict.values
                |> List.filter
                    (\entry ->
                        sameDay time { posix = entry.start, zone = time.zone }
                    )
                |> List.map secondsForTogglEntry
                |> List.sum
                |> (\seconds -> round (toFloat seconds / 60))
                |> (+) (completedSecondsFromRunningEntry runningEntry calendar time // 60)

        RizeHabitCalendar rizeHabitCalendar ->
            rizeHabitCalendar.entries
                |> Dict.values
                |> List.filter
                    (\entry ->
                        sameDay time { posix = entry.start, zone = time.zone }
                    )
                |> List.map .amount
                |> List.sum
                |> (\seconds -> round (toFloat seconds / 60))


weekRow : HabitCalendar -> PointInTime -> PointInTime -> RunningEntry -> Html.Html FrontendMsg
weekRow calendar now whenToStart runningEntry =
    List.range 0 6
        |> List.map
            (\offset ->
                let
                    day =
                        { now
                            | posix =
                                Time.Extra.add Time.Extra.Day
                                    offset
                                    whenToStart.zone
                                    whenToStart.posix
                        }

                    isToday =
                        compareDays now day
                in
                dayCell isToday day calendar.successColor calendar.nonzeroColor (completedMinutesForDay calendar runningEntry day)
            )
        |> div [ class "flex justify-center gap-1" ]


gridWithTitle : String -> NetworkStatus -> Html.Html FrontendMsg -> Html.Html FrontendMsg
gridWithTitle title networkStatus content =
    div [ class "flex justify-center" ]
        [ div [ class "flex flex-col font-sans justify-center gap-1" ]
            [ h2 [] [ text title ]
            , content
            , button [ class "btn btn-primary", onClick FetchTimeEntries ] [ text "Load 30 Days" ]
            , text
                (case networkStatus of
                    Loading ->
                        "Loading..."

                    Success ->
                        "Loaded!"

                    Error err ->
                        "Error: " ++ stringifyHttpError err
                )
            ]
        ]


lazyGrid : HabitCalendar -> Zone -> Posix -> RunningEntry -> Html.Html FrontendMsg
lazyGrid calendar zone posix runningEntry =
    Html.Lazy.lazy4 grid calendar zone posix runningEntry


grid : HabitCalendar -> Zone -> Posix -> RunningEntry -> Html.Html FrontendMsg
grid calendar zone posix runningEntry =
    let
        weeks =
            List.range 0 calendar.weeksShowing |> List.reverse

        now =
            { zone = zone, posix = posix }
    in
    div [ class "text-xs flex justify-center flex-col gap-1" ]
        (weeks
            |> List.map
                (\offset ->
                    weekRow calendar now (mondaysAgo offset now) runningEntry
                )
        )
