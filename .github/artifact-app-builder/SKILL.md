---
name: artifact-app-builder
version: 1.0.0
updated: 2026-03-26
description: Build multi-feature React apps as Claude.ai artifacts using a modular part-file architecture. Features a local test shell with mocked window.storage, esbuild bundling, and Playwright-based feature tests with screenshots. Apps are developed as separate part files, concatenated into a single .jsx artifact that runs in Claude.ai with full storage persistence.
---

# Artifact App Builder

Build production-quality React apps as Claude.ai `.jsx` artifacts using a modular, testable pipeline.

## When to Use

- User wants a **multi-feature React app** delivered as a Claude.ai artifact
- App needs **window.storage** persistence across sessions
- App is complex enough to benefit from **modular parts** (>200 lines)
- User wants **tested, screenshot-verified** features before delivery

## Architecture

```
project/
├── parts/                    # Modular source files (edit these)
│   ├── part-data.jsx         # Data models, mock data, helpers
│   ├── part-state.jsx        # Reducer, storage, state management
│   ├── part-ui-shared.jsx    # Shared UI: Sparkline, TabBar, Header, Notifications
│   ├── part-ui-trading.jsx   # Trading pillar: Portfolio, Watchlist, Orders, etc.
│   ├── part-ui-compliance.jsx# Compliance pillar: Screening, Alerts, MiFID, AML
│   ├── part-ui-operations.jsx# Operations pillar: Settlement, Events, Reporting
│   ├── part-ui-assets.jsx    # Asset Mgmt pillar: Risk, Allocation, Performance
│   └── part-app.jsx          # Main shell, routing, layout (always last)
├── parts-agent/              # Optional: AI agent fork
│   └── part-agent.jsx        # Embedded agent panel + tool definitions
├── scripts/
│   ├── concat.sh             # Parts → single artifact .jsx
│   └── dev.sh                # Build + test cycle with JSONL logging
├── shell/
│   ├── entry.jsx             # Mock runtime (window.storage + React mount)
│   ├── index.html            # Local test harness
│   └── tailwind-subset.css   # Offline Tailwind utilities (~200 classes)
├── tests/
│   ├── run.js                # Test runner (discovers test-*.js files)
│   ├── helpers.js            # Shared: launch(), screenshot(), assert(), wait()
│   └── test-{feature}.js     # One file per feature (accumulate, never delete)
├── dev.log                   # JSONL build log (gitignored)
├── app.jsx                   # ← Assembled artifact output (runs in Claude.ai)
└── app-agent.jsx             # ← Agent fork output (optional)
```

## Setup

### Step 1: Scaffold project

```bash
PROJECT="my-app"
mkdir -p /home/claude/$PROJECT/{parts,parts-agent,scripts,shell,tests}

# Copy scripts from skill
cp /mnt/skills/user/artifact-app-builder/scripts/concat.sh /home/claude/$PROJECT/scripts/
cp /mnt/skills/user/artifact-app-builder/scripts/dev.sh /home/claude/$PROJECT/scripts/
cp /mnt/skills/user/artifact-app-builder/templates/entry.jsx /home/claude/$PROJECT/shell/
cp /mnt/skills/user/artifact-app-builder/templates/index.html /home/claude/$PROJECT/shell/
cp /mnt/skills/user/artifact-app-builder/templates/tailwind-subset.css /home/claude/$PROJECT/shell/
cp /mnt/skills/user/artifact-app-builder/templates/run.js /home/claude/$PROJECT/tests/
cp /mnt/skills/user/artifact-app-builder/templates/helpers.js /home/claude/$PROJECT/tests/

chmod +x /home/claude/$PROJECT/scripts/*.sh

# Install dependencies
cd /home/claude/$PROJECT
npm init -y
npm install react@18 react-dom@18 esbuild puppeteer-core

# Git safety
git init && git config user.email "ai@dev" && git config user.name "AI"
echo "dev.log\ntests/screenshots/\nnode_modules/" > .gitignore
git add -A && git commit -m "scaffold: project initialized"
```

### Step 2: Customize concat.sh

Edit `scripts/concat.sh` to set your output filename:

