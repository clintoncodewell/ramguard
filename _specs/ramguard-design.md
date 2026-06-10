# RamGuard - Design Specification

> macOS menu bar app for real-time RAM monitoring, process management, and (Phase 2) AI-powered kill recommendations via Gemma 4.

---

## 1. Product Definition

| Attribute | Value |
|-----------|-------|
| **Type** | System utility / monitoring tool |
| **Platform** | macOS (menu bar / status bar) |
| **Architecture** | Single-file Swift, pure AppKit, zero dependencies (matches CatEye pattern) |
| **Build** | `swiftc` direct compilation, no Xcode project |
| **Binary target** | < 300KB |
| **Activation policy** | `.accessory` (no Dock icon, no Cmd+Tab) |
| **UI surface** | NSPopover from NSStatusItem |

---

## 2. Design System

### 2.1 Style: Dark Mode Native + Real-Time Monitoring Hybrid

RamGuard uses **macOS system colors** as the foundation (matching CatEye's native feel) with a dark-leaning palette optimized for an always-on monitoring tool. The app respects the user's system appearance but defaults to a dark aesthetic for its data-dense content.

**Why system colors:** Consistency with CatEye, zero maintenance for macOS appearance changes, automatic accessibility compliance.

### 2.2 Color Tokens

```
┌─────────────────────────────────────────────────────────────┐
│  SEMANTIC COLORS (NSColor system)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Surfaces                                                   │
│  ─────────                                                  │
│  Background      .windowBackgroundColor     Header/Footer   │
│  Content         .controlBackgroundColor    Process list     │
│  Hover           .selectedContentBgColor    @ 0.15 alpha    │
│  Press           .selectedContentBgColor    @ 0.25 alpha    │
│  Separator       .separatorColor            @ 0.5pt         │
│                                                             │
│  Text                                                       │
│  ────                                                       │
│  Primary         .labelColor                Process names   │
│  Secondary       .secondaryLabelColor       PIDs, metadata  │
│  Tertiary        .tertiaryLabelColor        Timestamps      │
│                                                             │
│  RAM Status (severity-mapped)                               │
│  ──────────                                                 │
│  Healthy         .systemGreen    #34C759    < 60% RAM       │
│  Elevated        .systemYellow   #FFD60A    60-80% RAM      │
│  Critical        .systemOrange   #FF9F0A    80-90% RAM      │
│  Danger          .systemRed      #FF453A    > 90% RAM       │
│                                                             │
│  Process-specific                                           │
│  ────────────────                                           │
│  System proc     .systemBlue     #0A84FF    macOS core      │
│  User proc       .labelColor                User-launched   │
│  Background      .systemPurple   #BF5AF2    Helpers/agents  │
│  AI suggestion   .systemTeal     #64D2FF    Phase 2 only    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Typography

All system fonts (SF Pro via NSFont), matching CatEye's approach:

```
┌──────────────────────────────────────────────────────────────┐
│  TYPOGRAPHY SCALE                                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Menu bar label    .monospacedDigitSystemFont  10.5  .medium │
│                    (e.g. "1.2G" — live RAM in status bar)    │
│                                                              │
│  Section header    .systemFont                 11    .bold   │
│                    (e.g. "USER PROCESSES")                   │
│                                                              │
│  Process name      .systemFont                 12.5  .semi   │
│                    (e.g. "Google Chrome")                    │
│                                                              │
│  RAM value         .monospacedDigitSystemFont   12   .semi   │
│                    (e.g. "842 MB" — tabular for alignment)   │
│                                                              │
│  Metadata          .systemFont                 11    .reg    │
│                    (e.g. "PID 1234 · Helper")               │
│                                                              │
│  Filter/search     .systemFont                 12    .reg    │
│                    (NSTextField input)                       │
│                                                              │
│  Timestamp         .systemFont                 10.5  .reg    │
│                    (e.g. "running 2h 14m")                  │
│                                                              │
│  Button label      .systemFont                 11    .medium │
│                    (e.g. "Kill" / "Force Quit")             │
│                                                              │
│  AI badge          .systemFont                 10    .bold   │
│                    (Phase 2: "AI SAFE TO KILL")              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 2.4 Layout Constants

```swift
let POP_W:     CGFloat = 480    // Popover width (narrower than CatEye — denser data)
let POP_MAX_H: CGFloat = 640    // Max popover height
let ROW_H:     CGFloat = 48     // Process row height
let HDR_H:     CGFloat = 32     // Section header height
let FTR_H:     CGFloat = 40     // Footer height
let TOOLBAR_H: CGFloat = 36     // Sort/filter toolbar
let SEARCH_H:  CGFloat = 32     // Search field height
let PAD:       CGFloat = 12     // Horizontal padding
let PAD_SM:    CGFloat = 8      // Small padding
let ICON_SZ:   CGFloat = 18     // Process icon size
let BTN_SZ:    CGFloat = 24     // Action button size
let BAR_H:     CGFloat = 6      // RAM usage micro-bar height
let CORNER_R:  CGFloat = 4      // Corner radius for badges/bars
```

### 2.5 Icon System

SF Symbols only (no bundled assets, no emoji):

```
┌──────────────────────────────────────────────────────────┐
│  SF SYMBOL MAPPING                                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Status bar icon       memorychip              14pt      │
│  Sort ascending        chevron.up              12pt      │
│  Sort descending       chevron.down            12pt      │
│  Search                magnifyingglass         12pt      │
│  Filter                line.3.horizontal.decrease  12pt  │
│  Kill process          xmark.circle.fill       14pt      │
│  Force quit            exclamationmark.triangle 14pt     │
│  System process        gearshape               12pt      │
│  User process          person                  12pt      │
│  Background proc       circle.dotted           12pt      │
│  Refresh               arrow.clockwise         12pt      │
│  Settings              gearshape.fill          12pt      │
│  Quit app              power                   12pt      │
│  Expand row            chevron.right           10pt      │
│  Collapse row          chevron.down            10pt      │
│  AI recommend (P2)     sparkles                12pt      │
│  AI safe (P2)          checkmark.shield        12pt      │
│  AI caution (P2)       exclamationmark.shield  12pt      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Information Architecture

```
┌─────────────────────────────────────────────────────┐
│  STATUS BAR                                         │
│  [memorychip icon] [1.2G]  ← live used RAM (tinted  │
│                               green/yellow/orange/   │
│                               red by threshold)      │
└──────────────────────┬──────────────────────────────┘
                       │ click
                       ▼
┌─────────────────────────────────────────────────────┐
│  POPOVER                                            │
│                                                     │
│  ┌─ RAM Overview Bar ─────────────────────────────┐ │
│  │  ████████████████░░░░░░  12.4 / 16.0 GB (78%) │ │
│  │  App: 8.2G  Wired: 2.1G  Compressed: 1.8G     │ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─ Toolbar ──────────────────────────────────────┐ │
│  │ [🔍 Filter processes...    ] [Sort ▾] [Type ▾]│ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─ Process List (scrollable) ────────────────────┐ │
│  │                                                │ │
│  │  Chrome              ██████████░  842 MB   [×] │ │
│  │  PID 1234 · User app · 12 threads              │ │
│  │                                                │ │
│  │  ─────────────────────────────────────────     │ │
│  │                                                │ │
│  │  Slack               ████████░░░  624 MB   [×] │ │
│  │  PID 2345 · User app · 8 threads               │ │
│  │                                                │ │
│  │  ─────────────────────────────────────────     │ │
│  │                                                │ │
│  │  kernel_task         ███████░░░░  580 MB       │ │
│  │  PID 0 · System · Protected                    │ │
│  │                                                │ │
│  │  ... (virtualized list)                        │ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─ Footer ───────────────────────────────────────┐ │
│  │  ↻ Refresh    ⚙ Settings    ⏻ Quit            │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## 4. Component Specifications

### 4.1 Status Bar Item

The always-visible menu bar presence.

```
┌───────────────────────────────────────────────────────┐
│  STATES                                               │
├───────────────────────────────────────────────────────┤
│                                                       │
│  Healthy (< 60%):                                     │
│  [memorychip ■] 6.2G     icon + text: .systemGreen    │
│                                                       │
│  Elevated (60-80%):                                   │
│  [memorychip ■] 11.8G    icon + text: .systemYellow   │
│                           icon pulses slowly (3s)     │
│                                                       │
│  Critical (80-90%):                                   │
│  [memorychip ■] 14.1G    icon + text: .systemOrange   │
│                           icon pulses faster (1.5s)   │
│                                                       │
│  Danger (> 90%):                                      │
│  [memorychip ■] 15.6G    icon + text: .systemRed      │
│                           icon pulses fast (0.8s)     │
│                                                       │
│  DISPLAY MODES (user-configurable):                   │
│  • Icon + used RAM          [■ 12.4G]                 │
│  • Icon + percentage        [■ 78%]                   │
│  • Icon + used/total        [■ 12.4/16G]              │
│  • Icon only                [■]                       │
│                                                       │
│  BEHAVIOR:                                            │
│  • Left-click: toggle popover                         │
│  • Text uses .monospacedDigitSystemFont (no jitter)   │
│  • Updates every 2 seconds                            │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 4.2 RAM Overview Bar

Top-of-popover system RAM summary.

```
┌──────────────────────────────────────────────────────────┐
│  LAYOUT (full popover width, 52pt height)                │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  RAM Usage                          12.4 / 16.0 GB  │ │
│  │  ██████████████████████░░░░░░░░░░░░  78%            │ │
│  │  App 8.2G   Wired 2.1G   Compressed 1.8G   Free 3.6G│ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  BAR RENDERING:                                          │
│  • Segmented horizontal bar (full width - 2*PAD)         │
│  • Height: 6pt, corner radius: 3pt                       │
│  • Segments (left to right):                             │
│    App Memory      .systemBlue                           │
│    Wired           .systemPurple                         │
│    Compressed      .systemOrange                         │
│    Free            .quaternaryLabelColor (subtle gray)   │
│  • Smooth width animation on value change (200ms)        │
│                                                          │
│  BREAKDOWN ROW:                                          │
│  • 10.5pt .secondaryLabelColor                           │
│  • Colored dots (6pt circles) before each label          │
│  • Monospaced digit font for values                      │
│                                                          │
│  PRESSURE INDICATOR:                                     │
│  • When memory pressure is "critical" (from host_stats): │
│    - Bar background pulses subtly (0.04 alpha oscillation)│
│    - "Memory Pressure: Critical" in .systemRed below bar │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 4.3 Toolbar (Search + Sort + Filter)

The filtering/sorting command center.

```
┌───────────────────────────────────────────────────────────┐
│  LAYOUT (full width, TOOLBAR_H height)                    │
│                                                           │
│  ┌────────────────────────┐ ┌──────────┐ ┌─────────────┐ │
│  │ 🔍 Filter processes... │ │ RAM ▾    │ │ All types ▾ │ │
│  └────────────────────────┘ └──────────┘ └─────────────┘ │
│   NSTextField (search)       NSPopUp       NSPopUp        │
│   ~55% width                 ~20%          ~25%           │
│                                                           │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  SEARCH FIELD:                                            │
│  • Placeholder: "Filter processes..." (magnifyingglass)   │
│  • Live filtering as user types (debounced 150ms)         │
│  • Matches against: process name, PID                     │
│  • Clear button (xmark.circle) appears when text entered  │
│  • Focus: Cmd+F keyboard shortcut                         │
│  • Style: .roundedBezel, 12pt font                        │
│                                                           │
│  SORT DROPDOWN:                                           │
│  ┌────────────────────┐                                   │
│  │  ▾ Sort by         │                                   │
│  ├────────────────────┤                                   │
│  │  ● RAM (high→low)  │  ← default                       │
│  │  ○ RAM (low→high)  │                                   │
│  │  ○ CPU (high→low)  │                                   │
│  │  ○ Name (A→Z)      │                                   │
│  │  ○ Name (Z→A)      │                                   │
│  │  ○ PID             │                                   │
│  │  ○ Runtime          │                                  │
│  └────────────────────┘                                   │
│                                                           │
│  TYPE FILTER:                                             │
│  ┌────────────────────┐                                   │
│  │  ▾ Process type    │                                   │
│  ├────────────────────┤                                   │
│  │  ● All processes   │  ← default                       │
│  │  ○ User apps       │  (launched by user)              │
│  │  ○ System          │  (launchd, kernel, daemons)      │
│  │  ○ Background      │  (helpers, agents, XPC)          │
│  │  ○ High RAM (>200MB)│ (quick filter)                  │
│  └────────────────────┘                                   │
│                                                           │
│  ACTIVE FILTER INDICATOR:                                 │
│  • When any non-default filter is active:                 │
│    - Show count badge: "Showing 12 of 187 processes"      │
│    - Small text below toolbar, .tertiaryLabelColor        │
│    - "Clear filters" link at right                        │
│                                                           │
│  KEYBOARD SHORTCUTS:                                      │
│  • Cmd+F         Focus search field                       │
│  • Escape        Clear search / close popover             │
│  • Cmd+1-4       Quick switch type filter                 │
│  • Cmd+S         Cycle sort mode                          │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 4.4 Process Row

The core repeating element.

```
┌───────────────────────────────────────────────────────────┐
│  LAYOUT (ROW_H = 48pt)                                    │
│                                                           │
│  ┌─ Normal State ──────────────────────────────────────┐  │
│  │                                                     │  │
│  │  [icon]  Chrome                    ████░░  842 MB   │  │
│  │          PID 1234 · User app · 4.2% CPU     [Kill]  │  │
│  │                                                     │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ELEMENT POSITIONS (left to right):                       │
│                                                           │
│  x=PAD          App icon (NSRunningApplication.icon)      │
│                 18x18pt, from running app bundle           │
│                 Fallback: SF Symbol by process type        │
│                                                           │
│  x=PAD+26       Process name                              │
│                 12.5pt .semibold .labelColor               │
│                 Truncated with ellipsis if > available     │
│                                                           │
│  x=PAD+26       Metadata line (below name)                │
│                 11pt .regular .secondaryLabelColor         │
│                 "PID {pid} · {type} · {cpu}% CPU"         │
│                                                           │
│  x=right-140    RAM micro-bar                             │
│                 60pt wide, 6pt tall, corner radius 3pt    │
│                 Fill color: mapped to RAM severity         │
│                   < 100MB   .systemGreen                  │
│                   100-500MB .systemYellow                  │
│                   500MB-1GB .systemOrange                  │
│                   > 1GB     .systemRed                     │
│                 Background: .quaternaryLabelColor          │
│                                                           │
│  x=right-70     RAM value                                 │
│                 12pt .monospacedDigitSystemFont .semibold  │
│                 Right-aligned for tabular readability      │
│                 Format: "842 MB" / "1.2 GB"               │
│                                                           │
│  x=right-PAD    Kill button (xmark.circle.fill)           │
│                 24x24pt tap target (extends to 32x32)     │
│                 Hidden for protected system processes      │
│                 Appears on hover (non-protected rows)      │
│                                                           │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  INTERACTION STATES:                                      │
│                                                           │
│  Default         No background                            │
│  Hover           .selectedContentBgColor @ 0.15           │
│                  Kill button fades in (150ms)              │
│  Press           .selectedContentBgColor @ 0.25           │
│  Protected       Kill button hidden, row slightly muted   │
│                  (system processes: kernel_task, launchd)  │
│                                                           │
│  KILL CONFIRMATION (inline, replaces row content):        │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Kill "Chrome"?                [Cancel] [Kill] [Force]│ │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  • "Kill" sends SIGTERM (graceful)                        │
│  • "Force" sends SIGKILL (immediate) — .systemRed text   │
│  • Cancel restores normal row (Escape key also works)     │
│  • Row background: .systemRed @ 0.08 during confirmation │
│  • Auto-cancel after 5 seconds (prevents stuck state)     │
│                                                           │
│  POST-KILL:                                               │
│  • Row fades out (200ms) and list reflows                 │
│  • Brief toast at bottom: "Chrome (PID 1234) terminated"  │
│  • If kill fails: row shows error state for 3s            │
│    "Failed to kill — try Force Quit" in .systemRed        │
│                                                           │
│  PROTECTED PROCESS INDICATOR:                             │
│  • System-critical processes (PID 0, 1, WindowServer):    │
│    - No kill button ever shown                            │
│    - Metadata shows "Protected" badge                     │
│    - Row icon tinted .systemBlue                          │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 4.5 Footer

```
┌───────────────────────────────────────────────────────────┐
│  LAYOUT (FTR_H = 40pt)                                    │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  ↻ Refresh   │  ⚙ Settings   │  [sparkles] AI  │  ⏻  │ │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  • Background: .windowBackgroundColor                     │
│  • Top border: .separatorColor @ 0.5pt                    │
│  • Buttons: .inline bezel, 11pt .medium                   │
│  • "AI" button: Phase 2 only, .systemTeal tint            │
│  • Refresh shows last-updated timestamp on hover          │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 4.6 Settings Panel

Replaces popover content when settings tapped (matches CatEye pattern).

```
┌───────────────────────────────────────────────────────────┐
│  SETTINGS                                          [Done] │
│  ─────────────────────────────────────────────────────     │
│                                                           │
│  Status Bar Display                                       │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ [●] Used RAM         [○] Percentage                │  │
│  │ [○] Used / Total     [○] Icon only                 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  Refresh Interval                                         │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  [2s]  [5s]  [10s]  [30s]                          │  │
│  └─────────────────────────────────────────────────────┘  │
│  NSSegmentedControl                                       │
│                                                           │
│  Alert Threshold                                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Warn when RAM usage exceeds:  [80 ▾] %            │  │
│  │  [✓] Show notification                             │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  Process Display                                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Show up to: [50 ▾] processes                      │  │
│  │  [✓] Group by application (merge helpers)          │  │
│  │  [✓] Show CPU percentage                           │  │
│  │  [ ] Show thread count                             │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  AI Features (Phase 2)                                    │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  [ ] Enable AI recommendations (requires Gemma 4)  │  │
│  │  [ ] Allow AI auto-kill (background processes only)│  │
│  │  Model path: [~/models/gemma-4  ] [Browse]         │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ─────────────────────────────────────────────────────     │
│  Config: ~/.config/ramguard/config.json                   │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## 5. Interaction & Animation Spec

### 5.1 Micro-interactions

| Interaction | Duration | Easing | Detail |
|-------------|----------|--------|--------|
| Row hover bg | 150ms | ease-out | `.selectedContentBgColor` alpha 0→0.15 |
| Row press bg | 80ms | ease-in | alpha 0.15→0.25 |
| Kill button appear | 150ms | ease-out | opacity 0→1 on row hover |
| Kill confirmation slide | 200ms | ease-out | Row content crossfades to confirm state |
| Kill confirmation auto-cancel | 5000ms | — | Reverts to normal state |
| Process row removal | 200ms | ease-in | opacity 1→0, height collapses |
| RAM bar segment resize | 200ms | ease-out | Smooth width transition |
| Status bar value change | — | — | Instant (monospaced prevents jitter) |
| Status bar icon pulse | 800-3000ms | sine | Alpha 0.5↔1.0, speed by severity |
| Popover show/hide | system | system | Native NSPopover animation |
| Settings slide | 250ms | ease-out | Content crossfade |
| Toast appear | 200ms | ease-out | Slide up + fade in |
| Toast dismiss | 3000ms + 200ms | — + ease-in | Auto-dismiss with fade out |

### 5.2 Keyboard Navigation

| Key | Action |
|-----|--------|
| `Cmd+F` | Focus search field |
| `Escape` | Clear search → close popover (two-stage) |
| `↑` / `↓` | Navigate process list |
| `Enter` | Expand selected process detail |
| `Delete` / `Backspace` | Initiate kill on selected process |
| `Cmd+K` | Kill selected (with confirmation) |
| `Cmd+S` | Cycle sort mode |
| `Cmd+1-4` | Quick type filter |
| `Cmd+R` | Refresh |
| `Cmd+,` | Open settings |
| `Cmd+Q` | Quit RamGuard |

### 5.3 Accessibility

- All interactive elements: keyboard navigable, VoiceOver labels
- Process rows: `accessibilityLabel = "{name}, using {ram}, {type} process"`
- Kill button: `accessibilityLabel = "Kill {name}"`
- RAM bar: `accessibilityValue = "{percentage}% memory used"`
- Sort/filter state announced on change
- `prefers-reduced-motion`: disable pulse animations, use instant state changes
- Minimum contrast: 4.5:1 for all text (guaranteed by system colors)

---

## 6. Data Architecture

### 6.1 Process Data Model

```swift
struct ProcessInfo {
    let pid: pid_t
    let name: String
    let ramBytes: UInt64           // resident memory (RSS)
    let cpuPercent: Double
    let icon: NSImage?             // from app bundle
    let type: ProcessType          // .user, .system, .background
    let isProtected: Bool          // kernel_task, launchd, WindowServer, loginwindow
    let threadCount: Int
    let startTime: Date
    let parentPID: pid_t
}

enum ProcessType {
    case user        // launched from /Applications or by user
    case system      // PID 0-1, daemons owned by root
    case background  // XPC services, helpers, agents
}
```

### 6.2 RAM Data Source

```swift
// System-level RAM via host_statistics64
struct SystemRAM {
    let total: UInt64
    let used: UInt64              // active + wired + compressed
    let appMemory: UInt64         // active (app-attributed)
    let wired: UInt64             // kernel/driver locked
    let compressed: UInt64        // memory compressor
    let free: UInt64
    let pressure: MemoryPressure  // .nominal, .warn, .critical
}

// Process-level via proc_pidinfo / libproc
// Aggregation: optionally group helper processes under parent app
```

### 6.3 Configuration

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
    "defaultSort": "ramDesc",
    "defaultFilter": "all",
    "ai": {
        "enabled": false,
        "autoKill": false,
        "modelPath": ""
    }
}
```

---

## 7. Phase 2 — AI Features (Gemma 4 Integration)

### 7.1 Architecture: On-Demand / Lazy Load

The AI feature does NOT run continuously. It is invoked explicitly by the user.

```
┌──────────────────────────────────────────────────────────┐
│  TRIGGER                                                 │
│                                                          │
│  User clicks [sparkles AI] button in footer              │
│  OR presses Cmd+I                                        │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ LOAD STATE                                         │ │
│  │                                                    │ │
│  │ 1. Check if Gemma 4 model exists at configured path│ │
│  │ 2. If not found → show setup instructions          │ │
│  │ 3. If found → lazy load model into memory          │ │
│  │    (show loading indicator: "Loading AI model...")  │ │
│  │ 4. Model stays loaded for 60s after last use       │ │
│  │    then auto-unloads to free RAM (ironic, right?)  │ │
│  └─────────────────────────────────────────────────────┘ │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ ANALYSIS                                           │ │
│  │                                                    │ │
│  │ Prompt Gemma 4 with:                               │ │
│  │ • Current process list (name, RAM, type, runtime)  │ │
│  │ • System RAM state                                 │ │
│  │ • Which processes are protected                    │ │
│  │                                                    │ │
│  │ Ask for:                                           │ │
│  │ • Categorize each process: safe/caution/critical   │ │
│  │ • Reasoning for each recommendation               │ │
│  │ • Suggested kill order if RAM needs freeing        │ │
│  └─────────────────────────────────────────────────────┘ │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ UI OVERLAY                                         │ │
│  │                                                    │ │
│  │ Process list gets AI badges per row:               │ │
│  │                                                    │ │
│  │  Chrome         842 MB  [AI: SAFE TO KILL]    [×]  │ │
│  │  "Browser can be safely restarted"                 │ │
│  │                                                    │ │
│  │  Spotlight      340 MB  [AI: CAUTION]              │ │
│  │  "System indexer — killing may slow search"        │ │
│  │                                                    │ │
│  │  WindowServer   280 MB  [AI: DO NOT KILL]          │ │
│  │  "Critical display server — will log you out"      │ │
│  │                                                    │ │
│  │ Badge colors:                                      │ │
│  │  SAFE TO KILL    .systemGreen + checkmark.shield   │ │
│  │  CAUTION         .systemYellow + excl.shield       │ │
│  │  DO NOT KILL     .systemRed + xmark.shield         │ │
│  │                                                    │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  OPTIONAL: AUTO-KILL MODE                                │
│  • Only available if explicitly enabled in settings      │
│  • Only targets processes AI marks "SAFE TO KILL"        │
│  • Only targets .background type processes               │
│  • Shows confirmation before acting:                     │
│    "AI wants to kill 3 background processes              │
│     freeing ~420 MB. Allow?"                             │
│    [Cancel]  [Review Each]  [Kill All Safe]              │
│  • Never auto-kills without user consent on screen       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 7.2 AI Integration Method

