module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , CalendarInfo
    , CodaProject
    , CodaStatus(..)
    , CreateCalendarModal
    , EditCalendarModal
    , FrontendModel
    , FrontendMsg(..)
    , ModalState(..)
    , RunningEntry(..)
    , ToBackend(..)
    , ToFrontend(..)
    , TogglConnectionStatus(..)
    , WebhookDebugEntry
    )

import CalendarDict exposing (CalendarDict)
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Effect.Http
import HabitCalendar exposing (HabitCalendarId)
import Http
import Time exposing (Posix, Zone)
import Toggl exposing (TimeEntry, TimeEntryId, TogglProject, TogglProjectId, TogglWorkspace, TogglWorkspaceId)
import Url exposing (Url)


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Posix
    , currentZone : Maybe Zone
    , calendars : CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List TogglProject -- Projects for the selected workspace
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry -- Recent webhook events for debugging
    , stopTimerError : Maybe String
    , codaStatus : CodaStatus
    , startMonofocusTimerError : Maybe String
    }


{-| A debug entry for tracking incoming webhook requests.
-}
type alias WebhookDebugEntry =
    { timestamp : Posix
    , eventType : String -- "validation" or "event"
    , description : String
    , rawJson : String
    }


{-| A project from the Coda "Current Focus!" table.
-}
type alias CodaProject =
    { name : String
    , startDate : Maybe Time.Posix
    , endDate : Maybe Time.Posix
    }


{-| Status of the Coda project integration.
-}
type CodaStatus
    = CodaNotFetched
    | CodaLoading
    | CodaOneActive CodaProject
    | CodaInvalidCount Int -- 0 or 2+ active projects
    | CodaError String


{-| Modal state for the frontend.
-}
type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
    | ModalEditCalendar EditCalendarModal


{-| State for the "Create Calendar" modal.
-}
type alias CreateCalendarModal =
    { selectedWorkspace : Maybe TogglWorkspace
    , selectedProject : Maybe TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


{-| State for the "Edit Calendar" modal.
-}
type alias EditCalendarModal =
    { calendarId : HabitCalendar.HabitCalendarId
    , originalProjectId : Toggl.TogglProjectId -- To detect if project changed
    , selectedWorkspace : Toggl.TogglWorkspace
    , selectedProject : Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


{-| Status of the Toggl API connection.
-}
type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List TogglWorkspace)
    | ConnectionError String


{-| Represents the current running time entry from Toggl.
Updated via webhook events.
-}
type RunningEntry
    = NoRunningEntry
    | RunningEntry Toggl.WebhookPayload


type alias BackendModel =
    { calendars : CalendarDict
    , togglWorkspaces : List TogglWorkspace
    , togglProjects : List TogglProject
    , runningEntry : RunningEntry
    , webhookEvents : List WebhookDebugEntry -- Store all webhook events for debugging
    , codaStatus : CodaStatus
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg
    | GotTime Posix
    | GotZone Zone
    | Tick Posix -- Timer update every second
      -- Toggl actions
    | RefreshWorkspaces
    | RefreshCalendar HabitCalendarId TogglWorkspaceId TogglProjectId String -- calendarId, workspaceId, projectId, calendarName
      -- Modal actions
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace TogglWorkspace
    | SelectProject TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | OrangetheoryToggled Bool
    | SubmitCreateCalendar
      -- Edit calendar actions
    | OpenEditCalendarModal HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Toggl.TogglWorkspace
    | EditCalendarSelectProject Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | EditOrangetheoryToggled Bool
    | SubmitEditCalendar
    | DeleteCalendar HabitCalendar.HabitCalendarId
      -- Project filter (shared between Create and Edit modals)
    | UpdateProjectFilter String
      -- Stop timer actions
    | StopRunningTimer
    | DismissStopTimerError
      -- Webhook debug actions
    | ClearWebhookEvents
      -- Coda actions
    | RefreshCodaProject
      -- Start Monofocus timer actions
    | StartMonofocusTimer String -- Coda project name as description
    | DismissStartMonofocusTimerError


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo TogglWorkspaceId Toggl.TogglProjectId String String Zone -- calendarInfo, workspaceId, projectId, startDate, endDate, userZone
    | StopTogglTimer TogglWorkspaceId TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar HabitCalendar.HabitCalendarId String Toggl.TogglWorkspaceId Toggl.TogglProjectId String String Bool -- calendarId, name, workspaceId, projectId, successColor, nonzeroColor, isOrangetheory
    | DeleteCalendarRequest HabitCalendar.HabitCalendarId
    | FetchCodaProject
    | StartMonofocusTimerRequest String -- description


{-| Info needed to create a calendar from fetched time entries.
-}
type alias CalendarInfo =
    { calendarId : HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    }


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Toggl.TogglApiError (List TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Toggl.TogglApiError (List TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo TogglWorkspaceId TogglProjectId Zone (Result Toggl.TogglApiError (List TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry -- Used for testing and webhook simulation
    | CodaPollTick Time.Posix
    | GotCodaResponse (Result Effect.Http.Error String)
    | StartTimerWithTime Effect.Lamdera.ClientId String Time.Posix
    | GotStartTimerResponse Effect.Lamdera.ClientId (Result Toggl.TogglApiError ())
    | GotRpcStartTimerResponse (Result Http.Error ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated CalendarDict
    | TogglWorkspacesReceived (Result String (List TogglWorkspace))
    | TogglProjectsReceived (Result String (List TogglProject))
    | TogglTimeEntriesReceived (Result String (List TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
    | CodaStatusUpdated CodaStatus
    | StartMonofocusTimerFailed String
