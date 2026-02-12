# Lamdera REPL Bridge - Chrome Extension

A Chrome extension that provides programmatic access to the Lamdera dev environment's REPL and internal app state, without needing to interact with the UI.

## What It Does

When you run `lamdera live`, this extension intercepts the Elm app initialization and exposes a `window.__lamdera` object that lets you:

- **Access the Elm runtime model** directly (`getModel()`)
- **Modify frontend/backend state** programmatically (`setFem()`, `setBem()`)
- **Execute REPL commands** from the console (`replExec()`)
- **Send messages to the app** (`sendToApp()`)

## Installation

1. **Load the extension in Chrome:**
   - Open Chrome and navigate to `chrome://extensions/`
   - Enable "Developer mode" (toggle in top-right)
   - Click "Load unpacked"
   - Select the `/tools/lamdera-repl-bridge/` directory

2. **Verify it's loaded:**
   - You should see "Lamdera REPL Bridge" in your extensions list
   - The extension only activates on `http://localhost:8000/*`

3. **If you previously loaded this extension:**
   - Click the refresh icon (⟳) on the extension card in `chrome://extensions/`
   - Then reload your `localhost:8000` tab

## Usage

### 1. Start Lamdera Dev Server

```bash
cd /path/to/your/lamdera/project
lamdera live
```

Open `http://localhost:8000` in Chrome.

### 2. Open the Console

Press `F12` or `Cmd+Option+I` to open DevTools, then go to the Console tab.

You should see:
```
[Lamdera Bridge] Injection loaded, waiting for Elm init...
[Lamdera Bridge] App captured! Ports: [...]
```

### 3. Use the `window.__lamdera` API

#### Check if the app is ready

```javascript
await window.__lamdera.ready
// Returns the app instance when ready
```

#### Get the current model

```javascript
const model = window.__lamdera.getModel()
console.log("Frontend model:", model.fem)
console.log("Backend model:", model.bem)
```

#### Execute a REPL command

```javascript
// Execute a command and get the result back directly
const result = await window.__lamdera.replExec("fem")
console.log(result.output)  // The REPL output as a string
console.log(result.error)   // Error message if any, null otherwise
console.log(result.raw)     // Raw response from the worker

// Example with an expression
const count = await window.__lamdera.replExec("List.length model.entries")
console.log(count.output)  // "42" (or whatever the length is)

// Execute multiple commands and get all results
const results = await window.__lamdera.replExecMany([
  "fem",
  "bem",
  "List.length model.entries"
], 100) // 100ms delay between commands (default)

results.forEach(r => console.log(r.output))
```

#### Direct model manipulation

```javascript
// Get the current frontend model
const model = window.__lamdera.getModel()

// Modify it (example - adjust based on your app's FrontendModel structure)
const newFem = { ...model.fem, someField: "new value" }

// Set the modified model back
window.__lamdera.setFem(newFem)
```

**⚠️ Warning:** Direct model manipulation requires understanding the Elm runtime's internal structure. The model must be a valid Elm value, not a plain JavaScript object. This is advanced usage.

#### Send a message to the app

```javascript
// This requires knowing the internal Elm message structure
// Generally safer to use replExec() instead
window.__lamdera.sendToApp(someElmMessage)
```

## API Reference

### `window.__lamdera`

| Method | Returns | Description |
|--------|---------|-------------|
| `ready` | `Promise<App>` | Resolves when the Lamdera app is initialized |
| `workerReady` | `Promise<Worker>` | Resolves when the REPL worker is loaded |
| `getModel()` | `{fem, bem}` | Returns the current Elm runtime model |
| `setFem(model)` | `model` | Sets the frontend model (advanced) |
| `setBem(model)` | `model` | Sets the backend model (advanced) |
| `sendToApp(msg)` | `undefined` | Sends an update message to the app (advanced) |
| `replExec(cmd)` | `Promise<{output, error, raw}>` | Executes a REPL command and returns the result |
| `replExecMany(cmds, delay)` | `Promise<Array<{output, error, raw}>>` | Executes commands sequentially, returns all results |

