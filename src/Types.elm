module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , CalendarInfo
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
import Color exposing (Color)
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
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
    }


{-| A debug entry for tracking incoming webhook requests.
-}
type alias WebhookDebugEntry =
    { timestamp : Posix
    , eventType : String -- "validation" or "event"
    , description : String
    , rawJson : String
    }


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
    , successColor : Color
    , nonzeroColor : Color
    }


{-| State for the "Edit Calendar" modal.
-}
type alias EditCalendarModal =
    { calendarId : HabitCalendar.HabitCalendarId
    , originalProjectId : Toggl.TogglProjectId -- To detect if project changed
    , selectedWorkspace : Toggl.TogglWorkspace
    , selectedProject : Toggl.TogglProject
    , calendarName : String
    , successColor : Color
    , nonzeroColor : Color
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
    | SubmitCreateCalendar
      -- Edit calendar actions
    | OpenEditCalendarModal HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Toggl.TogglWorkspace
    | EditCalendarSelectProject Toggl.TogglProject
    | EditCalendarNameChanged String
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
    | SubmitEditCalendar
    | DeleteCalendar HabitCalendar.HabitCalendarId
      -- Stop timer actions
    | StopRunningTimer
    | DismissStopTimerError
      -- Webhook debug actions
    | ClearWebhookEvents


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo TogglWorkspaceId Toggl.TogglProjectId String String Zone -- calendarInfo, workspaceId, projectId, startDate, endDate, userZone
    | StopTogglTimer TogglWorkspaceId TimeEntryId
    | ClearWebhookEventsRequest
    | UpdateCalendar HabitCalendar.HabitCalendarId String Toggl.TogglWorkspaceId Toggl.TogglProjectId Color Color -- calendarId, name, workspaceId, projectId, successColor, nonzeroColor
    | DeleteCalendarRequest HabitCalendar.HabitCalendarId


{-| Info needed to create a calendar from fetched time entries.
-}
type alias CalendarInfo =
    { calendarId : HabitCalendarId
    , calendarName : String
    , successColor : Color
    , nonzeroColor : Color
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
