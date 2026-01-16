# Edit/Delete Calendar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add edit and delete buttons to calendar cards, allowing users to rename calendars, change their Toggl project, or delete them.

**Architecture:** Extend existing modal system with `ModalEditCalendar` state. Edit button opens pre-populated modal. Delete button fires message that sends delete request to backend. Backend broadcasts updated calendar dict to all clients.

**Tech Stack:** Elm, Lamdera, lamdera/program-test for E2E tests

---

## Task 1: Add Types for Edit Modal

**Files:**
- Modify: `src/Types.elm:54-66`

**Step 1: Add EditCalendarModal type alias**

After the `CreateCalendarModal` type alias (line 65), add:

```elm
{-| State for the "Edit Calendar" modal.
-}
type alias EditCalendarModal =
    { calendarId : HabitCalendar.HabitCalendarId
    , originalProjectId : Toggl.TogglProjectId -- To detect if project changed
    , selectedWorkspace : Toggl.TogglWorkspace
    , selectedProject : Toggl.TogglProject
    , calendarName : String
    }
```

**Step 2: Add import for HabitCalendar**

Add to imports:

```elm
import HabitCalendar
```

**Step 3: Add ModalEditCalendar to ModalState type**

Change:
```elm
type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
```

To:
```elm
type ModalState
    = ModalClosed
    | ModalCreateCalendar CreateCalendarModal
    | ModalEditCalendar EditCalendarModal
```

**Step 4: Export EditCalendarModal**

Update the module exposing to include `EditCalendarModal`.

**Step 5: Run elm-review**

Run: `elm-review`
Expected: PASS (or fixable warnings)

**Step 6: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add EditCalendarModal type for edit calendar modal"
```

---

## Task 2: Add Frontend Messages for Edit/Delete

**Files:**
- Modify: `src/Types.elm:94-116`

**Step 1: Add new FrontendMsg variants**

After `SubmitCreateCalendar` (around line 110), add:

```elm
    -- Edit calendar actions
    | OpenEditCalendarModal HabitCalendar.HabitCalendar
    | EditCalendarSelectWorkspace Toggl.TogglWorkspace
    | EditCalendarSelectProject Toggl.TogglProject
    | EditCalendarNameChanged String
    | SubmitEditCalendar
    | DeleteCalendar HabitCalendar.HabitCalendarId
```

**Step 2: Run elm-review**

Run: `elm-review`
Expected: Warnings about unused constructors (expected - we'll use them next)

**Step 3: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add FrontendMsg variants for edit/delete calendar"
```

---

## Task 3: Add ToBackend Messages

**Files:**
- Modify: `src/Types.elm:118-126`

**Step 1: Add UpdateCalendar and DeleteCalendarRequest**

After `ClearWebhookEventsRequest` (line 125), add:

```elm
    | UpdateCalendar HabitCalendar.HabitCalendarId String Toggl.TogglWorkspaceId Toggl.TogglProjectId -- calendarId, name, workspaceId, projectId
    | DeleteCalendarRequest HabitCalendar.HabitCalendarId
```

**Step 2: Run elm-review**

Run: `elm-review`
Expected: Warnings about unused constructors (expected)

