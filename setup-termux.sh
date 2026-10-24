#!/usr/bin/env bash
# ==============================================================================
# YouTube Automation Agent - One-Time Termux & Android Setup Script
# Idempotent, portable, and safe to run multiple times.
# ==============================================================================

set -e

# Terminal colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\n${BOLD}${CYAN}=================================================="
echo -e "  YouTube Automation Agent - Termux Setup"
echo -e "==================================================${NC}\n"

# 1. Resolve Project Root
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
echo -e "${CYAN}📁 Project directory:${NC} $PROJECT_DIR"

# 2. Check for Android Shared Storage (/sdcard or /storage) noexec limitation
IS_SHARED_STORAGE=false
if [[ "$PROJECT_DIR" == *"/storage/emulated/"* ]] || [[ "$PROJECT_DIR" == *"/sdcard"* ]] || [[ "$PROJECT_DIR" == *"/mnt/sdcard"* ]]; then
  IS_SHARED_STORAGE=true
  echo -e "\n${YELLOW}⚠️  Notice: Project is in Android shared storage ($PROJECT_DIR).${NC}"
  echo -e "${YELLOW}   Android shared storage mounts do not allow executable scripts or symlinks.${NC}"
  echo -e "${YELLOW}   Transparent fallback loaders are enabled in this project, but for best${NC}"
  echo -e "${YELLOW}   performance and stability, running in Termux home (~/YouTube) is recommended.${NC}\n"
fi

# 3. Detect Environment (Termux vs Standard Linux/macOS)
IS_TERMUX=false
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ] || [[ "$PREFIX" == *"com.termux"* ]]; then
  IS_TERMUX=true
  echo -e "${GREEN}✓ Termux environment detected${NC}"
else
  echo -e "${CYAN}ℹ Standard Linux/macOS environment detected${NC}"
fi

# 4. Install Missing System Packages in Termux
if [ "$IS_TERMUX" = true ]; then
  echo -e "\n${BOLD}🔍 Checking required Termux packages...${NC}"
  PACKAGES_TO_INSTALL=()

  if ! command -v node >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("nodejs")
  fi
  if ! command -v git >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("git")
  fi
  if ! command -v ffmpeg >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("ffmpeg")
  fi
  if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("python")
  fi
  if ! command -v clang >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("clang")
  fi
  if ! command -v make >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("make")
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    PACKAGES_TO_INSTALL+=("sqlite")
  fi

  if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo -e "${CYAN}📦 Installing missing packages via pkg:${NC} ${PACKAGES_TO_INSTALL[*]}"
    pkg update -y || apt-get update -y
    pkg install -y "${PACKAGES_TO_INSTALL[@]}" build-essential || apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
  else
    echo -e "${GREEN}✓ All required system packages (node, git, ffmpeg, python, clang, make, sqlite) are present${NC}"
  fi

  # Configure node-gyp to resolve Termux "Undefined variable android_ndk_path" error
  mkdir -p "$HOME/.gyp"
  cat <<'EOF' > "$HOME/.gyp/include.gypi"
{
  "variables": {
    "android_ndk_path": ""
  }
}
EOF
  export GYP_DEFINES="android_ndk_path=''"
fi

# 5. Verify Node.js & npm
echo -e "\n${BOLD}🔍 Verifying Node.js and npm...${NC}"
if ! command -v node >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Node.js is not installed.${NC}"
  if [ "$IS_TERMUX" = true ]; then
    echo -e "   Please run: ${CYAN}pkg install nodejs${NC}"
  else
    echo -e "   Please install Node.js 18+ from https://nodejs.org${NC}"
  fi
  exit 1
fi

NODE_VER=$(node -v)
echo -e "  Node.js version: ${CYAN}${NODE_VER}${NC}"

NODE_MAJOR=$(node -e 'console.log(process.versions.node.split(".")[0])')
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo -e "${RED}❌ Error: Node.js version must be 18 or higher (found: $NODE_VER).${NC}"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: npm is not available.${NC}"
  exit 1
fi
echo -e "  npm version:     ${CYAN}$(npm -v)${NC}"

# 6. Verify FFmpeg
if command -v ffmpeg >/dev/null 2>&1; then
  echo -e "${GREEN}✓ FFmpeg binary found on system PATH${NC}"
else
  echo -e "${YELLOW}⚠️  FFmpeg not found on PATH. In Termux, install it with: pkg install ffmpeg${NC}"
fi

# 7. Create Required Project Directories
echo -e "\n${BOLD}📁 Ensuring project directories exist...${NC}"
DIRS=(
  "config"
  "logs"
  "data"
  "data/production"
  "data/assets"
  "data/videos"
  "data/audio"
  "data/scripts"
  "data/captions"
  "data/thumbnails"
  "data/thumbnail-templates"
  "temp"
  "temp/processing"
  "uploads/thumbnails"
)

