module SmokeTests exposing (appTests, main)

import Backend
import Dict
import Effect.Browser.Dom as Dom
import Effect.Http
import Effect.Lamdera
import Effect.Test exposing (HttpRequest, HttpResponse(..))
import Effect.Time
import Expect
import Frontend
import HabitCalendar
import Html.Attributes
import Iso8601
import Json.Encode as E
import Test exposing (describe)
import Test.Html.Query
import Test.Html.Selector
import Time
import Toggl
import Types exposing (BackendModel, BackendMsg(..), FrontendModel, FrontendMsg, ToBackend, ToFrontend)
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
    , successColor = "#805AD5"
    , nonzeroColor = "#D8B4FE"
    , isOrangetheory = False
    }


{-| Mock calendar info for Orangetheory tracking.
-}
mockOrangetheoryCalendarInfo : Types.CalendarInfo
mockOrangetheoryCalendarInfo =
    { calendarId = HabitCalendar.HabitCalendarId "159881404"
    , calendarName = "Exercise"
    , successColor = "#2da608"
    , nonzeroColor = "#82f75f"
    , isOrangetheory = True
    }


{-| Mock time entry with Orangetheory in description.
-}
mockOrangetheoryEntry1 : Toggl.TimeEntry
mockOrangetheoryEntry1 =
    { id = Toggl.TimeEntryId 1001
    , projectId = Just (Toggl.TogglProjectId 159881404)
    , description = Just "Orangetheory workout"
    , start = Time.millisToPosix (january1st2026 + (2 * 24 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (2 * 24 * 60 * 60 * 1000) + (60 * 60 * 1000)))
    , duration = 3600
    }


{-| Second mock Orangetheory entry on a different day.
-}
mockOrangetheoryEntry2 : Toggl.TimeEntry
mockOrangetheoryEntry2 =
    { id = Toggl.TimeEntryId 1002
    , projectId = Just (Toggl.TogglProjectId 159881404)
    , description = Just "Orangetheory class"
    , start = Time.millisToPosix (january1st2026 + (4 * 24 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (4 * 24 * 60 * 60 * 1000) + (60 * 60 * 1000)))
    , duration = 3600
    }


{-| Mock entry without Orangetheory in description (should not count).
-}
mockNonOrangetheoryEntry : Toggl.TimeEntry
mockNonOrangetheoryEntry =
    { id = Toggl.TimeEntryId 1003
    , projectId = Just (Toggl.TogglProjectId 159881404)
    , description = Just "Running"
    , start = Time.millisToPosix (january1st2026 + (6 * 24 * 60 * 60 * 1000))
    , stop = Just (Time.millisToPosix (january1st2026 + (6 * 24 * 60 * 60 * 1000) + (30 * 60 * 1000)))
    , duration = 1800
    }


{-| Mock running timer webhook payload.
-}
mockRunningEntry : Toggl.WebhookPayload
mockRunningEntry =
    { id = Toggl.TimeEntryId 888
    , projectId = Just (Toggl.TogglProjectId 159657524)
    , workspaceId = Toggl.TogglWorkspaceId 12345
    , description = Just "Working on tests"
    , start = Time.millisToPosix january1st2026
    , stop = Nothing
    , duration = -1 -- Running entries have duration -1
    }



-- JSON ENCODERS FOR HTTP MOCKING


{-| Encode a workspace to JSON (matches Toggl API response format).
-}
encodeWorkspace : Toggl.TogglWorkspace -> E.Value
encodeWorkspace workspace =
    E.object
        [ ( "id", E.int (Toggl.togglWorkspaceIdToInt workspace.id) )
        , ( "name", E.string workspace.name )
        , ( "organization_id", E.int workspace.organizationId )
        ]


{-| Encode a project to JSON (matches Toggl API response format).
-}
encodeProject : Toggl.TogglProject -> E.Value
encodeProject project =
    E.object
        [ ( "id", E.int (Toggl.togglProjectIdToInt project.id) )
        , ( "workspace_id", E.int (Toggl.togglWorkspaceIdToInt project.workspaceId) )
        , ( "name", E.string project.name )
        , ( "color", E.string project.color )
        ]


{-| Encode inner time entry (id, seconds, start, stop only - description/project at group level).
-}
encodeInnerTimeEntry : Toggl.TimeEntry -> E.Value
encodeInnerTimeEntry entry =
    E.object
        [ ( "id", E.int (Toggl.timeEntryIdToInt entry.id) )
        , ( "start", E.string (Iso8601.fromTime entry.start) )
        , ( "stop"
          , case entry.stop of
                Just stopTime ->
                    E.string (Iso8601.fromTime stopTime)

                Nothing ->
                    E.null
          )
        , ( "seconds", E.int entry.duration )
        ]


