module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , CalendarInfo
    , CreateCalendarModal
    , FrontendModel
    , FrontendMsg(..)
    , ModalState(..)
    , RunningEntry(..)
    , ToBackend(..)
    , ToFrontend(..)
    , TogglConnectionStatus(..)
    )

import CalendarDict exposing (CalendarDict)
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import HabitCalendar exposing (HabitCalendarId)
import Http
import Time exposing (Posix, Zone)
import Toggl exposing (TimeEntry, TogglProject, TogglWorkspace, TogglWorkspaceId)
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
    }


{-| Modal state for the frontend.
-}
type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal


{-| State for the "Create Calendar" modal.
-}
type alias CreateCalendarModal =
    { selectedWorkspace : Maybe TogglWorkspace
    , selectedProject : Maybe TogglProject
    , calendarName : String
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
      -- Modal actions
    | OpenCreateCalendarModal
    | CloseModal
    | SelectWorkspace TogglWorkspace
    | SelectProject TogglProject
    | CalendarNameChanged String
    | SubmitCreateCalendar


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | FetchTogglWorkspaces
    | FetchTogglProjects TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo TogglWorkspaceId Toggl.TogglProjectId String String -- calendarInfo, workspaceId, projectId, startDate, endDate


{-| Info needed to create a calendar from fetched time entries.
-}
type alias CalendarInfo =
    { calendarId : HabitCalendarId
    , calendarName : String
    }


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Toggl.TogglApiError (List TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Toggl.TogglApiError (List TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo (Result Toggl.TogglApiError (List TimeEntry))
    | GotWebhookValidation (Result Http.Error ())


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated CalendarDict
    | TogglWorkspacesReceived (Result String (List TogglWorkspace))
    | TogglProjectsReceived (Result String (List TogglProject))
    | TogglTimeEntriesReceived (Result String (List TimeEntry))
    | RunningEntryUpdated RunningEntry
