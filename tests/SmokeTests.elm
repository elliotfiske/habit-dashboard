module SmokeTests exposing (appTests, main)

import Backend
import Effect.Http
import Effect.Lamdera
import Effect.Test exposing (HttpResponse(..))
import Effect.Time
import Frontend
import Html.Attributes
import Test exposing (describe)
import Test.Html.Query
import Test.Html.Selector
import Types exposing (BackendModel, BackendMsg, FrontendModel, FrontendMsg, ToBackend, ToFrontend)
import Url exposing (Url)


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests


{-| January 1, 2026 00:00:00 UTC in milliseconds since epoch.
-}
january1st2026 : Int
january1st2026 =
    1767225600000


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ Effect.Test.start
        "Dashboard title renders correctly"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\client1 ->
                [ client1.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Habit Dashboard" ])
                ]
            )
        ]
    , Effect.Test.start
        "Future days should show dash instead of zero"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\client1 ->
                [ -- January 1, 2026 is a Thursday
                  -- January 2 is a future day and should show "-"
                  client1.checkView 100
                    (Test.Html.Query.find [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-02") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
                    )
                ]
            )
        ]
    , Effect.Test.start
        "Create a new Habit Calendar from Toggl project"
        (Effect.Time.millisToPosix january1st2026)
        configWithMockToggl
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\client1 ->
                [ -- Initially, demo calendar should be visible since no real calendars exist
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Example Habit" ])
                , -- Should see "Not connected to Toggl" initially
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Not connected to Toggl" ])
                , -- Click "Connect to Toggl" button to fetch workspaces
                  client1.clickButton 100 "Connect to Toggl"
                , -- After clicking, should see "Connecting to Toggl..."
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Connecting to Toggl..." ])
                , -- After the mock API responds, should see "Connected" status and the "+ New Calendar" button
                  client1.checkView 1000
                    (Test.Html.Query.has [ Test.Html.Selector.text "+ New Calendar" ])
                , client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Connected" ])
                , -- Click the "+ New Calendar" button to open the modal
                  client1.clickButton 100 "New Calendar"
                , -- Verify the modal opened with title "Create New Calendar"
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Create New Calendar" ])
                , -- Should see "Select Workspace" label
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Select Workspace" ])
                , -- Should see the mock workspace
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Test Workspace" ])
                , -- Click the workspace button to select it
                  client1.clickButton 100 "Test Workspace"
                , -- After selecting workspace, should show "Loading projects..."
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Loading projects..." ])
                , -- After projects load, should see the mock project
                  client1.checkView 1000
                    (Test.Html.Query.has [ Test.Html.Selector.text "Test Project" ])
                , -- Click the project button to select it
                  client1.clickButton 100 "Test Project"
                , -- Calendar name input should be auto-filled with project name
                  client1.checkView 100
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "type" "text") ]
                        >> Test.Html.Query.has
                            [ Test.Html.Selector.attribute (Html.Attributes.attribute "value" "Test Project") ]
                    )
                , -- Create button should now be enabled
                  client1.checkView 100
                    (Test.Html.Query.find
                        [ Test.Html.Selector.text "Create" ]
                        >> Test.Html.Query.hasNot
                            [ Test.Html.Selector.attribute (Html.Attributes.attribute "disabled" "true") ]
                    )
                , -- Click "Create" button to submit the form
                  client1.clickButton 100 "Create"
                , -- Modal should close (no longer see "Create New Calendar" heading)
                  client1.checkView 100
                    (Test.Html.Query.hasNot [ Test.Html.Selector.text "Create New Calendar" ])
                , -- After time entries are fetched, the new calendar should appear
                  -- The demo calendar should no longer be visible
                  client1.checkView 2000
                    (Test.Html.Query.hasNot [ Test.Html.Selector.text "Example Habit" ])
                , -- The new "Test Project" calendar should be visible
                  client1.checkView 100
                    (Test.Html.Query.has [ Test.Html.Selector.text "Test Project" ])
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


{-| Config for tests that need mock Toggl API responses.
-}
configWithMockToggl : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
configWithMockToggl =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = mockTogglApiHandler
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }


{-| Mock HTTP handler that returns fake Toggl API responses.
-}
mockTogglApiHandler : Effect.Http.Request -> HttpResponse
mockTogglApiHandler request =
    if request.url == "https://api.track.toggl.com/api/v9/workspaces" then
        -- Return mock workspaces
        JsonResponse
            """[
                {"id": 12345, "name": "Test Workspace", "organization_id": 1}
            ]"""

    else if String.contains "/projects" request.url then
        -- Return mock projects for any workspace
        JsonResponse
            """[
                {"id": 67890, "workspace_id": 12345, "name": "Test Project", "color": "#9e5bd9"}
            ]"""

    else if String.contains "/search/time_entries" request.url then
        -- Return mock time entries (last 28 days with some sample data)
        JsonResponse
            """[
                {
                    "time_entries": [
                        {
                            "id": 1,
                            "project_id": 67890,
                            "description": "Working on tests",
                            "start": "2025-12-30T10:00:00Z",
                            "stop": "2025-12-30T11:30:00Z",
                            "seconds": 5400
                        },
                        {
                            "id": 2,
                            "project_id": 67890,
                            "description": "More work",
                            "start": "2025-12-31T14:00:00Z",
                            "stop": "2025-12-31T15:00:00Z",
                            "seconds": 3600
                        }
                    ]
                }
            ]"""

    else
        NetworkErrorResponse


appTests : Test.Test
appTests =
    describe "App tests" (List.map Effect.Test.toTest tests)
