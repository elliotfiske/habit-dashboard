module Evergreen.V14.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Http
import Effect.Lamdera
import Evergreen.V14.CalendarDict
import Evergreen.V14.HabitCalendar
import Evergreen.V14.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V14.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V14.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V14.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


type alias EditCalendarModal =
    { calendarId : Evergreen.V14.HabitCalendar.HabitCalendarId
    , originalProjectId : Evergreen.V14.Toggl.TogglProjectId
    , selectedWorkspace : Evergreen.V14.Toggl.TogglWorkspace
    , selectedProject : Evergreen.V14.Toggl.TogglProject
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
    | RunningEntry Evergreen.V14.Toggl.WebhookPayload


type alias WebhookDebugEntry =
    { timestamp : Time.Posix
    , eventType : String
    , description : String
    , rawJson : String
    }


type alias CodaProject =
    { name : String
    , startDate : Maybe Time.Posix
    , endDate : Maybe Time.Posix
    }


type CodaStatus
    = CodaNotFetched
    | CodaLoading
    | CodaOneActive CodaProject
    | CodaInvalidCount Int
    | CodaError String


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Time.Posix
    , currentZone : Maybe Time.Zone
    , calendars : Evergreen.V14.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V14.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    , codaStatus : CodaStatus
    }


type alias BackendModel =
    { calendars : Evergreen.V14.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V14.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V14.Toggl.TogglProject
    , runningEntry : RunningEntry
    , webhookEvents : List WebhookDebugEntry
    , codaStatus : CodaStatus
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg
    | GotTime Time.Posix
    | GotZone Time.Zone
    | Tick Time.Posix
    | RefreshWorkspaces
    | RefreshCalendar Evergreen.V14.HabitCalendar.HabitCalendarId Evergreen.V14.Toggl.TogglWorkspaceId Evergreen.V14.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V14.Toggl.TogglWorkspace
    | SelectProject Evergreen.V14.Toggl.TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | OrangetheoryToggled Bool
    | SubmitCreateCalendar
    | OpenEditCalendarModal Evergreen.V14.HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Evergreen.V14.Toggl.TogglWorkspace
    | EditCalendarSelectProject Evergreen.V14.Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | EditOrangetheoryToggled Bool
    | SubmitEditCalendar
    | DeleteCalendar Evergreen.V14.HabitCalendar.HabitCalendarId
    | UpdateProjectFilter String
    | StopRunningTimer
    | DismissStopTimerError
    | ClearWebhookEvents
    | RefreshCodaProject


type alias CalendarInfo =
    { calendarId : Evergreen.V14.HabitCalendar.HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V14.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V14.Toggl.TogglWorkspaceId Evergreen.V14.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V14.Toggl.TogglWorkspaceId Evergreen.V14.Toggl.TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar Evergreen.V14.HabitCalendar.HabitCalendarId String Evergreen.V14.Toggl.TogglWorkspaceId Evergreen.V14.Toggl.TogglProjectId String String Bool
    | DeleteCalendarRequest Evergreen.V14.HabitCalendar.HabitCalendarId
    | FetchCodaProject


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V14.Toggl.TogglApiError (List Evergreen.V14.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V14.Toggl.TogglApiError (List Evergreen.V14.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V14.Toggl.TogglWorkspaceId Evergreen.V14.Toggl.TogglProjectId Time.Zone (Result Evergreen.V14.Toggl.TogglApiError (List Evergreen.V14.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V14.Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry
    | CodaPollTick Time.Posix
    | GotCodaResponse (Result Effect.Http.Error String)


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V14.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V14.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V14.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V14.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
    | CodaStatusUpdated CodaStatus
