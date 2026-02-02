module Evergreen.V16.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Http
import Effect.Lamdera
import Evergreen.V16.CalendarDict
import Evergreen.V16.HabitCalendar
import Evergreen.V16.Toggl
import Http
import Time
import Url


type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List Evergreen.V16.Toggl.TogglWorkspace)
    | ConnectionError String


type alias CreateCalendarModal =
    { selectedWorkspace : Maybe Evergreen.V16.Toggl.TogglWorkspace
    , selectedProject : Maybe Evergreen.V16.Toggl.TogglProject
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    , projectFilter : String
    }


type alias EditCalendarModal =
    { calendarId : Evergreen.V16.HabitCalendar.HabitCalendarId
    , originalProjectId : Evergreen.V16.Toggl.TogglProjectId
    , selectedWorkspace : Evergreen.V16.Toggl.TogglWorkspace
    , selectedProject : Evergreen.V16.Toggl.TogglProject
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
    | RunningEntry Evergreen.V16.Toggl.WebhookPayload


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
    , calendars : Evergreen.V16.CalendarDict.CalendarDict
    , togglStatus : TogglConnectionStatus
    , modalState : ModalState
    , availableProjects : List Evergreen.V16.Toggl.TogglProject
    , projectsLoading : Bool
    , runningEntry : RunningEntry
    , webhookDebugLog : List WebhookDebugEntry
    , stopTimerError : Maybe String
    , codaStatus : CodaStatus
    , startMonofocusTimerError : Maybe String
    }


type alias BackendModel =
    { calendars : Evergreen.V16.CalendarDict.CalendarDict
    , togglWorkspaces : List Evergreen.V16.Toggl.TogglWorkspace
    , togglProjects : List Evergreen.V16.Toggl.TogglProject
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
    | RefreshCalendar Evergreen.V16.HabitCalendar.HabitCalendarId Evergreen.V16.Toggl.TogglWorkspaceId Evergreen.V16.Toggl.TogglProjectId String
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace Evergreen.V16.Toggl.TogglWorkspace
    | SelectProject Evergreen.V16.Toggl.TogglProject
    | CalendarNameChanged String
    | SuccessColorChanged String
    | NonzeroColorChanged String
    | OrangetheoryToggled Bool
    | SubmitCreateCalendar
    | OpenEditCalendarModal Evergreen.V16.HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Evergreen.V16.Toggl.TogglWorkspace
    | EditCalendarSelectProject Evergreen.V16.Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | EditOrangetheoryToggled Bool
    | SubmitEditCalendar
    | DeleteCalendar Evergreen.V16.HabitCalendar.HabitCalendarId
    | UpdateProjectFilter String
    | StopRunningTimer
    | DismissStopTimerError
    | ClearWebhookEvents
    | RefreshCodaProject
    | StartMonofocusTimer String
    | DismissStartMonofocusTimerError


type alias CalendarInfo =
    { calendarId : Evergreen.V16.HabitCalendar.HabitCalendarId
    , calendarName : String
    , successColor : String
    , nonzeroColor : String
    , isOrangetheory : Bool
    }


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects Evergreen.V16.Toggl.TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo Evergreen.V16.Toggl.TogglWorkspaceId Evergreen.V16.Toggl.TogglProjectId String String Time.Zone
    | StopTogglTimer Evergreen.V16.Toggl.TogglWorkspaceId Evergreen.V16.Toggl.TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar Evergreen.V16.HabitCalendar.HabitCalendarId String Evergreen.V16.Toggl.TogglWorkspaceId Evergreen.V16.Toggl.TogglProjectId String String Bool
    | DeleteCalendarRequest Evergreen.V16.HabitCalendar.HabitCalendarId
    | FetchCodaProject
    | StartMonofocusTimerRequest String


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Evergreen.V16.Toggl.TogglApiError (List Evergreen.V16.Toggl.TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Evergreen.V16.Toggl.TogglApiError (List Evergreen.V16.Toggl.TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo Evergreen.V16.Toggl.TogglWorkspaceId Evergreen.V16.Toggl.TogglProjectId Time.Zone (Result Evergreen.V16.Toggl.TogglApiError (List Evergreen.V16.Toggl.TimeEntry))
    | GotWebhookValidation (Result Http.Error ())
    | GotStopTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V16.Toggl.TogglApiError ())
    | BroadcastRunningEntry RunningEntry
    | CodaPollTick Time.Posix
    | GotCodaResponse (Result Effect.Http.Error String)
    | StartTimerWithTime Effect.Lamdera.ClientId String Time.Posix
    | GotStartTimerResponse Effect.Lamdera.ClientId (Result Evergreen.V16.Toggl.TogglApiError ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated Evergreen.V16.CalendarDict.CalendarDict
    | TogglWorkspacesReceived (Result String (List Evergreen.V16.Toggl.TogglWorkspace))
    | TogglProjectsReceived (Result String (List Evergreen.V16.Toggl.TogglProject))
    | TogglTimeEntriesReceived (Result String (List Evergreen.V16.Toggl.TimeEntry))
    | RunningEntryUpdated RunningEntry
    | WebhookDebugEvent WebhookDebugEntry
    | WebhookEventsCleared
    | StopTimerFailed String RunningEntry
    | CodaStatusUpdated CodaStatus
    | StartMonofocusTimerFailed String
