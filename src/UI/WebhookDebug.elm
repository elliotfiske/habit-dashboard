module UI.WebhookDebug exposing (view)

{-| Webhook debug log display for troubleshooting webhook events.

This module provides UI components for displaying webhook debug information.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Types exposing (FrontendModel, FrontendMsg, WebhookDebugEntry)


{-| Display webhook debug log for troubleshooting webhook events.
Shows nothing if the log is empty, otherwise displays a collapsible card
with all recent webhook events.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    if List.isEmpty model.webhookDebugLog then
        Html.text ""

    else
        Html.div [ Attr.class "mt-8" ]
            [ Html.div [ Attr.class "card bg-base-100 shadow-lg" ]
                [ Html.div [ Attr.class "card-body" ]
                    [ Html.h2 [ Attr.class "card-title text-base-content" ]
                        [ Html.text "Webhook Debug Log"
                        , Html.span [ Attr.class "badge badge-info" ]
                            [ Html.text (String.fromInt (List.length model.webhookDebugLog)) ]
                        ]
                    , Html.div [ Attr.class "space-y-2 max-h-96 overflow-y-auto" ]
                        (List.map viewEntry model.webhookDebugLog)
                    ]
                ]
            ]


{-| View a single webhook debug entry.
Displays as a collapsible item with event type badge, description, and raw JSON payload.
-}
viewEntry : WebhookDebugEntry -> Html FrontendMsg
viewEntry entry =
    let
        badgeClass : String
        badgeClass =
            case entry.eventType of
                "validation" ->
                    "badge-success"

                "event" ->
                    "badge-info"

                "error" ->
                    "badge-error"

                _ ->
                    "badge-ghost"
    in
    Html.div [ Attr.class "collapse collapse-arrow bg-base-200" ]
        [ Html.input [ Attr.type_ "checkbox", Attr.class "peer" ] []
        , Html.div [ Attr.class "collapse-title font-medium flex items-center gap-2" ]
            [ Html.span [ Attr.class ("badge " ++ badgeClass) ]
                [ Html.text entry.eventType ]
            , Html.text entry.description
            ]
        , Html.div [ Attr.class "collapse-content" ]
            [ Html.pre [ Attr.class "bg-base-300 p-3 rounded text-xs overflow-x-auto" ]
                [ Html.text entry.rawJson ]
            ]
        ]
