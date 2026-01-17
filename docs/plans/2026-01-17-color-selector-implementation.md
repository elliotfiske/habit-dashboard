# Color Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add color picker inputs to Create/Edit Calendar modals for customizing successColor and nonzeroColor.

**Architecture:** Update ColorLogic to use `escherlies/elm-color` utilities, add color fields to modal types, add color picker UI, and wire up message handling through Frontend/Backend.

**Tech Stack:** Elm, Lamdera, escherlies/elm-color (hex parsing, isLight), avh4/elm-color (Color type), HTML `<input type="color">`

---

### Task 1: Update ColorLogic to use escherlies/elm-color

**Files:**
- Modify: `src/ColorLogic.elm`

**Step 1: Replace ColorLogic with escherlies/elm-color utilities**

Replace the entire file with:

```elm
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
```

**Step 2: Run elm-review to check for issues**

Run: `elm-review`
Expected: May have unused import warnings from files that used old ColorLogic functions

**Step 3: Commit**

```bash
git add src/ColorLogic.elm
git commit -m "refactor: migrate ColorLogic to escherlies/elm-color"
```

---

### Task 2: Update Calendar.elm to use new ColorLogic

**Files:**
- Modify: `src/Calendar.elm:215-229`

**Step 1: Update cellColors to use ColorLogic.isLight for text color**

Replace the `cellColors` function:

```elm
{-| Determine cell colors based on minutes and day comparison.
-}
cellColors : HabitCalendar -> DayComparison -> Int -> ( String, String )
cellColors calendar comparison minutes =
    case comparison of
        Future ->
            ( "oklch(var(--b3))", "oklch(var(--bc) / 0.4)" )

        _ ->
            if minutes >= 30 then
                let
                    textColor =
                        if ColorLogic.isLight calendar.successColor then
                            "#000"
                        else
                            "#fff"
                in
                ( ColorLogic.colorToHex calendar.successColor, textColor )

            else if minutes > 0 then
                let
                    textColor =
                        if ColorLogic.isLight calendar.nonzeroColor then
                            "#000"
                        else
                            "#fff"
                in
                ( ColorLogic.colorToHex calendar.nonzeroColor, textColor )

            else
                ( "oklch(var(--b3))", "oklch(var(--bc))" )
```

**Step 2: Add ColorLogic import**

Add to imports:

```elm
import ColorLogic
```

**Step 3: Remove unused Color import if needed**

The `Color` import may no longer be needed directly. Run elm-review to check.

**Step 4: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 5: Commit**

```bash
git add src/Calendar.elm
git commit -m "refactor: use ColorLogic for calendar cell colors"
```

---

### Task 3: Update Frontend.elm to use new ColorLogic

**Files:**
- Modify: `src/Frontend.elm:420-431`

**Step 1: Update background style to use new ColorLogic.muteColor**

The `muteColor` function signature changed from `String -> String` to `Color -> Color`. Update the view function's backgroundStyle:

```elm
        backgroundStyle : Html.Attribute FrontendMsg
        backgroundStyle =
            case model.runningEntry of
                RunningEntry payload ->
                    payload.projectId
                        |> Maybe.andThen
                            (\projectId ->
                                List.filter (\p -> p.id == projectId) model.availableProjects
                                    |> List.head
                                    |> Maybe.map
                                        (\project ->
                                            let
                                                projectColor =
                                                    ColorLogic.hexToColor project.color

                                                mutedColor =
                                                    ColorLogic.muteColor projectColor
                                            in
                                            Attr.style "background-color" (ColorLogic.colorToHex mutedColor)
                                        )
                            )
                        |> Maybe.withDefault (Attr.class "bg-base-200")

                NoRunningEntry ->
                    Attr.class "bg-base-200"
```

**Step 2: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 3: Commit**

```bash
git add src/Frontend.elm
git commit -m "refactor: update Frontend to use new ColorLogic API"
```

---

