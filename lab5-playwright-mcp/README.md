# Lab 4 — Give Copilot a Browser

Use the **Playwright MCP server** to let GitHub Copilot browse the web, take screenshots, click buttons, and fill forms — all from chat.

## Setup

No manual install needed. The MCP server is configured in `.vscode/mcp.json` and runs via `npx` automatically.

In Codespaces the server runs **headless** (no visible browser window).

## Quick Test

Open the GitHub Copilot side panel in **Agent mode** and try:

```
Navigate to https://example.com and tell me what's on the page
```
