module Evergreen.V2.Types exposing (..)

import Browser
import Browser.Navigation
import Dict
import Http
import Lamdera
import Time
import Url


type alias TimeEntries =
    Dict.Dict String Int


type NetworkRequest value
    = NotRequested
    | Loading
    | Success value
    | Failure Http.Error


type alias FrontendModel =
    { key : Browser.Navigation.Key
    , currentTime : Maybe Time.Posix
    , currentZone : Maybe Time.Zone
    , timeEntries : NetworkRequest TimeEntries
    }


type alias BackendModel =
    { timeEntries : NetworkRequest TimeEntries
    , debouncingTimeEntries : Bool
    }


type FrontendMsg
    = UrlClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg
    | FetchCurrentTime Time.Posix
    | FetchCurrentZone Time.Zone
    | FetchTimeEntries


type ToBackend
    = NoOpToBackend
    | FrontendWantsUpdate


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Lamdera.SessionId Lamdera.ClientId
    | GotTimeEntryData (Result Http.Error TimeEntries)
    | DelayedInit
    | Tick Time.Posix


type ToFrontend
    = BackendUpdated (NetworkRequest TimeEntries)
