module Evergreen.V19.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Http
import Effect.Lamdera
import Evergreen.V19.CalendarDict
import Evergreen.V19.HabitCalendar
import Evergreen.V19.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V19.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V19.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V19.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


type alias EditCalendarModal =
    { calendarId : Evergreen.V19.HabitCalendar.HabitCalendarId
    , originalProjectId : Evergreen.V19.Toggl.TogglProjectId
    , selectedWorkspace : Evergreen.V19.Toggl.TogglWorkspace
    , selectedProject : Evergreen.V19.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
    | ModalEditCalendar EditCalendarModal


type RunningEntry
    = NoRunningEntry
    | RunningEntry Evergreen.V19.Toggl.WebhookPayload


type alias WebhookDebugEntry =
    { timestamp : Time.Posix
    , eventType : String
    , description : String
    , rawJson : String
    }


type alias MonofocusProject =
    { title : String
    , startDate : Time.Posix
    , endDate : Time.Posix
    }


type MonofocusStatus
    = MonofocusNotFetched
    | MonofocusLoading
    | MonofocusOneActive MonofocusProject
    | MonofocusNoActive
    | MonofocusError String


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Time.Posix
    , currentZone : Maybe Time.Zone
    , calendars : Evergreen.V19.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V19.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    , monofocusStatus : MonofocusStatus
    , startMonofocusTimerError : Maybe String
    }


type alias BackendModel =
    { calendars : Evergreen.V19.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V19.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V19.Toggl.TogglProject
    , runningEntry : RunningEntry
    , webhookEvents : List WebhookDebugEntry
    , monofocusStatus : MonofocusStatus
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg
    | GotTime Time.Posix
    | GotZone Time.Zone
    | Tick Time.Posix
    | RefreshWorkspaces
    | RefreshCalendar Evergreen.V19.HabitCalendar.HabitCalendarId Evergreen.V19.Toggl.TogglWorkspaceId Evergreen.V19.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V19.Toggl.TogglWorkspace
    | SelectProject Evergreen.V19.Toggl.TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | OrangetheoryToggled Bool
    | SubmitCreateCalendar
    | OpenEditCalendarModal Evergreen.V19.HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Evergreen.V19.Toggl.TogglWorkspace
    | EditCalendarSelectProject Evergreen.V19.Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | EditOrangetheoryToggled Bool
    | SubmitEditCalendar
    | DeleteCalendar Evergreen.V19.HabitCalendar.HabitCalendarId
    | UpdateProjectFilter String
    | StopRunningTimer
    | DismissStopTimerError
    | ClearWebhookEvents
    | RefreshMonofocusProject
    | StartMonofocusTimer String
    | DismissStartMonofocusTimerError


type alias CalendarInfo =
    { calendarId : Evergreen.V19.HabitCalendar.HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V19.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V19.Toggl.TogglWorkspaceId Evergreen.V19.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V19.Toggl.TogglWorkspaceId Evergreen.V19.Toggl.TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar Evergreen.V19.HabitCalendar.HabitCalendarId String Evergreen.V19.Toggl.TogglWorkspaceId Evergreen.V19.Toggl.TogglProjectId String String Bool
    | DeleteCalendarRequest Evergreen.V19.HabitCalendar.HabitCalendarId
    | FetchMonofocusProject
    | StartMonofocusTimerRequest String


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V19.Toggl.TogglApiError (List Evergreen.V19.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V19.Toggl.TogglApiError (List Evergreen.V19.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V19.Toggl.TogglWorkspaceId Evergreen.V19.Toggl.TogglProjectId Time.Zone (Result Evergreen.V19.Toggl.TogglApiError (List Evergreen.V19.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V19.Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry
    | MonofocusPollTick Time.Posix
    | GotMonofocusResponse (Result Effect.Http.Error String)
    | StartTimerWithTime Effect.Lamdera.ClientId String Time.Posix
    | GotStartTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V19.Toggl.TogglApiError ())
    | GotRpcStartTimerResponse (Result Http.Error ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V19.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V19.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V19.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V19.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
    | MonofocusStatusUpdated MonofocusStatus
    | StartMonofocusTimerFailed String