{-| Encode a time entry group in the Reports API search format.
The actual API puts description and project\_id at the group level, not inside time\_entries.
-}
encodeTimeEntryGroup : Toggl.TimeEntry -> E.Value
encodeTimeEntryGroup entry =
    E.object
        [ ( "description"
          , case entry.description of
                Just desc ->
                    E.string desc

                Nothing ->
                    E.null
          )
        , ( "project_id"
          , case entry.projectId of
                Just pid ->
                    E.int (Toggl.togglProjectIdToInt pid)

                Nothing ->
                    E.null
          )
        , ( "time_entries", E.list encodeInnerTimeEntry [ entry ] )
        ]


{-| Encode time entries in the Reports API search format.
The API returns: [{ description, project\_id, time\_entries: [...] }, ...]
Each entry becomes its own group with description at the top level.
-}
encodeTimeEntriesSearchResponse : List Toggl.TimeEntry -> E.Value
encodeTimeEntriesSearchResponse entries =
    E.list encodeTimeEntryGroup entries


{-| Create HTTP metadata for a successful response.
-}
okMetadata : String -> Effect.Http.Metadata
okMetadata url =
    { url = url
    , statusCode = 200
    , statusText = "OK"
    , headers = Dict.empty
    }


{-| Helper to create a standard test with common boilerplate.
Takes a description and a function that receives client actions and returns test steps.
-}
standardTest :
    String
    -> (Effect.Test.FrontendActions ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel -> List (Effect.Test.Action ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel))
    -> Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
