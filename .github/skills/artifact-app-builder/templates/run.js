// Test runner: discovers tests/test-*.js, runs targeted or all
// Usage: node run.js portfolio orders   (specific features)
//        node run.js all                (full regression)
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const TESTS_DIR = __dirname;
const requested = process.argv.slice(2);

// Discover all test files: test-{feature}.js
const allTests = fs.readdirSync(TESTS_DIR)
  .filter((f) => f.startsWith("test-") && f.endsWith(".js") && f !== "run.js")
  .map((f) => ({ file: f, feature: f.replace("test-", "").replace(".js", "") }));

// Select which to run
let toRun;
if (requested[0] === "all") {
  toRun = allTests;
} else {
  toRun = allTests.filter((t) => requested.includes(t.feature));
  const missing = requested.filter((r) => !allTests.some((t) => t.feature === r));
  if (missing.length) console.log(`⚠️  No test found for: ${missing.join(", ")}`);
}

if (toRun.length === 0) {
  console.log("No tests to run. Available:", allTests.map((t) => t.feature).join(", "));
  process.exit(0);
}

// Run each test in sequence
let passed = 0;
let failed = 0;

for (const test of toRun) {
  try {
    const output = execSync(`node ${path.join(TESTS_DIR, test.file)}`, {
      encoding: "utf8",
      timeout: 30000,
    });
    process.stdout.write(output);
    passed++;
  } catch (e) {
    process.stdout.write(e.stdout || "");
    process.stderr.write(e.stderr || "");
    failed++;
  }
}

console.log(`\n${"═".repeat(40)}`);
console.log(`Features: ${passed} passed, ${failed} failed (${toRun.length} total)`);
console.log(`${"═".repeat(40)}`);
if (failed > 0) process.exit(1);
