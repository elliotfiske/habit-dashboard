module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    )

import CalendarDict exposing (CalendarDict)
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Time exposing (Posix, Zone)
import Url exposing (Url)


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , currentTime : Maybe Posix
    , currentZone : Maybe Zone
    , calendars : CalendarDict
    }


type alias BackendModel =
    { calendars : CalendarDict
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg
    | GotTime Posix
    | GotZone Zone


type ToBackend
    = NoOpToBackend
    | RequestCalendars


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId


type ToFrontend
    = NoOpToFrontend
    | CalendarsUpdated CalendarDict
