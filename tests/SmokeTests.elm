module SmokeTests exposing (appTests, main)

import Backend
import CalendarDict
import Effect.Lamdera
import Effect.Test exposing (HttpResponse(..))
import Effect.Time
import Frontend
import HabitCalendar
import Html.Attributes
import Json.Encode as E
import Test exposing (describe)
import Test.Html.Query
import Test.Html.Selector
import Time
import Toggl
import Types exposing (BackendModel, BackendMsg(..), FrontendModel, FrontendMsg(..), RunningEntry(..), ToBackend(..), ToFrontend(..))
import Url exposing (Url)


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests


{-| January 1, 2026 00:00:00 UTC in milliseconds since epoch.
-}
january1st2026 : Int
january1st2026 =
    1767225600000


{-| Mock data for testing
-}
mockWorkspace : Toggl.TogglWorkspace
mockWorkspace =
    { id = Toggl.TogglWorkspaceId 12345
    , name = "Test Workspace"
    , organizationId = 1
    }


mockProject : Toggl.TogglProject
mockProject =
    { id = Toggl.TogglProjectId 159657524
    , workspaceId = Toggl.TogglWorkspaceId 12345
    , name = "Chores"
    , color = "#9E77ED"
    }


mockTimeEntry : Toggl.TimeEntry
mockTimeEntry =
    { id = Toggl.TimeEntryId 999
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , description = Just "Cleaning"
    , start = Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000) + (30 * 60 * 1000)))
    , duration = 1800
    }


mockTimeEntry2 : Toggl.TimeEntry
mockTimeEntry2 =
    { id = Toggl.TimeEntryId 1000
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , description = Just "More cleaning"
    , start = Time.millisToPosix (january1st2026 + (14 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (14 * 60 * 60 * 1000) + (45 * 60 * 1000)))
    , duration = 2700
    }


mockUpdatedTimeEntry : Toggl.TimeEntry
mockUpdatedTimeEntry =
    { id = Toggl.TimeEntryId 999
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , description = Just "Cleaning (updated)"
    , start = Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000) + (60 * 60 * 1000)))
    , duration = 3600
    }


mockCalendarInfo : Types.CalendarInfo
mockCalendarInfo =
    { calendarId = HabitCalendar.HabitCalendarId "159657524"
    , calendarName = "Cleaning"
    }


mockWebhookPayload : Toggl.WebhookPayload
mockWebhookPayload =
    { id = Toggl.TimeEntryId 999
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , workspaceId = Toggl.TogglWorkspaceId 12345
    , description = Just "Cleaning"
    , start = Time.millisToPosix (january1st2026 + (9 * 60 * 60 * 1000))
    , stop = Nothing
    , duration = -1
    }


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ Effect.Test.start
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
        "Create Calendar UI shows projects from selected workspace"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- First, send backend message with workspaces
                  Effect.Test.backendUpdate 100
                    (GotTogglWorkspaces
                        actions.clientId
                        (Ok [ mockWorkspace ])
                    )
                , -- Check that Connect button appeared (workspaces received)
                  actions.checkView 200
                    (Test.Html.Query.has
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "create-calendar-button") ]
                    )
                ]
            )
        ]
    , Effect.Test.start
        "Calendar shows time entry data from API call"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Send workspaces and projects to set up
                  Effect.Test.backendUpdate 100
                    (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglProjects actions.clientId (Ok [ mockProject ]))
                , -- Send time entries for the calendar (30 minutes on Jan 1st)
                  Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry ])
                    )
                , -- Check that calendar appears with the time entry data (30 minutes)
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
                    )
                ]
            )
        ]
    , Effect.Test.start
        "Calendar updates when new time entry added (webhook created simulation)"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Create initial calendar with one entry (30 min)
                  Effect.Test.backendUpdate 100
                    (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglProjects actions.clientId (Ok [ mockProject ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry ])
                    )
                , -- Verify initial state: 30 minutes
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
                    )
                , -- Simulate webhook "created" by sending updated data with both entries (30 + 45 = 75 min)
                  Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry, mockTimeEntry2 ])
                    )
                , -- Verify updated state: 75 minutes total
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "75" ]
                    )
                ]
            )
        ]
    , Effect.Test.start
        "Calendar updates when time entry modified (webhook updated simulation)"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Create initial calendar with one entry (30 min)
                  Effect.Test.backendUpdate 100
                    (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglProjects actions.clientId (Ok [ mockProject ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry ])
                    )
                , -- Verify initial state: 30 minutes
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
                    )
                , -- Simulate webhook "updated" by sending modified entry (now 60 min)
                  Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockUpdatedTimeEntry ])
                    )
                , -- Verify updated state: 60 minutes
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "60" ]
                    )
                ]
            )
        ]
    , Effect.Test.start
        "Calendar updates when time entry deleted (webhook deleted simulation)"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Create initial calendar with two entries (30 + 45 = 75 min)
                  Effect.Test.backendUpdate 100
                    (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglProjects actions.clientId (Ok [ mockProject ]))
                , Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry, mockTimeEntry2 ])
                    )
                , -- Verify initial state: 75 minutes
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "75" ]
                    )
                , -- Simulate webhook "deleted" by sending data with one entry removed (only 45 min left)
                  Effect.Test.backendUpdate 100
                    (GotTogglTimeEntries
                        actions.clientId
                        mockCalendarInfo
                        mockWorkspace.id
                        mockProject.id
                        Time.utc
                        (Ok [ mockTimeEntry2 ])
                    )
                , -- Verify updated state: 45 minutes (one entry removed)
                  actions.checkView 200
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "45" ]
                    )
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
