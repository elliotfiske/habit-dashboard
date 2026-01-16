module UI.Modal exposing (view)

{-| Modal dialog UI for creating calendars.

This module provides all modal-related UI components, including the
"Create Calendar" modal with workspace selection, project selection,
and calendar name input.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Toggl exposing (TogglProject, TogglWorkspace)
import Types exposing (CreateCalendarModal, FrontendModel, FrontendMsg(..), ModalState(..), TogglConnectionStatus(..))


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

        ModalEditCalendar _ ->
            -- TODO: Implement edit calendar modal view
            Html.text ""


{-| View the "Create Calendar" modal.
Shows workspace selector, project selector, calendar name input, and action buttons.
-}
viewCreateCalendar : FrontendModel -> CreateCalendarModal -> Html FrontendMsg
viewCreateCalendar model modalData =
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
                [ Html.text "Create New Calendar" ]
            , viewWorkspaceSelector model modalData
            , viewProjectSelector model modalData
            , viewCalendarNameInput modalData
            , Html.div [ Attr.class "flex justify-end gap-2 mt-6" ]
                [ Html.button
                    [ Attr.class "btn"
                    , Events.onClick CloseModal
                    ]
                    [ Html.text "Cancel" ]
                , Html.button
                    [ Attr.class "btn btn-primary"
                    , Attr.disabled (not (canSubmitCalendar modalData))
                    , Events.onClick SubmitCreateCalendar
                    , Attr.attribute "data-testid" "submit-create-calendar"
                    ]
                    [ Html.text "Create" ]
                ]
            ]
        ]


{-| Check if the modal has enough data to submit.
Requires workspace, project, and non-empty calendar name.
-}
canSubmitCalendar : CreateCalendarModal -> Bool
canSubmitCalendar modalData =
    case ( modalData.selectedWorkspace, modalData.selectedProject ) of
        ( Just _, Just _ ) ->
            not (String.isEmpty modalData.calendarName)

        _ ->
            False


{-| View the workspace selector.
Shows available workspaces as buttons, with selected workspace highlighted.
-}
viewWorkspaceSelector : FrontendModel -> CreateCalendarModal -> Html FrontendMsg
viewWorkspaceSelector model modalData =
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
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Workspace" ] ]
        , Html.div [ Attr.class "flex flex-wrap gap-2" ]
            (List.map (workspaceButton modalData.selectedWorkspace) workspaces)
        ]


{-| Button for selecting a workspace.
Highlighted in primary color when selected.
-}
workspaceButton : Maybe TogglWorkspace -> TogglWorkspace -> Html FrontendMsg
workspaceButton selectedWorkspace workspace =
    let
        isSelected : Bool
        isSelected =
            case selectedWorkspace of
                Just ws ->
                    ws.id == workspace.id

                Nothing ->
                    False
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
        , Events.onClick (SelectWorkspace workspace)
        , Attr.attribute "data-testid" ("workspace-" ++ String.fromInt (Toggl.togglWorkspaceIdToInt workspace.id))
        ]
        [ Html.text workspace.name ]


{-| View the project selector.
Disabled until workspace is selected. Shows loading state while fetching projects.
-}
viewProjectSelector : FrontendModel -> CreateCalendarModal -> Html FrontendMsg
viewProjectSelector model modalData =
    case modalData.selectedWorkspace of
        Nothing ->
            Html.div [ Attr.class "form-control mb-4 opacity-50" ]
                [ Html.label [ Attr.class "label" ]
                    [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Project" ] ]
                , Html.p [ Attr.class "text-sm text-base-content/60" ]
                    [ Html.text "Select a workspace first" ]
                ]

        Just _ ->
            Html.div [ Attr.class "form-control mb-4" ]
                [ Html.label [ Attr.class "label" ]
                    [ Html.span [ Attr.class "label-text" ] [ Html.text "Select Project" ] ]
                , if model.projectsLoading then
                    Html.div [ Attr.class "flex items-center gap-2" ]
                        [ Html.span [ Attr.class "loading loading-spinner loading-sm" ] []
                        , Html.text "Loading projects..."
                        ]

                  else if List.isEmpty model.availableProjects then
                    Html.p [ Attr.class "text-sm text-base-content/60" ]
                        [ Html.text "No projects found in this workspace" ]

                  else
                    Html.div [ Attr.class "flex flex-wrap gap-2 max-h-48 overflow-y-auto" ]
                        (List.map (projectButton modalData.selectedProject) model.availableProjects)
                ]


{-| Button for selecting a project.
Highlighted in primary color when selected.
-}
projectButton : Maybe TogglProject -> TogglProject -> Html FrontendMsg
projectButton selectedProject project =
    let
        isSelected : Bool
        isSelected =
            case selectedProject of
                Just p ->
                    p.id == project.id

                Nothing ->
                    False
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
        , Events.onClick (SelectProject project)
        , Attr.attribute "data-testid" ("project-" ++ Toggl.togglProjectIdToString project.id)
        ]
        [ Html.text project.name ]


{-| View the calendar name input field.
-}
viewCalendarNameInput : CreateCalendarModal -> Html FrontendMsg
viewCalendarNameInput modalData =
    Html.div [ Attr.class "form-control mb-4" ]
        [ Html.label [ Attr.class "label" ]
            [ Html.span [ Attr.class "label-text" ] [ Html.text "Calendar Name" ] ]
        , Html.input
            [ Attr.type_ "text"
            , Attr.placeholder "Enter a name for this calendar"
            , Attr.value modalData.calendarName
            , Attr.class "input input-bordered"
            , Events.onInput CalendarNameChanged
            , Attr.attribute "data-testid" "calendar-name-input"
            ]
            []
        ]