```
Option A (recommended): llama.cpp via subprocess
  - Bundle or reference a local GGUF model
  - Invoke via Process() shell command
  - Parse structured JSON output
  - Pros: no Swift ML framework dependencies, works offline
  - Cons: model file size (~2-4GB for Gemma 4)

Option B: MLX (Apple's ML framework)
  - Native Swift integration
  - Better memory management on Apple Silicon
  - Pros: tighter integration, faster inference
  - Cons: more complex build, Apple Silicon only
```

### 7.3 AI Safety Guardrails

- AI can **never** kill a process without user confirmation displayed on screen
- Protected processes are excluded from AI analysis entirely
- Auto-kill (if enabled) is limited to `.background` type processes only
- AI model auto-unloads after 60s idle to avoid being the RAM problem itself
- All AI recommendations show reasoning — no opaque "just trust me" kills
- Kill history logged to `~/.config/ramguard/ai-kills.log`

---

## 8. Technical Implementation Notes

### 8.1 Matching CatEye Patterns

| CatEye Pattern | RamGuard Equivalent |
|---------------|---------------------|
| Single `main.swift` | Single `main.swift` (~1200-1500 lines est.) |
| `swiftc` build with `-Osize` | Same, add `-framework IOKit` for memory stats |
| `NSStatusItem` + `NSPopover` | Same pattern, `memorychip` icon |
| `.accessory` activation | Same |
| `~/.config/cat-eye/config.json` | `~/.config/ramguard/config.json` |
| Frame-based layout | Same (no AutoLayout) |
| System colors + SF Symbols | Same |
| Tracking areas for hover | Same |
| `NSAnimationContext` | Same |
| Rebuild-on-refresh | Same (rebuild process list each tick) |
| `LSUIElement: true` in Info.plist | Same |

