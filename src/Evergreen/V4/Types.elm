module Evergreen.V4.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V4.CalendarDict
import Evergreen.V4.HabitCalendar
import Evergreen.V4.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V4.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V4.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V4.Toggl.TogglProject
    , calendarName : String
    }


type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal


type RunningEntry
    = NoRunningEntry
    | RunningEntry Evergreen.V4.Toggl.WebhookPayload


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
    , calendars : Evergreen.V4.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V4.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    }


type alias BackendModel =
    { calendars : Evergreen.V4.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V4.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V4.Toggl.TogglProject
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
    | RefreshCalendar Evergreen.V4.HabitCalendar.HabitCalendarId Evergreen.V4.Toggl.TogglWorkspaceId Evergreen.V4.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V4.Toggl.TogglWorkspace
    | SelectProject Evergreen.V4.Toggl.TogglProject
    | CalendarNameChanged String
    | SubmitCreateCalendar


type alias CalendarInfo =
    { calendarId : Evergreen.V4.HabitCalendar.HabitCalendarId
    , calendarName : String
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V4.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V4.Toggl.TogglWorkspaceId Evergreen.V4.Toggl.TogglProjectId String String Time.Zone


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V4.Toggl.TogglApiError (List Evergreen.V4.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V4.Toggl.TogglApiError (List Evergreen.V4.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V4.Toggl.TogglWorkspaceId Evergreen.V4.Toggl.TogglProjectId Time.Zone (Result Evergreen.V4.Toggl.TogglApiError (List Evergreen.V4.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V4.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V4.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V4.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V4.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
