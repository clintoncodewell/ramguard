# RamGuard

A lightweight macOS menu bar app for real-time RAM and disk monitoring, process management, and on-demand AI-powered kill recommendations.

**Single-file Swift. Pure AppKit. Zero dependencies. 232KB binary. 18MB runtime footprint.**

---

## What It Does

RamGuard lives in your menu bar and shows your current RAM and SSD usage at a glance:

```
RAM 72%   SSD 84%
```

Click to open a popover with full system details:

- **RAM Overview Bar** — Segmented bar showing App / Wired / Compressed / Free breakdown with animated transitions and memory pressure indicator
- **Process List** — Every running process with app icon, name, PID, type, CPU%, RAM usage bar, and RAM value in monospaced digits
- **Search & Filter** — Live search by name or PID, sort by RAM/CPU/Name/PID/Runtime, filter by type (User/System/Background/High RAM)
- **Kill Processes** — Hover to reveal kill button, inline confirmation with Cancel/Kill/Force Quit, 5-second auto-cancel safety timer
- **Process Descriptions** — Click any row to expand and see what the process does (100+ pre-loaded descriptions). Unknown processes get a "Search" button that opens a pre-built Google query
- **Copy Footprint** — One click copies a full formatted snapshot of your system (RAM breakdown, SSD usage, top 40 processes) to clipboard for pasting into AI or sharing
- **Settings** — Configurable display mode, refresh interval (2/5/10/30s), alert thresholds, notification preferences, process display options
- **AI Analysis (Phase 2)** — On-demand process analysis via local Ollama/Gemma model. Badges each process as SAFE/CAUTION/KEEP with reasoning. Optional auto-kill for background processes

---

## Install

### Build from source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone <repo-url> ramguard
cd ramguard
./build.sh
```

### Run

```bash
open RamGuard.app
```

Or copy to Applications:

```bash
cp -R RamGuard.app /Applications/
open /Applications/RamGuard.app
```

RamGuard runs as a menu bar app — no Dock icon, no Cmd+Tab entry. To quit, click the menu bar text and use the Quit button in the popover footer.

---

## Architecture

Everything lives in a single `main.swift` (~1060 lines). No Xcode project, no Package.swift, no storyboards, no SwiftUI.

```
ramguard/
├── main.swift                    # All app logic
├── build.sh                      # Build script (swiftc + strip)
├── .gitignore
└── RamGuard.app/
    └── Contents/
        ├── Info.plist            # LSUIElement, bundle ID
        └── MacOS/
            └── ramguard          # 232KB compiled binary
