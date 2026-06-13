# RamGuard — Claude Context

## What this project is

A macOS menu bar app for RAM/disk monitoring and process management. Single-file Swift/AppKit, zero dependencies, designed for minimal memory footprint (~18MB).

## Architecture

- **Single file**: Everything is in `main.swift` (~1060 lines). No Xcode project.
- **Pure AppKit**: NSStatusItem + NSPopover. No SwiftUI. Frame-based layout (no AutoLayout).
- **Build**: `swiftc -Osize` via `build.sh`. Binary is ~232KB.
- **Activation**: `.accessory` policy — no Dock icon, no Cmd+Tab.
- **Pattern**: Follows the same architecture as the `cat-eye` project in this repo.

## File structure

```
main.swift        — All code: constants, config, models, data fetching, views, AI, app delegate
build.sh          — Build script (swiftc + strip)
Info.plist        — App bundle metadata (LSUIElement: true)
.gitignore        — Excludes compiled binary
```

## Code organization within main.swift

The file follows this order (search for `// MARK:` headings):
1. Constants + Process Description Database
2. Configuration (AppConfig struct, load/save, JSON persistence)
3. Enums + Models (SysRAM, DiskInfo, ProcInfo, AI types)
4. Global State (CPU tracking, icon cache, timebase)
5. System Data functions (fetchSystemRAM, fetchDiskUsage, fetchProcesses, groupProcesses)
6. Helper functions (formatting, colors, SF Symbol helper)
7. Views: Flipped, RAMOverview, Toolbar, ProcessRow, Footer, SettingsView
8. AIManager (Ollama HTTP integration)
9. MainVC (NSViewController — popover content, list rebuild, all actions)
10. RamGuardApp (NSApplicationDelegate — status bar, polling, notifications)
11. Entry Point

## Key patterns

- **Data flow**: Timer tick → fetch RAM/disk → update status bar → if popover showing: fetch processes → MainVC.update() → rebuildList()
- **View rebuild**: Process rows are torn down and recreated on each refresh. Toolbar and footer persist across refreshes to keep search field focus.
- **Icon caching**: Process icons cached by app name in global `iconCache` dict, pruned when apps quit.
- **Memory management**: Process data + view hierarchy cleared when popover closes. Autoreleasepool wraps the fetch loop.
- **Kill flow**: Row click → confirmPID set → row shows Cancel/Kill/Force → popover goes semitransient → 5s auto-cancel timer.
- **Expandable rows**: Click row → expandedPID toggled → row rebuilds taller with description text or Google search button.

## Data sources

- `host_statistics64(HOST_VM_INFO64)` — system RAM (active, wired, compressed, free)
- `proc_listallpids` + `proc_pidinfo(PROC_PIDTASKINFO/PROC_PIDTBSDINFO)` — per-process RAM, CPU, UID, PPID
- `FileManager.attributesOfFileSystem(forPath: "/")` — disk total/free
- `NSWorkspace.shared.runningApplications` — app names and icons
- Per-process CPU% is delta-based: cumulative CPU time difference between samples, converted via Mach timebase
- System CPU% (menu bar): `host_statistics(HOST_CPU_LOAD_INFO)` tick deltas (user+sys+nice / total)
- Network rate (menu bar): `getifaddrs()` AF_LINK `ifi_ibytes`/`ifi_obytes` deltas over wall-clock, all non-`lo` interfaces summed

## Menu bar metrics

The four menu bar segments (Memory `M`, CPU `C`, SSD `S`, Network `↓↑`) are each independently
toggled via the **right-click context menu** (`showContextMenu` / `toggleMetric` in the app delegate,
driven by the `metricToggles` array). State persists to config keys `menuBarRAM/CPU/SSD/Net` (Bool?,
nil → per-key default). CPU and Net are delta-based, so `toggleMetric` and `refresh`/`tick` seed a
sample when enabled. `updateStatusBar` builds the bar segment-by-segment; if all are off it shows a
`gauge.with.needle` icon so the app stays clickable. Right-click is wired via
`sendAction(on: [.leftMouseUp, .rightMouseUp])` + an event-type check in `toggle()`.

## Config

JSON at `~/.config/ramguard/config.json`. Global mutable `var config`. Saved on settings Done, quit,
popover close, or any menu bar metric toggle. New `menuBar*` keys are `Bool?` (optional) so older
config files still decode.

## AI integration

- Ollama HTTP API at configurable URL (default localhost:11434)
- POST to `/api/generate` with structured prompt, `format: "json"`, `stream: false`
- Response parsed as `AIResp` (recommendations array + summary)
- Auto-kill only targets background + non-protected + AI-safe processes
- Kill log at `~/.config/ramguard/ai-kills.log`

## Important constraints

- Must stay single-file (matches cat-eye pattern)
- Must compile with plain `swiftc` — no SPM, no Xcode
- Target <20MB runtime footprint
- System colors + SF Symbols only — no bundled assets
- No SwiftUI, no AutoLayout
- `LSUIElement: true` — menu bar only, no Dock presence

## Common tasks

- **Build**: `./build.sh`
- **Run**: `open RamGuard.app` or `./RamGuard.app/Contents/MacOS/ramguard`
- **Install**: `cp -R RamGuard.app /Applications/`
- **Check memory**: `footprint -p $(pgrep ramguard)`
- **Kill running**: `pkill ramguard`