**Step 3: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add ToBackend messages for update/delete calendar"
```

---

## Task 4: Add Edit/Delete Buttons to Calendar Card

**Files:**
- Modify: `src/UI/CalendarView.elm:82-98`

**Step 1: Update viewCalendar to include edit/delete buttons**

Replace the `viewCalendar` function:

```elm
{-| Display individual calendar card with action buttons.
-}
viewCalendar : PointInTime -> RunningEntry -> HabitCalendar -> Html FrontendMsg
viewCalendar now runningEntry calendar =
    Html.div [ Attr.class "card bg-base-100 shadow-lg p-6" ]
        [ Html.div [ Attr.class "flex justify-between items-start mb-4" ]
            [ Html.h3 [ Attr.class "text-lg font-semibold text-base-content" ]
                [ Html.text calendar.name ]
            , Html.div [ Attr.class "flex gap-1" ]
                [ Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick (RefreshCalendar calendar.id calendar.workspaceId calendar.projectId calendar.name)
                    , Attr.title "Refresh calendar data from Toggl"
                    , Attr.attribute "data-testid" ("refresh-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "🔄" ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost"
                    , Events.onClick (OpenEditCalendarModal calendar)
                    , Attr.title "Edit calendar"
                    , Attr.attribute "data-testid" ("edit-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "✏️" ]
                , Html.button
                    [ Attr.class "btn btn-sm btn-ghost text-error"
                    , Events.onClick (DeleteCalendar calendar.id)
                    , Attr.title "Delete calendar"
                    , Attr.attribute "data-testid" ("delete-calendar-" ++ HabitCalendar.habitCalendarIdToString calendar.id)
                    ]
                    [ Html.text "🗑️" ]
                ]
            ]
        , Calendar.view now runningEntry calendar
        ]
```

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 3: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 4: Commit**

```bash
git add src/UI/CalendarView.elm
git commit -m "feat: add edit and delete buttons to calendar card header"
```

---

## Task 5: Add Edit Modal View

**Files:**
- Modify: `src/UI/Modal.elm:21-29` and add new function

**Step 1: Update view function to handle ModalEditCalendar**

Replace the `view` function:

```elm
{-| View the modal overlay if a modal is open.
Renders nothing if modal is closed, otherwise shows the appropriate modal content.
-}
view : FrontendModel -> Html FrontendMsg
view model =
    case model.modalState of
        ModalClosed ->
            Html.text ""

        ModalCreateCalendar modalData ->
            viewCreateCalendar model modalData

        ModalEditCalendar modalData ->
            viewEditCalendar model modalData
```

**Step 2: Add viewEditCalendar function**

Add after `viewCreateCalendar`:

```elm
{-| View the "Edit Calendar" modal.
Pre-populated with current calendar values.
-}
viewEditCalendar : FrontendModel -> Types.EditCalendarModal -> Html FrontendMsg
viewEditCalendar model modalData =
    Html.div [ Attr.class "fixed inset-0 z-50 flex items-center justify-center" ]
        [ -- Backdrop
          Html.div
            [ Attr.class "absolute inset-0 bg-black/50"
            , Events.onClick CloseModal
            ]
            []
        , -- Modal box
          Html.div [ Attr.class "relative z-10 bg-base-100 rounded-lg shadow-xl p-6 max-w-md w-full mx-4" ]
            [ Html.h3 [ Attr.class "font-bold text-lg mb-4" ]
                [ Html.text "Edit Calendar" ]
            , viewEditWorkspaceSelector model modalData
            , viewEditProjectSelector model modalData
            , viewEditCalendarNameInput modalData
            , Html.div [ Attr.class "flex justify-end gap-2 mt-6" ]
                [ Html.button
                    [ Attr.class "btn"
                    , Events.onClick CloseModal
                    ]
                    [ Html.text "Cancel" ]
                , Html.button
                    [ Attr.class "btn btn-primary"
                    , Attr.disabled (String.isEmpty modalData.calendarName)
                    , Events.onClick SubmitEditCalendar
                    , Attr.attribute "data-testid" "submit-edit-calendar"
                    ]
                    [ Html.text "Save" ]
                ]
            ]
        ]


{-| View workspace selector for edit modal (shows currently selected).
-}
viewEditWorkspaceSelector : FrontendModel -> Types.EditCalendarModal -> Html FrontendMsg
viewEditWorkspaceSelector model modalData =
    let
        workspaces : List TogglWorkspace
        workspaces =
            case model.togglStatus of
                Connected ws ->
                    ws

                _ ->
                    []
    in
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Workspace" ] ]
        , Html.div [ Attr.class "flex flex-wrap gap-2" ]
            (List.map (editWorkspaceButton modalData.selectedWorkspace) workspaces)
        ]


{-| Button for selecting a workspace in edit modal.
-}
editWorkspaceButton : TogglWorkspace -> TogglWorkspace -> Html FrontendMsg
editWorkspaceButton selectedWorkspace workspace =
    let
        isSelected : Bool
        isSelected =
            selectedWorkspace.id == workspace.id
    in
    Html.button
        [ Attr.class
            ("btn btn-sm "
                ++ (if isSelected then
                        "btn-primary"

                    else
                        "btn-outline"
                   )
            )
        , Events.onClick (EditCalendarSelectWorkspace workspace)
        , Attr.attribute "data-testid" ("edit-workspace-" ++ String.fromInt (Toggl.togglWorkspaceIdToInt workspace.id))
        ]
        [ Html.text workspace.name ]


{-| View project selector for edit modal.
-}
viewEditProjectSelector : FrontendModel -> Types.EditCalendarModal -> Html FrontendMsg
viewEditProjectSelector model modalData =
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Project" ] ]
        , if model.projectsLoading then
            Html.div [ Attr.class "flex items-center gap-2" ]
                [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                , Html.text "Loading projects..."
                ]

          else if List.isEmpty model.availableProjects then
            Html.p [ Attr.class "text-sm text-base-content/60" ]
                [ Html.text "No projects found" ]

          else
            Html.div [ Attr.class "flex flex-wrap gap-2 max-h-48 overflow-y-auto" ]
                (List.map (editProjectButton modalData.selectedProject) model.availableProjects)
        ]