standardTest description testSteps =
    Effect.Test.start
        description
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            testSteps
        ]


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ standardTest "Future days should show dash instead of zero"
        (\client1 ->
                [ -- January 1, 2026 is a Thursday
                  -- January 2 is a future day and should show "-"
                  client1.checkView 100
                    (Test.Html.Query.find [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-02") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.text "-" ]
                    )
                ]
        )
    , standardTest "Create Calendar UI shows projects from selected workspace"
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
    , standardTest "Calendar shows time entry data from API call"
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
    , standardTest "Calendar updates when new time entry added (webhook created simulation)"
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
    , standardTest "Calendar updates when time entry modified (webhook updated simulation)"
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
    , standardTest "Calendar updates when time entry deleted (webhook deleted simulation)"
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
    , standardTest "Stop button UI elements have correct test IDs"
        (\actions ->
            [ -- Verify no-timer banner exists with correct test ID
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "no-timer-banner") ]
                    >> Test.Html.Query.has
                        [ Test.Html.Selector.text "No timer running" ]
                )
            ]
        )
    , standardTest "Stop button not visible when no timer running"
        (\actions ->
            [ -- Verify stop button does NOT exist
              actions.checkView 100
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute
                        (Html.Attributes.attribute "data-testid" "stop-timer-button")
                    ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
    , standardTest "Edit calendar updates name"
        (\actions ->
            [ Effect.Test.backendUpdate 100
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
            , actions.checkView 200
                (Test.Html.Query.has [ Test.Html.Selector.text "Cleaning" ])
            , actions.click 100 (Dom.id "edit-calendar-159657524")
            , actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "edit-calendar-name-input") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.attribute (Html.Attributes.value "Cleaning") ]
                )
            , actions.input 100 (Dom.id "edit-calendar-name-input") "Chores Updated"
            , actions.click 100 (Dom.id "submit-edit-calendar")
            , actions.checkView 200
                (Test.Html.Query.has [ Test.Html.Selector.text "Chores Updated" ])
            ]
        )
    , standardTest "Edit calendar Save button disabled when name is empty"
        (\actions ->
            [ Effect.Test.backendUpdate 100
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
            , actions.click 100 (Dom.id "edit-calendar-159657524")
            , actions.input 100 (Dom.id "edit-calendar-name-input") ""
            , actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-edit-calendar") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled True ]
                )
            , actions.input 100 (Dom.id "edit-calendar-name-input") "New Name"
            , actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-edit-calendar") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled False ]
                )
            ]
        )
    , standardTest "Delete calendar removes it from view"
        (\actions ->
            [ Effect.Test.backendUpdate 100
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
            , actions.checkView 200
                (Test.Html.Query.has [ Test.Html.Selector.text "Cleaning" ])
            , actions.click 100 (Dom.id "delete-calendar-159657524")
            , actions.checkView 200
                (Test.Html.Query.has [ Test.Html.Selector.text "Example Habit" ])
            ]
        )
    , standardTest "HTTP mocking: Connect button triggers API call and receives mocked response"
        (\actions ->
            [ -- Initially shows "Not connected"
              actions.checkView 100
                (Test.Html.Query.has [ Test.Html.Selector.text "Not connected to Toggl" ])

            -- Click "Connect to Toggl" button - this sends FetchTogglWorkspaces to backend
            -- which triggers an HTTP request that gets intercepted by handleHttpRequest
            , actions.click 100 (Dom.id "connect-toggl-button")

            -- Wait for the HTTP response to be processed and UI to update
            -- Should now show "Connected · 1 workspace(s)" from mocked response
            , actions.checkView 500
                (Test.Html.Query.has [ Test.Html.Selector.text "Connected" ])

            -- Should also show the mocked workspace count
            , actions.checkView 100
                (Test.Html.Query.has [ Test.Html.Selector.text "1 workspace" ])

            -- The Create Calendar button should now be visible
            , actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "create-calendar-button") ]
                )
            ]
        )
    , standardTest "Running timer shows description and stop button"
        (\actions ->
            [ -- Broadcast running entry to all frontends
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockRunningEntry))
            , -- Verify running timer banner appears with description
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "running-timer-banner") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "Working on tests" ]
                )
            , -- Verify stop button is visible
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "stop-timer-button") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "Stop" ]
                )
            , -- Verify no-timer banner is NOT visible
              actions.checkView 100
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "no-timer-banner") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
    , standardTest "Stop timer clears running entry"
        (\actions ->
            [ -- Broadcast running entry
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockRunningEntry))
            , -- Verify timer is showing
              actions.checkView 200
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "running-timer-banner") ]
                )
            , -- Click stop button
              actions.click 100 (Dom.id "stop-timer-button")
            , -- Verify running timer banner is gone (optimistic update)
              actions.checkView 200
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "running-timer-banner") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            , -- Verify no-timer banner is back
              actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "no-timer-banner") ]
                )
            ]
        )
    , standardTest "Stop timer error shows error banner and restores timer"
        (\actions ->
            [ -- Broadcast running entry
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockRunningEntry))
            , -- Click stop button
              actions.click 200 (Dom.id "stop-timer-button")
            , -- Verify timer is gone (optimistic update)
              actions.checkView 100
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "running-timer-banner") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            , -- Simulate backend receiving an error from Toggl API
              Effect.Test.backendUpdate 100
                (GotStopTimerResponse actions.clientId (Err (Toggl.HttpError Effect.Http.NetworkError)))
            , -- Verify error banner appears
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "stop-timer-error") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "Network error" ]
                )
            , -- Verify timer is restored
              actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "running-timer-banner") ]
                )
            ]
        )
    , standardTest "Dismiss stop timer error"
        (\actions ->
            [ -- Setup: broadcast running entry and simulate error response
              Effect.Test.backendUpdate 100
                (BroadcastRunningEntry (Types.RunningEntry mockRunningEntry))
            , Effect.Test.backendUpdate 100
                (GotStopTimerResponse actions.clientId (Err (Toggl.HttpError Effect.Http.NetworkError)))
            , -- Verify error banner exists
              actions.checkView 200
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "stop-timer-error") ]
                )
            , -- Click dismiss button
              actions.click 100 (Dom.id "dismiss-error-button")
            , -- Verify error banner is gone
              actions.checkView 200
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "stop-timer-error") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
    , standardTest "Create calendar modal opens with correct UI elements"
        (\actions ->
            [ -- Setup: send workspaces so Connect button appears (wait for auto-project-fetch to complete)
              Effect.Test.backendUpdate 100
                (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
            , -- Click Create Calendar button to open modal
              actions.click 500 (Dom.id "create-calendar-button")
            , -- Verify modal opened
              actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "create-calendar-modal") ]
                )
            , -- Submit button should be disabled (no project selected yet)
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-create-calendar") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled True ]
                )
            , -- Workspace button should be visible
              actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.text "Test Workspace" ]
                )
            , -- Select workspace from dropdown
              actions.click 100 (Dom.id "workspace-select-12345")
            , -- After selecting workspace, project selector should show project from the auto-fetched projects
              actions.checkView 500
                (Test.Html.Query.has
                    [ Test.Html.Selector.text "Chores" ]
                )
            , -- Click on the project (use checkView + has to verify it's clickable, then use data-testid find)
              actions.click 100 (Dom.id "project-select-159657524")
            , -- Calendar name should auto-fill with project name
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "calendar-name-input") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.attribute (Html.Attributes.value "Chores") ]
                )
            , -- Submit button should now be enabled
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-create-calendar") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.disabled False ]
                )
            ]
        )
    , standardTest "Close modal without submitting"
        (\actions ->
            [ -- Setup: send workspaces
              Effect.Test.backendUpdate 100
                (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
            , -- Open create calendar modal
              actions.click 100 (Dom.id "create-calendar-button")
            , -- Verify modal is open
              actions.checkView 100
                (Test.Html.Query.has
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "create-calendar-modal") ]
                )
            , -- Click close button
              actions.click 100 (Dom.id "close-modal-button")
            , -- Verify modal is closed
              actions.checkView 200
                (Test.Html.Query.findAll
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "create-calendar-modal") ]
                    >> Test.Html.Query.count (Expect.equal 0)
                )
            ]
        )
    , standardTest "Connection error shows error message"
        (\actions ->
            [ -- Simulate backend receiving API error
              Effect.Test.backendUpdate 100
                (GotTogglWorkspaces actions.clientId
                    (Err (Toggl.RateLimited { secondsUntilReset = 60, message = "API rate limited" }))
                )
            , -- Verify rate limit message appears
              actions.checkView 200
                (Test.Html.Query.has [ Test.Html.Selector.text "Rate Limit Exceeded" ])
            ]
        )
    , standardTest "Past days with no entries show 0"
        (\actions ->
            [ -- Setup: create calendar with time entry only on Jan 1st
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
            , -- Dec 31 is a past day with no entries, should show "0"
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2025-12-31") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "0" ]
                )
            , -- Jan 1st has entries, should show "30"
              actions.checkView 100
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "day-2026-01-01") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
                )
            ]
        )
    , standardTest "Orangetheory counter shows correct count based on description filter"
        (\actions ->
            [ -- Setup: create Orangetheory calendar with mixed entries
              -- (2 with "Orangetheory" in description, 1 without)
              Effect.Test.backendUpdate 100
                (GotTogglWorkspaces actions.clientId (Ok [ mockWorkspace ]))
            , Effect.Test.backendUpdate 100
                (GotTogglProjects actions.clientId (Ok [ mockProject ]))
            , Effect.Test.backendUpdate 100
                (GotTogglTimeEntries
                    actions.clientId
                    mockOrangetheoryCalendarInfo
                    mockWorkspace.id
                    mockProject.id
                    Time.utc
                    (Ok [ mockOrangetheoryEntry1, mockOrangetheoryEntry2, mockNonOrangetheoryEntry ])
                )
            , -- Verify the Orangetheory counter shows "2/8" (only entries with "Orangetheory" in description)
              actions.checkView 200
                (Test.Html.Query.find
                    [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "orangetheory-counter") ]
                    >> Test.Html.Query.has [ Test.Html.Selector.text "2/8" ]
                )
            ]
        )
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
    , handleHttpRequest = handleHttpRequest
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }


