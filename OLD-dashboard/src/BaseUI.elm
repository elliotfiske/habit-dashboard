module BaseUI exposing (genericModal)

import Html exposing (..)
import Html.Attributes exposing (class)
import Material.Icons as Filled
import Material.Icons.Types exposing (Coloring(..))
import Types exposing (..)
import W.Button
import W.Modal


genericModal : String -> Html.Html FrontendMsg -> Html.Html FrontendMsg
genericModal title content =
    W.Modal.view []
        { isOpen = True
        , onClose = Just (SetModalState Closed)
        , content =
            [ div [ class "p-8" ]
                [ div [ class "flex justify-between" ]
                    [ h2 [ class "text-3xl text-black font-bold" ] [ text title ]
                    , closeButton (SetModalState Closed)
                    ]
                , content
                ]
            ]
        }


closeButton : FrontendMsg -> Html.Html FrontendMsg
closeButton msg =
    W.Button.view [ W.Button.icon ]
        { label =
            [ Filled.close
                16
                Inherit
            ]
        , onClick = msg
        }
