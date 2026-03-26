#!/usr/bin/env bash
set -euo pipefail

echo "================================================"
echo "  Setting up GenAI & AI Agents Lab Environment"
echo "================================================"

echo ""
echo "--- Python dependencies ---"
pip install --upgrade pip --quiet
for req in lab2-skills/requirements.txt lab3-mcp-server/requirements.txt; do
    if [ -f "$req" ]; then
        echo "Installing $req..."
        pip install -r "$req" --quiet
    fi
done

echo ""
echo "--- Node.js dependencies (Lab 1) ---"
cd lab1-web-app
if command -v pnpm &> /dev/null; then
    pnpm install --silent
else
    echo "pnpm not found, using npm..."
    npm install --silent
fi
cd ..

echo ""
echo "--- Playwright browser (Lab 4) ---"
sudo npx -y playwright install-deps chromium 2>/dev/null || true
npx -y playwright install chromium

echo ""
echo "================================================"
echo "  Setup complete! Open Copilot and type /lab1"
echo "================================================"
