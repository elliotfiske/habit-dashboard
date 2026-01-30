module Evergreen.V13.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V13.CalendarDict
import Evergreen.V13.HabitCalendar
import Evergreen.V13.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V13.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V13.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V13.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


type alias EditCalendarModal =
    { calendarId : Evergreen.V13.HabitCalendar.HabitCalendarId
    , originalProjectId : Evergreen.V13.Toggl.TogglProjectId
    , selectedWorkspace : Evergreen.V13.Toggl.TogglWorkspace
    , selectedProject : Evergreen.V13.Toggl.TogglProject
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
    | RunningEntry Evergreen.V13.Toggl.WebhookPayload


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
    , calendars : Evergreen.V13.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V13.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    }


type alias BackendModel =
    { calendars : Evergreen.V13.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V13.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V13.Toggl.TogglProject
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
    | RefreshCalendar Evergreen.V13.HabitCalendar.HabitCalendarId Evergreen.V13.Toggl.TogglWorkspaceId Evergreen.V13.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V13.Toggl.TogglWorkspace
    | SelectProject Evergreen.V13.Toggl.TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | OrangetheoryToggled Bool
    | SubmitCreateCalendar
    | OpenEditCalendarModal Evergreen.V13.HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Evergreen.V13.Toggl.TogglWorkspace
    | EditCalendarSelectProject Evergreen.V13.Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | EditOrangetheoryToggled Bool
    | SubmitEditCalendar
    | DeleteCalendar Evergreen.V13.HabitCalendar.HabitCalendarId
    | UpdateProjectFilter String
    | StopRunningTimer
    | DismissStopTimerError
    | ClearWebhookEvents


type alias CalendarInfo =
    { calendarId : Evergreen.V13.HabitCalendar.HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V13.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V13.Toggl.TogglWorkspaceId Evergreen.V13.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V13.Toggl.TogglWorkspaceId Evergreen.V13.Toggl.TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar Evergreen.V13.HabitCalendar.HabitCalendarId String Evergreen.V13.Toggl.TogglWorkspaceId Evergreen.V13.Toggl.TogglProjectId String String Bool
    | DeleteCalendarRequest Evergreen.V13.HabitCalendar.HabitCalendarId


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V13.Toggl.TogglApiError (List Evergreen.V13.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V13.Toggl.TogglApiError (List Evergreen.V13.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V13.Toggl.TogglWorkspaceId Evergreen.V13.Toggl.TogglProjectId Time.Zone (Result Evergreen.V13.Toggl.TogglApiError (List Evergreen.V13.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V13.Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V13.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V13.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V13.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V13.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
