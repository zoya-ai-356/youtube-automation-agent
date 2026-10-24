#!/usr/bin/env bash
# ==============================================================================
# YouTube Automation Agent - Stop Script
# Safely stops running server processes and cleans up PID files.
# ==============================================================================

# Terminal formatting
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PID_FILE="$PROJECT_DIR/.app.pid"

echo -e "\n${BOLD}${CYAN}YouTube Automation${NC}\n"
echo -e "Status: ${BOLD}${YELLOW}STOPPING${NC}\n"
echo -e "Stopping application..."

STOPPED=false

# 1. Stop by PID File if Present
if [ -f "$PID_FILE" ]; then
  APP_PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    # Send SIGTERM for graceful shutdown
    kill -15 "$APP_PID" 2>/dev/null || true

    # Wait up to 6 seconds for graceful termination
    WAIT_SEC=0
    while [ $WAIT_SEC -lt 6 ]; do
      if ! kill -0 "$APP_PID" 2>/dev/null; then
        STOPPED=true
        break
      fi
      sleep 1
      WAIT_SEC=$((WAIT_SEC + 1))
    done

    # Force kill if still hanging
    if kill -0 "$APP_PID" 2>/dev/null; then
      kill -9 "$APP_PID" 2>/dev/null || true
      sleep 1
    fi
    STOPPED=true
  else
    STOPPED=true
  fi
  rm -f "$PID_FILE"
fi

# 2. Check for any orphan node index.js process
LEFTOVER_PIDS=$(pgrep -f "node index.js" 2>/dev/null || true)
if [ -n "$LEFTOVER_PIDS" ]; then
  for p in $LEFTOVER_PIDS; do
    if [ "$p" != "$$" ]; then
      kill -15 "$p" 2>/dev/null || true
      sleep 1
      if kill -0 "$p" 2>/dev/null; then
        kill -9 "$p" 2>/dev/null || true
      fi
      STOPPED=true
    fi
  done
fi

rm -f "$PID_FILE"

echo -e "\nStatus: ${BOLD}${GREEN}STOPPED${NC}\n"
exit 0