### 8.2 Build Command

```bash
swiftc -Osize -o RamGuard.app/Contents/MacOS/ramguard main.swift \
  -framework Cocoa \
  -framework IOKit \
  -framework UserNotifications
strip RamGuard.app/Contents/MacOS/ramguard
```

### 8.3 Required Entitlements / Permissions

- **No special entitlements needed** for reading process info (libproc is available to all user processes)
- `kill()` syscall works for user-owned processes without privilege
- Root-owned / system processes require privilege escalation → show "requires admin" dialog
- Notification permission: requested on first launch

### 8.4 Process List Performance

- Fetch via `proc_listallpids()` + `proc_pidinfo()` — fast C API, no shell overhead
- Process icon via `NSRunningApplication.runningApplications(withBundleIdentifier:)`
- Target: full refresh in < 50ms for 200+ processes
- List rendering: manual frame layout, no cell reuse needed at these counts
- If > 200 processes visible, implement basic virtualization (only render visible rows)

---

## 9. File Structure

```
ramguard/
├── main.swift                    # All app logic (~1200-1500 lines)
├── build.sh                      # Build script
├── RamGuard.app/
│   └── Contents/
│       ├── Info.plist            # LSUIElement, bundle ID, version
│       └── MacOS/
│           └── ramguard          # Compiled binary
├── README.md
└── .gitignore
```

---

## 10. Implementation Priority

### Phase 1 (Core — build this first)
1. Status bar item with live RAM display
2. RAM overview bar in popover
3. Process list with RAM/CPU data
4. Sort by RAM (default), CPU, name, PID
5. Search/filter toolbar
6. Type filter (all, user, system, background)
7. Kill process (SIGTERM + SIGKILL)
8. Protected process detection
9. Settings panel
10. Config persistence

### Phase 2 (AI — build after Phase 1 is solid)
1. Gemma 4 model detection and lazy loading
2. Process analysis prompt engineering
3. AI badge rendering on process rows
4. Auto-kill flow with confirmation
5. Kill history logging
6. Model auto-unload timer
