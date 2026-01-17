module UI.ConnectionCard exposing (view)

{-| Toggl connection status card and "Create Calendar" button.

This module displays the current Toggl connection status and provides
buttons for connecting, refreshing, and creating calendars.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Time
import TimerLogic
import Types exposing (FrontendModel, FrontendMsg(..), TogglConnectionStatus(..))


{-| Display the Toggl connection status card.
Shows different UI states based on connection status: NotConnected, Connecting,
Connected, or ConnectionError (including rate limit handling).
-}
view : FrontendModel -> Html FrontendMsg
view model =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6 mb-8" ]
        [ case model.togglStatus of
            NotConnected ->
                Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-2 text-base-content/60" ]
                        [ Html.text "Not connected to Toggl" ]
                    , Html.button
                        [ Attr.class "btn btn-outline btn-sm"
                        , Attr.id "connect-toggl-button"
                        , Events.onClick RefreshWorkspaces
                        , Attr.attribute "data-testid" "connect-toggl-button"
                        ]
                        [ Html.text "Connect to Toggl" ]
                    ]

            Connecting ->
                Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , Html.text "Connecting to Toggl..."
                    ]

            Connected workspaces ->
                Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-2 text-success" ]
                        [ Html.span [ Attr.class "text-lg" ] [ Html.text "✓" ]
                        , Html.text ("Connected · " ++ String.fromInt (List.length workspaces) ++ " workspace(s)")
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.button
                            [ Attr.class "btn btn-ghost btn-sm"
                            , Events.onClick RefreshWorkspaces
                            , Attr.title "Refresh workspaces from Toggl"
                            ]
                            [ Html.text "🔄" ]
                        , Html.button
                            [ Attr.class "btn btn-primary"
                            , Attr.id "create-calendar-button"
                            , Events.onClick OpenCreateCalendarModal
                            , Attr.attribute "data-testid" "create-calendar-button"
                            ]
                            [ Html.text "+ New Calendar" ]
                        ]
                    ]

            ConnectionError errorMsg ->
                if String.startsWith "RATE_LIMIT:" errorMsg then
                    let
                        resetTimeStr : String
                        resetTimeStr =
                            case ( model.currentTime, model.currentZone ) of
                                ( Just now, Just zone ) ->
                                    let
                                        -- Parse format: "RATE_LIMIT:seconds|message"
                                        afterPrefix : String
                                        afterPrefix =
                                            String.dropLeft 11 errorMsg

                                        parts : List String
                                        parts =
                                            String.split "|" afterPrefix

                                        secondsStr : String
                                        secondsStr =
                                            List.head parts |> Maybe.withDefault "0"

                                        seconds : Int
                                        seconds =
                                            String.toInt secondsStr |> Maybe.withDefault 3600

                                        resetPosix : Time.Posix
                                        resetPosix =
                                            Time.millisToPosix (Time.posixToMillis now + seconds * 1000)
                                    in
                                    TimerLogic.formatTimeOfDay zone resetPosix

                                _ ->
                                    "soon"
                    in
                    Html.div [ Attr.class "flex flex-col gap-3" ]
                        [ Html.div [ Attr.class "alert alert-warning" ]
                            [ Html.div [ Attr.class "flex flex-col gap-1" ]
                                [ Html.div [ Attr.class "font-semibold" ]
                                    [ Html.text "⏱️ Toggl API Rate Limit Exceeded" ]
                                , Html.div []
                                    [ Html.text ("You've hit the hourly API limit. Resets at " ++ resetTimeStr ++ ".") ]
                                , Html.div [ Attr.class "text-sm opacity-80 mt-2" ]
                                    [ Html.text "Tip: Refresh the page after that time to reconnect." ]
                                ]
                            ]
                        ]

                else
                    Html.div [ Attr.class "alert alert-error" ]
                        [ Html.text ("Connection error: " ++ errorMsg) ]
        ]
