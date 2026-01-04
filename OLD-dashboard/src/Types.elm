module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Color exposing (Color)
import DatasourceIds exposing (RizeDatasourceId, TogglDatasourceId)
import Dict exposing (Dict)
import Http
import IDict exposing (IDict)
import Id exposing (Id)
import Lamdera exposing (ClientId, SessionId)
import SDict exposing (SDict)
import Time exposing (Posix, Zone)
import UUID exposing (UUID)
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , currentTime : Maybe Posix
    , currentZone : Maybe Zone
    , habitCalendars : Dict String HabitCalendar
    , modalState : ModalState
    , debugRequests : List String
    , runningEntry : RunningEntry
    , error : Maybe BackendError
    , rizeDatasource : RizeDatasource
    , togglDatasource : TogglDatasource
    , togglProjects : IDict TogglProjectId TogglProject
    , rizeCategories : SDict RizeCategoryId RizeCategory
    , pendingDatasourceCredentials : Dict String DatasourceCredentials
    , allEntries : Dict String TogglWebhookEvent

    -- Toggl habit calendar form entry
    , togglProjectSearchString : String
    }


type alias BackendModel =
    { habitCalendars : Dict String HabitCalendar
    , connectedClients : List ( SessionId, ClientId )
    , runningEntry : RunningEntry
    , rizeDatasource : RizeDatasource
    , togglDatasource : TogglDatasource
    , togglProjects : IDict TogglProjectId TogglProject
    , rizeCategories : SDict RizeCategoryId RizeCategory
    , datasourceCredentials : Dict String DatasourceCredentials
    , zone : Zone
    , now : Posix
    }


type RunningEntry
    = NoRunningEntry
    | RunningEntry TogglEntry
    | TogglNotConnected
    | ErrorGettingRunningEntry String


type alias TogglWebhookEvent =
    { payload : TogglEntry
    , metadata : TogglWebhookEventMetadata
    }


type alias TogglEntry =
    { id : TogglEntryId
    , projectId : Maybe TogglProjectId
    , description : Maybe String
    , start : Posix
    , stop : Maybe Posix
    }


{-| A Rize entry represents the amount of time that was spent on a given Category for 24 hours starting at `start`.
-}
type alias RizeEntry =
    { amount : Int
    , start : Posix
    }


type alias TogglWebhookEventMetadata =
    { action : String
    }


type DayComparison
    = Today
    | Past
    | Future


type DatasourceCredentialsState credentialsIdType
    = NotSubmitted
    | Submitted credentialsIdType SubmittedDatasourceCredentialsState


type SubmittedDatasourceCredentialsState
    = TestingConnection
    | Connected
    | RecoverableError RecoverableErrorDetail
    | UnrecoverableError UnrecoverableErrorDetail


type RecoverableErrorDetail
    = RateLimited
    | RecoverableNetworkError String
    | ServerError Int


type UnrecoverableErrorDetail
    = InvalidCredentials
    | NotFound String
      -- Something is wrong with the data of THIS app.
    | BadAppDataShape String
    | BadHttpStatus Int
    | BadHttpBody String


type alias DateRange =
    { start : Posix
    , end : Posix
    }


type alias RizeDatasource =
    { id : RizeDatasourceId
    , name : String

    -- This must be on the Datasource type because the client needs to know
    -- the status of the credentials, but not the actual credentials themselves.
    , credentialsId : DatasourceCredentialsState RizeDatasourceCredentialsId
    }


type alias TogglDatasource =
    { id : TogglDatasourceId
    , name : String
    , workspaces : IDict TogglWorkspaceId TogglWorkspace
    , projects : IDict TogglProjectId TogglProject

    -- This must be on the Datasource type because the client needs to know
    -- the status of the credentials, but not the actual credentials themselves.
    , credentialsId : DatasourceCredentialsState TogglDatasourceCredentialsId
    }


