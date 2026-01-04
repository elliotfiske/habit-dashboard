module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    )

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Url exposing (Url)


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , message : String
    }


type alias BackendModel =
    { message : String
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg


type ToBackend
    = NoOpToBackend


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId


type ToFrontend
    = NoOpToFrontend
