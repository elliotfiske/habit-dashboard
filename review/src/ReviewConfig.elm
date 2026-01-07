module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import Docs.ReviewAtDocs
import NoConfusingPrefixOperator
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeAnnotationInLetIn
import NoMissingTypeExpose
import NoPrematureLetComputation
import NoSimpleLetBody
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule as Rule exposing (Rule)


config : List Rule
config =
    let
        -- LamderaRPC.elm is a library file that gets overwritten in production
        -- RPC.elm uses a magic function name that Lamdera looks for
        lamderaRpcFiles : List String
        lamderaRpcFiles =
            [ "src/LamderaRPC.elm", "src/RPC.elm" ]
    in
    [ Docs.ReviewAtDocs.rule
    , NoConfusingPrefixOperator.rule
    , NoDebug.Log.rule
        |> Rule.ignoreErrorsForFiles (lamderaRpcFiles ++ [ "src/Backend.elm" ])
    , NoDebug.TodoOrToString.rule
        |> Rule.ignoreErrorsForDirectories [ "tests/" ]
    , NoExposingEverything.rule
        |> Rule.ignoreErrorsForDirectories [ "src/Evergreen/" ]
        |> Rule.ignoreErrorsForFiles lamderaRpcFiles
    , NoImportingEverything.rule []
        |> Rule.ignoreErrorsForFiles lamderaRpcFiles
    , NoMissingTypeAnnotation.rule
        |> Rule.ignoreErrorsForFiles lamderaRpcFiles
    , NoMissingTypeAnnotationInLetIn.rule
        |> Rule.ignoreErrorsForFiles lamderaRpcFiles
    , NoMissingTypeExpose.rule
    , NoSimpleLetBody.rule
    , NoPrematureLetComputation.rule
    , NoUnused.Exports.rule
        |> Rule.ignoreErrorsForDirectories [ "tests/", "src/Evergreen/" ]
        |> Rule.ignoreErrorsForFiles ([ "src/Env.elm", "src/CalendarDict.elm", "src/HabitCalendar.elm", "src/Toggl.elm" ] ++ lamderaRpcFiles)
    , NoUnused.Parameters.rule
        |> Rule.ignoreErrorsForDirectories [ "src/Evergreen/"]
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    ]
