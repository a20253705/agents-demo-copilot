#!/bin/bash
# Concat parts into a single artifact-ready .jsx file
# Usage: ./concat.sh [--agent] [-o output.jsx]
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PARTS_DIR="$PROJECT_DIR/parts"
AGENT_DIR="$PROJECT_DIR/parts-agent"
OUTPUT="$PROJECT_DIR/app.jsx"
INCLUDE_AGENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) INCLUDE_AGENT=true; OUTPUT="$PROJECT_DIR/app-agent.jsx"; shift ;;
    -o) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# Fixed concat order — discovers part files in dependency order
# Convention: part-data → part-state → part-ui-* (alphabetical) → part-app
# Agent parts inserted before part-app
PARTS=()

# 1. Core: data, state (explicit order)
[ -f "$PARTS_DIR/part-data.jsx" ] && PARTS+=("$PARTS_DIR/part-data.jsx")
[ -f "$PARTS_DIR/part-state.jsx" ] && PARTS+=("$PARTS_DIR/part-state.jsx")

# 2. UI parts: shared first, then alphabetical
[ -f "$PARTS_DIR/part-ui-shared.jsx" ] && PARTS+=("$PARTS_DIR/part-ui-shared.jsx")
for f in "$PARTS_DIR"/part-ui-*.jsx; do
  [ -f "$f" ] || continue
  [[ "$f" == *"part-ui-shared.jsx" ]] && continue  # already added
  PARTS+=("$f")
done

# 3. Backwards compat: single part-components.jsx (if no split yet)
[ -f "$PARTS_DIR/part-components.jsx" ] && [ ${#PARTS[@]} -eq 2 ] && PARTS+=("$PARTS_DIR/part-components.jsx")

# 4. Agent parts (if --agent flag)
if [ "$INCLUDE_AGENT" = true ]; then
  for f in "$AGENT_DIR"/part-*.jsx; do
    [ -f "$f" ] && PARTS+=("$f")
  done
fi

# 5. App shell (always last)
[ -f "$PARTS_DIR/part-app.jsx" ] && PARTS+=("$PARTS_DIR/part-app.jsx")

# Header: React imports for Claude.ai artifact
cat > "$OUTPUT" << 'HEADER'
import React, { useState, useReducer, useEffect, useRef, useCallback } from "react";

HEADER

# Concatenate parts, stripping individual imports/exports
for part in "${PARTS[@]}"; do
  if [ ! -f "$part" ]; then
    echo "⚠️  Missing: $part"
    continue
  fi
  sed -E \
    -e '/^export default/d' \
    -e '/^import .* from ["\x27]react["\x27]/d' \
    -e '/^const \{ .* \} = React;/d' \
    "$part" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
done

# Find the component name from part-app.jsx
COMPONENT=$(grep -oP '(?<=^function )\w+' "$PARTS_DIR/part-app.jsx" | tail -1)
echo "export default ${COMPONENT:-App};" >> "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
echo "✅ Assembled $OUTPUT ($LINES lines, ${#PARTS[@]} parts)"
