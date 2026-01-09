module UI.TimerBanner exposing (view)

{-| Running timer display and error handling UI.

This module provides UI components for displaying the current Toggl timer
and handling errors from timer operations.

-}

import ColorLogic
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import TimerLogic
import Toggl exposing (TogglProject)
import Types exposing (FrontendModel, FrontendMsg(..), RunningEntry(..))


{-| Main entry point - displays error banner (if any) and the timer banner.
-}
view : FrontendModel -> List (Html FrontendMsg)
view model =
    [ stopTimerErrorBanner model.stopTimerError
    , runningTimerHeader model
    ]


{-| Display the current running timer from Toggl at the top of the page.
Shows "No timer running" when there's no active timer.
-}
runningTimerHeader : FrontendModel -> Html FrontendMsg
runningTimerHeader model =
    case model.runningEntry of
        NoRunningEntry ->
            Html.div
                [ Attr.class "card bg-base-200 text-base-content shadow-lg p-4 mb-6"
                , Attr.attribute "data-testid" "no-timer-banner"
                ]
                [ Html.div [ Attr.class "flex items-center justify-center gap-3" ]
                    [ Html.div [ Attr.class "text-center" ]
                        [ Html.div [ Attr.class "font-semibold text-lg opacity-60" ] [ Html.text "No timer running" ]
                        , Html.div [ Attr.class "text-sm opacity-40" ] [ Html.text "Start a timer in Toggl Track" ]
                        ]
                    ]
                ]

        RunningEntry payload ->
            let
                description : String
                description =
                    Maybe.withDefault "(no description)" payload.description

                timerText : String
                timerText =
                    case model.currentTime of
                        Just now ->
                            TimerLogic.relativeTimer now payload.start

                        Nothing ->
                            "--:--:--"

                -- Look up the project to get its color
                maybeProject : Maybe TogglProject
                maybeProject =
                    payload.projectId
                        |> Maybe.andThen
                            (\projectId ->
                                List.filter (\p -> p.id == projectId) model.availableProjects
                                    |> List.head
                            )

                -- Use project color if available, otherwise use default primary color
                ( bgStyle, textColorClass ) =
                    case maybeProject of
                        Just project ->
                            let
                                isDark : Bool
                                isDark =
                                    ColorLogic.isColorDark project.color
                            in
                            ( Attr.style "background-color" project.color
                            , if isDark then
                                "text-white"

                              else
                                "text-primary-content"
                            )

                        Nothing ->
                            ( Attr.class "bg-primary", "text-primary-content" )
            in
            Html.div
                [ Attr.class ("card shadow-lg p-4 mb-6 " ++ textColorClass)
                , bgStyle
                , Attr.attribute "data-testid" "running-timer-banner"
                ]
                [ Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.div [ Attr.class "flex items-center gap-3" ]
                        [ Html.span [ Attr.class "loading loading-ring loading-md" ] []
                        , Html.div []
                            [ Html.div
                                [ Attr.class "font-semibold text-lg"
                                , Attr.attribute "data-testid" "running-timer-description"
                                ]
                                [ Html.text description ]
                            , Html.div [ Attr.class "text-sm opacity-80" ] [ Html.text "Currently tracking" ]
                            ]
                        ]
                    , Html.div [ Attr.class "flex items-center gap-4" ]
                        [ Html.div
                            [ Attr.class "text-3xl font-mono font-bold"
                            , Attr.attribute "data-testid" "running-timer-duration"
                            ]
                            [ Html.text timerText ]
                        , Html.button
                            [ Attr.class "btn btn-sm btn-ghost"
                            , Events.onClick StopRunningTimer
                            , Attr.attribute "data-testid" "stop-timer-button"
                            ]
                            [ Html.text "Stop" ]
                        ]
                    ]
                ]


{-| Display error banner when stopping timer fails.
-}
stopTimerErrorBanner : Maybe String -> Html FrontendMsg
stopTimerErrorBanner maybeError =
    case maybeError of
        Nothing ->
            Html.text ""

        Just errorMsg ->
            Html.div
                [ Attr.class "alert alert-error mb-4"
                , Attr.attribute "data-testid" "stop-timer-error"
                ]
                [ Html.div [ Attr.class "flex items-center justify-between flex-1" ]
                    [ Html.span [] [ Html.text ("⚠ " ++ errorMsg) ]
                    , Html.button
                        [ Attr.class "btn btn-sm btn-ghost"
                        , Events.onClick DismissStopTimerError
                        , Attr.attribute "data-testid" "dismiss-error-button"
                        ]
                        [ Html.text "×" ]
                    ]
                ]