### Task 4: Update UI/TimerBanner.elm if it uses ColorLogic

**Files:**
- Check: `src/UI/TimerBanner.elm`

**Step 1: Check if TimerBanner uses ColorLogic**

Run: `grep -n "ColorLogic" src/UI/TimerBanner.elm`

If it uses `isColorDark`, update to use `ColorLogic.isLight` (note: logic is inverted - `isLight` returns true for light colors, `isColorDark` returned true for dark colors).

**Step 2: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 3: Commit if changes were made**

```bash
git add src/UI/TimerBanner.elm
git commit -m "refactor: update TimerBanner to use new ColorLogic API"
```

---

### Task 5: Add color fields to modal types in Types.elm

**Files:**
- Modify: `src/Types.elm`

**Step 1: Add Color import**

Add to imports:

```elm
import Color exposing (Color)
```

**Step 2: Add color fields to CreateCalendarModal**

Update the type alias:

```elm
{-| State for the "Create Calendar" modal.
-}
type alias CreateCalendarModal =
    { selectedWorkspace : Maybe TogglWorkspace
    , selectedProject : Maybe TogglProject
    , calendarName : String
    , successColor : Color
    , nonzeroColor : Color
    }
```

**Step 3: Add color fields to EditCalendarModal**

Update the type alias:

```elm
{-| State for the "Edit Calendar" modal.
-}
type alias EditCalendarModal =
    { calendarId : HabitCalendar.HabitCalendarId
    , originalProjectId : Toggl.TogglProjectId
    , selectedWorkspace : Toggl.TogglWorkspace
    , selectedProject : Toggl.TogglProject
    , calendarName : String
    , successColor : Color
    , nonzeroColor : Color
    }
```

**Step 4: Add new FrontendMsg variants for color changes**

Add to the FrontendMsg type:

```elm
    -- Color picker actions (create modal)
    | SuccessColorChanged String
    | NonzeroColorChanged String
    -- Color picker actions (edit modal)
    | EditSuccessColorChanged String
    | EditNonzeroColorChanged String
```

**Step 5: Update UpdateCalendar ToBackend message to include colors**

Change:

```elm
    | UpdateCalendar HabitCalendar.HabitCalendarId String Toggl.TogglWorkspaceId Toggl.TogglProjectId
```

To:

```elm
    | UpdateCalendar HabitCalendar.HabitCalendarId String Toggl.TogglWorkspaceId Toggl.TogglProjectId Color Color
```

