module Evergreen.V10.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V10.CalendarDict
import Evergreen.V10.HabitCalendar
import Evergreen.V10.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V10.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V10.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V10.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    }


type alias EditCalendarModal =
    { calendarId : Evergreen.V10.HabitCalendar.HabitCalendarId
    , originalProjectId : Evergreen.V10.Toggl.TogglProjectId
    , selectedWorkspace : Evergreen.V10.Toggl.TogglWorkspace
    , selectedProject : Evergreen.V10.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    }


type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
    | ModalEditCalendar EditCalendarModal


type RunningEntry
    = NoRunningEntry
    | RunningEntry Evergreen.V10.Toggl.WebhookPayload


type alias WebhookDebugEntry =
    { timestamp : Time.Posix
    , eventType : String
    , description : String
    , rawJson : String
    }


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Time.Posix
    , currentZone : Maybe Time.Zone
    , calendars : Evergreen.V10.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V10.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    }


type alias BackendModel =
    { calendars : Evergreen.V10.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V10.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V10.Toggl.TogglProject
    , runningEntry : RunningEntry
    , webhookEvents : List WebhookDebugEntry
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg
    | GotTime Time.Posix
    | GotZone Time.Zone
    | Tick Time.Posix
    | RefreshWorkspaces
    | RefreshCalendar Evergreen.V10.HabitCalendar.HabitCalendarId Evergreen.V10.Toggl.TogglWorkspaceId Evergreen.V10.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V10.Toggl.TogglWorkspace
    | SelectProject Evergreen.V10.Toggl.TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | SubmitCreateCalendar
    | OpenEditCalendarModal Evergreen.V10.HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Evergreen.V10.Toggl.TogglWorkspace
    | EditCalendarSelectProject Evergreen.V10.Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | SubmitEditCalendar
    | DeleteCalendar Evergreen.V10.HabitCalendar.HabitCalendarId
    | StopRunningTimer
    | DismissStopTimerError
    | ClearWebhookEvents


type alias CalendarInfo =
    { calendarId : Evergreen.V10.HabitCalendar.HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V10.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V10.Toggl.TogglWorkspaceId Evergreen.V10.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V10.Toggl.TogglWorkspaceId Evergreen.V10.Toggl.TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar Evergreen.V10.HabitCalendar.HabitCalendarId String Evergreen.V10.Toggl.TogglWorkspaceId Evergreen.V10.Toggl.TogglProjectId String String
    | DeleteCalendarRequest Evergreen.V10.HabitCalendar.HabitCalendarId


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V10.Toggl.TogglApiError (List Evergreen.V10.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V10.Toggl.TogglApiError (List Evergreen.V10.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V10.Toggl.TogglWorkspaceId Evergreen.V10.Toggl.TogglProjectId Time.Zone (Result Evergreen.V10.Toggl.TogglApiError (List Evergreen.V10.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V10.Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V10.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V10.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V10.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V10.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
