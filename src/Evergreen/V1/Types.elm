module Evergreen.V1.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V1.CalendarDict
import Evergreen.V1.HabitCalendar
import Evergreen.V1.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V1.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V1.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V1.Toggl.TogglProject
    , calendarName : String
    }


type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal


type RunningEntry
    = NoRunningEntry
    | RunningEntry Evergreen.V1.Toggl.WebhookPayload


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
    , calendars : Evergreen.V1.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V1.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    }


type alias BackendModel =
    { calendars : Evergreen.V1.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V1.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V1.Toggl.TogglProject
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
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V1.Toggl.TogglWorkspace
    | SelectProject Evergreen.V1.Toggl.TogglProject
    | CalendarNameChanged String
    | SubmitCreateCalendar


type alias CalendarInfo =
    { calendarId : Evergreen.V1.HabitCalendar.HabitCalendarId
    , calendarName : String
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V1.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V1.Toggl.TogglWorkspaceId Evergreen.V1.Toggl.TogglProjectId String String Time.Zone


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V1.Toggl.TogglApiError (List Evergreen.V1.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V1.Toggl.TogglApiError (List Evergreen.V1.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Time.Zone (Result Evergreen.V1.Toggl.TogglApiError (List Evergreen.V1.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V1.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V1.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V1.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V1.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