{-| Handle HTTP requests by mocking Toggl API responses.

Routes requests based on URL patterns:

  - /api/v9/workspaces -> Returns mock workspaces
  - /api/v9/workspaces/{id}/projects -> Returns mock projects
  - /reports/api/v3/workspace/{id}/search/time\_entries -> Returns mock time entries

-}
handleHttpRequest : { data : Effect.Test.Data FrontendModel BackendModel, currentRequest : HttpRequest } -> HttpResponse
handleHttpRequest { currentRequest } =
    let
        url : String
        url =
            currentRequest.url
    in
    if String.contains "api.track.toggl.com/api/v9/workspaces" url && not (String.contains "/projects" url) then
        -- GET /api/v9/workspaces - Return list of workspaces
        JsonHttpResponse
            (okMetadata url)
            (E.list encodeWorkspace [ mockWorkspace ])

    else if String.contains "/projects" url then
        -- GET /api/v9/workspaces/{id}/projects - Return list of projects
        JsonHttpResponse
            (okMetadata url)
            (E.list encodeProject [ mockProject ])

    else if String.contains "reports/api/v3/workspace" url && String.contains "search/time_entries" url then
        -- POST /reports/api/v3/workspace/{id}/search/time_entries - Return time entries
        JsonHttpResponse
            (okMetadata url)
            (encodeTimeEntriesSearchResponse [ mockTimeEntry ])

    else
        -- Unhandled request - return network error
        NetworkErrorResponse


appTests : Test.Test
appTests =
    describe "App tests" (List.map Effect.Test.toTest tests)
