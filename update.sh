#!/usr/bin/env bash
# ==============================================================================
# YouTube Automation Agent - Quick Update Script for Termux & Linux
# Safely updates to the latest code, fixes Termux sqlite3 build, and restarts.
# ==============================================================================

set -e

# Terminal colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${BOLD}${CYAN}=================================================="
echo -e "  YouTube Automation Agent - Update"
echo -e "==================================================${NC}\n"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 1. Stop running application before updating
if [ -f "$PROJECT_DIR/stop.sh" ]; then
  echo -e "${CYAN}Stopping active application...${NC}"
  bash "$PROJECT_DIR/stop.sh" 2>/dev/null || true
fi

# 2. Fix Termux node-gyp & sqlite3 environment
IS_TERMUX=false
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ] || [[ "$PREFIX" == *"com.termux"* ]]; then
  IS_TERMUX=true
  echo -e "\n${BOLD}🔧 Setting up Termux build environment...${NC}"

  # Install required build tools
  pkg install -y python make clang sqlite build-essential || apt-get install -y python make clang sqlite build-essential || true

  # Fix node-gyp android_ndk_path issue
  mkdir -p "$HOME/.gyp"
  cat <<'EOF' > "$HOME/.gyp/include.gypi"
{
  "variables": {
    "android_ndk_path": ""
  }
}
EOF
  export GYP_DEFINES="android_ndk_path=''"
  echo -e "${GREEN}✓ Fixed Termux node-gyp configuration (android_ndk_path)${NC}"
fi

# 3. Pull latest code from GitHub (preserving user .env and data/)
echo -e "\n${BOLD}📥 Pulling latest updates from GitHub...${NC}"
git stash 2>/dev/null || true
git pull origin main || git pull origin master || true
git stash pop 2>/dev/null || true

# 4. If sqlite3 was broken, clean its cache and rebuild
if [ "$IS_TERMUX" = true ]; then
  if ! node -e "require('sqlite3')" 2>/dev/null; then
    echo -e "${YELLOW}Rebuilding sqlite3 from source for Termux...${NC}"
    rm -rf "$PROJECT_DIR/node_modules/sqlite3"
    export GYP_DEFINES="android_ndk_path=''"
    PREFIX_PATH="${PREFIX:-/data/data/com.termux/files/usr}"
    npm install sqlite3 --build-from-source --sqlite="$PREFIX_PATH" || true
  fi
fi

# 5. Run setup-termux.sh to ensure all dependencies and directories are ready
echo -e "\n${BOLD}📦 Verifying dependencies and configuration...${NC}"
bash "$PROJECT_DIR/setup-termux.sh"

# 6. Start the server
echo -e "\n${BOLD}🚀 Starting application...${NC}"
bash "$PROJECT_DIR/start.sh"

echo -e "\n${BOLD}${GREEN}=================================================="
echo -e "  🎉 Update Complete!"
echo -e "==================================================${NC}\n"
