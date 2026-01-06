module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , CalendarInfo
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    , TogglConnectionStatus(..)
    )

import CalendarDict exposing (CalendarDict)
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Http
import Effect.Lamdera
import HabitCalendar exposing (HabitCalendarId)
import Time exposing (Posix, Zone)
import Toggl exposing (ApiKey, TimeEntry, TogglProject, TogglWorkspace, TogglWorkspaceId)
import Url exposing (Url)


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Posix
    , currentZone : Maybe Zone
    , calendars : CalendarDict
    , togglApiKey : String -- Input field for API key
    , togglStatus : TogglConnectionStatus
    }


{-| Status of the Toggl API connection.
-}
type TogglConnectionStatus
    = NotConnected
    | Connecting
    | Connected (List TogglWorkspace)
    | ConnectionError String


type alias BackendModel =
    { calendars : CalendarDict
    , togglApiKey : Maybe ApiKey
    , togglWorkspaces : List TogglWorkspace
    , togglProjects : List TogglProject
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg
    | GotTime Posix
    | GotZone Zone
    | TogglApiKeyChanged String
    | SubmitTogglApiKey


type ToBackend
    = NoOpToBackend
    | RequestCalendars
    | SetTogglApiKey ApiKey
    | FetchTogglWorkspaces
    | FetchTogglProjects TogglWorkspaceId
    | FetchTogglTimeEntries CalendarInfo TogglWorkspaceId String String -- calendarInfo, workspaceId, startDate, endDate


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
    | GotTogglWorkspaces Effect.Lamdera.ClientId (Result Effect.Http.Error (List TogglWorkspace))
    | GotTogglProjects Effect.Lamdera.ClientId (Result Effect.Http.Error (List TogglProject))
    | GotTogglTimeEntries Effect.Lamdera.ClientId CalendarInfo (Result Effect.Http.Error (List TimeEntry))


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated CalendarDict
    | TogglWorkspacesReceived (Result String (List TogglWorkspace))
    | TogglProjectsReceived (Result String (List TogglProject))
    | TogglTimeEntriesReceived (Result String (List TimeEntry))