type DatasourceCredentials
    = TogglDatasourceCredentials TogglDatasourceCredentialsData
    | RizeDatasourceCredentials RizeDatasourceCredentialsData


type alias TogglDatasourceCredentialsData =
    { id : TogglDatasourceCredentialsId
    , apiKey : String
    }


type alias RizeDatasourceCredentialsData =
    { id : RizeDatasourceCredentialsId
    , accessToken : String
    , clientId : String
    , uid : String
    }


type alias HabitCalendar =
    { name : String
    , nonzeroColor : Color
    , successColor : Color
    , weeksShowing : Int
    , networkStatus : NetworkStatus
    , specifics : HabitCalendarSpecifics
    }


type HabitCalendarSpecifics
    = TogglHabitCalendar TogglHabitCalendarSpecifics
    | RizeHabitCalendar RizeHabitCalendarSpecifics


type alias RizeHabitCalendarSpecifics =
    { id : RizeHabitCalendarId

    -- TODO: make this a RizeCategoryId. Problem is what does it get set to initially? Need to have separate "form" data structure.
    , categoryKey : String
    , datasourceId : RizeDatasourceId
    , entries : Dict Int RizeEntry
    }


type alias TogglHabitCalendarSpecifics =
    { id : TogglHabitCalendarId
    , datasourceId : TogglDatasourceId
    , workspaceId : TogglWorkspaceId
    , togglProjectId : Maybe TogglProjectId
    , descriptionMatchString : String
    , entries : IDict TogglEntryId TogglEntry
    }


type NetworkStatus
    = Loading
    | Error Http.Error
    | Success


type alias PointInTime =
    { zone : Zone, posix : Posix }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg
    | FetchCurrentTime Posix
    | FetchCurrentZone Zone
    | FetchTimeEntries
    | SubmitHabitCalendar HabitCalendar
    | DeleteHabitCalendar HabitCalendarId
    | ModifyPendingDatasourceCredentials DatasourceCredentials
    | SubmitPendingRizeDatasourceCredentials RizeDatasourceId RizeDatasourceCredentialsData
    | SubmitPendingTogglDatasourceCredentials TogglDatasourceId TogglDatasourceCredentialsData
    | CreateAndStartEditingTogglDatasourceCredentials TogglDatasourceId
    | CreateAndStartEditingRizeDatasourceCredentials RizeDatasourceId
    | GotRandomUUIDForNewRizeDatasourceCredentials RizeDatasourceId UUID
    | GotRandomUUIDForNewTogglDatasourceCredentials TogglDatasourceId UUID
    | GotRandomUUIDForNewRizeHabitCalendar RizeDatasourceId UUID
    | GotRandomUUIDForNewTogglHabitCalendar TogglDatasourceId UUID
    | SetModalState ModalState
    | CreateAndStartEditingRizeHabitCalendar RizeDatasourceId
    | CreateAndStartEditingTogglHabitCalendar TogglDatasourceId
    | ModifyClientHabitCalendar HabitCalendar
    | SetTogglProjectSearchString String
    | SetImportDataString String


type EditCalendarModalState
    = ChoosingDatasource
    | LoadingUUID
    | GotUUID HabitCalendar


type DatasourceModalState
    = ListDatasources
    | LoadingDatasourceCredentials
    | EditRizeDatasourceCredentials RizeDatasourceId RizeDatasourceCredentialsId
    | EditTogglDatasourceCredentials TogglDatasourceId TogglDatasourceCredentialsId


type ModalState
    = Closed
    | DatasourceModal DatasourceModalState
    | EditCalendarModalOpen EditCalendarModalState
    | ImportingData String


type ToBackend
    = NoOpToBackend
    | FrontendWantsUpdate
    | UpdateHabitCalendar HabitCalendar
    | UpdateRizeDatasourceCredentials RizeDatasourceId RizeDatasourceCredentialsData
    | UpdateTogglDatasourceCredentials TogglDatasourceId TogglDatasourceCredentialsData
    | TellBackendToDeleteHabitCalendar HabitCalendarId


