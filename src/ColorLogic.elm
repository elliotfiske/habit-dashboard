module ColorLogic exposing (colorToHex, hexToColor, isLight, muteColor)

{-| Color manipulation using escherlies/elm-color.

Provides utilities for:

  - Converting between hex strings and Color
  - Checking if a color is light (for text contrast)
  - Creating muted/lightened colors for backgrounds

-}

import Color exposing (Color)


{-| Convert a Color to a hex string for HTML color inputs.
Returns format "#rrggbb".
-}
colorToHex : Color -> String
colorToHex =
    Color.toCssString


{-| Parse a hex string to a Color.
Accepts formats: "#rgb", "#rrggbb", "rgb", "rrggbb".
Returns a default blue if parsing fails.
-}
hexToColor : String -> Color
hexToColor hex =
    Color.fromHexUnsafe hex


{-| Check if a color is light (needs dark text for readability).
Uses CIELAB color space for perceptually accurate results.
-}
isLight : Color -> Bool
isLight =
    Color.isLight


{-| Create a muted (lightened) version of a color.
Used for deriving nonzeroColor from successColor.
Increases lightness by blending toward white.
-}
muteColor : Color -> Color
muteColor =
    Color.mapLightness (\l -> l + (1 - l) * 0.5)