{-| Button for selecting a project in edit modal.
-}
editProjectButton : TogglProject -> TogglProject -> Html FrontendMsg
editProjectButton selectedProject project =
    let
        isSelected : Bool
        isSelected =
            selectedProject.id == project.id
    in
    Html.button
        [ Attr.class
            ("btn btn-sm "
                ++ (if isSelected then
                        "btn-primary"

                    else
                        "btn-outline"
                   )
            )
        , Events.onClick (EditCalendarSelectProject project)
        , Attr.attribute "data-testid" ("edit-project-" ++ Toggl.togglProjectIdToString project.id)
        ]
        [ Html.text project.name ]


{-| View calendar name input for edit modal.
-}
viewEditCalendarNameInput : Types.EditCalendarModal -> Html FrontendMsg
viewEditCalendarNameInput modalData =
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Calendar Name" ] ]
        , Html.input
            [ Attr.type_ "text"
            , Attr.placeholder "Enter a name for this calendar"
            , Attr.value modalData.calendarName
            , Attr.class "input input-bordered"
            , Events.onInput EditCalendarNameChanged
            , Attr.attribute "data-testid" "edit-calendar-name-input"
            ]
            []
        ]
```

**Step 3: Update imports in Modal.elm**

Add `EditCalendarModal` to the Types import and add new message imports:

```elm
import Types exposing (CreateCalendarModal, EditCalendarModal, FrontendModel, FrontendMsg(..), ModalState(..), TogglConnectionStatus(..))
```

**Step 4: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 5: Commit**

```bash
git add src/UI/Modal.elm
git commit -m "feat: add edit calendar modal view"
```

---

## Task 6: Handle Edit Modal Messages in Frontend

**Files:**
- Modify: `src/Frontend.elm:93-243`

**Step 1: Add OpenEditCalendarModal handler**

After `CloseModal` handler, add:

```elm
        OpenEditCalendarModal calendar ->
            let
                -- Find the workspace for this calendar
                maybeWorkspace : Maybe Toggl.TogglWorkspace
                maybeWorkspace =
                    case model.togglStatus of
                        Connected workspaces ->
                            List.filter (\ws -> ws.id == calendar.workspaceId) workspaces
                                |> List.head

                        _ ->
                            Nothing

                -- Find the project for this calendar
                maybeProject : Maybe Toggl.TogglProject
                maybeProject =
                    List.filter (\p -> p.id == calendar.projectId) model.availableProjects
                        |> List.head
            in
            case ( maybeWorkspace, maybeProject ) of
                ( Just workspace, Just project ) ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { calendarId = calendar.id
                                , originalProjectId = calendar.projectId
                                , selectedWorkspace = workspace
                                , selectedProject = project
                                , calendarName = calendar.name
                                }
                      }
                    , Command.none
                    )

                _ ->
                    -- Can't edit if we don't have workspace/project info
                    ( model, Command.none )
```

**Step 2: Add EditCalendarSelectWorkspace handler**

```elm
        EditCalendarSelectWorkspace workspace ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | selectedWorkspace = workspace }
                        , projectsLoading = True
                      }
                    , Effect.Lamdera.sendToBackend (FetchTogglProjects workspace.id)
                    )

                _ ->
                    ( model, Command.none )
```

**Step 3: Add EditCalendarSelectProject handler**

```elm
        EditCalendarSelectProject project ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | selectedProject = project }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )
