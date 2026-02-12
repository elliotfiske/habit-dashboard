# Lamdera REPL Bridge - Usage Guide

Complete guide to using the Lamdera REPL Bridge extension for programmatic access to your Lamdera app's state.

## Table of Contents

- [Quick Start](#quick-start)
- [Understanding the Lamdera REPL](#understanding-the-lamdera-repl)
- [API Reference](#api-reference)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Install the Extension

See [README.md](README.md) for installation instructions.

### 2. Open Your Lamdera App

```bash
lamdera live
# Open http://localhost:8000 in Chrome
```

### 3. Open DevTools Console

Press `F12` or `Cmd+Option+I` and go to the Console tab.

### 4. Verify the Bridge is Ready

```javascript
await window.__lamdera.ready
console.log("✅ Bridge ready!")
```

### 5. Access Your Model

```javascript
// Get the full model (frontend + backend)
const model = window.__lamdera.getModel()
console.log("Frontend model:", model.fem)
console.log("Backend model:", model.bem)
```

---

## Understanding the Lamdera REPL

### Special Variables in the REPL

The Lamdera REPL provides these special variables for accessing your app state:

| Variable | Type | Description |
|----------|------|-------------|
| `fem` | `FrontendModel` | The current frontend model |
| `bem` | `BackendModel` | The current backend model |
| `model` | N/A | **Does not exist** - use `fem` or `bem` instead |

### Important: Use `fem` and `bem`, NOT `model`

❌ **Wrong:**
```javascript
const result = await window.__lamdera.replExec("model.currentTime")
// ERROR: I cannot find a `model` variable
```

✅ **Correct:**
```javascript
const result = await window.__lamdera.replExec("fem.currentTime")
// Just (Posix 1770858967264) : Maybe Time.Posix
```

### Type System

The REPL is fully type-aware and will catch type errors:

```javascript
// This will fail because calendars is a CalendarDict, not a List
await window.__lamdera.replExec("List.length fem.calendars")
// ERROR: But `length` needs the 1st argument to be: List a

// This works
await window.__lamdera.replExec("Dict.size fem.calendars")
// 5 : Int
```

---

## API Reference

### `window.__lamdera.ready`

**Type:** `Promise<App>`

**Description:** Resolves when the Lamdera app is initialized and the bridge is ready.

**Usage:**
```javascript
await window.__lamdera.ready
console.log("App is ready!")
```

**Always call this first** before using other bridge methods.

---

### `window.__lamdera.getModel()`

**Type:** `() => {fem: FrontendModel, bem: BackendModel}`

**Description:** Returns the current Elm runtime model directly from JavaScript.

**Usage:**
```javascript
const model = window.__lamdera.getModel()

// Access frontend model
console.log("Current time:", model.fem.currentTime)
console.log("Toggl status:", model.fem.togglStatus)

// Access backend model
console.log("Backend data:", model.bem)
```

**Note:** This returns the raw Elm runtime object. Field names match your Elm types exactly.

---

### `window.__lamdera.replExec(command)`

**Type:** `(command: string) => Promise<{output: string, error: string | null, raw: any}>`

**Description:** Executes a REPL command and returns the result.

**Parameters:**
- `command` - Any valid Elm expression (as a string)

**Returns:**
- `output` - The REPL output as a string (e.g., `"2 : number"`)
- `error` - Error message if compilation failed, `null` otherwise
- `raw` - Raw response array `[success, error, entries]`

**Usage:**

```javascript
// Simple expression
const result = await window.__lamdera.replExec("1 + 1")
console.log(result.output)  // "2 : number"

// Access frontend model
const time = await window.__lamdera.replExec("fem.currentTime")
console.log(time.output)  // "Just (Posix 1770858967264) : Maybe Time.Posix"

// Use Elm functions
const count = await window.__lamdera.replExec("Dict.size fem.calendars")
console.log(count.output)  // "5 : Int"

// Error handling
const bad = await window.__lamdera.replExec("model.foo")
if (bad.error) {
  console.error("REPL error:", bad.output)
}
```

**Common REPL Commands:**

```javascript
// Check if a Maybe is Just or Nothing
await window.__lamdera.replExec("fem.currentTime")
// Just (Posix ...) : Maybe Time.Posix

// Check boolean flags
await window.__lamdera.replExec("fem.projectsLoading")
// False : Bool

// Check list/dict sizes
await window.__lamdera.replExec("Dict.size fem.calendars")
// 5 : Int

// Check custom types
await window.__lamdera.replExec("fem.togglStatus")
// NotConnected : Types.TogglConnectionStatus

// Pattern match on custom types
await window.__lamdera.replExec("case fem.togglStatus of\n  Connected _ -> True\n  _ -> False")
// False : Bool
```

---

### `window.__lamdera.replExecMany(commands, delay)`

**Type:** `(commands: string[], delay?: number) => Promise<Array<{output, error, raw}>>`

**Description:** Executes multiple REPL commands sequentially.

**Parameters:**
- `commands` - Array of REPL commands
- `delay` - Optional delay between commands in milliseconds (default: 100ms)

**Returns:** Array of result objects (same format as `replExec`)

**Usage:**

```javascript
// Execute multiple queries
const results = await window.__lamdera.replExecMany([
  "fem.currentTime",
  "fem.togglStatus",
  "Dict.size fem.calendars"
])

results.forEach((r, i) => {
  console.log(`Result ${i}:`, r.output)
})

// With custom delay
const slowResults = await window.__lamdera.replExecMany([
  "fem.projectsLoading",
  "List.isEmpty fem.webhookDebugLog"
], 500)  // 500ms between commands
```

---

### `window.__lamdera.setFem(model)` ⚠️ Advanced

**Type:** `(model: FrontendModel) => FrontendModel`

**Description:** Directly set the frontend model (advanced usage).

**Warning:** This modifies the Elm runtime's internal state. The model must be a valid Elm value, not a plain JavaScript object. Use with caution.

**Usage:**
```javascript
// Get current model
const model = window.__lamdera.getModel()

// Modify it (be very careful here!)
const newFem = { ...model.fem, someField: "new value" }

// Set it back
window.__lamdera.setFem(newFem)
```

**Recommendation:** Use `replExec` instead for safer model inspection.

---

## Common Patterns

### Inspecting Model State

```javascript
// Check what fields exist
const model = window.__lamdera.getModel()
console.log("Frontend model fields:", Object.keys(model.fem))

// Query specific field
const result = await window.__lamdera.replExec("fem.togglStatus")
console.log("Toggl status:", result.output)
```

### Debugging During Development

```javascript
// Watch for model changes
setInterval(async () => {
  const loading = await window.__lamdera.replExec("fem.projectsLoading")
  console.log("Loading:", loading.output)
}, 1000)
```

### Batch State Inspection

```javascript
// Check multiple flags at once
const checks = await window.__lamdera.replExecMany([
  "fem.projectsLoading",
  "fem.togglStatus",
  "Dict.isEmpty fem.calendars",
  "List.isEmpty fem.webhookDebugLog"
])

const [loading, toggl, noCals, noLogs] = checks.map(r => r.output)
console.log({ loading, toggl, noCals, noLogs })
```

### Working with Custom Types

```javascript
// Extract values from custom types
const status = await window.__lamdera.replExec(`
  case fem.togglStatus of
    Connected data -> Just data
    _ -> Nothing
`)
console.log("Connection data:", status.output)
```

### Working with Dict/List

```javascript
// Get dict keys
await window.__lamdera.replExec("Dict.keys fem.calendars")

// Get dict values
await window.__lamdera.replExec("Dict.values fem.calendars")

// Filter lists
await window.__lamdera.replExec("List.filter (\\entry -> entry.completed) fem.entries")

// Map over lists
await window.__lamdera.replExec("List.map .name fem.availableProjects")
```

### Multi-line Expressions

```javascript
// Complex expressions work too
const result = await window.__lamdera.replExec(`
  let
    projects = fem.availableProjects
    count = List.length projects
  in
    if count > 0 then
      Just (List.head projects)
    else
      Nothing
`)
console.log(result.output)
```

---

## Troubleshooting

### "Cannot find a `model` variable"

**Problem:**
```javascript
await window.__lamdera.replExec("model.currentTime")
// ERROR: I cannot find a `model` variable
```

**Solution:** Use `fem` or `bem` instead of `model`
```javascript
await window.__lamdera.replExec("fem.currentTime")
// ✅ Works!
```

### Type Mismatch Errors

**Problem:**
```javascript
await window.__lamdera.replExec("List.length fem.calendars")
// ERROR: But `length` needs the 1st argument to be: List a
```

**Solution:** Use the correct function for the type
```javascript
// calendars is a Dict, so use Dict.size
await window.__lamdera.replExec("Dict.size fem.calendars")
// ✅ 5 : Int
```

### "REPL input not found after 5s"

**Problem:** The REPL didn't auto-open.

**Solution:**
1. Manually click "Show Repl" in the dev toolbar
2. Check browser console for 🔧 logs to see what failed
3. Reload the extension and page

### Promise Never Resolves

**Problem:** `replExec()` hangs forever.

**Possible causes:**
1. The REPL worker crashed
2. The command has infinite output
3. The port subscription failed

**Solution:**
1. Reload the page
2. Check console for 🔧 logs
3. Try a simpler command first (e.g., `"1 + 1"`)

### Field Not Found Errors

**Problem:**
```javascript
await window.__lamdera.replExec("fem.currentTab")
// ERROR: This `fem` record does not have a `currentTab` field
```

**Solution:** Check the actual field names
```javascript
// List all fields
const model = window.__lamdera.getModel()
console.log(Object.keys(model.fem))

// Use the correct field name
await window.__lamdera.replExec("fem.currentTime")
```

---

## Advanced Usage

### Filter Console Logs

Use the 🔧 emoji to filter bridge logs in the console:

```
Filter: 🔧
```

This shows only bridge-related logs and hides app logs.

### Debugging the Bridge

```javascript
// Check if bridge loaded
console.log("Bridge:", window.__lamdera)

// Check app instance
console.log("App:", window.__lamdera.app)

// Check worker (lazy-loaded)
console.log("Worker:", window.__lamdera.worker)
```

### Direct Port Access (Very Advanced)

```javascript
// Access the app's ports directly
const app = await window.__lamdera.ready
console.log("Available ports:", Object.keys(app.ports))

// Send messages to ports (be careful!)
app.ports.somePort.send(someData)
```

---

## Tips

1. **Always await `window.__lamdera.ready`** before using other methods
2. **Use `fem` and `bem`** instead of `model` in REPL commands
3. **Check types** - the REPL is fully type-checked
4. **Multi-line expressions** work great for complex queries
5. **Use `getModel()`** for direct JS access, `replExec()` for type-safe queries
6. **Filter logs by 🔧** to see only bridge activity
7. **The REPL auto-opens** after hot reloads - no manual intervention needed

---

## Examples

See [example-usage.js](example-usage.js) for runnable examples.

---

## Need Help?

- Check the [README.md](README.md) for installation issues
- See [lamdera-repl-internals.md](../../docs/lamdera-repl-internals.md) for architecture details
- Look for 🔧 logs in the console for debugging
