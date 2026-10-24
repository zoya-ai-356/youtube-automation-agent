#!/usr/bin/env bash
# ==============================================================================
# YouTube Automation Agent - Startup Script
# Starts the background server, verifies health, and displays dashboard URL.
# ==============================================================================

set -e

# Terminal formatting
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Resolve Project Root
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PID_FILE="$PROJECT_DIR/.app.pid"
LOG_FILE="$PROJECT_DIR/logs/server.log"

echo -e "\n${BOLD}${CYAN}YouTube Automation${NC}\n"
echo -e "Status: ${BOLD}${YELLOW}STARTING${NC}\n"

# 2. Check Node.js
echo -e "Checking dependencies..."
if ! command -v node >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Node.js is not installed.${NC}"
  echo -e "   Please run: ./setup-termux.sh"
  exit 1
fi

if [ ! -d "$PROJECT_DIR/node_modules" ]; then
  echo -e "${RED}❌ Error: Dependencies are missing (node_modules not found).${NC}"
  echo -e "   Please run: ./setup-termux.sh"
  exit 1
fi

# 3. Load & Check Configuration
echo -e "Checking configuration..."
if [ ! -f "$PROJECT_DIR/.env" ]; then
  if [ -f "$PROJECT_DIR/.env.example" ]; then
    echo -e "${YELLOW}ℹ .env not found; copying template from .env.example...${NC}"
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  fi
fi

# Extract PORT & HOST from .env or defaults
PORT="3456"
HOST="0.0.0.0"
if [ -f "$PROJECT_DIR/.env" ]; then
  ENV_PORT=$(grep -E "^PORT=" "$PROJECT_DIR/.env" | cut -d '=' -f2 | tr -d ' "\r' || true)
  if [ -n "$ENV_PORT" ]; then
    PORT="$ENV_PORT"
  fi
  ENV_HOST=$(grep -E "^HOST=" "$PROJECT_DIR/.env" | cut -d '=' -f2 | tr -d ' "\r' || true)
  if [ -n "$ENV_HOST" ]; then
    HOST="$ENV_HOST"
  fi
fi

# 4. Check if Application is Already Running
if [ -f "$PID_FILE" ]; then
  EXISTING_PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [ -n "$EXISTING_PID" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    echo -e "\nStatus: ${BOLD}${GREEN}RUNNING${NC} (Already active, PID: $EXISTING_PID)\n"
    echo -e "Dashboard:"
    echo -e "${BOLD}${CYAN}http://127.0.0.1:${PORT}${NC}\n"
    exit 0
  else
    # Process is no longer alive, clean up stale PID file
    rm -f "$PID_FILE"
  fi
fi

# 5. Check if Port is Already Bound
PORT_IN_USE=$(node -e "
const net = require('net');
const s = net.createServer();
s.once('error', err => {
  if (err.code === 'EADDRINUSE') {
    console.log('occupied');
  }
  process.exit(0);
});
s.once('listening', () => {
  s.close(() => process.exit(0));
});
s.listen($PORT, '$HOST');
" 2>/dev/null || true)

if [ "$PORT_IN_USE" = "occupied" ]; then
  # Check if it's already responding to our /health endpoint
  HEALTH_OK=$(node -e "
    fetch('http://127.0.0.1:${PORT}/health')
      .then(r => r.json())
      .then(d => { if (d.status !== undefined || d.initialized !== undefined) console.log('ok'); })
      .catch(() => {});
  " 2>/dev/null || true)

  if [ "$HEALTH_OK" = "ok" ]; then
    echo -e "\nStatus: ${BOLD}${GREEN}RUNNING${NC} (Server is already active on port ${PORT})\n"
    echo -e "Dashboard:"
    echo -e "${BOLD}${CYAN}http://127.0.0.1:${PORT}${NC}\n"
    exit 0
  else
    echo -e "${RED}❌ Error: Port ${PORT} is occupied by another service.${NC}"
    echo -e "   Please change PORT in .env or stop the other application."
    exit 1
  fi
fi

# 6. Ensure Logs and Data Directories Exist
mkdir -p "$PROJECT_DIR/logs" "$PROJECT_DIR/data"

# 7. Start Server in Background
echo -e "Starting server..."
if command -v setsid >/dev/null 2>&1; then
  setsid node index.js >> "$LOG_FILE" 2>&1 < /dev/null &
  APP_PID=$!
else
  nohup node index.js >> "$LOG_FILE" 2>&1 < /dev/null &
  APP_PID=$!
fi
disown "$APP_PID" 2>/dev/null || true
echo "$APP_PID" > "$PID_FILE"

# 8. Health Check Verification Loop (up to 60 seconds)
MAX_ATTEMPTS=60
ATTEMPT=0
SERVER_READY=false

printf "Waiting for server to respond"

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  sleep 1
  ATTEMPT=$((ATTEMPT + 1))
  printf "."

  # Verify process is still alive
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo -e "\n${RED}❌ Server process terminated unexpectedly!${NC}"
    if [ -f "$LOG_FILE" ]; then
      echo -e "${YELLOW}Recent log output:${NC}"
      tail -n 15 "$LOG_FILE"
    fi
    rm -f "$PID_FILE"
    exit 1
  fi

  # Probe health endpoint using built-in Node fetch
  STATUS_CHECK=$(node -e "
    fetch('http://127.0.0.1:${PORT}/health')
      .then(r => r.json())
      .then(d => {
        if (d.initialized !== undefined || d.status !== undefined) {
          process.stdout.write('ready');
        }
      })
      .catch(() => {});
  " 2>/dev/null || true)

  if [ "$STATUS_CHECK" = "ready" ]; then
    SERVER_READY=true
    break
  fi
done
echo ""

if [ "$SERVER_READY" = false ]; then
  echo -e "\n${RED}❌ Health check timed out after ${MAX_ATTEMPTS} seconds.${NC}"
  if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Recent log output:${NC}"
    tail -n 15 "$LOG_FILE"
  fi
  kill "$APP_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
  exit 1
fi

# 9. Clean Status Output
echo -e "\nStatus: ${BOLD}${GREEN}RUNNING${NC}\n"
echo -e "Dashboard:"
echo -e "${BOLD}${CYAN}http://127.0.0.1:${PORT}${NC}\n"
echo -e "PID:  $APP_PID"
echo -e "Logs: logs/server.log\n"

# 10. Automatically Launch Browser (if available, without blocking or erroring)
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
elif command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then
  open "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
fi