**Step 6: Run elm-review (expect compile errors - that's OK)**

Run: `elm-review`
Expected: Compile errors because Frontend.elm and Backend.elm need updates

**Step 7: Commit**

```bash
git add src/Types.elm
git commit -m "feat: add color fields to modal types and messages"
```

---

### Task 6: Update Frontend.elm modal initialization and color handlers

**Files:**
- Modify: `src/Frontend.elm`

**Step 1: Add Color and ColorLogic imports if not present**

```elm
import Color
import ColorLogic
```

**Step 2: Update OpenCreateCalendarModal to initialize colors**

Update the handler (around line 132-142):

```elm
        OpenCreateCalendarModal ->
            let
                defaultBlue =
                    Color.rgb255 59 130 246  -- blue-500
            in
            ( { model
                | modalState =
                    ModalCreateCalendar
                        { selectedWorkspace = Nothing
                        , selectedProject = Nothing
                        , calendarName = ""
                        , successColor = defaultBlue
                        , nonzeroColor = ColorLogic.muteColor defaultBlue
                        }
              }
            , Command.none
            )
```

**Step 3: Update SelectWorkspace to preserve colors**

Update the handler (around line 147-159):

```elm
        SelectWorkspace workspace ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalCreateCalendar
                                { modalData
                                    | selectedWorkspace = Just workspace
                                    , selectedProject = Nothing
                                }
                        , availableProjects = []
                        , projectsLoading = True
                      }
                    , Effect.Lamdera.sendToBackend (FetchTogglProjects workspace.id)
                    )

                _ ->
                    ( model, Command.none )
```

**Step 4: Update SelectProject to set colors from project**

Update the handler (around line 161-186):

```elm
        SelectProject project ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    let
                        projectColor =
                            ColorLogic.hexToColor project.color
                    in
                    ( { model
                        | modalState =
                            ModalCreateCalendar
                                { modalData
                                    | selectedProject = Just project
                                    , calendarName =
                                        if String.isEmpty modalData.calendarName then
                                            project.name
                                        else
                                            modalData.calendarName
                                    , successColor = projectColor
                                    , nonzeroColor = ColorLogic.muteColor projectColor
                                }
                      }
                    , Command.none
                    )

                ModalEditCalendar _ ->
                    ( model, Command.none )

                ModalClosed ->
                    ( model, Command.none )
```

**Step 5: Add handlers for color change messages**

Add new cases after CalendarNameChanged (around line 203):

```elm
        SuccessColorChanged hexColor ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalCreateCalendar
                                { modalData | successColor = ColorLogic.hexToColor hexColor }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )

        NonzeroColorChanged hexColor ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalCreateCalendar
                                { modalData | nonzeroColor = ColorLogic.hexToColor hexColor }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )

        EditSuccessColorChanged hexColor ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | successColor = ColorLogic.hexToColor hexColor }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )

        EditNonzeroColorChanged hexColor ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData | nonzeroColor = ColorLogic.hexToColor hexColor }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )
```

**Step 6: Update OpenEditCalendarModal to load colors from calendar**

Update the handler (around line 257-293):

```elm
        OpenEditCalendarModal calendar ->
            let
                maybeWorkspace : Maybe Toggl.TogglWorkspace
                maybeWorkspace =
                    case model.togglStatus of
                        Connected workspaces ->
                            List.filter (\ws -> ws.id == calendar.workspaceId) workspaces
                                |> List.head

                        _ ->
                            Nothing

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
                                , successColor = calendar.successColor
                                , nonzeroColor = calendar.nonzeroColor
                                }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )
```

**Step 7: Update EditCalendarSelectProject to update colors**

Update the handler (around line 310-322):

```elm
        EditCalendarSelectProject project ->
            case model.modalState of
                ModalEditCalendar modalData ->
                    let
                        projectColor =
                            ColorLogic.hexToColor project.color
                    in
                    ( { model
                        | modalState =
                            ModalEditCalendar
                                { modalData
                                    | selectedProject = project
                                    , successColor = projectColor
                                    , nonzeroColor = ColorLogic.muteColor projectColor
                                }
                      }
                    , Command.none
                    )

                _ ->
                    ( model, Command.none )
```

**Step 8: Update SubmitEditCalendar to pass colors**

Update the handler (around line 337-348):

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
                            modalData.successColor
                            modalData.nonzeroColor
                        )
                    )

                _ ->
                    ( model, Command.none )
