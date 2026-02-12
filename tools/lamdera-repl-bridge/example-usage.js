/**
 * Example usage of the Lamdera REPL Bridge
 *
 * Run this in the Chrome DevTools console at http://localhost:8000
 * after the extension is loaded.
 */

// Example 1: Wait for the app to be ready
async function example1_basic() {
  console.log("=== Example 1: Basic Usage ===");

  await window.__lamdera.ready;
  console.log("✓ App is ready!");

  // Get the current model
  const model = window.__lamdera.getModel();
  console.log("Current model:", model);
}

// Example 2: Execute REPL commands and get results
async function example2_replCommands() {
  console.log("\n=== Example 2: REPL Commands ===");

  await window.__lamdera.ready;

  // Simple expression
  const result1 = await window.__lamdera.replExec("1 + 1");
  console.log("1 + 1 =", result1.output);

  // Access model
  const result2 = await window.__lamdera.replExec("fem");
  console.log("Frontend model:", result2.output);

  // Evaluate an expression
  const result3 = await window.__lamdera.replExec("String.length \"hello\"");
  console.log("String.length \"hello\" =", result3.output);
}

// Example 3: Execute multiple commands
async function example3_multipleCommands() {
  console.log("\n=== Example 3: Multiple Commands ===");

  await window.__lamdera.ready;

  const results = await window.__lamdera.replExecMany([
    "fem",
    "bem",
    "model"
  ], 100);

  results.forEach((result, i) => {
    console.log(`Result ${i + 1}:`, result.output);
    if (result.error) {
      console.error(`Error ${i + 1}:`, result.error);
    }
  });
}

// Example 4: Error handling
async function example4_errorHandling() {
  console.log("\n=== Example 4: Error Handling ===");

  await window.__lamdera.ready;

  // Try an invalid command
  const result = await window.__lamdera.replExec("thisDoesNotExist");

  if (result.error) {
    console.error("Command failed:", result.error);
  } else {
    console.log("Command succeeded:", result.output);
  }
}

// Example 5: Agent-style inspection
async function example5_agentInspection() {
  console.log("\n=== Example 5: Agent-Style Inspection ===");

  await window.__lamdera.ready;

  // Query multiple pieces of state
  const queries = [
    { name: "Has entries", cmd: "not (List.isEmpty model.entries)" },
    { name: "Entry count", cmd: "List.length model.entries" },
    { name: "Is loading", cmd: "model.isLoading" }
  ];

  for (const query of queries) {
    const result = await window.__lamdera.replExec(query.cmd);
    console.log(`${query.name}:`, result.output);
  }
}

// Example 6: Verify state after changes
async function example6_verifyChanges() {
  console.log("\n=== Example 6: Verify State Changes ===");

  await window.__lamdera.ready;

  // Before
  const before = await window.__lamdera.replExec("model.isLoading");
  console.log("Before:", before.output);

  // Make a change (this depends on your app's structure)
  // await window.__lamdera.replExec("setFem { fem | isLoading = True }");

  // After
  const after = await window.__lamdera.replExec("model.isLoading");
  console.log("After:", after.output);
}

// Run all examples
async function runAllExamples() {
  try {
    await example1_basic();
    await new Promise(r => setTimeout(r, 500));

    await example2_replCommands();
    await new Promise(r => setTimeout(r, 500));

    await example3_multipleCommands();
    await new Promise(r => setTimeout(r, 500));

    await example4_errorHandling();
    await new Promise(r => setTimeout(r, 500));

    await example5_agentInspection();
    await new Promise(r => setTimeout(r, 500));

    await example6_verifyChanges();

    console.log("\n✓ All examples completed!");
  } catch (error) {
    console.error("Error running examples:", error);
  }
}

// Export for console usage
console.log(`
Lamdera REPL Bridge Examples
=============================

Available functions:
- example1_basic()          - Basic setup and model access
- example2_replCommands()   - Execute REPL commands
- example3_multipleCommands() - Execute multiple commands
- example4_errorHandling()  - Handle errors gracefully
- example5_agentInspection() - Agent-style state queries
- example6_verifyChanges()  - Verify state changes
- runAllExamples()          - Run all examples

Try: await example1_basic()
`);