```

**Step 4: Add EditCalendarNameChanged handler**

```elm
        EditCalendarNameChanged newName ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar { modalData | calendarName = newName }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )
```

**Step 5: Add SubmitEditCalendar handler**

```elm
        SubmitEditCalendar ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model | modalState = ModalClosed }
                    , Effect.Lamdera.sendToBackend
                        (UpdateCalendar
                            modalData.calendarId
                            modalData.calendarName
                            modalData.selectedWorkspace.id
                            modalData.selectedProject.id
                        )
                    )

                _ ->
                    ( model, Command.none )
```

**Step 6: Add DeleteCalendar handler**

```elm
        DeleteCalendar calendarId ->
            -- Note: In production, we'd use a port for window.confirm()
            -- For now, just send the delete request directly
            ( model
            , Effect.Lamdera.sendToBackend (DeleteCalendarRequest calendarId)
            )
```

**Step 7: Update imports**

Add to Types import:
```elm
import Types exposing (FrontendModel, FrontendMsg(..), ModalState(..), RunningEntry(..), ToBackend(..), ToFrontend(..), TogglConnectionStatus(..), EditCalendarModal)
```

**Step 8: Run elm-review**

Run: `elm-review`
Expected: PASS (or warnings about unused ToBackend constructors)

**Step 9: Commit**

```bash
git add src/Frontend.elm
git commit -m "feat: handle edit/delete calendar messages in frontend"
```

---

## Task 7: Handle Update/Delete in Backend

**Files:**
- Modify: `src/Backend.elm:267-311`

**Step 1: Add UpdateCalendar handler**

After `ClearWebhookEventsRequest` handler, add:

```elm
        UpdateCalendar calendarId newName newWorkspaceId newProjectId ->
            case CalendarDict.get calendarId model.calendars of
                Just existingCalendar ->
                    let
                        projectChanged : Bool
                        projectChanged =
                            existingCalendar.projectId /= newProjectId

                        -- Update calendar with new name (and project info)
                        updatedCalendar : HabitCalendar.HabitCalendar
                        updatedCalendar =
                            { existingCalendar
                                | name = newName
                                , workspaceId = newWorkspaceId
                                , projectId = newProjectId
                            }

                        -- If project changed, clear entries (will re-fetch)
                        calendarToSave : HabitCalendar.HabitCalendar
                        calendarToSave =
                            if projectChanged then
                                { updatedCalendar
                                    | entries = Dict.empty
                                    , timeEntries = SeqDict.empty
                                }

                            else
                                updatedCalendar

                        updatedCalendars : CalendarDict.CalendarDict
                        updatedCalendars =
                            CalendarDict.insert calendarId calendarToSave model.calendars

                        -- If project changed, trigger a re-fetch
                        fetchCmd : Command BackendOnly ToFrontend BackendMsg
                        fetchCmd =
                            if projectChanged then
                                -- We need to fetch new data, but we need the client's timezone
                                -- For now, just broadcast the update - client will need to refresh
                                Command.none

                            else
                                Command.none
                    in
                    ( { model | calendars = updatedCalendars }
                    , Command.batch
                        [ Effect.Lamdera.broadcast (CalendarsUpdated updatedCalendars)
                        , fetchCmd
                        ]
                    )

                Nothing ->
                    ( model, Command.none )
```

**Step 2: Add DeleteCalendarRequest handler**

```elm
        DeleteCalendarRequest calendarId ->
            let
                updatedCalendars : CalendarDict.CalendarDict
                updatedCalendars =
                    CalendarDict.remove calendarId model.calendars
            in
            ( { model | calendars = updatedCalendars }
            , Effect.Lamdera.broadcast (CalendarsUpdated updatedCalendars)
            )
