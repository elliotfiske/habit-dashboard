module SmokeTests exposing (appTests, main)

import Backend
import Effect.Lamdera
import Effect.Test exposing (HttpResponse(..))
import Effect.Time
import Frontend
import Test exposing (describe)
import Test.Html.Query
import Test.Html.Selector
import Types exposing (BackendModel, BackendMsg, FrontendModel, FrontendMsg, ToBackend, ToFrontend)
import Url exposing (Url)


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ Effect.Test.start
        "Check basic render functionality"
        (Effect.Time.millisToPosix 0)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\client1 ->
                [ client1.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.exactText "Hello world!" ])
                ]
            )
        ]
    ]


safeUrl : Url
safeUrl =
    { protocol = Url.Https
    , host = "habit-dashboard.lamdera.app"
    , port_ = Nothing
    , path = "/"
    , query = Nothing
    , fragment = Nothing
    }


config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = always NetworkErrorResponse
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }


appTests : Test.Test
appTests =
    describe "App tests" (List.map Effect.Test.toTest tests)