```

**Step 9: Run elm-review (may still have Backend errors)**

Run: `elm-review`
Expected: Possible compile errors in Backend.elm

**Step 10: Commit**

```bash
git add src/Frontend.elm
git commit -m "feat: add color handling to Frontend modal logic"
```

---

### Task 7: Update Backend.elm to handle colors in UpdateCalendar

**Files:**
- Modify: `src/Backend.elm:330-365`

**Step 1: Update UpdateCalendar handler to accept and store colors**

Update the pattern match and handler:

```elm
        UpdateCalendar calendarId newName newWorkspaceId newProjectId newSuccessColor newNonzeroColor ->
            case CalendarDict.get calendarId model.calendars of
                Just existingCalendar ->
                    let
                        projectChanged : Bool
                        projectChanged =
                            existingCalendar.projectId /= newProjectId

                        -- Update calendar with new values
                        updatedCalendar : HabitCalendar.HabitCalendar
                        updatedCalendar =
                            { existingCalendar
                                | name = newName
                                , workspaceId = newWorkspaceId
                                , projectId = newProjectId
                                , successColor = newSuccessColor
                                , nonzeroColor = newNonzeroColor
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
                    in
                    ( { model | calendars = updatedCalendars }
                    , Effect.Lamdera.broadcast (CalendarsUpdated updatedCalendars)
                    )

                Nothing ->
                    ( model, Command.none )
```

**Step 2: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS (or close - may have test issues)

**Step 3: Commit**

```bash
git add src/Backend.elm
git commit -m "feat: handle colors in UpdateCalendar backend message"
```

---

### Task 8: Update HabitCalendar.elm to support custom colors on creation

**Files:**
- Modify: `src/HabitCalendar.elm`

**Step 1: Add a new function for creating calendar with custom colors**

Add after the `fromTimeEntries` function:

```elm
{-| Create a calendar from time entries with custom colors.
-}
fromTimeEntriesWithColors :
    HabitCalendarId
    -> String
    -> Zone
    -> TogglWorkspaceId
    -> TogglProjectId
    -> Color
    -> Color
    -> List TimeEntry
    -> HabitCalendar
fromTimeEntriesWithColors calendarId name zone workspaceId projectId successColor nonzeroColor entries =
    let
        entriesDict : SeqDict TimeEntryId TimeEntry
        entriesDict =
            List.foldl
                (\entry acc -> SeqDict.insert entry.id entry acc)
                SeqDict.empty
                entries

        aggregatedEntries : Dict Int DayEntry
        aggregatedEntries =
            aggregateEntriesByDay zone (SeqDict.values entriesDict)
    in
    { id = calendarId
    , name = name
    , successColor = successColor
    , nonzeroColor = nonzeroColor
    , weeksShowing = 4
    , entries = aggregatedEntries
    , timeEntries = entriesDict
    , timezone = zone
    , workspaceId = workspaceId
    , projectId = projectId
    }
```

**Step 2: Export the new function**

Update the module exposing:

```elm
module HabitCalendar exposing
    ( DayEntry
    , HabitCalendar
    , HabitCalendarId(..)
    , addOrUpdateTimeEntry
    , deleteTimeEntry
    , emptyCalendar
    , fromTimeEntries
    , fromTimeEntriesWithColors
    , getMinutesForDay
    , habitCalendarIdToString
    , setEntries
    )
```

**Step 3: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 4: Commit**

```bash
git add src/HabitCalendar.elm
git commit -m "feat: add fromTimeEntriesWithColors for custom calendar colors"
```

---

### Task 9: Add color picker UI to Modal.elm

**Files:**
- Modify: `src/UI/Modal.elm`

**Step 1: Add ColorLogic import**

Add to imports:

```elm
import ColorLogic
```

**Step 2: Add color picker component for Create modal**

Add after `viewCalendarNameInput`:

```elm
{-| View the color pickers for success and nonzero colors.
-}
viewColorPickers : { successColor : String, nonzeroColor : String, onSuccessChange : String -> FrontendMsg, onNonzeroChange : String -> FrontendMsg } -> Html FrontendMsg
viewColorPickers config =
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Colors" ] ]
        , Html.div [ Attr.class "flex gap-6" ]
            [ Html.div [ Attr.class "flex flex-col gap-1" ]
                [ Html.label [ Attr.class "text-sm text-base-content/70" ]
                    [ Html.text "Success Color" ]
                , Html.input
                    [ Attr.type_ "color"
                    , Attr.value config.successColor
                    , Events.onInput config.onSuccessChange
                    , Attr.class "w-12 h-10 cursor-pointer rounded border border-base-300"
                    , Attr.attribute "data-testid" "success-color-picker"
                    ]
                    []
                ]
            , Html.div [ Attr.class "flex flex-col gap-1" ]
                [ Html.label [ Attr.class "text-sm text-base-content/70" ]
                    [ Html.text "Nonzero Color" ]
                , Html.input
                    [ Attr.type_ "color"
                    , Attr.value config.nonzeroColor
                    , Events.onInput config.onNonzeroChange
                    , Attr.class "w-12 h-10 cursor-pointer rounded border border-base-300"
                    , Attr.attribute "data-testid" "nonzero-color-picker"
                    ]
                    []
                ]
            ]
        ]
