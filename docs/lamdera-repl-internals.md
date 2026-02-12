# Lamdera REPL Internals

How the Lamdera in-browser REPL works under the hood, and how to interact with it programmatically.

## Architecture Overview

The Lamdera dev environment (`lamdera live` at `localhost:8000`) consists of:

1. **`Elm.Lamdera.Live`** - The main Elm app (your app + Lamdera dev toolbar)
2. **`Elm.Repl.Worker`** - A separate Elm Worker that compiles and evaluates REPL expressions
3. **A JavaScript bridge** - Connects the two via Elm ports, handles JS evaluation

```
User types in REPL input
        |
        v
  Elm.Lamdera.Live (main app)
        |
        | sendToWorkerPort (Elm outgoing port)
        v
  JavaScript bridge (loadWorker / sendToWorker)
        |
        | worker.ports.receiveFromClientPort (Elm incoming port)
        v
  Elm.Repl.Worker (compiles Elm expressions)
        |
        |--- sendToClientPort ----> JS bridge ----> app.ports.receiveFromWorkerPort
        |                                          (results displayed in REPL UI)
        |
        |--- sendToJavaScriptPort ----> JS interpret() function
                                        (eval's compiled JS for setFem, etc.)
```

## Key Variables and Their Locations

| Variable | Description | Accessible? |
|----------|-------------|-------------|
| `s` | The main app instance (in IIFE closure) | No - closure variable |
| `Elm` | Global with `Lamdera.Live` and `Repl.Worker` | Yes - `window.Elm` |
| `window.setupApp` | Function that initializes the app | Yes - global |
| `window.elmPkgJsIncludes` | Package JS init (loads REPL bridge) | Yes - global |
| `app.fns` | `{getModel, setFem, setBem, sendToApp}` | Only via `s` |
| `worker` | REPL Worker instance | No - closure variable |

## The App Instance (`s`)

Created by `Elm.Lamdera.Live.init({node, flags})` inside `setupApp`. Returns:

```javascript
{
  ports: { /* all Elm ports */ },
  die: function() { /* hot-reload cleanup */ },
  bury: function() { /* memory cleanup */ },
  fns: {
    getModel: function() { return model },        // Current backend+frontend model
    setBem: function(m) { model.bem = m; return m }, // Set backend model
    setFem: function(m) { model.fem = m; return m }, // Set frontend model
    sendToApp: function(m) { sendToApp(m, true) },   // Send update message
  }
}
```

The `model` variable is the Elm runtime's internal state. `model.fem` is the `FrontendModel`, `model.bem` is the `BackendModel`.

## How `setFem` / `fem` Work in the REPL

When you type `fem` in the REPL:

1. Elm sends the input string via `sendToWorkerPort`
2. JS bridge forwards to `worker.ports.receiveFromClientPort`
3. The Worker compiles `fem` to JavaScript code containing a `jsImpl` call
4. Worker sends compiled JS via `sendToJavaScriptPort`
5. JS `interpret()` function receives it, does a regex replace:
   ```javascript
   code.replace(
     /\$author\$project\$Lamdera\$Repl\$Interface\$jsImpl\('(.*)'\);$/gm,
     (_, p) => p.replace(/\\/g, "") + ';'
   )
   ```
6. The cleaned code is `eval()`'d in `interpret`'s scope, which has `app` in its closure
7. `app.fns.getModel()` is called, returning the current model
8. Result sent back via `worker.ports.receiveFromJavaScriptPort`

## The REPL Worker Lifecycle

The Worker is **lazy-loaded** on first use:

1. `elmPkgJsIncludes.init(app)` sets up `app.ports.sendToWorkerPort.subscribe(loadWorker)`
2. First REPL command triggers `loadWorker`, which fetches `/_c/_repl-worker.js`
3. After loading, `Elm.Repl.Worker.init({flags: [...]})` creates the worker
4. Subscriptions are wired up:
   - `app.ports.sendToWorkerPort` → `worker.ports.receiveFromClientPort`
   - `worker.ports.sendToClientPort` → `app.ports.receiveFromWorkerPort`
   - `worker.ports.sendToJavaScriptPort` → `interpret()` function

## The WebSocket (`/_w`)

A reconnecting WebSocket at `ws://localhost:8000/_w` handles:

| Message type | Direction | Purpose |
|-------------|-----------|---------|
| `r` | Server → Browser | Trigger full page reload (code change) |
| `s` | Server → Browser | Session init (clientId, leaderId) |
| `e` | Server → Browser | Leader election update |
| `ToBackend` | Both ways | Backend messages |
| `ToFrontend` | Both ways | Frontend messages |
| `p` | Server → Browser | Backend model push |
| `q` | Server → Browser | RPC call |

## DOM Structure

- **REPL input**: `<input id="repl-input" type="text">` inside a `<form>`
- **Form submission**: `onSubmit` → Elm `FormSubmitted` msg
- **Input change**: `onInput` → Elm `InputChanged` msg
- The REPL UI is toggled by clicking "Show Repl" / "Hide Repl" in the Dev Toolbar

## Programmatic REPL Access

### Method 1: Form Submission (works today)

The `__replSend` trick: set the input value via native setter, dispatch `input` event, then submit the form.

```javascript
function replSend(cmd) {
  const input = document.getElementById('repl-input');
  const form = input.closest('form');
  const nativeSetter = Object.getOwnPropertyDescriptor(
    HTMLInputElement.prototype, 'value'
  ).set;
  nativeSetter.call(input, cmd);
  input.dispatchEvent(new Event('input', { bubbles: true }));
  setTimeout(() => {
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
  }, 100);
}
```

Requires the REPL to be open (worker loaded, input in DOM).

### Method 2: Chrome Extension Content Script (recommended)

Intercept `Elm.Lamdera.Live.init` before the page JS runs using `Object.defineProperty` on `window.Elm`. This captures the app instance with its `fns` object, enabling direct model manipulation without the REPL UI.

See `tools/lamdera-repl-bridge/` for the implementation.

### Method 3: Direct Worker Communication (advanced)

With both the app and worker instances captured, you can bypass the REPL UI entirely by sending encoded messages directly to `worker.ports.receiveFromClientPort` and listening on `worker.ports.sendToClientPort`. Requires understanding the Elm-encoded message format.
