module UI.ProjectBanner exposing (isDateOutOfRange, view)

{-| Active project banner UI.

Displays the current active project from Coda with status indicators
and a refresh button.

-}

import Coda
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Time
import Types exposing (CodaProject, CodaStatus(..), FrontendModel, FrontendMsg(..), RunningEntry(..))


{-| Render the active project banner.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    case model.codaStatus of
        CodaNotFetched ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base opacity-60" ] [ Html.text "Loading..." ]
                , refreshButton False
                ]

        CodaLoading ->
            viewBanner "bg-base-300" "text-base-content"
                [ viewHeader
                , Html.div [ Attr.class "flex items-center gap-2" ]
                    [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                    , Html.span [ Attr.class "text-base opacity-60" ] [ Html.text "Refreshing..." ]
                    ]
                , refreshButton True
                ]

        CodaOneActive project ->
            let
                dateWarning : Bool
                dateWarning =
                    isDateOutOfRange model.currentTime project

                ( bgColor, textColor ) =
                    if dateWarning then
                        ( "bg-warning", "text-warning-content" )

                    else
                        ( "bg-success", "text-success-content" )

                buttonDisabled : Bool
                buttonDisabled =
                    isMonofocusRunning model
            in
            Html.div []
                [ viewBanner bgColor textColor
                    [ viewHeader
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.span [ Attr.class "text-lg font-semibold" ] [ Html.text project.name ]
                        , Html.span [ Attr.class "text-base opacity-80" ] [ Html.text (formatDateRange project) ]
                        , if dateWarning then
                            Html.span [ Attr.class "badge badge-warning badge-sm" ] [ Html.text "Dates out of range" ]

                          else
                            Html.text ""
                        ]
                    , Html.div [ Attr.class "flex items-center gap-2" ]
                        [ startTimerButton buttonDisabled project.name
                        , refreshButton False
                        ]
                    ]
                , viewStartTimerError model.startMonofocusTimerError
                ]

        CodaInvalidCount count ->
            let
                message : String
                message =
                    if count == 0 then
                        "No active project in Coda"

                    else
                        "Multiple active projects (" ++ String.fromInt count ++ ") - fix in Coda"
            in
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base font-semibold" ] [ Html.text message ]
                , refreshButton False
                ]

        CodaError errorMsg ->
            viewBanner "bg-error" "text-error-content"
                [ viewHeader
                , Html.div [ Attr.class "text-base" ] [ Html.text ("Coda error: " ++ errorMsg) ]
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
        , Events.onClick RefreshCodaProject
        , Attr.attribute "data-testid" "refresh-coda-button"
        ]
        [ Html.text "↻" ]


{-| Check if the current date is outside the project's date range.

Note: End dates from Coda are stored as midnight (00:00:00) of that day.
We treat the end date as inclusive, meaning the entire final day is valid.

-}
isDateOutOfRange : Maybe Time.Posix -> CodaProject -> Bool
isDateOutOfRange maybeNow project =
    case maybeNow of
        Nothing ->
            False

        Just now ->
            let
                nowMillis : Int
                nowMillis =
                    Time.posixToMillis now

                beforeStart : Bool
                beforeStart =
                    case project.startDate of
                        Just start ->
                            nowMillis < Time.posixToMillis start

                        Nothing ->
                            False

                afterEnd : Bool
                afterEnd =
                    case project.endDate of
                        Just end ->
                            let
                                oneDayMillis : Int
                                oneDayMillis =
                                    24 * 60 * 60 * 1000
                            in
                            -- End date is stored as midnight, so add one day
                            -- to include the entire final day as valid
                            nowMillis >= Time.posixToMillis end + oneDayMillis

                        Nothing ->
                            False
            in
            beforeStart || afterEnd


{-| Check if the currently running timer is for the Monofocus project.
-}
isMonofocusRunning : FrontendModel -> Bool
isMonofocusRunning model =
    case model.runningEntry of
        NoRunningEntry ->
            False

        RunningEntry payload ->
            payload.projectId == Just Coda.monofocusProjectId


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
formatDateRange : CodaProject -> String
formatDateRange project =
    let
        formatDate : Time.Posix -> String
        formatDate posix =
            let
                -- Use UTC for simplicity; could use user's zone if passed in
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

        startStr : String
        startStr =
            Maybe.map formatDate project.startDate
                |> Maybe.withDefault "?"

        endStr : String
        endStr =
            Maybe.map formatDate project.endDate
                |> Maybe.withDefault "?"
    in
    "(" ++ startStr ++ " - " ++ endStr ++ ")"