```

**Step 3: Update viewCreateCalendar to include color pickers**

Add the color picker call after `viewCalendarNameInput modalData`:

```elm
viewCreateCalendar : FrontendModel -> CreateCalendarModal -> Html FrontendMsg
viewCreateCalendar model modalData =
    Html.div
        [ Attr.class "fixed inset-0 z-50 flex items-center justify-center"
        , Attr.attribute "data-testid" "create-calendar-modal"
        ]
        [ -- Backdrop
          Html.div
            [ Attr.class "absolute inset-0 bg-black/50"
            , Events.onClick CloseModal
            ]
            []
        , -- Modal box
          Html.div [ Attr.class "relative z-10 bg-base-100 rounded-lg shadow-xl p-6 max-w-md w-full mx-4" ]
            [ Html.h3 [ Attr.class "font-bold text-lg mb-4" ]
                [ Html.text "Create New Calendar" ]
            , viewWorkspaceSelector model modalData
            , viewProjectSelector model modalData
            , viewCalendarNameInput modalData
            , viewColorPickers
                { successColor = ColorLogic.colorToHex modalData.successColor
                , nonzeroColor = ColorLogic.colorToHex modalData.nonzeroColor
                , onSuccessChange = SuccessColorChanged
                , onNonzeroChange = NonzeroColorChanged
                }
            , Html.div [ Attr.class "flex justify-end gap-2 mt-6" ]
                [ Html.button
                    [ Attr.class "btn"
                    , Attr.id "close-modal-button"
                    , Events.onClick CloseModal
                    ]
                    [ Html.text "Cancel" ]
                , Html.button
                    [ Attr.class "btn btn-primary"
                    , Attr.id "submit-create-calendar"
                    , Attr.disabled (not (canSubmitCalendar modalData))
                    , Events.onClick SubmitCreateCalendar
                    , Attr.attribute "data-testid" "submit-create-calendar"
                    ]
                    [ Html.text "Create" ]
                ]
            ]
        ]
```

**Step 4: Update viewEditCalendar to include color pickers**

Add the color picker call after `viewEditCalendarNameInput modalData`:

```elm
viewEditCalendar : FrontendModel -> EditCalendarModal -> Html FrontendMsg
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
            , viewColorPickers
                { successColor = ColorLogic.colorToHex modalData.successColor
                , nonzeroColor = ColorLogic.colorToHex modalData.nonzeroColor
                , onSuccessChange = EditSuccessColorChanged
                , onNonzeroChange = EditNonzeroColorChanged
                }
            , Html.div [ Attr.class "flex justify-end gap-2 mt-6" ]
                [ Html.button
                    [ Attr.class "btn"
                    , Events.onClick CloseModal
                    ]
                    [ Html.text "Cancel" ]
                , Html.button
                    [ Attr.class "btn btn-primary"
                    , Attr.id "submit-edit-calendar"
                    , Attr.disabled (String.isEmpty modalData.calendarName)
                    , Events.onClick SubmitEditCalendar
                    , Attr.attribute "data-testid" "submit-edit-calendar"
                    ]
                    [ Html.text "Save" ]
                ]
            ]
        ]