```bash
# Change this line in concat.sh:
OUTPUT="$PROJECT_DIR/app.jsx"
# And the agent version:
OUTPUT="$PROJECT_DIR/app-agent.jsx"
```

## Part File Rules

### Concatenation Order (fixed)

```
part-data → part-state → part-ui-shared → part-ui-* (alphabetical) → [part-agent] → part-app
```

The `concat.sh` script auto-discovers `part-ui-*.jsx` files and sorts them alphabetically, with `part-ui-shared.jsx` always first. This means you can add new UI pillar files (e.g. `part-ui-analytics.jsx`) without editing concat.sh.

Dependencies flow top-down. Earlier parts define functions/constants used by later parts.

### Splitting Components by Pillar

For apps with many features, split UI components into separate files by domain/pillar:

```
parts/
├── part-ui-shared.jsx      # Cross-cutting: Sparkline, TabBar, Header, Toasts
├── part-ui-trading.jsx     # Trading: Portfolio, Watchlist, Orders, OrderModal
├── part-ui-compliance.jsx  # Compliance: Screening, Alerts, MiFID panel
├── part-ui-operations.jsx  # Operations: Settlement, Events, Reporting
└── part-ui-assets.jsx      # Asset Mgmt: Risk, Allocation, Performance
```

This keeps each file under ~600 lines while the monolith stays single-file in the assembled output. When building Phase 4 (Compliance), you only edit `part-ui-compliance.jsx` — no risk of colliding with trading code.

For simpler apps (<500 lines total), a single `part-components.jsx` also works — concat.sh supports both patterns.

### Writing Parts

Each part file is a fragment — NOT a standalone module:

```jsx
// ═══════════════════════════════════════════════════════════
// PART: DATA — description of what this part contains
// ═══════════════════════════════════════════════════════════

const MY_DATA = { ... };

function myHelper(x) { return x * 2; }
```

**DO:**
- Use `React.createElement()` for all UI (not JSX syntax — avoids transform issues in concat)
- Reference `React.useState`, `React.useEffect` etc. via namespace OR destructure in part-app.jsx only
- Add `data-testid` attributes to every testable element
- Use Tailwind classes for styling (they work in both Claude.ai and local shell)

**DON'T:**
- Don't add `import` statements in parts (the concat header handles this)
- Don't add `export default` in parts except part-app.jsx (concat strips it)
- Don't destructure `const { useState } = React` in multiple parts (do it once in part-app.jsx)

### The App Part (always last)

```jsx
// part-app.jsx — must contain:
const { useState, useReducer, useEffect, useRef, useCallback } = React;

function MyApp() {
  // ... app shell using components from earlier parts
}

export default MyApp;
```

The concat script adds `import React, { ... } from "react";` at the top and `export default MyApp;` at the bottom.

## Dev Workflow

### Commands

```bash
# Build only (compile check) — ~2s
bash scripts/dev.sh

# Build + test specific features — ~10s per feature
bash scripts/dev.sh portfolio
bash scripts/dev.sh portfolio orders

# Build + full regression (before commit) — scales with test count
bash scripts/dev.sh all
```

### Dev Cycle

```
1. Edit parts/*.jsx
2. bash scripts/dev.sh              →  2s compile check
3. bash scripts/dev.sh {feature}    →  10s visual verify
4. git add -A && git commit         →  checkpoint
5. Repeat
```

### When to Run What

| Situation | Command |
|---|---|
| Changed one feature's code | `dev.sh {feature}` |
| Changed shared data/state | `dev.sh {affected-features}` |
| Before committing | `dev.sh all` |
| Just checking syntax | `dev.sh` |
| Adding a new feature | Write test first, then code, then `dev.sh {feature}` |

## Writing Feature Tests

Each feature gets one file: `tests/test-{feature}.js`

