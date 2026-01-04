module Frontend exposing (..)

import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command)
import Effect.Lamdera
import Effect.Subscription as Subscription exposing (Subscription)
import Html
import Html.Attributes as Attr
import Lamdera as L
import Types exposing (..)
import Url


type alias Model =
    FrontendModel


app =
    Effect.Lamdera.frontend
        L.sendToBackend
        app_


app_ : { init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command restriction toMsg FrontendMsg ), onUrlRequest : UrlRequest -> FrontendMsg, onUrlChange : Url.Url -> FrontendMsg, update : FrontendMsg -> Model -> ( Model, Command a b FrontendMsg ), updateFromBackend : ToFrontend -> Model -> ( Model, Command c d FrontendMsg ), subscriptions : e -> Subscription f msg, view : Model -> Effect.Browser.Document FrontendMsg }
app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = \m -> Subscription.none
    , view = view
    }


init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command restriction toMsg FrontendMsg )
init _ key =
    ( { key = key
      , message = "Hello world!"
      }
    , Command.none
    )


update : FrontendMsg -> Model -> ( Model, Command restriction toMsg FrontendMsg )
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


updateFromBackend : ToFrontend -> Model -> ( Model, Command restriction toMsg FrontendMsg )
updateFromBackend msg model =
    case msg of
        NoOpToFrontend ->
            ( model, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = ""
    , body =
        [ Html.div [ Attr.style "text-align" "center", Attr.style "padding-top" "40px" ]
            [ Html.img [ Attr.src "https://lamdera.app/lamdera-logo-black.png", Attr.width 150 ] []
            , Html.div
                [ Attr.style "font-family" "sans-serif"
                , Attr.style "padding-top" "40px"
                ]
                [ Html.text model.message ]
            ]
        ]
    }