```

**Step 5: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 6: Commit**

```bash
git add src/UI/Modal.elm
git commit -m "feat: add color picker UI to Create/Edit Calendar modals"
```

---

### Task 10: Update SubmitCreateCalendar to pass colors to backend

**Files:**
- Modify: `src/Frontend.elm`
- Modify: `src/Types.elm`
- Modify: `src/Backend.elm`

**Step 1: Update FetchTogglTimeEntries ToBackend message to include colors**

In `src/Types.elm`, update:

```elm
    | FetchTogglTimeEntries CalendarInfo TogglWorkspaceId Toggl.TogglProjectId String String Zone Color Color
```

**Step 2: Update CalendarInfo type to include colors**

Or alternatively, add colors to the CalendarInfo type:

```elm
type alias CalendarInfo =
    { calendarId : HabitCalendarId
    , calendarName : String
    , successColor : Color
    , nonzeroColor : Color
    }
```

**Step 3: Update sendFetchCalendarCommand in Frontend.elm**

Update the function signature and usage to accept colors.

**Step 4: Update SubmitCreateCalendar handler to pass colors**

```elm
        SubmitCreateCalendar ->
            case model.modalState of
                ModalCreateCalendar modalData ->
                    case ( modalData.selectedWorkspace, modalData.selectedProject ) of
                        ( Just workspace, Just project ) ->
                            let
                                calendarId : HabitCalendarId
                                calendarId =
                                    HabitCalendarId (Toggl.togglProjectIdToString project.id)

                                calendarInfo : Types.CalendarInfo
                                calendarInfo =
                                    { calendarId = calendarId
                                    , calendarName = modalData.calendarName
                                    , successColor = modalData.successColor
                                    , nonzeroColor = modalData.nonzeroColor
                                    }
                            in
                            ( { model | modalState = ModalClosed }
                            , sendFetchCalendarCommand calendarInfo workspace.id project.id model
                            )

                        _ ->
                            ( model, Command.none )

                _ ->
                    ( model, Command.none )
```

**Step 5: Update Backend.elm GotTogglTimeEntries to use colors**

Update the handler to use `HabitCalendar.fromTimeEntriesWithColors`:

```elm
        GotTogglTimeEntries clientId calendarInfo workspaceId projectId userZone result ->
            case result of
                Ok entries ->
                    let
                        newCalendar : HabitCalendar.HabitCalendar
                        newCalendar =
                            HabitCalendar.fromTimeEntriesWithColors
                                calendarInfo.calendarId
                                calendarInfo.calendarName
                                userZone
                                workspaceId
                                projectId
                                calendarInfo.successColor
                                calendarInfo.nonzeroColor
                                entries
                        -- rest unchanged...
```

**Step 6: Run elm-review and elm-test**

Run: `elm-review && elm-test`
Expected: PASS

**Step 7: Commit**

```bash
git add src/Types.elm src/Frontend.elm src/Backend.elm
git commit -m "feat: pass colors through calendar creation flow"
```

---

### Task 11: Final verification and cleanup

**Step 1: Run full test suite**

Run: `elm-test`
Expected: All tests pass

**Step 2: Run elm-review**

Run: `elm-review`
Expected: No errors

**Step 3: Manual testing checklist**

Start the dev server: `lamdera live`

Test the following:
- [ ] Open Create Calendar modal - color pickers appear with blue default
- [ ] Select a project - colors update to project color
- [ ] Manually change success color - it persists
- [ ] Manually change nonzero color - it persists
- [ ] Create calendar - colors are saved and displayed
- [ ] Open Edit Calendar modal - colors are loaded from calendar
- [ ] Change project in edit modal - colors update
- [ ] Save edit - colors are persisted
- [ ] Calendar cells use correct colors based on minutes

**Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: address any issues found in manual testing"
```

---

## Summary

This implementation adds color picker functionality to both Create and Edit Calendar modals by:

1. Migrating `ColorLogic` to use `escherlies/elm-color` utilities
2. Adding color fields to modal state types
3. Adding new messages for color changes
4. Updating Frontend handlers for color selection and project-based color defaults
5. Adding color picker UI components
6. Passing colors through the backend calendar creation/update flow