```

### Tech stack

| Layer | Choice | Why |
|-------|--------|-----|
| Language | Swift | Native, fast, no runtime overhead |
| UI | AppKit (NSStatusItem + NSPopover) | Native menu bar integration, minimal memory |
| Layout | Manual frames | No AutoLayout overhead, predictable positioning |
| Data | Mach APIs (host_statistics64, proc_pidinfo) | Direct kernel calls, no shell overhead |
| Config | JSON at `~/.config/ramguard/config.json` | Simple, human-editable |
| Build | `swiftc -Osize` + `strip` | No Xcode project needed |

### Memory efficiency

RamGuard targets <20MB runtime footprint. Key techniques:

- **Icon caching** — Process icons fetched once per app, reused across refresh cycles
- **Autoreleasepool** — Temporary objects in the fetch loop freed immediately
- **Popover cleanup** — Process data and view hierarchy freed when popover closes
- **Shared state** — Running app PID set cached and reused between fetch and group functions
- **No wasted layers** — Layer-backed views only where GPU compositing is needed

### How process data is collected

1. `host_statistics64(HOST_VM_INFO64)` — System-wide RAM breakdown (active, wired, compressed, free)
2. `proc_listallpids()` — All process IDs on the system
3. `proc_pidinfo(PROC_PIDTASKINFO)` — Per-process resident memory, CPU time, thread count
4. `proc_pidinfo(PROC_PIDTBSDINFO)` — Per-process UID, parent PID, start time
5. `NSWorkspace.shared.runningApplications` — App names and icons for GUI processes
6. CPU% calculated as delta of cumulative CPU time between samples, converted via Mach timebase

### How kill works

- **Kill** sends `SIGTERM` (graceful shutdown, app can save state)
- **Force** sends `SIGKILL` (immediate termination, no cleanup)
- Protected processes (kernel_task, launchd, WindowServer, root-owned) cannot be killed
- Kill confirmation is inline (replaces the row), auto-cancels after 5 seconds
- Popover switches to semi-transient mode during confirmation to prevent accidental dismiss
- Kill failure triggers an audible beep

---

## AI Features (Phase 2)

RamGuard can connect to a local [Ollama](https://ollama.com) instance to analyze running processes and recommend what's safe to kill.

### Setup

1. Install Ollama: `brew install ollama`
2. Pull a model: `ollama pull gemma3` (or any model you prefer)
3. Start Ollama: `ollama serve`
4. In RamGuard Settings, enable "AI recommendations" and set the model name

### How it works

1. Click the **AI** button in the popover footer
2. RamGuard sends the top 30 processes (by RAM) to Ollama with a structured prompt
3. The model classifies each as **SAFE** / **CAUTION** / **CRITICAL** with reasoning
4. Badges appear on each process row with color-coded verdicts
5. Click AI again to dismiss the analysis

### Auto-kill

If enabled in settings, RamGuard can automatically kill processes the AI marks as SAFE — but only:
- Background-type processes (not user apps, not system)
- Non-protected processes
- With full logging to `~/.config/ramguard/ai-kills.log`

Auto-kill is off by default and requires explicit opt-in.

### Safety

- AI can never kill without on-screen confirmation (auto-kill still logs everything)
- Protected processes are excluded from AI analysis entirely
- The Ollama `keep_alive: 60s` parameter tells the model to unload after idle, so the AI doesn't become the RAM problem
- All recommendations show reasoning — no opaque decisions

---

## Configuration

Config file: `~/.config/ramguard/config.json`

```json
{
    "displayMode": "usedRam",
    "refreshInterval": 2,
    "alertThreshold": 80,
    "showNotifications": true,
    "maxProcesses": 50,
    "groupHelpers": true,
    "showCPU": true,
    "showThreads": false,
    "aiEnabled": false,
    "aiAutoKill": false,
    "aiModel": "gemma3",
    "ollamaURL": "http://localhost:11434"
}
```

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `displayMode` | `usedRam`, `percent`, `usedTotal`, `iconOnly` | `usedRam` | What the status bar display mode setting controls (settings UI overrides this) |
| `refreshInterval` | `2`, `5`, `10`, `30` | `2` | Seconds between data refreshes |
| `alertThreshold` | `60`, `70`, `80`, `90` | `80` | RAM % that triggers a notification |
| `showNotifications` | boolean | `true` | Send macOS notifications on high RAM |
| `maxProcesses` | `25`, `50`, `100`, `200` | `50` | Max process rows shown in popover |
| `groupHelpers` | boolean | `true` | Merge helper/XPC processes under parent app |
| `showCPU` | boolean | `true` | Show CPU% in process metadata |
| `showThreads` | boolean | `false` | Show thread count in process metadata |
| `aiEnabled` | boolean | `false` | Show AI button and enable Ollama integration |
| `aiAutoKill` | boolean | `false` | Allow AI to auto-kill safe background processes |
| `aiModel` | string | `gemma3` | Ollama model name for AI analysis |
| `ollamaURL` | string | `http://localhost:11434` | Ollama server URL |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Type in search field | Live filter by process name or PID |
| Click process row | Expand/collapse description |
| Hover process row | Reveal kill button |

---

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel
- Xcode Command Line Tools (for building from source)
- Ollama (optional, for AI features)

---

## License

MIT