```javascript
const { launch, screenshot, assert, wait } = require("./helpers");
(async () => {
  console.log("📋 feature-name");
  const { browser, page } = await launch();
  let ok = true;

  // Navigate to the right screen
  await page.evaluate(() =>
    document.querySelector('[data-testid="tab-myfeature"]').click());
  await wait();

  // Assert what should be visible
  ok &= assert("Feature renders", await page.evaluate(() =>
    !!document.querySelector('[data-testid="my-feature"]')));

  // Screenshot at key visual moments
  await screenshot(page, "feature-name");

  // Interactive tests
  await page.evaluate(() =>
    document.querySelector('[data-testid="my-button"]').click());
  await wait();
  ok &= assert("Action worked", await page.evaluate(() => /* check result */));
  await screenshot(page, "feature-name-after-action");

  await browser.close();
  process.exit(ok ? 0 : 1);
})();
```

**Test rules:**
- Tests accumulate — never delete a test file
- Each test takes screenshots at key visual moments → `tests/screenshots/`
- Tests must clean up after themselves (close modals, navigate away)
- Use `data-testid` for all selectors (never CSS classes)
- For React-controlled inputs, use the native setter pattern:

```javascript
await page.evaluate(() => {
  const input = document.querySelector('[data-testid="my-input"]');
  const setter = Object.getOwnPropertyDescriptor(
    window.HTMLInputElement.prototype, 'value').set;
  setter.call(input, 'new value');
  input.dispatchEvent(new Event('input', { bubbles: true }));
  input.dispatchEvent(new Event('change', { bubbles: true }));
});
```

## JSONL Dev Log

Every `dev.sh` invocation appends one JSON line to `dev.log`:

```json
{"ts":"2026-03-26T09:03:40Z","commit":"c84d1be","args":"all","parts":4,"lines":876,"bundle_ms":78,"bundle_kb":264.8,"bundle_ok":true,"tests":["all"],"test_pass":10,"test_fail":0,"test_ms":60268,"total_ms":62599}
```

Analyze with:

```bash
# Slowest 5 runs
cat dev.log | jq -s 'sort_by(.total_ms) | reverse | .[0:5]'

# All failed runs
cat dev.log | jq 'select(.test_fail > 0)'

# Bundle size over time
cat dev.log | jq -r '[.ts, .bundle_kb] | @tsv'
```

## Agent Fork

To add an embedded AI agent to the app:

1. Create `parts-agent/part-agent.jsx` with:
   - Chat panel UI component
   - Tool definitions mapping to the same state actions the UI uses
   - Anthropic API integration (`fetch` to `api.anthropic.com/v1/messages`)

2. Build the fork:
   ```bash
   bash scripts/dev.sh --agent
   ```

3. The concat script includes `part-agent.jsx` between `part-components.jsx` and `part-app.jsx`

The agent fork extends the app — it doesn't replace it. Both versions share the same parts.

## Delivering the Artifact

```bash
# Copy assembled artifact to outputs
cp /home/claude/$PROJECT/app.jsx /mnt/user-data/outputs/app.jsx
```

Then use `present_files` to deliver to the user. The `.jsx` file runs directly in Claude.ai as an artifact with full `window.storage` persistence.

## window.storage API Reference

The local shell mocks the exact Claude.ai storage API:

```javascript
await window.storage.get(key, shared?)     // → {key, value, shared} | throws if missing
await window.storage.set(key, value, shared?) // → {key, value, shared}
await window.storage.delete(key, shared?)   // → {key, deleted, shared}
await window.storage.list(prefix?, shared?) // → {keys, prefix, shared}
```

- Keys < 200 chars, no whitespace/slashes/quotes
- Values < 5MB, text/JSON only
- Missing keys throw (not return null) — always try/catch `.get()`
- Use hierarchical keys: `"table:record_id"`

## Build Order Strategy

When building a multi-feature app, sequence features so the **app is always usable after each feature**:

1. **Core data + state** — models, reducer, storage
2. **Primary view** — the main screen users see first
3. **Global chrome** — header, navigation, account summary
4. **Secondary views** — additional tabs/screens
5. **Data infrastructure** — history tracking, derived data
6. **Visualizations** — charts, sparklines (build on data from step 5)
7. **Interactive features** — forms, modals, actions
8. **Detail views** — drill-down screens that tie everything together
9. **Additive features** — alerts, notifications, feeds
10. **Agent panel** — embedded AI (fork, not replacement)

Each feature gets a test. Each test takes screenshots. After each feature, `dev.sh all` must pass.