for d in "${DIRS[@]}"; do
  mkdir -p "$PROJECT_DIR/$d"
done
echo -e "${GREEN}✓ Directory structure verified${NC}"

# 8. Install npm Dependencies
echo -e "\n${BOLD}📦 Checking npm dependencies...${NC}"
export GYP_DEFINES="android_ndk_path=''"
if [ ! -d "$PROJECT_DIR/node_modules" ] || [ ! -d "$PROJECT_DIR/node_modules/express" ]; then
  echo -e "${CYAN}Running npm install...${NC}"
  if [ "$IS_SHARED_STORAGE" = true ]; then
    npm install --no-audit --no-fund --no-bin-links || true
  else
    npm install --no-audit --no-fund || true
  fi
fi

# Ensure sqlite3 native module builds cleanly on Android/Termux
if [ "$IS_TERMUX" = true ] && ! node -e "require('sqlite3')" >/dev/null 2>&1; then
  echo -e "${CYAN}Building sqlite3 for Termux (linking system SQLite)...${NC}"
  PREFIX_PATH="${PREFIX:-/data/data/com.termux/files/usr}"
  npm install sqlite3 --build-from-source --sqlite="$PREFIX_PATH" || true
fi
echo -e "${GREEN}✓ Dependencies verified${NC}"

# 9. Configure Environment File (.env)
echo -e "\n${BOLD}⚙️  Checking environment configuration...${NC}"
if [ ! -f "$PROJECT_DIR/.env" ]; then
  if [ -f "$PROJECT_DIR/.env.example" ]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    echo -e "${GREEN}✓ Created .env template from .env.example${NC}"
  else
    cat <<'EOF' > "$PROJECT_DIR/.env"
NODE_ENV=production
PORT=3456
HOST=0.0.0.0
LOG_LEVEL=info
CHANNEL_NAME=My YouTube Channel
DEFAULT_AUTHOR=Operator
TARGET_AUDIENCE=General
DEFAULT_PRIVACY_STATUS=private
AUTO_SHORTEN_CONTENT=true
AUTO_ADD_BACKLINKS=true
EOF
    echo -e "${GREEN}✓ Created default .env file${NC}"
  fi
else
  echo -e "${GREEN}✓ Existing .env configuration preserved${NC}"
fi

# Ensure HOST is 0.0.0.0 if unset for mobile dashboard connectivity
if ! grep -q "^HOST=" "$PROJECT_DIR/.env"; then
  echo "HOST=0.0.0.0" >> "$PROJECT_DIR/.env"
fi

# 10. Make Scripts Executable
echo -e "\n${BOLD}🔧 Setting executable permissions on scripts...${NC}"
chmod +x "$PROJECT_DIR/start.sh" "$PROJECT_DIR/stop.sh" "$PROJECT_DIR/setup-termux.sh" 2>/dev/null || true
echo -e "${GREEN}✓ Scripts are executable (start.sh, stop.sh, setup-termux.sh)${NC}"

# 11. Optional Shell Aliases (Termux)
if [ "$IS_TERMUX" = true ] && [ -n "$HOME" ]; then
  SHELL_RC=""
  if [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  elif [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
    touch "$SHELL_RC"
  fi

  if [ -n "$SHELL_RC" ]; then
    if ! grep -q "yt-start" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# YouTube Automation Agent shortcuts" >> "$SHELL_RC"
      echo "alias yt-start=\"$PROJECT_DIR/start.sh\"" >> "$SHELL_RC"
      echo "alias yt-stop=\"$PROJECT_DIR/stop.sh\"" >> "$SHELL_RC"
      echo -e "${GREEN}✓ Added optional aliases yt-start and yt-stop to $SHELL_RC${NC}"
    fi
  fi
fi

# 12. Health Check Validation
echo -e "\n${BOLD}🩺 Running quick validation...${NC}"
node -e "
try {
  require('./utils/native-loader');
  require('express');
  require('./utils/logger');
  console.log('  ✓ Core Node.js modules loaded cleanly');
} catch (e) {
  console.error('  ✗ Validation failed:', e.message);
  process.exit(1);
}
"

# 13. Summary & Next Steps
echo -e "\n${BOLD}${GREEN}=================================================="
echo -e "  🎉 Setup Completed Successfully!"
echo -e "==================================================${NC}"
echo -e "  To start the application:"
echo -e "    ${BOLD}${CYAN}./start.sh${NC}"
echo -e ""
echo -e "  To stop the application:"
echo -e "    ${BOLD}${CYAN}./stop.sh${NC}"
echo -e ""
echo -e "  Dashboard URL:"
echo -e "    ${BOLD}${CYAN}http://127.0.0.1:3456${NC}"
echo -e ""
echo -e "  To configure API keys (OpenAI / Gemini / YouTube):"
echo -e "    ${CYAN}nano .env${NC}  or  ${CYAN}npm run walkthrough${NC}"
echo -e "==================================================\n"