type ErrorDetailed body
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Http.Metadata body
    | BadBody Http.Metadata body String


type BackendError
    = BadDataShape String
    | HttpFailure Http.Error
    | Unimplemented


type BackendMsg
    = NoOpBackendMsg
    | GotTime PointInTime
    | ClientConnected SessionId ClientId
    | ClientDisconnected SessionId ClientId
      -- Toggl data fetching
    | GotWorkspaceData TogglDatasourceId TogglDatasourceCredentialsData (Result Http.Error (List TogglWorkspace))
    | GotProjectsData TogglWorkspaceId (Result Http.Error (List TogglProject))
    | GotTogglEntries TogglHabitCalendarId Time.Posix Time.Posix (Result Http.Error (List TogglEntryResult))
    | UpdateRunningEntry Time.Posix
    | GotRunningEntry (Result Http.Error RunningEntry)
      -- Rize data fetching
    | GotRizeCategoriesData RizeDatasourceId (Result Http.Error (List RizeCategory))
    | GotRizeEntries RizeHabitCalendarId (Result Http.Error (List RizeEntry))
    | WipeDebounceStates Time.Posix
    | FetchCurrentTimeBackend Time.Posix


type ToFrontend
    = BackendUpdated (Dict String HabitCalendar) RizeDatasource TogglDatasource (IDict TogglProjectId TogglProject) (SDict RizeCategoryId RizeCategory) RunningEntry
    | AddDebugRequest String
    | ReportError BackendError


type alias TimeEntries =
    Dict String Int


type alias TogglWorkspace =
    { id : TogglWorkspaceId
    , organizationId : Int
    , name : String
    , logoUrl : String
    }


type alias TogglProject =
    { id : TogglProjectId, workspaceId : TogglWorkspaceId, name : String, color : Color }


type alias TogglEntryResult =
    { timeEntries : List TogglEntry
    }


type alias RizeCategory =
    { id : RizeCategoryId
    , name : String -- Human readable name.
    , key : String -- Key used in the API. Snake cased human readable name.
    }



-- ID types


type DatasourceCredentialsId
    = TogglDSCID TogglDatasourceCredentialsId
    | RizeDSCID RizeDatasourceCredentialsId


type HabitCalendarId
    = TogglHC TogglHabitCalendarId
    | RizeHC RizeHabitCalendarId


type TogglDatasourceCredentialsBrand
    = TogglDatasourceCredentialsBrand


type alias TogglDatasourceCredentialsId =
    Id String TogglDatasourceCredentialsBrand


type RizeDatasourceCredentialsBrand
    = RizeDatasourceCredentialsBrand


type alias RizeDatasourceCredentialsId =
    Id String RizeDatasourceCredentialsBrand


type TogglHabitCalendarBrand
    = TogglHabitCalendarBrand


type alias TogglHabitCalendarId =
    Id String TogglHabitCalendarBrand


type RizeHabitCalendarBrand
    = RizeHabitCalendarBrand


type alias RizeHabitCalendarId =
    Id String RizeHabitCalendarBrand


type RizeCategoryBrand
    = RizeCategoryBrand


type alias RizeCategoryId =
    Id String RizeCategoryBrand


type TogglWorkspaceBrand
    = TogglWorkspaceBrand


type alias TogglWorkspaceId =
    Id Int TogglWorkspaceBrand


type TogglProjectBrand
    = TogglProjectBrand


type alias TogglProjectId =
    Id Int TogglProjectBrand


type TogglEntryBrand
    = TogglEntryBrand


type alias TogglEntryId =
    Id Int TogglEntryBrand


type RizeEntryBrand
    = RizeEntryBrand


type alias RizeEntryId =
    Id UUID RizeEntryBrand
