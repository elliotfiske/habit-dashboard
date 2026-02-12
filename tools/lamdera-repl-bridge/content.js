/**
 * Lamdera REPL Bridge - Content Script
 *
 * Runs in the Chrome extension's isolated world at document_start.
 * Injects page-inject.js synchronously into the page context.
 *
 * CRITICAL: We inject synchronously using a <script src> tag with the extension URL.
 * This runs before the page's own scripts because we're at document_start.
 */
(function () {
  "use strict";

  console.log("🔧 [Bridge] Content script started");
  console.log("🔧 [Bridge] document.readyState:", document.readyState);
  console.log("🔧 [Bridge] document.documentElement exists:", !!document.documentElement);

  try {
    // Create and inject the script tag synchronously
    const script = document.createElement("script");
    const scriptUrl = chrome.runtime.getURL("page-inject.js");

    console.log("🔧 [Bridge] Script URL:", scriptUrl);
    script.src = scriptUrl;

    // Add error handler
    script.onerror = function(e) {
      console.error("🔧 [Bridge] ❌ Failed to load page-inject.js:", e);
    };

    script.onload = function() {
      console.log("🔧 [Bridge] ✅ page-inject.js loaded successfully");
    };

    // Use prepend to ensure it's first, and do it synchronously
    // The script will execute before any page scripts because we're at document_start
    const target = document.documentElement;
    target.insertBefore(script, target.firstChild);

    console.log("🔧 [Bridge] Script tag injected into DOM");
  } catch (error) {
    console.error("🔧 [Bridge] ❌ Error in content script:", error);
    console.error("🔧 [Bridge] Error stack:", error.stack);
  }
})();
