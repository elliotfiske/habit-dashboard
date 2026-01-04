module Frontend exposing (FrontendApp, Model, UnwrappedFrontendApp, app, app_)

import Browser
import Browser.Navigation
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera
import Effect.Subscription as Subscription exposing (Subscription)
import Html
import Html.Attributes as Attr
import Lamdera as L
import Types exposing (FrontendModel, FrontendMsg(..), ToBackend, ToFrontend(..))
import Url


type alias Model =
    FrontendModel


app_ : FrontendApp
app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = \_ -> Subscription.none
    , view = view
    }


init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
init _ key =
    ( { key = key
      , message = "Hello world!"
      }
    , Command.none
    )


update : FrontendMsg -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        UrlClicked _ ->
            -- Currently unneeded (everything is on one page)
            ( model, Command.none )

        UrlChanged _ ->
            -- Currently unneeded (everything is on one page)
            ( model, Command.none )

        NoOpFrontendMsg ->
            ( model, Command.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = "Habit Dashboard"
    , body =
        [ Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css" ] []
        , Html.div [ Attr.class "min-h-screen bg-base-200 flex flex-col items-center justify-center p-8" ]
            [ Html.div [ Attr.class "card bg-base-100 shadow-xl p-8" ]
                [ Html.img
                    [ Attr.src "https://lamdera.app/lamdera-logo-black.png"
                    , Attr.width 150
                    , Attr.class "mx-auto"
                    ]
                    []
                , Html.h1 [ Attr.class "text-3xl font-bold text-center mt-6" ]
                    [ Html.text "Habit Dashboard" ]
                , Html.p [ Attr.class "text-center text-base-content/70 mt-2" ]
                    [ Html.text model.message ]
                , Html.div [ Attr.class "flex gap-2 justify-center mt-6" ]
                    [ Html.button [ Attr.class "btn btn-primary" ] [ Html.text "Get Started" ]
                    , Html.button [ Attr.class "btn btn-ghost" ] [ Html.text "Learn More" ]
                    ]
                ]
            ]
        ]
    }


{-| Type alias for the frontend application configuration record (Effect-wrapped version).
-}
type alias FrontendApp =
    { init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , onUrlRequest : UrlRequest -> FrontendMsg
    , onUrlChange : Url.Url -> FrontendMsg
    , update : FrontendMsg -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
    , subscriptions : Model -> Subscription FrontendOnly FrontendMsg
    , view : Model -> Effect.Browser.Document FrontendMsg
    }


{-| Type alias for the unwrapped frontend application (uses standard Cmd/Sub).
-}
type alias UnwrappedFrontendApp =
    { init : Url.Url -> Browser.Navigation.Key -> ( Model, Cmd FrontendMsg )
    , view : Model -> Browser.Document FrontendMsg
    , update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
    , updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
    , subscriptions : Model -> Sub FrontendMsg
    , onUrlRequest : Browser.UrlRequest -> FrontendMsg
    , onUrlChange : Url.Url -> FrontendMsg
    }


app : UnwrappedFrontendApp
app =
    Effect.Lamdera.frontend
        L.sendToBackend
        app_
