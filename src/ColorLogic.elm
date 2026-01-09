module ColorLogic exposing (isColorDark, muteColor)

{-| Color manipulation and contrast calculations.

This module provides utilities for working with hex colors, including:

  - Determining if a color is dark (for choosing readable text colors)
  - Creating muted/desaturated versions of colors for backgrounds

-}


{-| Determine if a hex color is dark (needs white text for readability).
Uses relative luminance calculation: L = 0.2126\_R + 0.7152\_G + 0.0722\*B
-}
isColorDark : String -> Bool
isColorDark hexColor =
    let
        -- Remove # prefix if present
        cleanHex : String
        cleanHex =
            if String.startsWith "#" hexColor then
                String.dropLeft 1 hexColor

            else
                hexColor

        -- Parse hex pairs to RGB values (0-255)
        parseHexPair : String -> Int
        parseHexPair pair =
            String.toList pair
                |> List.map
                    (\char ->
                        case char of
                            '0' ->
                                0

                            '1' ->
                                1

                            '2' ->
                                2

                            '3' ->
                                3

                            '4' ->
                                4

                            '5' ->
                                5

                            '6' ->
                                6

                            '7' ->
                                7

                            '8' ->
                                8

                            '9' ->
                                9

                            'A' ->
                                10

                            'a' ->
                                10

                            'B' ->
                                11

                            'b' ->
                                11

                            'C' ->
                                12

                            'c' ->
                                12

                            'D' ->
                                13

                            'd' ->
                                13

                            'E' ->
                                14

                            'e' ->
                                14

                            'F' ->
                                15

                            'f' ->
                                15

                            _ ->
                                0
                    )
                |> (\vals ->
                        case vals of
                            [ high, low ] ->
                                high * 16 + low

                            _ ->
                                0
                   )

        -- Extract RGB components
        r : Float
        r =
            String.slice 0 2 cleanHex |> parseHexPair |> toFloat

        g : Float
        g =
            String.slice 2 4 cleanHex |> parseHexPair |> toFloat

        b : Float
        b =
            String.slice 4 6 cleanHex |> parseHexPair |> toFloat

        -- Calculate relative luminance (using sRGB coefficients)
        luminance : Float
        luminance =
            (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    in
    -- Colors with luminance below 0.5 are considered dark
    luminance < 0.5


{-| Create a muted (very light, low opacity) version of a hex color for backgrounds.
Blends the color with white to create a subtle tint.
-}
muteColor : String -> String
muteColor hexColor =
    let
        -- Remove # prefix if present
        cleanHex : String
        cleanHex =
            if String.startsWith "#" hexColor then
                String.dropLeft 1 hexColor

            else
                hexColor

        -- Parse hex pair to int
        parseHexPair : String -> Int
        parseHexPair pair =
            String.toList pair
                |> List.map
                    (\char ->
                        case Char.toUpper char of
                            '0' ->
                                0

                            '1' ->
                                1

                            '2' ->
                                2

                            '3' ->
                                3

                            '4' ->
                                4

                            '5' ->
                                5

                            '6' ->
                                6

                            '7' ->
                                7

                            '8' ->
                                8

                            '9' ->
                                9

                            'A' ->
                                10

                            'B' ->
                                11

                            'C' ->
                                12

                            'D' ->
                                13

                            'E' ->
                                14

                            'F' ->
                                15

                            _ ->
                                0
                    )
                |> (\vals ->
                        case vals of
                            [ high, low ] ->
                                high * 16 + low

                            _ ->
                                0
                   )

        -- Extract RGB components
        r : Int
        r =
            String.slice 0 2 cleanHex |> parseHexPair

        g : Int
        g =
            String.slice 2 4 cleanHex |> parseHexPair

        b : Int
        b =
            String.slice 4 6 cleanHex |> parseHexPair

        -- Mix with white (255,255,255) at 70% white / 30% color for more visible tint
        mixedR : Int
        mixedR =
            round (255 * 0.7 + toFloat r * 0.3)

        mixedG : Int
        mixedG =
            round (255 * 0.7 + toFloat g * 0.3)

        mixedB : Int
        mixedB =
            round (255 * 0.7 + toFloat b * 0.3)

        -- Convert back to hex
        toHex : Int -> String
        toHex n =
            let
                high : Int
                high =
                    n // 16

                low : Int
                low =
                    modBy 16 n

                hexDigit : Int -> String
                hexDigit val =
                    if val < 10 then
                        String.fromInt val

                    else
                        case val of
                            10 ->
                                "a"

                            11 ->
                                "b"

                            12 ->
                                "c"

                            13 ->
                                "d"

                            14 ->
                                "e"

                            15 ->
                                "f"

                            _ ->
                                "0"
            in
            hexDigit high ++ hexDigit low
    in
    "#" ++ toHex mixedR ++ toHex mixedG ++ toHex mixedB
