/**
 * Lamdera REPL Bridge - Page Injection Script
 *
 * Injected into the page's JavaScript context by content.js.
 * Must run before the page's own scripts to intercept Elm initialization.
 *
 * Intercepts Elm.Lamdera.Live.init to capture the app instance,
 * subscribes to REPL worker output, and exposes window.__lamdera
 * for programmatic access with result capture.
 */
(function () {
  "use strict";

  console.log("🔧 [Bridge] ============================================");
  console.log("🔧 [Bridge] Page injection script starting execution");
  console.log("🔧 [Bridge] Timestamp:", new Date().toISOString());
  console.log("🔧 [Bridge] ============================================");

  try {

  const lamdera = {
    app: null,
    worker: null,
    _readyResolve: null,
    _workerReadyResolve: null,
    _pendingCommands: [], // Queue of {command, resolve, reject}

    /** Resolves when the app instance is captured. */
    ready: null,

    /** Resolves when the REPL worker is loaded. */
    workerReady: null,

    /** Get the current Elm runtime model (has .fem and .bem). */
    getModel: function () {
      return this.app?.fns?.getModel();
    },

    /** Directly set the frontend model. Argument must be an Elm FrontendModel value. */
    setFem: function (m) {
      return this.app?.fns?.setFem(m);
    },

    /** Directly set the backend model. Argument must be an Elm BackendModel value. */
    setBem: function (m) {
      return this.app?.fns?.setBem(m);
    },

    /** Send an update message to the app. */
    sendToApp: function (m) {
      return this.app?.fns?.sendToApp(m);
    },

    /**
     * Execute a REPL command and return its output.
     * Returns a promise that resolves with {output, error} when the REPL responds.
     */
    replExec: function (cmd) {
      console.log("🔧 [Bridge] replExec called with command:", cmd);
      var self = this;
      return _ensureReplOpen()
        .then(function (input) {
          console.log("🔧 [Bridge] REPL is open, input element:", input);
          return new Promise(function (resolve, reject) {
            // Add to pending queue
            self._pendingCommands.push({ command: cmd, resolve: resolve, reject: reject });
            console.log("🔧 [Bridge] Added to pending queue. Queue length:", self._pendingCommands.length);

            // Submit the command
            _submitCommand(input, cmd);
          });
        })
        .catch(function (error) {
          console.error("🔧 [Bridge] ❌ replExec error:", error);
          throw error;
        });
    },

    /**
     * Execute multiple REPL commands sequentially.
     * @param {string[]} cmds - Array of REPL commands
     * @param {number} [delay=100] - Delay between commands in ms (reduced from 1500)
     * @returns {Promise<Array>} Array of {output, error} results
     */
    replExecMany: function (cmds, delay) {
      delay = delay || 100;
      var results = [];
      return cmds.reduce(function (chain, cmd) {
        return chain
          .then(function () {
            return new Promise(function (r) {
              setTimeout(r, delay);
            });
          })
          .then(function () {
            return lamdera.replExec(cmd);
          })
          .then(function (result) {
            results.push(result);
            return results;
          });
      }, Promise.resolve()).then(function () {
        return results;
      });
    },

    /**
     * Internal: Handle REPL output from the worker.
     * Called when worker.ports.sendToClientPort sends a result.
     */
    _handleReplOutput: function (data) {
      console.log("🔧 [Bridge] _handleReplOutput called with data:", data);
      console.log("🔧 [Bridge] Pending commands queue length:", this._pendingCommands.length);

      if (this._pendingCommands.length === 0) {
        // REPL sends startup messages (welcome banner, unit value, etc.)
        // before any user commands — silently ignore these.
        return;
      }

      var pending = this._pendingCommands.shift();
      console.log("🔧 [Bridge] Processing command:", pending.command);

      // Parse the response
      // data is an Elm value from sendToClientPort, typically an array like:
      // ["ReplOutput", {output: "...", error: null}] or similar
      var result = _parseReplResponse(data);
      console.log("🔧 [Bridge] Parsed result:", result);

      pending.resolve(result);
      console.log("🔧 [Bridge] ✅ Promise resolved for command:", pending.command);
    },
  };

  // Create deferred promises
  lamdera.ready = new Promise(function (resolve) {
    lamdera._readyResolve = resolve;
  });
  lamdera.workerReady = new Promise(function (resolve) {
    lamdera._workerReadyResolve = resolve;
  });

  window.__lamdera = lamdera;

  // --- Intercept Elm global ---
  // The Lamdera IIFE sets window.Elm = { Lamdera: { Live: ... }, Repl: { Worker: ... } }
  // We use Object.defineProperty to intercept this assignment and patch init functions.
  //
  // RACE CONDITION FIX: Our script loads via <script src>, which is async.
  // 50% of the time, the page's IIFE runs first and sets window.Elm before us.
  // Object.defineProperty would replace that value with a getter returning undefined.
  // Fix: capture any existing value, and if Elm is already set, patch it immediately.

  var _Elm = window.Elm; // Capture existing value (may be undefined or already set)
  console.log("🔧 [Bridge] Setting up Elm interceptor");
  console.log("🔧 [Bridge] window.Elm BEFORE interception:", _Elm);

  Object.defineProperty(window, "Elm", {
    configurable: true,
    enumerable: true,
    get: function () {
      return _Elm;
    },
    set: function (val) {
      console.log("🔧 [Bridge] window.Elm is being set!");
      _Elm = val;
      _patchElm(val);
    },
  });

  // If Elm was already set before we installed the interceptor, patch it now
  if (_Elm) {
    console.log("🔧 [Bridge] Elm was already set, patching retroactively...");
    _patchElm(_Elm);
  }

  function _patchElm(val) {
    // Patch the main app init
    if (val && val.Lamdera && val.Lamdera.Live && val.Lamdera.Live.init) {
      // Guard against double-patching (if setter fires after we already patched)
      if (val.Lamdera.Live.init.__bridgePatched) {
        console.log("🔧 [Bridge] Elm.Lamdera.Live.init already patched, skipping");
        return;
      }
      console.log("🔧 [Bridge] Found Elm.Lamdera.Live.init, patching...");
      var origInit = val.Lamdera.Live.init;
      var patchedInit = function (args) {
        console.log("🔧 [Bridge] Elm.Lamdera.Live.init called");
        var app = origInit.call(this, args);
        _onAppCaptured(app);
        return app;
      };
      patchedInit.__bridgePatched = true;
      val.Lamdera.Live.init = patchedInit;
    }
  }

  function _onAppCaptured(app) {
    lamdera.app = app;
    lamdera._readyResolve(app);

    // Intercept REPL output by monkey-patching the incoming port's .send()
    // receiveFromWorkerPort is an INCOMING port (JS → Elm), so it has .send(), not .subscribe()
    // The JS bridge calls .send(data) when the worker produces a result.
    // We wrap .send() to capture that data before it enters the Elm app.
    if (app.ports && app.ports.receiveFromWorkerPort) {
      console.log("🔧 [Bridge] Patching receiveFromWorkerPort.send...");
      var origSend = app.ports.receiveFromWorkerPort.send.bind(app.ports.receiveFromWorkerPort);
      app.ports.receiveFromWorkerPort.send = function (data) {
        lamdera._handleReplOutput(data);
        return origSend(data);
      };
      console.log("🔧 [Bridge] ✅ Patched receiveFromWorkerPort.send");
    }

    console.log(
      "🔧 [Bridge] ✅ App captured!",
      "Ports:",
      app.ports ? Object.keys(app.ports) : "none"
    );

    // Auto-open the REPL after a short delay to let the DOM settle.
    setTimeout(function () {
      _autoOpenRepl();
    }, 500);
  }

  // --- Helper functions ---

  function _autoOpenRepl() {
    console.log("🔧 [Bridge] Auto-opening REPL...");

    // The Lamdera dev toolbar is collapsed by default. It shows icons and "Env: Dev"
    // but "Show Repl" only appears after hovering. We need to:
    // 1. Find the toolbar (identified by "Env:" text)
    // 2. Simulate hover to expand it
    // 3. Poll for "Show Repl" to appear, then click it

    var toolbar = _findDevToolbar();
    if (!toolbar) {
      console.warn("🔧 [Bridge] Auto-open REPL failed: toolbar not found");
      return;
    }

    console.log("🔧 [Bridge] Found dev toolbar, simulating hover...");
    toolbar.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));
    toolbar.dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));

    // Poll for "Show Repl" to appear after hover expands the toolbar
    var attempts = 0;
    var maxAttempts = 25; // 5 seconds
    var interval = setInterval(function () {
      var showRepl = _findShowReplButton();
      if (showRepl) {
        clearInterval(interval);
        console.log("🔧 [Bridge] Found 'Show Repl' button, clicking...");
        showRepl.click();
        console.log("🔧 [Bridge] ✅ REPL auto-opened successfully");
      } else if (++attempts >= maxAttempts) {
        clearInterval(interval);
        console.warn("🔧 [Bridge] Auto-open REPL failed: 'Show Repl' never appeared");
        // Move mouse away to un-hover
        toolbar.dispatchEvent(new MouseEvent("mouseleave", { bubbles: true }));
      }
    }, 200);
  }

  function _findDevToolbar() {
    // The collapsed toolbar contains "Env:" text. Find that element
    // and walk up to the toolbar root.
    var divs = document.querySelectorAll("div");
    for (var i = 0; i < divs.length; i++) {
      if (divs[i].textContent.indexOf("Env:") !== -1 && divs[i].childElementCount <= 2) {
        // Walk up to the outermost toolbar container
        var el = divs[i];
        while (el.parentElement && el.parentElement !== document.body) {
          el = el.parentElement;
        }
        console.log("🔧 [Bridge] Found toolbar via 'Env:' text:", el.tagName, el.style.cssText.substring(0, 80));
        return el;
      }
    }

    console.log("🔧 [Bridge] ⚠️ Could not find dev toolbar");
    return null;
  }

  function _findShowReplButton() {
    var divs = document.querySelectorAll("div");
    for (var i = 0; i < divs.length; i++) {
      if (divs[i].textContent.trim() === "Show Repl") {
        return divs[i];
      }
    }
    return null;
  }

  function _ensureReplOpen() {
    console.log("🔧 [Bridge] _ensureReplOpen called");
    return new Promise(function (resolve, reject) {
      // Check if REPL input already exists
      var input = document.getElementById("repl-input");
      if (input) {
        console.log("🔧 [Bridge] REPL input already exists:", input);
        resolve(input);
        return;
      }

      console.log("🔧 [Bridge] REPL not open, looking for 'Show Repl' button");

      // Click "Show Repl" to open it
      var showRepl = null;
      var divs = document.querySelectorAll("div");
      for (var i = 0; i < divs.length; i++) {
        if (divs[i].textContent.trim() === "Show Repl") {
          showRepl = divs[i];
          break;
        }
      }
      if (showRepl) {
        console.log("🔧 [Bridge] Found 'Show Repl' button, clicking...");
        showRepl.click();
      } else {
        console.log("🔧 [Bridge] ⚠️ 'Show Repl' button not found");
      }

      // Wait for input to appear
      var attempts = 0;
      var maxAttempts = 25; // 5 seconds
      var interval = setInterval(function () {
        input = document.getElementById("repl-input");
        if (input) {
          console.log("🔧 [Bridge] ✅ REPL input appeared after", attempts * 200, "ms");
          clearInterval(interval);
          resolve(input);
        } else if (++attempts >= maxAttempts) {
          console.error("🔧 [Bridge] ❌ REPL input not found after 5s");
          clearInterval(interval);
          reject(new Error("REPL input not found after 5s"));
        }
      }, 200);
    });
  }

  function _submitCommand(input, cmd) {
    console.log("🔧 [Bridge] _submitCommand called with:", cmd);
    // Just submit the command, don't resolve yet
    // The promise will be resolved when _handleReplOutput is called
    var form = input.closest("form");
    console.log("🔧 [Bridge] Form element:", form);

    var nativeSetter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      "value"
    ).set;

    nativeSetter.call(input, cmd);
    console.log("🔧 [Bridge] Input value set to:", cmd);

    input.dispatchEvent(new Event("input", { bubbles: true }));
    console.log("🔧 [Bridge] Dispatched 'input' event");

    setTimeout(function () {
      console.log("🔧 [Bridge] Dispatching 'submit' event");
      form.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true })
      );
      console.log("🔧 [Bridge] ✅ Submit event dispatched");
    }, 100);
  }

  function _parseReplResponse(data) {
    // Format: [success: bool, error: string|null, entries: string[]]
    // e.g. [true, null, ["2 : number"]]
    // Each entry is "value : type"

    if (!Array.isArray(data) || data.length < 3) {
      console.log("🔧 [Bridge] Unexpected response format:", data);
      return { output: null, error: "Unexpected format", raw: data };
    }

    var success = data[0];
    var error = data[1];
    var entries = data[2];

    // Join all entries (usually just one, but multi-line results may have more)
    var output = Array.isArray(entries) ? entries.join("\n") : null;

    console.log("🔧 [Bridge] Parsed: success=" + success + " output=" + JSON.stringify(output));

    return {
      output: output,
      error: error,
      raw: data,
    };
  }

  console.log("🔧 [Bridge] Page injection script loaded and executing");
  console.log("🔧 [Bridge] window.__lamdera created:", !!window.__lamdera);
  console.log("🔧 [Bridge] Waiting for Elm init...");
  console.log("🔧 [Bridge] ============================================");

  } catch (error) {
    console.error("🔧 [Bridge] ❌❌❌ FATAL ERROR in page-inject.js ❌❌❌");
    console.error("🔧 [Bridge] Error:", error);
    console.error("🔧 [Bridge] Error message:", error.message);
    console.error("🔧 [Bridge] Error stack:", error.stack);
    console.error("🔧 [Bridge] ============================================");
  }
})();
