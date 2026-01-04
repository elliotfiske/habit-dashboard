module Evergreen.V1.Types exposing (..)

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


type ToBackend
    = NoOpToBackend


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Lamdera.SessionId Lamdera.ClientId
    | GotTimeEntryData (Result Http.Error TimeEntries)
    | ResetTimeEntryRequestDebounce


type ToFrontend
    = BackendUpdated (NetworkRequest TimeEntries)
