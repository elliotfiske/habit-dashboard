# Habit Dashboard

A Lamdera application for tracking habits via Toggl time tracking integration.

## Architecture

This is a full-stack Elm application built with [Lamdera](https://lamdera.app), featuring a clean separation of concerns across frontend and backend.

### Frontend Architecture

The frontend follows The Elm Architecture (TEA) with clear module boundaries:

**src/Frontend.elm** (~360 lines)
- Main orchestration layer
- Handles routing, initialization, and the update loop
- Delegates to specialized modules for UI and business logic
- Contains `init`, `update`, `updateFromBackend`, `subscriptions`, and `view`

**UI Modules** (src/UI/)
- `UI.TimerBanner` - Running timer display and stop timer error handling
- `UI.ConnectionCard` - Toggl connection status and workspace management
- `UI.CalendarView` - Calendar grid rendering and demo calendar
- `UI.Modal` - Modal dialogs (create calendar, workspace/project selection)
- `UI.WebhookDebug` - Webhook event log display (debug feature)

**Business Logic Modules**
- `ColorLogic` - Color manipulation and contrast calculations
- `TimerLogic` - Time duration formatting and relative timer calculations
- `CalendarLogic` - Calendar operations (date ranges, demo data)

**Domain Models**
- `Types` - Shared types for messages, models, and data structures
- `HabitCalendar` - Calendar data structures and operations
- `Toggl` - Toggl API types (workspaces, projects, time entries)

### Backend Architecture

**src/Backend.elm**
- Handles Toggl API integration via HTTP requests
- Manages persistent state (calendars, cached workspaces, running timer)
- Webhook endpoint for real-time timer updates
- Broadcasts updates to connected frontend clients

### Key Design Principles

1. **Separation of Concerns**: UI components don't contain business logic; logic modules are pure functions
2. **Single Responsibility**: Each module has one clear purpose
3. **No Duplication**: Shared logic is extracted into helper functions
4. **Type Safety**: Extensive use of custom types and type aliases
5. **Testability**: Pure logic modules are easy to test in isolation

## Prerequisites

Install the following tools:

```bash
# Lamdera (Elm-based full-stack framework)
# See https://dashboard.lamdera.app/docs/download

# elm-review (linter)
npm install -g elm-review

# elm-test (testing)
npm install -g elm-test

# elm-format (code formatter)
npm install -g elm-format

# Node.js (for TailwindCSS)
# See https://nodejs.org/
```

## Setup

Install npm dependencies (for TailwindCSS):

```bash
npm install
```

Build the CSS:

```bash
npm run build:css
```

## Development

### Running the Dev Server

```bash
lamdera live
```

This starts the development server at `http://localhost:8000`.

### TailwindCSS

To rebuild CSS after changing Tailwind classes in Elm files:

```bash
npm run build:css
```

For automatic rebuilds during development:

```bash
npm run watch:css
```

### Linting

```bash
elm-review
```

To automatically fix issues:

```bash
elm-review --fix
```

### Testing

Run tests in the terminal:

```bash
elm-test
```

#### Visual Test Output

You can view a visual, interactive output of `lamdera/program-test` tests by navigating to the test file in your browser:

```
http://localhost:8000/tests/SmokeTests.elm
```

This provides a step-by-step visualization of the test execution, which is helpful for debugging end-to-end tests.

### Formatting

```bash
elm-format src/ --yes
```

## Documentation

- [Lamdera Docs](https://dashboard.lamdera.app/docs)
- [Lamdera REPL Docs](https://dashboard.lamdera.app/docs/repl)

