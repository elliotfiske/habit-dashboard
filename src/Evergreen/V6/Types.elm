module Evergreen.V6.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V6.CalendarDict
import Evergreen.V6.HabitCalendar
import Evergreen.V6.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V6.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V6.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V6.Toggl.TogglProject
    , calendarName : String
    }


type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal


type RunningEntry
    = NoRunningEntry
    | RunningEntry Evergreen.V6.Toggl.WebhookPayload


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
    , calendars : Evergreen.V6.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V6.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    }


type alias BackendModel =
    { calendars : Evergreen.V6.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V6.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V6.Toggl.TogglProject
    , runningEntry : RunningEntry
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg
    | GotTime Time.Posix
    | GotZone Time.Zone
    | Tick Time.Posix
    | RefreshWorkspaces
    | RefreshCalendar Evergreen.V6.HabitCalendar.HabitCalendarId Evergreen.V6.Toggl.TogglWorkspaceId Evergreen.V6.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V6.Toggl.TogglWorkspace
    | SelectProject Evergreen.V6.Toggl.TogglProject
    | CalendarNameChanged String
    | SubmitCreateCalendar
    | StopRunningTimer
    | DismissStopTimerError


type alias CalendarInfo =
    { calendarId : Evergreen.V6.HabitCalendar.HabitCalendarId
    , calendarName : String
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V6.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V6.Toggl.TogglWorkspaceId Evergreen.V6.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V6.Toggl.TogglWorkspaceId Evergreen.V6.Toggl.TimeEntryId


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V6.Toggl.TogglApiError (List Evergreen.V6.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V6.Toggl.TogglApiError (List Evergreen.V6.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V6.Toggl.TogglWorkspaceId Evergreen.V6.Toggl.TogglProjectId Time.Zone (Result Evergreen.V6.Toggl.TogglApiError (List Evergreen.V6.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V6.Toggl.TogglApiError ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V6.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V6.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V6.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V6.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | StopTimerFailed String RunningEntry
