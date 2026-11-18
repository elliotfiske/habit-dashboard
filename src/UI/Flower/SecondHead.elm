module UI.Flower.SecondHead exposing (view)

{-| The extra head the flower sprouts once the day's water goal is met: a
lopsided orange bloom on a side shoot, with mismatched googly eyes and its
tongue out, bobbling to its own beat.

It's always drawn, scaled to nothing until the goal is met, so it springs out
of the stem instead of popping in (see the `flower-sprout`, `flower-bobble`
and `flower-googly` classes in `src/input.css`).

-}

import Html.Attributes as Attr
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


view : Bool -> Svg msg
view grown =
    Svg.g
        [ SvgAttr.class "flower-sprout"
        , Attr.style "transform"
            (if grown then
                "scale(1)"

             else
                "scale(0)"
            )
        , Attr.style "opacity"
            (if grown then
                "1"

             else
                "0"
            )
        ]
        [ Svg.path
            [ SvgAttr.d "M100 136 C 120 142, 146 134, 158 110"
            , SvgAttr.fill "none"
            , SvgAttr.strokeWidth "5"
            , SvgAttr.strokeLinecap "round"
            , SvgAttr.stroke "#16a34a"
            ]
            []
        , Svg.g [ Attr.style "transform" "translate(160px, 102px) scale(0.84)" ]
            [ Svg.g [ SvgAttr.class "flower-bobble" ]
                [ Svg.g [ SvgAttr.fill "#fb923c" ] (List.map petal (List.range 0 5))
                , hair
                , Svg.circle [ SvgAttr.r "17", SvgAttr.fill "#a78bfa" ] []
                , googlyEye ( -6, -5 ) 7.5 "1.1s"
                , googlyEye ( 8, -3 ) 4.2 "0.7s"
                , mouth
                ]
            ]
        ]


{-| Six petals that don't agree on a size.
-}
petal : Int -> Svg msg
petal index =
    let
        big : Bool
        big =
            modBy 2 index == 0
    in
    Svg.ellipse
        [ SvgAttr.cx "0"
        , SvgAttr.cy
            (if big then
                "-22"

             else
                "-18"
            )
        , SvgAttr.rx
            (if big then
                "12"

             else
                "8"
            )
        , SvgAttr.ry
            (if big then
                "20"

             else
                "14"
            )
        , SvgAttr.transform ("rotate(" ++ String.fromInt (index * 60 + 15) ++ ")")
        ]
        []


{-| One curly hair, sticking straight up out of the middle.
-}
hair : Svg msg
hair =
    Svg.path
        [ SvgAttr.d "M0 -14 C 5 -28, -7 -34, 1 -46 C 6 -53, 14 -47, 8 -42"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "#3f2d1d"
        , SvgAttr.strokeWidth "1.6"
        , SvgAttr.strokeLinecap "round"
        ]
        []


{-| A white eye whose pupil rattles around inside it.
-}
googlyEye : ( Float, Float ) -> Float -> String -> Svg msg
googlyEye ( x, y ) radius duration =
    Svg.g [ Attr.style "transform" ("translate(" ++ String.fromFloat x ++ "px, " ++ String.fromFloat y ++ "px)") ]
        [ Svg.circle
            [ SvgAttr.r (String.fromFloat radius)
            , SvgAttr.fill "white"
            , SvgAttr.stroke "#3f2d1d"
            , SvgAttr.strokeWidth "1.2"
            ]
            []
        , Svg.circle
            [ SvgAttr.r (String.fromFloat (radius * 0.45))
            , SvgAttr.fill "#3f2d1d"
            , SvgAttr.class "flower-googly"
            , Attr.style "--googly" (String.fromFloat (radius * 0.45) ++ "px")
            , Attr.style "animation-duration" duration
            ]
            []
        ]


{-| A big open grin with the tongue hanging out.
-}
mouth : Svg msg
mouth =
    Svg.g []
        [ Svg.path
            [ SvgAttr.d "M-9 5 Q0 17 9 5 Z"
            , SvgAttr.fill "#3f2d1d"
            , SvgAttr.strokeLinejoin "round"
            , SvgAttr.stroke "#3f2d1d"
            , SvgAttr.strokeWidth "1.2"
            ]
            []
        , Svg.path
            [ SvgAttr.d "M0 9 C 0 19, 8 19, 8 9 Z"
            , SvgAttr.fill "#fb7185"
            , SvgAttr.stroke "#3f2d1d"
            , SvgAttr.strokeWidth "1"
            ]
            []
        , Svg.path
            [ SvgAttr.d "M4 10 L4 15"
            , SvgAttr.stroke "#be123c"
            , SvgAttr.strokeWidth "0.8"
            , SvgAttr.strokeLinecap "round"
            ]
            []
        ]