## Examples

### Inspecting State During Development

```javascript
// Quick peek at current state
window.__lamdera.getModel().fem

// Execute a REPL command to evaluate an expression
const result = await window.__lamdera.replExec("List.length model.entries")
console.log("Number of entries:", result.output)
```

### Agent-Driven Development

```javascript
// Agent can query state programmatically
await window.__lamdera.ready

// Get information without UI interaction
const entries = await window.__lamdera.replExec("model.entries")
const count = await window.__lamdera.replExec("List.length model.entries")

console.log("Entries:", entries.output)
console.log("Count:", count.output)

// Agent can verify changes
const results = await window.__lamdera.replExecMany([
  "model.currentTab",
  "model.isLoading",
  "model.error"
])

results.forEach((r, i) => {
  console.log(`Result ${i}:`, r.output)
  if (r.error) console.error(`Error ${i}:`, r.error)
})
```

### Automated Testing Setup

```javascript
// Wait for app to be ready, then set up test state
await window.__lamdera.ready

// Use REPL to set up test data and verify
const results = await window.__lamdera.replExecMany([
  "setFem { fem | testMode = True }",
  "setFem { fem | entries = [] }",
  "model.testMode",  // Verify it worked
  "List.length model.entries"  // Should be 0
])

console.log("Test mode:", results[2].output)
console.log("Entry count:", results[3].output)
```

### Debugging Without UI Interaction

```javascript
// No need to click through the UI to open REPL
// No need to type commands manually
const debug = await window.__lamdera.replExec("Debug.log \"Current state\" model")
console.log("Debug output:", debug.output)
```

## How It Works

See `/docs/lamdera-repl-internals.md` for detailed architecture notes.

**Summary:**
1. `content.js` runs at `document_start` (before DOM or page scripts)
2. It injects `page-inject.js` as a `<script>` tag into the page context
3. `page-inject.js` uses `Object.defineProperty` to intercept `window.Elm` assignment
4. When Lamdera's IIFE runs and sets `window.Elm`, our setter patches `Elm.Lamdera.Live.init`
5. When `setupApp()` calls `init()`, we capture the returned app instance
6. The app instance has a `fns` object with `getModel`, `setFem`, etc.
7. When the REPL worker loads, we subscribe to its output port to capture results
8. We expose everything via `window.__lamdera` for console access

## Troubleshooting

**"Could not establish connection. Receiving end does not exist"**
- This means the extension needs to be reloaded
- Go to `chrome://extensions/` and click the refresh icon (⟳) on "Lamdera REPL Bridge"
- Then hard-reload the page (Cmd+Shift+R or Ctrl+Shift+F5)

**"window.__lamdera is undefined"**
- Make sure the extension is loaded and enabled
- Check that you're on `http://localhost:8000`
- Reload the page to re-inject the script
- Check browser console for "[Lamdera Bridge] Injection loaded" message

**"REPL input not found after 5s"**
- The REPL might be taking longer to load
- Try manually opening the REPL first (click "Show Repl")
- Check console for other errors

**Commands not executing**
- Use `await` with `replExec()` - it's async
- Increase the delay in `replExecMany()` if commands are running too fast
- Check that the REPL is visible (commands use form submission)

**Results are null or undefined**
- Check `result.error` to see if the REPL command failed
- Use `result.raw` to see the raw response from the worker
- Some commands (like `setFem`) may not return visible output
- Verify your command syntax is valid Elm REPL syntax

**Commands hang/never resolve**
- The promise waits for the worker to respond via `sendToClientPort`
- If the worker is busy or crashed, commands may hang
- Check console for "[Lamdera Bridge] REPL Worker captured!" message
- Try reloading the page to reset the worker

## Development

To modify the extension:

1. Edit files in `/tools/lamdera-repl-bridge/`
2. Go to `chrome://extensions/` and click the refresh icon on "Lamdera REPL Bridge"
3. Reload `localhost:8000` to test changes

## License

Part of the habit-dashboard project.
