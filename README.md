# Habit Dashboard

A Lamdera application for tracking habits.

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

