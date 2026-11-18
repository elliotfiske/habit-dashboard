module UI.Flower exposing (Mood(..), view)

{-| A potted flower drawn in SVG: thriving, happy, or wilting.

Every difference between moods is a CSS transform, fill or opacity, so when the
mood changes the flower droops or perks up smoothly instead of snapping (see
the `flower-*` classes in `src/input.css`).

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr
import UI.Flower.SecondHead as SecondHead


type Mood
    = Thriving
    | Happy
    | Wilting


view : Mood -> Html msg
view mood =
    let
        wilting : Bool
        wilting =
            mood == Wilting
    in
    Svg.svg
        [ SvgAttr.viewBox "0 0 200 230"
        , SvgAttr.class "w-full h-full"
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" (moodLabel mood)
        , Attr.attribute "data-testid" ("flower-" ++ String.toLower (moodLabel mood))
        ]
        [ Svg.g
            [ SvgAttr.class
                (if wilting then
                    ""

                 else
                    "flower-sway"
                )
            ]
            [ stemSegment "M100 178 L100 128" wilting
            , leaf "M0 0 C -12 -14, -34 -12, -40 -4 C -30 4, -12 6, 0 0 Z" ( 100, 160 ) (pick mood 20 12 -40) wilting
            , leaf "M0 0 C 12 -14, 34 -12, 40 -4 C 30 4, 12 6, 0 0 Z" ( 100, 146 ) (pick mood -20 -12 40) wilting
            , SecondHead.view (mood == Thriving)
            , Svg.g
                [ SvgAttr.class "flower-part"
                , Attr.style "transform-origin" "100px 128px"
                , Attr.style "transform" ("rotate(" ++ String.fromFloat (pick mood -8 0 80) ++ "deg)")
                ]
                [ stemSegment "M100 128 C 98 112, 102 96, 100 80" wilting
                , head mood
                ]
            ]
        , fallenPetal wilting
        , pot
        , sparkles (mood == Thriving)
        ]


moodLabel : Mood -> String
moodLabel mood =
    case mood of
        Thriving ->
            "Thriving"

        Happy ->
            "Happy"

        Wilting ->
            "Wilting"


{-| A value for each mood: thriving, happy, wilting.
-}
pick : Mood -> Float -> Float -> Float -> Float
pick mood thriving happy wilting =
    case mood of
        Thriving ->
            thriving

        Happy ->
            happy

        Wilting ->
            wilting


stemSegment : String -> Bool -> Svg msg
stemSegment d wilting =
    Svg.path
        [ SvgAttr.d d
        , SvgAttr.class "flower-part"
        , SvgAttr.fill "none"
        , SvgAttr.strokeWidth "6"
        , SvgAttr.strokeLinecap "round"
        , Attr.style "stroke" (color wilting "#16a34a" "#8a9a5b")
        ]
        []


leaf : String -> ( Float, Float ) -> Float -> Bool -> Svg msg
leaf d ( x, y ) degrees wilting =
    Svg.path
        [ SvgAttr.d d
        , SvgAttr.class "flower-part"
        , Attr.style "transform" (translate x y ++ " rotate(" ++ String.fromFloat degrees ++ "deg)")
        , Attr.style "fill" (color wilting "#22c55e" "#a3a86b")
        ]
        []


{-| Petals, a center and a face, centered on the top of the stem.
-}
head : Mood -> Svg msg
head mood =
    let
        wilting : Bool
        wilting =
            mood == Wilting

        petal : Int -> Svg msg
        petal index =
            Svg.ellipse
                [ SvgAttr.cx "0"
                , SvgAttr.cy "-21"
                , SvgAttr.rx "11"
                , SvgAttr.ry "19"
                , SvgAttr.transform ("rotate(" ++ String.fromInt (index * 45) ++ ")")
                ]
                []
    in
    Svg.g
        [ SvgAttr.class "flower-part"
        , Attr.style "transform"
            (translate 100 74 ++ " rotate(" ++ String.fromFloat (pick mood 0 0 25) ++ "deg) scale(" ++ String.fromFloat (pick mood 1.12 1 0.9) ++ ")")
        ]
        [ Svg.g
            [ SvgAttr.class "flower-part"
            , Attr.style "fill" (petalColor mood)
            ]
            (List.map petal (List.range 0 7))
        , Svg.circle
            [ SvgAttr.r "15"
            , SvgAttr.class "flower-part"
            , Attr.style "fill" (color wilting "#facc15" "#c9b26b")
            ]
            []
        , face mood
        ]


petalColor : Mood -> String
petalColor mood =
    case mood of
        Thriving ->
            "#ec4899"

        Happy ->
            "#f472b6"

        Wilting ->
            "#bfa2aa"


{-| Once the second head sprouts, the eyes glance nervously over at it and
the smile goes wobbly.
-}
face : Mood -> Svg msg
face mood =
    let
        wilting : Bool
        wilting =
            mood == Wilting

        eye : String -> Svg msg
        eye cx =
            Svg.circle [ SvgAttr.cx cx, SvgAttr.cy "-3", SvgAttr.r "1.8", SvgAttr.fill "#3f2d1d" ] []
    in
    Svg.g []
        [ Svg.g
            [ SvgAttr.class "flower-part"
            , Attr.style "transform" (translate (pick mood 3 0 0) (pick mood 0.8 0 0))
            ]
            [ eye "-5", eye "5" ]
        , Svg.path
            [ SvgAttr.d
                (case mood of
                    Thriving ->
                        -- a nervous wobbly line: what is that thing
                        "M-6 6 Q-3 3 0 6 Q3 9 6 6"

                    Happy ->
                        "M-6 3 Q0 10 6 3"

                    Wilting ->
                        "M-5 8 Q0 3 5 8"
                )
            , SvgAttr.fill "none"
            , SvgAttr.stroke "#3f2d1d"
            , SvgAttr.strokeWidth "1.6"
            , SvgAttr.strokeLinecap "round"
            ]
            []
        , Svg.circle
            [ SvgAttr.cx "-9"
            , SvgAttr.cy "3"
            , SvgAttr.r "2.4"
            , SvgAttr.fill "#fb7185"
            , SvgAttr.class "flower-part"
            , Attr.style "opacity" (color wilting "0.7" "0")
            ]
            []
        , Svg.circle
            [ SvgAttr.cx "9"
            , SvgAttr.cy "3"
            , SvgAttr.r "2.4"
            , SvgAttr.fill "#fb7185"
            , SvgAttr.class "flower-part"
            , Attr.style "opacity" (color wilting "0.7" "0")
            ]
            []
        ]


{-| A petal that dropped onto the soil. Only visible while wilting.
-}
fallenPetal : Bool -> Svg msg
fallenPetal wilting =
    Svg.ellipse
        [ SvgAttr.cx "0"
        , SvgAttr.cy "0"
        , SvgAttr.rx "5"
        , SvgAttr.ry "10"
        , SvgAttr.fill "#bfa2aa"
        , SvgAttr.class "flower-part"
        , Attr.style "transform" (translate 126 174 ++ " rotate(70deg)")
        , Attr.style "opacity" (color wilting "0" "1")
        ]
        []


pot : Svg msg
pot =
    Svg.g []
        [ Svg.ellipse [ SvgAttr.cx "100", SvgAttr.cy "180", SvgAttr.rx "38", SvgAttr.ry "5", SvgAttr.fill "#5b3a1e" ] []
        , Svg.path [ SvgAttr.d "M64 190 L136 190 L128 226 L72 226 Z", SvgAttr.fill "#ea580c" ] []
        , Svg.rect [ SvgAttr.x "58", SvgAttr.y "178", SvgAttr.width "84", SvgAttr.height "14", SvgAttr.rx "3", SvgAttr.fill "#c2410c" ] []
        ]


{-| Twinkling sparkles around the flower once the goal is met.
-}
sparkles : Bool -> Svg msg
sparkles visible =
    if visible then
        Svg.g [ SvgAttr.fill "#fde047" ]
            (List.map sparkle [ ( 40, 50, "0s" ), ( 158, 36, "0.6s" ), ( 184, 160, "1.2s" ), ( 30, 120, "0.9s" ) ])

    else
        Svg.g [] []


sparkle : ( Float, Float, String ) -> Svg msg
sparkle ( x, y, delay ) =
    Svg.g [ Attr.style "transform" (translate x y) ]
        [ Svg.path
            [ SvgAttr.d "M0 -9 L2.2 -2.2 L9 0 L2.2 2.2 L0 9 L-2.2 2.2 L-9 0 L-2.2 -2.2 Z"
            , SvgAttr.class "flower-twinkle"
            , Attr.style "animation-delay" delay
            ]
            []
        ]


translate : Float -> Float -> String
translate x y =
    "translate(" ++ String.fromFloat x ++ "px, " ++ String.fromFloat y ++ "px)"


{-| The healthy or wilting version of a color (or any other style value).
-}
color : Bool -> String -> String -> String
color wilting healthy wilted =
    if wilting then
        wilted

    else
        healthy
