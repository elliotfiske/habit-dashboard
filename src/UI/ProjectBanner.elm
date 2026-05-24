module UI.ProjectBanner exposing (view)

{-| Active project banner UI.

Displays the current active project served by the Monofocus Hub, with a
refresh button and a "Start Timer" button.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Monofocus
import Time
import Types exposing (FrontendModel, FrontendMsg(..), MonofocusProject, MonofocusStatus(..), RunningEntry(..))


{-| Render the active project banner.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    case model.monofocusStatus of
        MonofocusNotFetched ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base opacity-60" ] [ Html.text "Loading..." ]
                , refreshButton False
                ]

        MonofocusLoading ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , Html.span [ Attr.class "text-base opacity-60" ] [ Html.text "Refreshing..." ]
                    ]
                , refreshButton True
                ]

        MonofocusOneActive project ->
            let
                buttonDisabled : Bool
                buttonDisabled =
                    isMonofocusRunning model
            in
            Html.div []
                [ viewBanner "bg-success" "text-success-content"
                    [ viewHeader
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.span [ Attr.class "text-lg font-semibold" ] [ Html.text project.title ]
                        , Html.span [ Attr.class "text-base opacity-80" ] [ Html.text (formatDateRange project) ]
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ startTimerButton buttonDisabled project.title
                        , refreshButton False
                        ]
                    ]
                , viewStartTimerError model.startMonofocusTimerError
                ]

        MonofocusNoActive ->
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base font-semibold" ] [ Html.text "No active project" ]
                , refreshButton False
                ]

        MonofocusError errorMsg ->
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base" ] [ Html.text ("Monofocus error: " ++ errorMsg) ]
                , refreshButton False
                ]


{-| Common banner container.
-}
viewBanner : String -> String -> List (Html FrontendMsg) -> Html FrontendMsg
viewBanner bgColor textColor content =
    Html.div
        [ Attr.class ("card shadow-lg p-4 mb-6 " ++ bgColor ++ " " ++ textColor)
        , Attr.attribute "data-testid" "project-banner"
        ]
        [ Html.div [ Attr.class "grid grid-cols-1 sm:grid-cols-[auto_1fr_auto] items-center gap-2 sm:gap-4" ]
            content
        ]


{-| The "Active Project" header label.
-}
viewHeader : Html FrontendMsg
viewHeader =
    Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60 mr-4" ]
        [ Html.text "Active Project" ]


{-| Refresh button with optional disabled state during loading.
-}
refreshButton : Bool -> Html FrontendMsg
refreshButton isLoading =
    Html.button
        [ Attr.class "btn btn-sm btn-ghost"
        , Attr.disabled isLoading
        , Events.onClick RefreshMonofocusProject
        , Attr.attribute "data-testid" "refresh-monofocus-button"
        ]
        [ Html.text "↻" ]


{-| Check if the currently running timer is for the Monofocus project.
-}
isMonofocusRunning : FrontendModel -> Bool
isMonofocusRunning model =
    case model.runningEntry of
        NoRunningEntry ->
            False

        RunningEntry payload ->
            payload.projectId == Just Monofocus.monofocusProjectId


{-| Start timer button with disabled state.
-}
startTimerButton : Bool -> String -> Html FrontendMsg
startTimerButton isDisabled projectName =
    Html.button
        [ Attr.class "btn btn-sm btn-primary"
        , Attr.disabled isDisabled
        , Events.onClick (StartMonofocusTimer projectName)
        , Attr.attribute "data-testid" "start-monofocus-button"
        ]
        [ Html.text "Start Timer" ]


{-| Error banner for start timer failures.
-}
viewStartTimerError : Maybe String -> Html FrontendMsg
viewStartTimerError maybeError =
    case maybeError of
        Nothing ->
            Html.text ""

        Just errorMsg ->
            Html.div
                [ Attr.class "alert alert-error mt-2"
                , Attr.attribute "data-testid" "start-timer-error"
                ]
                [ Html.span [] [ Html.text errorMsg ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick DismissStartMonofocusTimerError
                    , Attr.id "dismiss-start-timer-error"
                    ]
                    [ Html.text "✕" ]
                ]


{-| Format the date range for display.
-}
formatDateRange : MonofocusProject -> String
formatDateRange project =
    "(" ++ formatDate project.startDate ++ " - " ++ formatDate project.endDate ++ ")"


formatDate : Time.Posix -> String
formatDate posix =
    let
        month : Time.Month
        month =
            Time.toMonth Time.utc posix

        day : Int
        day =
            Time.toDay Time.utc posix

        monthStr : String
        monthStr =
            case month of
                Time.Jan ->
                    "Jan"

                Time.Feb ->
                    "Feb"

                Time.Mar ->
                    "Mar"

                Time.Apr ->
                    "Apr"

                Time.May ->
                    "May"

                Time.Jun ->
                    "Jun"

                Time.Jul ->
                    "Jul"

                Time.Aug ->
                    "Aug"

                Time.Sep ->
                    "Sep"

                Time.Oct ->
                    "Oct"

                Time.Nov ->
                    "Nov"

                Time.Dec ->
                    "Dec"
    in
    monthStr ++ " " ++ String.fromInt day
