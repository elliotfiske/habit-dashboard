module Backend exposing (BackendApp, Model, UnwrappedBackendApp, app, app_)

import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Lamdera as L
import Types exposing (BackendModel, BackendMsg(..), ToBackend(..), ToFrontend)


type alias Model =
    BackendModel


{-| Type alias for the Effect-wrapped backend application record.
-}
type alias BackendApp =
    { init : ( Model, Command BackendOnly ToFrontend BackendMsg )
    , update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
    , updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
    , subscriptions : Model -> Subscription BackendOnly BackendMsg
    }


{-| Type alias for the unwrapped backend application (uses standard Cmd/Sub).
-}
type alias UnwrappedBackendApp =
    { init : ( Model, Cmd BackendMsg )
    , update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
    , updateFromFrontend : String -> String -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
    , subscriptions : Model -> Sub BackendMsg
    }


app : UnwrappedBackendApp
app =
    Effect.Lamdera.backend
        L.broadcast
        L.sendToFrontend
        app_


app_ : BackendApp
app_ =
    { init = init
    , update = update
    , updateFromFrontend = updateFromFrontend
    , subscriptions = subscriptions
    }


subscriptions : Model -> Subscription BackendOnly BackendMsg
subscriptions _ =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        ]


init : ( Model, Command restriction toMsg BackendMsg )
init =
    ( { message = "Hello!" }
    , Command.none
    )


update : BackendMsg -> Model -> ( Model, Command restriction toMsg BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Command.none )

        ClientConnected _ _ ->
            ( model, Command.none )

        ClientDisconnected _ _ ->
            ( model, Command.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command restriction toMsg BackendMsg )
updateFromFrontend _ _ msg model =
    case msg of
        NoOpToBackend ->
            ( model, Command.none )
