module UI.WaterFlower exposing (view)

{-| Today's water, as a flower that's happy when the day's drinking is on pace
and wilts when it falls behind. Hidden until Med Log has sent any water.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Time
import Types exposing (FrontendModel, FrontendMsg)
import UI.Flower as Flower
import Water exposing (Pace(..))


view : FrontendModel -> Html FrontendMsg
view model =
    case ( model.currentTime, model.currentZone, model.water.syncedAt ) of
        ( Just now, Just zone, Just syncedAt ) ->
            let
                progress : Water.Progress
                progress =
                    Water.progress zone now model.water
            in
            Html.div
                [ Attr.class "card bg-base-100 shadow-lg p-4 mb-6 w-full lg:w-[26rem] shrink-0 flex flex-row items-center gap-4"
                , Attr.attribute "data-testid" "water"
                ]
                [ Html.div [ Attr.class "w-40 h-44 shrink-0" ] [ Flower.view (mood progress.pace) ]
                , Html.div [ Attr.class "flex flex-col gap-1 min-w-0 grow" ]
                    [ Html.div [ Attr.class "text-xs uppercase tracking-wide opacity-60" ] [ Html.text "Water" ]
                    , Html.div [ Attr.class "flex items-baseline gap-1" ]
                        [ Html.span [ Attr.class "text-3xl font-bold", Attr.attribute "data-testid" "water-total" ]
                            [ Html.text (String.fromInt (round progress.totalOz)) ]
                        , Html.span [ Attr.class "text-base opacity-60" ]
                            [ Html.text ("/ " ++ String.fromInt (round Water.goalOz) ++ " oz") ]
                        ]
                    , Html.div [ Attr.class "text-sm font-semibold" ] [ Html.text (message progress.pace) ]
                    , progressBar progress
                    , Html.div [ Attr.class "text-xs opacity-50" ] [ Html.text ("Updated " ++ ago now syncedAt) ]
                    ]
                ]

        _ ->
            Html.text ""


mood : Pace -> Flower.Mood
mood pace =
    case pace of
        GoalMet ->
            Flower.Thriving

        OnPace ->
            Flower.Happy

        Behind _ ->
            Flower.Wilting


message : Pace -> String
message pace =
    case pace of
        GoalMet ->
            "Goal reached!"

        OnPace ->
            "On pace"

        Behind oz ->
            "Thirsty: " ++ String.fromInt (round oz) ++ " oz behind"


{-| Today's total as a bar, with a tick where the pace says it should be by now.
-}
progressBar : Water.Progress -> Html FrontendMsg
progressBar progress =
    let
        percent : Float -> String
        percent oz =
            String.fromFloat (100 * clamp 0 1 (oz / Water.goalOz)) ++ "%"

        fill : String
        fill =
            case progress.pace of
                Behind _ ->
                    "bg-warning"

                _ ->
                    "bg-info"
    in
    Html.div [ Attr.class "relative h-3 rounded-full bg-base-300 mt-1" ]
        [ Html.div
            [ Attr.class ("absolute inset-y-0 left-0 rounded-full transition-all duration-1000 " ++ fill)
            , Attr.style "width" (percent progress.totalOz)
            ]
            []
        , Html.div
            [ Attr.class "absolute -inset-y-1 w-0.5 rounded bg-base-content opacity-60"
            , Attr.style "left" (percent progress.expectedOz)
            , Attr.title "Where today's pace says you should be by now"
            ]
            []
        ]


ago : Time.Posix -> Time.Posix -> String
ago now time =
    let
        minutes : Int
        minutes =
            (Time.posixToMillis now - Time.posixToMillis time) // 60000
    in
    if minutes < 1 then
        "just now"

    else if minutes < 60 then
        String.fromInt minutes ++ " min ago"

    else if minutes < 48 * 60 then
        String.fromInt (minutes // 60) ++ " h ago"

    else
        String.fromInt (minutes // (24 * 60)) ++ " days ago"
