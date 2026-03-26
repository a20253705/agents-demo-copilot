#!/bin/bash
# Dev cycle: concat → bundle → run specified tests
# Every invocation logged to dev.log as JSONL
# Usage:
#   ./dev.sh                    Build only
#   ./dev.sh portfolio          Build + test portfolio
#   ./dev.sh portfolio orders   Build + test multiple
#   ./dev.sh all                Build + full regression
#   Add --agent for agent fork
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG="$PROJECT_DIR/dev.log"
AGENT_FLAG=""
FEATURES=()

for arg in "$@"; do
  case "$arg" in
    --agent) AGENT_FLAG="--agent" ;;
    *) FEATURES+=("$arg") ;;
  esac
done

START=$(date +%s%N)
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
COMMIT=$(cd "$PROJECT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "none")

# ── Concat ──
CONCAT_OUT=$(bash "$SCRIPT_DIR/concat.sh" $AGENT_FLAG 2>&1)
echo "$CONCAT_OUT" | grep -E "✅|❌"
LINES=$(echo "$CONCAT_OUT" | grep -oP '\d+ lines' | grep -oP '\d+' || echo "0")
PARTS=$(echo "$CONCAT_OUT" | grep -oP '\d+ parts' | grep -oP '\d+' || echo "0")

# ── Bundle ──
BUNDLE_START=$(date +%s%N)
if ! BUNDLE_OUT=$(npx esbuild "$PROJECT_DIR/shell/entry.jsx" \
  --bundle \
  --outfile="$PROJECT_DIR/shell/dist/bundle.js" \
  --format=iife --jsx=automatic --loader:.jsx=jsx \
  --define:process.env.NODE_ENV=\"production\" \
  --minify=false 2>&1); then
  echo "💥 Bundle failed"
  BUNDLE_MS=$(( ($(date +%s%N) - BUNDLE_START) / 1000000 ))
  echo "{\"ts\":\"$TIMESTAMP\",\"commit\":\"$COMMIT\",\"args\":\"$*\",\"parts\":$PARTS,\"lines\":$LINES,\"bundle_ms\":$BUNDLE_MS,\"bundle_ok\":false}" >> "$LOG"
  exit 1
fi
BUNDLE_MS=$(( ($(date +%s%N) - BUNDLE_START) / 1000000 ))
BUNDLE_KB=$(echo "$BUNDLE_OUT" | grep -oP '[\d.]+' | head -1 || echo "0")

# ── Tests ──
TEST_PASS=0
TEST_FAIL=0
TEST_NAMES="[]"
TEST_MS=0
if [ ${#FEATURES[@]} -gt 0 ]; then
  TEST_START=$(date +%s%N)
  if [ "${FEATURES[0]}" = "all" ]; then
    echo "🧪 Running ALL tests..."
    TEST_OUT=$(node "$PROJECT_DIR/tests/run.js" all 2>&1) || true
  else
    echo "🧪 Running: ${FEATURES[*]}"
    TEST_OUT=$(node "$PROJECT_DIR/tests/run.js" "${FEATURES[@]}" 2>&1) || true
  fi
  echo "$TEST_OUT"
  TEST_PASS=$(echo "$TEST_OUT" | grep -oP '\d+ passed' | grep -oP '\d+' || echo "0")
  TEST_FAIL=$(echo "$TEST_OUT" | grep -oP '\d+ failed' | grep -oP '\d+' || echo "0")
  TEST_MS=$(( ($(date +%s%N) - TEST_START) / 1000000 ))
  TEST_NAMES=$(printf '%s\n' "${FEATURES[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
fi

TOTAL_MS=$(( ($(date +%s%N) - START) / 1000000 ))

# ── JSONL log ──
echo "{\"ts\":\"$TIMESTAMP\",\"commit\":\"$COMMIT\",\"args\":\"$*\",\"parts\":$PARTS,\"lines\":$LINES,\"bundle_ms\":$BUNDLE_MS,\"bundle_kb\":$BUNDLE_KB,\"bundle_ok\":true,\"tests\":$TEST_NAMES,\"test_pass\":$TEST_PASS,\"test_fail\":$TEST_FAIL,\"test_ms\":$TEST_MS,\"total_ms\":$TOTAL_MS}" >> "$LOG"

echo "⏱️  ${TOTAL_MS}ms"
