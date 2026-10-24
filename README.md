# YouTube Automation Agent

**The open-source AI agent that runs a YouTube channel end to end, with you approving every video before it goes out.**

It researches topics, writes scripts, generates narration and visuals, assembles real MP4s, writes titles, descriptions and tags, schedules approved videos, and learns from analytics and audience comments. Runs on your own machine (Android/Termux, Linux, macOS, or Windows) with your own API keys.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node.js 18.17+](https://img.shields.io/badge/node-18.17%2B-43853d.svg)](package.json)
[![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux%20%7C%20macOS-blue)](https://termux.dev)

---

## 📱 Termux Quick Start (Android)

Run this entire application on an Android phone using [Termux](https://termux.dev) with just three commands.

### 1. One-time setup
```bash
# In Termux home directory (~/):
git clone <your-repo-url> YouTube
cd YouTube
bash setup-termux.sh
```
*The setup script installs Node.js, Git, FFmpeg, Python, verifies all npm dependencies, prepares the directory structure, and configures `.env`.*

### 2. Start the application
```bash
./start.sh
# (or: bash start.sh)
```
*Starts the background server, performs a health check, and automatically opens the mobile dashboard in your Android browser!*

### 3. Open the dashboard
If the browser did not open automatically, simply tap or visit:
👉 **`http://127.0.0.1:3456`**

### 4. Stop the application
When you are finished, stop the server with one command:
```bash
./stop.sh
# (or: bash stop.sh)
```

*(Optional shortcuts: If configured during setup, you can also use `yt-start` and `yt-stop` from anywhere in Termux!)*

---

## 💻 Desktop / Server Quick Start (Linux / macOS / Windows)

```bash
git clone <your-repo-url> youtube-automation
cd youtube-automation
npm install
./start.sh
```
Open **`http://localhost:3456`** in your browser.

To stop:
```bash
./stop.sh
```

---

## ⚙️ Configuration & API Credentials

Configuration is handled through `.env`. When you first run `setup-termux.sh` or `start.sh`, a `.env` file is automatically created from `.env.example`.

### Required vs. Optional Credentials

| Service | Status | Where to Get | Description |
| --- | --- | --- | --- |
| **At least ONE AI Text Provider** | **REQUIRED** | [Google AI Studio](https://aistudio.google.com/apikey) (Free) or [OpenAI](https://platform.openai.com) | Used to research ideas, write scripts, generate descriptions and tags. (Gemini free tier works great!) |
| **YouTube Data API** | **REQUIRED for Publishing** | [Google Cloud Console](https://console.cloud.google.com/) | OAuth2 credentials to schedule and upload videos to your channel. |
| **ElevenLabs TTS** | OPTIONAL | [ElevenLabs](https://elevenlabs.io/) | High-quality narration voices (fallback uses OpenAI TTS, Gemini TTS, or free slideshow). |
| **AI Video Generators** | OPTIONAL | Replicate (Seedance), MiniMax H3, Kling, or Wan | For AI video scenes. (Local slideshow video assembly is built-in and free!) |
| **API_KEY** | OPTIONAL | Any secure passphrase | Protects mutating API endpoints if you set `HOST=0.0.0.0` to access the dashboard across your local Wi-Fi. |

### Interactive Credential Wizard
You do not need to edit files manually. Simply run:
```bash
npm run walkthrough
```
This guided CLI will test your API keys as you enter them and authenticate your YouTube channel.

---

## 🤖 Why it's different

- **You approve before anything is published:** Finished videos wait for fact review, media-rights confirmation, and your approval. Turning on autonomy never skips safety gates.
- **Real output only:** Simulated or placeholder media is clearly marked and can never be approved or uploaded.
- **100% Self-hosted & Private:** Your API keys, generated videos, scripts, and channel data never leave your device.
- **Closed-Loop Channel Learning:** The agent analyzes 24-hour and 7-day retention curves, comments, and views to suggest actionable improvements for future videos.
- **Multi-provider choices:** Use Gemini, OpenAI, OpenRouter, DeepSeek, Kimi, MiMo, GLM, or MiniMax.

---

## 🔄 Live Automation Pipeline

```
Research & Backlog
       ↓
Script Generation
       ↓
Narration & Voice
       ↓
Visuals & Thumbnails
       ↓
Video Assembly (FFmpeg)
       ↓
Quality & Fact Review (Human Approval)
       ↓
YouTube Scheduling & Publishing
       ↓
Analytics & Audience Engagement
```

---

## 🛠 Single-Command Control Scripts

| Script | Purpose |
| --- | --- |
| **`./setup-termux.sh`** | Idempotent one-time installer for Android/Termux. Detects missing packages, installs Node.js, FFmpeg, Git, and npm dependencies. |
| **`./start.sh`** | Validates configuration, ensures no duplicate instances run, starts background service, monitors health until ready, and launches browser. |
| **`./stop.sh`** | Gracefully terminates server and child processes, cleans up PID files, and confirms shutdown. |
| **`npm run walkthrough`** | Interactive setup wizard explaining every credential and testing keys. |
| **`npm test`** | Complete system verification test suite. |

---

## 📱 Android & Termux Notes

1. **Storage Location (Important):**
   - For best performance and full file execution permissions, keep this project in Termux's internal home directory (`~/YouTube` or `/data/data/com.termux/files/home/YouTube`).
   - If cloned to `/sdcard/` or `/storage/emulated/0/`, Android's FUSE filesystem prohibits executable bits. Run scripts using `bash start.sh` and `bash stop.sh`.
2. **Prevent Sleep (Wakelock):**
   - When generating long videos or running background cron tasks, ensure Termux is not put to sleep by Android:
   - Swipe down Termux notification and tap **"Acquire Wakelock"**, or run `termux-wake-lock`.
3. **FFmpeg on Termux:**
   - FFmpeg is installed directly via `pkg install ffmpeg`. The project automatically detects the Termux FFmpeg binary on your PATH.

---

## 🔄 Updating the Application

To update to the latest version without losing your `.env` configuration or database:
```bash
git pull
bash setup-termux.sh
./start.sh
```
*Your `.env` file, generated videos, and database records in `data/` are never overwritten.*

---

## 📤 Publishing to Your Own GitHub Repository

To push this codebase to your own GitHub account:

1. Create a new empty repository on [GitHub](https://github.com/new) (e.g. `my-youtube-automation`).
2. Run these commands from inside this project directory:
```bash
# Add your remote repository:
git remote add origin https://github.com/<YOUR-USERNAME>/<YOUR-REPO-NAME>.git

# Push to your main branch:
git branch -M main
git push -u origin main
```
*(Your `.env`, API keys, logs, temporary files, and downloaded media are strictly excluded by `.gitignore` and will never be committed to Git).*

---

## ❓ Troubleshooting

| Issue | Solution |
| --- | --- |
| **Missing AI provider** | Run `npm run walkthrough` or add `GEMINI_API_KEY=...` to `.env`. |
| **Port 3456 is occupied** | Change `PORT=3457` in `.env` or run `./stop.sh` to terminate the active instance. |
| **Server won't start** | Check recent logs in `logs/server.log` or run `node index.js` directly to inspect error messages. |
| **Permission denied running `./start.sh`** | If on Android shared storage, invoke with `bash start.sh` or run `chmod +x start.sh`. |
| **Google OAuth access_denied** | Add your Google email as an authorized test user in Google Cloud Console under *OAuth Consent Screen → Test Users*. |

---

## 📄 License

MIT. See [LICENSE](LICENSE). Comply with [YouTube's Terms of Service](https://www.youtube.com/t/terms) and Community Guidelines.