```

**Step 3: Add imports**

Add to imports:
```elm
import Dict
import SeqDict
```

**Step 4: Run elm-review**

Run: `elm-review`
Expected: PASS

**Step 5: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 6: Commit**

```bash
git add src/Backend.elm
git commit -m "feat: handle update/delete calendar requests in backend"
```

---

## Task 8: Write Edit Happy Path Test

**Files:**
- Modify: `tests/SmokeTests.elm`

**Step 1: Add test for edit happy path**

Add to the `tests` list:

```elm
    , Effect.Test.start
        "Edit calendar updates name"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Set up: create a calendar first
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
                , -- Verify calendar exists with original name
                  actions.checkView 200
                    (Test.Html.Query.has
                        [ Test.Html.Selector.text "Cleaning" ]
                    )
                , -- Click the edit button
                  actions.clickButton "✏️"
                , -- Verify edit modal is open with name input
                  actions.checkView 100
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "edit-calendar-name-input") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.attribute (Html.Attributes.value "Cleaning") ]
                    )
                , -- Change the name
                  actions.inputText "edit-calendar-name-input" "Chores Updated"
                , -- Click Save
                  actions.clickButton "Save"
                , -- Verify modal closed and name updated
                  actions.checkView 200
                    (Test.Html.Query.has
                        [ Test.Html.Selector.text "Chores Updated" ]
                    )
                ]
            )
        ]
```

**Step 2: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 3: Commit**

```bash
git add tests/SmokeTests.elm
git commit -m "test: add edit calendar happy path test"
```

---

## Task 9: Write Edit Validation Test

**Files:**
- Modify: `tests/SmokeTests.elm`

**Step 1: Add test for edit validation**

Add to the `tests` list:

```elm
    , Effect.Test.start
        "Edit calendar Save button disabled when name is empty"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Set up: create a calendar first
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
                , -- Click the edit button
                  actions.clickButton "✏️"
                , -- Clear the name input
                  actions.inputText "edit-calendar-name-input" ""
                , -- Verify Save button is disabled
                  actions.checkView 100
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-edit-calendar") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.disabled True ]
                    )
                , -- Enter a new name
                  actions.inputText "edit-calendar-name-input" "New Name"
                , -- Verify Save button is now enabled
                  actions.checkView 100
                    (Test.Html.Query.find
                        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "submit-edit-calendar") ]
                        >> Test.Html.Query.has [ Test.Html.Selector.disabled False ]
                    )
                ]
            )
        ]
```

**Step 2: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 3: Commit**

```bash
git add tests/SmokeTests.elm
git commit -m "test: add edit calendar validation test"
```

---

## Task 10: Write Delete Happy Path Test

**Files:**
- Modify: `tests/SmokeTests.elm`

**Step 1: Add test for delete**

Add to the `tests` list:

```elm
    , Effect.Test.start
        "Delete calendar removes it from view"
        (Effect.Time.millisToPosix january1st2026)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\actions ->
                [ -- Set up: create a calendar first
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
                , -- Verify calendar exists
                  actions.checkView 200
                    (Test.Html.Query.has
                        [ Test.Html.Selector.text "Cleaning" ]
                    )
                , -- Click the delete button (skipping confirm for test)
                  actions.clickButton "🗑️"
                , -- Verify calendar is removed (demo calendar shown instead)
                  actions.checkView 200
                    (Test.Html.Query.has
                        [ Test.Html.Selector.text "Example Habit" ]
                    )
                ]
            )
        ]
```

**Step 2: Run elm-test**

Run: `elm-test`
Expected: PASS

**Step 3: Commit**

```bash
git add tests/SmokeTests.elm
git commit -m "test: add delete calendar test"
```

---

## Task 11: Final Review and Manual Testing

**Step 1: Run full test suite**

Run: `elm-test`
Expected: All tests PASS

**Step 2: Run elm-review**

Run: `elm-review`
Expected: PASS (no errors)

**Step 3: Start dev server and manually test**

Run: `lamdera live`

Manual test checklist:
- [ ] Create a calendar
- [ ] Click edit button - modal opens with pre-populated values
- [ ] Change name and save - name updates
- [ ] Click delete button - calendar is removed
- [ ] Demo calendar shows when no calendars exist

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete edit/delete calendar feature"
```

---

## Summary

Total tasks: 11
Files modified:
- `src/Types.elm` - New types and messages
- `src/UI/CalendarView.elm` - Edit/delete buttons
- `src/UI/Modal.elm` - Edit modal view
- `src/Frontend.elm` - Message handlers
- `src/Backend.elm` - Update/delete handlers
- `tests/SmokeTests.elm` - E2E tests

Note: Browser `confirm()` dialog for delete is not implemented in this plan. The delete currently happens immediately. A follow-up task could add a confirmation modal or port-based confirm() if desired.
