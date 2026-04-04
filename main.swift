import Cocoa
import UserNotifications

// MARK: - Constants

let POP_W:         CGFloat = 480
let POP_MAX_H:     CGFloat = 640
let OVERVIEW_H:    CGFloat = 60
let TOOLBAR_H:     CGFloat = 36
let ROW_H:         CGFloat = 48
let EXPAND_H:      CGFloat = 30
let FTR_H:         CGFloat = 40
let PAD:           CGFloat = 12
let ICON_SZ:       CGFloat = 18
let BTN_SZ:        CGFloat = 24
let BAR_W:         CGFloat = 54
let BAR_H:         CGFloat = 6
let OVERVIEW_BAR_H: CGFloat = 8
let KILL_PAD:      CGFloat = 16

let CONFIG_DIR  = NSString(string: "~/.config/ramguard").expandingTildeInPath
let CONFIG_PATH = (CONFIG_DIR as NSString).appendingPathComponent("config.json")
let AI_LOG_PATH = (CONFIG_DIR as NSString).appendingPathComponent("ai-kills.log")

let PROTECTED_NAMES: Set<String> = [
    "kernel_task", "launchd", "WindowServer", "loginwindow",
    "opendirectoryd", "fseventsd", "syslogd", "configd",
    "coreaudiod", "hidd", "diskarbitrationd", "logd",
    "UserEventAgent", "systemstats"
]

// MARK: - Process Description Database

let PROC_DESC: [String: String] = [
    "kernel_task": "macOS kernel — manages hardware, memory, and CPU scheduling",
    "WindowServer": "Renders all windows and handles display compositing",
    "launchd": "macOS init system — starts and manages all services",
    "loginwindow": "Manages the login screen and user sessions",
    "Finder": "macOS file manager and desktop",
    "Dock": "App launcher, window management, and Spaces",
    "SystemUIServer": "Renders menu bar extras and system UI elements",
    "mds": "Spotlight metadata server — indexes files for search",
    "mds_stores": "Spotlight index storage and query engine",
    "mdworker": "Spotlight indexing worker process",
    "coreaudiod": "Core Audio daemon — manages all audio I/O",
    "bluetoothd": "Manages Bluetooth connections and devices",
    "airportd": "Wi-Fi daemon — manages wireless networking",
    "configd": "System configuration daemon — network settings",
    "logd": "Unified logging daemon for macOS",
    "opendirectoryd": "Directory services — user accounts and LDAP",
    "diskarbitrationd": "Manages disk mounting and unmounting",
    "fseventsd": "File system events daemon — watches file changes",
    "hidd": "Human Interface Device daemon — keyboard/mouse/trackpad",
    "UserEventAgent": "User-level event monitoring agent",
    "systemstats": "Collects system performance statistics",
    "Google Chrome": "Web browser by Google",
    "Google Chrome Helper": "Chrome renderer/plugin subprocess",
    "Google Chrome Helper (Renderer)": "Chrome tab rendering process",
    "Google Chrome Helper (GPU)": "Chrome GPU acceleration process",
    "Safari": "Apple's web browser",
    "com.apple.WebKit.WebContent": "Safari/WebKit page rendering process",
    "com.apple.WebKit.Networking": "Safari/WebKit network request handler",
    "com.apple.WebKit.GPU": "Safari/WebKit GPU acceleration process",
    "Mail": "Apple Mail email client",
    "Messages": "Apple Messages — iMessage and SMS",
    "Slack": "Team messaging and collaboration platform",
    "Slack Helper": "Slack renderer subprocess",
    "Microsoft Teams": "Microsoft Teams collaboration app",
    "zoom.us": "Zoom video conferencing",
    "Spotify": "Music streaming service",
    "Discord": "Gaming and community chat platform",
    "iTerm2": "Terminal emulator for macOS",
    "Terminal": "Apple's built-in terminal",
    "Code Helper": "VS Code extension/renderer process",
    "Code Helper (Plugin)": "VS Code plugin host process",
    "Electron": "Electron framework process (shared by many apps)",
    "node": "Node.js JavaScript runtime",
    "python3": "Python 3 interpreter",
    "Xcode": "Apple's IDE for macOS/iOS development",
    "Simulator": "iOS/watchOS/tvOS simulator",
    "Activity Monitor": "macOS built-in system resource monitor",
    "Preview": "Image and PDF viewer",
    "Photos": "Apple Photos library manager",
    "Music": "Apple Music player",
    "Notes": "Apple Notes",
    "Calendar": "Apple Calendar",
    "FaceTime": "Apple video calling",
    "Figma": "Collaborative UI design tool",
    "Figma Helper": "Figma renderer subprocess",
    "Adobe Photoshop": "Professional image editor",
    "Adobe Premiere Pro": "Professional video editor",
    "Notion": "All-in-one workspace — notes, docs, databases",
    "Notion Helper": "Notion renderer subprocess",
    "Obsidian": "Markdown-based knowledge management",
    "Firefox": "Mozilla web browser",
    "Arc": "Browser by The Browser Company",
    "Brave Browser": "Privacy-focused web browser",
    "Microsoft Edge": "Microsoft's Chromium-based browser",
    "Microsoft Word": "Word processor",
    "Microsoft Excel": "Spreadsheet application",
    "Microsoft Outlook": "Email client by Microsoft",
    "1Password": "Password manager",
    "Raycast": "Productivity launcher and automation",
    "Docker Desktop": "Docker container runtime GUI",
    "Cursor": "AI-powered code editor",
    "Claude": "Claude AI desktop app by Anthropic",
    "ChatGPT": "OpenAI ChatGPT desktop app",
    "ollama": "Local LLM inference server",
    "Warp": "Modern terminal with AI features",
    "postgres": "PostgreSQL database server",
    "redis-server": "Redis in-memory data store",
    "nginx": "Web server / reverse proxy",
    "Dropbox": "Cloud file sync service",
    "Google Drive": "Google cloud file sync",
    "OneDrive": "Microsoft cloud file sync",
    "Little Snitch": "Network firewall and traffic monitor",
    "Bartender": "Menu bar icon manager",
    "Rectangle": "Window management utility",
    "backupd": "Time Machine backup daemon",
    "softwareupdated": "macOS software update daemon",
    "cloudd": "iCloud sync daemon",
    "bird": "iCloud Drive file provider",
    "sharingd": "AirDrop and sharing services",
    "rapportd": "Handoff and Universal Clipboard daemon",
    "coreservicesd": "Core Services daemon — Launch Services etc.",
    "lsd": "Launch Services daemon — app file associations",
    "tccd": "Privacy permissions daemon (TCC)",
    "trustd": "Certificate trust evaluation daemon",
    "securityd": "Security framework daemon",
    "locationd": "Location services daemon",
    "suggestd": "Siri Suggestions engine",
    "assistantd": "Siri assistant daemon",
    "searchpartyd": "Find My network daemon",
    "ControlCenter": "macOS Control Center",
    "NotificationCenter": "macOS Notification Center",
    "powerd": "Power management daemon",
    "thermald": "Thermal management daemon",
    "nsurlsessiond": "Background URL session daemon",
    "CatEye": "GitHub Actions & PR monitor menu bar app",
    "RamGuard": "RAM & disk monitor — that's us",
    "Steam": "Gaming platform by Valve",
    "VLC": "Open-source video/audio player",
    "IINA": "Modern media player for macOS",
    "Postman": "API testing and development tool",
    "TablePlus": "Database management GUI",
]

// MARK: - Configuration

struct AppConfig: Codable {
    var displayMode: String    = "usedRam"
    var refreshInterval: Int   = 2
    var alertThreshold: Int    = 80
    var showNotifications: Bool = true
    var maxProcesses: Int      = 50
    var groupHelpers: Bool     = true
    var showCPU: Bool          = true
    var showThreads: Bool      = false
    var aiEnabled: Bool        = false
    var aiAutoKill: Bool       = false
    var aiModel: String        = "gemma3"
    var ollamaURL: String      = "http://localhost:11434"
}

func loadConfig() -> AppConfig {
    guard FileManager.default.fileExists(atPath: CONFIG_PATH),
          let d = try? Data(contentsOf: URL(fileURLWithPath: CONFIG_PATH)),
          let c = try? JSONDecoder().decode(AppConfig.self, from: d) else { return AppConfig() }
    return c
}
func saveConfig(_ c: AppConfig) {
    try? FileManager.default.createDirectory(atPath: CONFIG_DIR, withIntermediateDirectories: true)
    if let d = try? JSONEncoder().encode(c) { try? d.write(to: URL(fileURLWithPath: CONFIG_PATH)) }
}
var config = loadConfig()

// MARK: - Enums

enum ProcessType: String { case user, system, background }
enum SortMode:  Int { case ramDesc, ramAsc, cpuDesc, nameAsc, nameDesc, pid, runtime }
enum TypeFilter: Int { case all, user, system, background, highRAM }
enum MemPressure { case healthy, elevated, critical, danger }
enum AIVerdict: String, Codable { case safe, caution, critical }

// MARK: - Models

struct SysRAM {
    let total: UInt64; let appMem: UInt64; let wired: UInt64
    let compressed: UInt64; let free: UInt64
    var used: UInt64 { total - free }
    var pct: Double  { Double(used) / Double(max(total, 1)) * 100 }
    var pressure: MemPressure {
        let p = pct
        if p > 90 { return .danger }; if p > 80 { return .critical }
        if p > 60 { return .elevated }; return .healthy
    }
    static let zero = SysRAM(total: 0, appMem: 0, wired: 0, compressed: 0, free: 0)
}

struct DiskInfo {
    let total: UInt64; let free: UInt64
    var used: UInt64 { total - free }
    var pct: Double { Double(used) / Double(max(total, 1)) * 100 }
    static let zero = DiskInfo(total: 0, free: 0)
}

struct ProcInfo {
    let pid: pid_t; let name: String; var ramBytes: UInt64; var cpuPct: Double
    let icon: NSImage?; let type: ProcessType; let isProtected: Bool
    let threads: Int32; let startTime: Date; let ppid: pid_t; var childCount: Int
}

struct AIRec: Codable { let pid: Int32; let verdict: AIVerdict; let reason: String }
struct AIResp: Codable { let recommendations: [AIRec]; let summary: String }

// MARK: - Global State

var prevCPU: [pid_t: (total: UInt64, time: CFAbsoluteTime)] = [:]
var tbInfo: mach_timebase_info_data_t = {
    var i = mach_timebase_info_data_t(); mach_timebase_info(&i); return i
}()

// MARK: - System Data

func fetchSystemRAM() -> SysRAM {
    var stats = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
    let kr = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return .zero }
    let ps = UInt64(getpagesize())
    let total = ProcessInfo.processInfo.physicalMemory
    return SysRAM(total: total, appMem: UInt64(stats.active_count) * ps,
                  wired: UInt64(stats.wire_count) * ps,
                  compressed: UInt64(stats.compressor_page_count) * ps,
                  free: UInt64(stats.free_count) * ps + UInt64(stats.inactive_count) * ps)
}

func fetchDiskUsage() -> DiskInfo {
    guard let a = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
          let t = a[.systemSize] as? UInt64,
          let f = a[.systemFreeSize] as? UInt64 else { return .zero }
    return DiskInfo(total: t, free: f)
}

func fetchProcesses() -> [ProcInfo] {
    var pids = [pid_t](repeating: 0, count: 4096)
    let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
    guard n > 0 else { return [] }
    pids = Array(pids.prefix(Int(n)))
    let apps = NSWorkspace.shared.runningApplications
    var appByPID: [pid_t: NSRunningApplication] = [:]
    for a in apps { appByPID[a.processIdentifier] = a }
    let now = CFAbsoluteTimeGetCurrent()
    var result: [ProcInfo] = []
    for pid in pids {
        guard pid > 0 else { continue }
        var ti = proc_taskinfo()
        let tiSz = Int32(MemoryLayout<proc_taskinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, tiSz) == tiSz else { continue }
        let rss = ti.pti_resident_size
        guard rss > 0 else { continue }
        var bi = proc_bsdinfo()
        let biSz = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let hasBSD = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bi, biSz) == biSz
        let uid  = hasBSD ? bi.pbi_uid : UInt32.max
        let ppid = hasBSD ? pid_t(bi.pbi_ppid) : 0
        let startSec = hasBSD ? TimeInterval(bi.pbi_start_tvsec) : 0
        let startTime = startSec > 0 ? Date(timeIntervalSince1970: startSec) : Date()
        var nameBuf = [CChar](repeating: 0, count: 256)
        proc_name(pid, &nameBuf, UInt32(nameBuf.count))
        var name = String(cString: nameBuf)
        var icon: NSImage? = nil
        if let a = appByPID[pid] {
            name = a.localizedName ?? name
            if let ai = a.icon { let c = ai.copy() as! NSImage; c.size = NSSize(width: ICON_SZ, height: ICON_SZ); icon = c }
        }
        guard !name.isEmpty else { continue }
        let isApp = appByPID[pid] != nil; let isRoot = uid == 0
        let type: ProcessType = isRoot || pid <= 1 ? .system : isApp ? .user : .background
        let prot = pid <= 1 || PROTECTED_NAMES.contains(name) || isRoot
        let totalCPU = ti.pti_total_user + ti.pti_total_system
        var cpu = 0.0
        if let prev = prevCPU[pid] {
            let dt = now - prev.time
            if dt > 0 && totalCPU >= prev.total {
                cpu = Double(totalCPU - prev.total) * Double(tbInfo.numer) / Double(tbInfo.denom) / 1e9 / dt * 100
            }
        }
        prevCPU[pid] = (totalCPU, now)
        result.append(ProcInfo(pid: pid, name: name, ramBytes: rss, cpuPct: cpu,
                               icon: icon, type: type, isProtected: prot,
                               threads: ti.pti_threadnum, startTime: startTime, ppid: ppid, childCount: 0))
    }
    prevCPU = prevCPU.filter { Set(pids).contains($0.key) }
    return result
}

func groupProcesses(_ procs: [ProcInfo]) -> [ProcInfo] {
    let appPIDs = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })
    var grouped: [ProcInfo] = []; var consumed = Set<pid_t>()
    for p in procs where appPIDs.contains(p.pid) {
        let kids = procs.filter { $0.ppid == p.pid && !appPIDs.contains($0.pid) }
        var g = p; g.ramBytes += kids.reduce(0) { $0 + $1.ramBytes }
        g.cpuPct += kids.reduce(0) { $0 + $1.cpuPct }; g.childCount = kids.count
        grouped.append(g); consumed.insert(p.pid); kids.forEach { consumed.insert($0.pid) }
    }
    for p in procs where !consumed.contains(p.pid) { grouped.append(p) }
    return grouped
}

// MARK: - Helpers

func fmtBytes(_ b: UInt64) -> String {
    if b >= 1_073_741_824 { return String(format: "%.1f GB", Double(b) / 1_073_741_824) }
    if b >= 1_048_576 { return "\(b / 1_048_576) MB" }
    if b >= 1024 { return "\(b / 1024) KB" }
    return "\(b) B"
}
func fmtShort(_ b: UInt64) -> String {
    if b >= 1_073_741_824 { return String(format: "%.1fG", Double(b) / 1_073_741_824) }
    if b >= 1_048_576 { return "\(b / 1_048_576)M" }
    return "\(max(b / 1024, 1))K"
}
func pressColor(_ p: MemPressure) -> NSColor {
    switch p { case .healthy: return .systemGreen; case .elevated: return .systemYellow
               case .critical: return .systemOrange; case .danger: return .systemRed }
}
func ramColor(_ b: UInt64) -> NSColor {
    if b > 1_073_741_824 { return .systemRed }; if b > 524_288_000 { return .systemOrange }
    if b > 104_857_600 { return .systemYellow }; return .systemGreen
}
func typeLabel(_ t: ProcessType) -> String {
    switch t { case .user: return "User app"; case .system: return "System"; case .background: return "Background" }
}
func sf(_ name: String, _ sz: CGFloat = 12, _ wt: NSFont.Weight = .regular) -> NSImage? {
    let c = NSImage.SymbolConfiguration(pointSize: sz, weight: wt)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(c)
}

func descriptionFor(_ proc: ProcInfo) -> String? {
    if let d = PROC_DESC[proc.name] { return d }
    // Fuzzy match for helper processes
    for (key, val) in PROC_DESC {
        if proc.name.hasPrefix(key) { return val }
    }
    return nil
}

func buildFootprintText(ram: SysRAM, disk: DiskInfo, procs: [ProcInfo]) -> String {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
    var s = "RamGuard Snapshot — \(df.string(from: Date()))\n"
    s += "RAM: \(fmtBytes(ram.used)) / \(fmtBytes(ram.total)) (\(Int(ram.pct))%)\n"
    s += "SSD: \(fmtBytes(disk.used)) / \(fmtBytes(disk.total)) (\(Int(disk.pct))%)\n"
    s += "Breakdown: App \(fmtShort(ram.appMem)) | Wired \(fmtShort(ram.wired)) | Compressed \(fmtShort(ram.compressed)) | Free \(fmtShort(ram.free))\n\n"
    s += "Processes (by RAM):\n"
    let sorted = procs.sorted { $0.ramBytes > $1.ramBytes }
    for (i, p) in sorted.prefix(40).enumerated() {
        s += "\(i+1). \(p.name) — \(fmtBytes(p.ramBytes)) (\(typeLabel(p.type)), \(String(format:"%.1f",p.cpuPct))% CPU)\n"
    }
    return s
}

// MARK: - Flipped View

class Flipped: NSView { override var isFlipped: Bool { true } }

// MARK: - RAM Overview View

class RAMOverview: NSView {
    private let valLabel  = NSTextField(labelWithString: "")
    private let barBg     = NSView()
    private let barApp    = NSView()
    private let barWired  = NSView()
    private let barComp   = NSView()
    private let breakdown = NSTextField(labelWithString: "")
    private let pressLbl  = NSTextField(labelWithString: "")

    init(w: CGFloat, ram: SysRAM) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: OVERVIEW_H))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let title = NSTextField(labelWithString: "RAM USAGE")
        title.font = .systemFont(ofSize: 11, weight: .bold); title.textColor = .labelColor
        title.frame = NSRect(x: PAD, y: 6, width: 100, height: 14); addSubview(title)
        valLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        valLabel.textColor = .secondaryLabelColor; valLabel.alignment = .right
        valLabel.frame = NSRect(x: w - PAD - 220, y: 6, width: 220 - PAD, height: 14); addSubview(valLabel)
        let barY: CGFloat = 24; let bw = w - PAD * 2
        barBg.frame = NSRect(x: PAD, y: barY, width: bw, height: OVERVIEW_BAR_H)
        barBg.wantsLayer = true; barBg.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        barBg.layer?.cornerRadius = OVERVIEW_BAR_H / 2; addSubview(barBg)
        for (seg, col) in [(barApp, NSColor.systemBlue), (barWired, NSColor.systemPurple), (barComp, NSColor.systemOrange)] {
            seg.wantsLayer = true; seg.layer?.cornerRadius = OVERVIEW_BAR_H / 2
            seg.layer?.backgroundColor = col.cgColor; seg.frame = NSRect(x: 0, y: 0, width: 0, height: OVERVIEW_BAR_H)
            barBg.addSubview(seg)
        }
        breakdown.font = .systemFont(ofSize: 10); breakdown.textColor = .tertiaryLabelColor
        breakdown.frame = NSRect(x: PAD, y: 38, width: bw * 0.65, height: 14); addSubview(breakdown)
        pressLbl.font = .systemFont(ofSize: 10, weight: .semibold); pressLbl.alignment = .right
        pressLbl.frame = NSRect(x: w - PAD - 160, y: 38, width: 160 - PAD, height: 14)
        pressLbl.isHidden = true; addSubview(pressLbl)
        let sep = NSView(frame: NSRect(x: 0, y: OVERVIEW_H - 0.5, width: w, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor; addSubview(sep)
        update(ram: ram)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(ram: SysRAM) {
        valLabel.stringValue = "\(fmtBytes(ram.used)) / \(fmtBytes(ram.total))  (\(Int(ram.pct))%)"
        let bw = barBg.frame.width; let t = CGFloat(max(ram.total, 1))
        let aw = CGFloat(ram.appMem)/t*bw; let ww = CGFloat(ram.wired)/t*bw; let cw = CGFloat(ram.compressed)/t*bw
        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.2
            barApp.animator().frame = NSRect(x: 0, y: 0, width: aw, height: OVERVIEW_BAR_H)
            barWired.animator().frame = NSRect(x: aw, y: 0, width: ww, height: OVERVIEW_BAR_H)
            barComp.animator().frame = NSRect(x: aw+ww, y: 0, width: cw, height: OVERVIEW_BAR_H)
        }
        breakdown.stringValue = "App \(fmtShort(ram.appMem))   Wired \(fmtShort(ram.wired))   Comp \(fmtShort(ram.compressed))   Free \(fmtShort(ram.free))"
        let pr = ram.pressure
        if pr != .healthy { pressLbl.isHidden = false; pressLbl.textColor = pressColor(pr)
            pressLbl.stringValue = pr == .danger ? "Pressure: Critical" : pr == .critical ? "Pressure: High" : "Pressure: Elevated"
        } else { pressLbl.isHidden = true }
    }
}

// MARK: - Toolbar

class Toolbar: NSView {
    let searchField = NSSearchField()
    let sortPopup   = NSPopUpButton(frame: .zero, pullsDown: false)
    let filterPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    init(w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: TOOLBAR_H))
        let sw = w * 0.48; let rest = w - sw - PAD*2 - 12; let pw = rest / 2
        searchField.frame = NSRect(x: PAD, y: 4, width: sw, height: 28)
        searchField.placeholderString = "Filter processes..."; searchField.font = .systemFont(ofSize: 12)
        searchField.focusRingType = .none; addSubview(searchField)
        sortPopup.frame = NSRect(x: PAD+sw+6, y: 4, width: pw, height: 28)
        sortPopup.font = .systemFont(ofSize: 11); sortPopup.removeAllItems()
        sortPopup.addItems(withTitles: ["RAM ↓","RAM ↑","CPU ↓","Name A→Z","Name Z→A","PID","Runtime"]); addSubview(sortPopup)
        filterPopup.frame = NSRect(x: PAD+sw+pw+12, y: 4, width: pw, height: 28)
        filterPopup.font = .systemFont(ofSize: 11); filterPopup.removeAllItems()
        filterPopup.addItems(withTitles: ["All types","User apps","System","Background","RAM > 200MB"]); addSubview(filterPopup)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Process Row

class ProcessRow: NSView {
    let proc: ProcInfo; let isConfirming: Bool; let aiRec: AIRec?; let maxRAM: UInt64
    let isExpanded: Bool; let desc: String?
    var onConfirm: ((pid_t) -> Void)?; var onKill: ((pid_t, Bool) -> Void)?
    var onCancel: (() -> Void)?; var onToggleExpand: ((pid_t) -> Void)?
    private var killBtn: NSButton?

    init(y: CGFloat, w: CGFloat, proc: ProcInfo, maxRAM: UInt64,
         confirming: Bool = false, ai: AIRec? = nil, expanded: Bool = false, desc: String? = nil) {
        self.proc = proc; self.isConfirming = confirming; self.aiRec = ai; self.maxRAM = maxRAM
        self.isExpanded = expanded; self.desc = desc
        let h = expanded ? ROW_H + EXPAND_H : ROW_H
        super.init(frame: NSRect(x: 0, y: y, width: w, height: h))
        wantsLayer = true; build()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if !isConfirming { onToggleExpand?(proc.pid) }
    }

    private func build() {
        if isConfirming { buildConfirm(); return }
        let iv = NSImageView(frame: NSRect(x: PAD, y: (ROW_H - ICON_SZ)/2, width: ICON_SZ, height: ICON_SZ))
        if let ic = proc.icon { iv.image = ic } else {
            let sym: String
            switch proc.type { case .system: sym = "gearshape"; case .user: sym = "macwindow"; case .background: sym = "circle.dotted" }
            iv.image = sf(sym, 14, .medium)
            iv.contentTintColor = proc.type == .system ? .systemBlue : .secondaryLabelColor
        }
        addSubview(iv)
        let tx = PAD + ICON_SZ + 8; let rZone: CGFloat = 150 + KILL_PAD
        let tw = frame.width - tx - rZone
        let nl = NSTextField(labelWithString: proc.name)
        nl.font = .systemFont(ofSize: 12.5, weight: .semibold)
        nl.textColor = proc.isProtected ? .secondaryLabelColor : .labelColor
        nl.lineBreakMode = .byTruncatingTail
        nl.frame = NSRect(x: tx, y: 6, width: tw - (aiRec != nil ? 70 : 0), height: 16); addSubview(nl)
        if let ai = aiRec { addSubview(makeBadge(ai, x: tx + nl.frame.width + 4)) }

        var meta = "PID \(proc.pid)"
        if proc.childCount > 0 { meta += " +\(proc.childCount)" }
        if let ai = aiRec { meta += " · \(ai.reason)" }
        else {
            meta += " · \(typeLabel(proc.type))"
            if proc.isProtected { meta += " · Protected" }
            if config.showCPU { meta += " · \(String(format: "%.1f", proc.cpuPct))% CPU" }
            if config.showThreads { meta += " · \(proc.threads) thr" }
        }
        let ml = NSTextField(labelWithString: meta)
        ml.font = .systemFont(ofSize: 10.5); ml.textColor = .tertiaryLabelColor
        ml.lineBreakMode = .byTruncatingTail
        ml.frame = NSRect(x: tx, y: 25, width: tw + 60, height: 14); addSubview(ml)

        let barX = frame.width - rZone + 4
        let bg = NSView(frame: NSRect(x: barX, y: (ROW_H - BAR_H)/2, width: BAR_W, height: BAR_H))
        bg.wantsLayer = true; bg.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        bg.layer?.cornerRadius = BAR_H/2; addSubview(bg)
        let frac = min(CGFloat(proc.ramBytes)/CGFloat(max(maxRAM, 1)), 1)
        let fill = NSView(frame: NSRect(x: 0, y: 0, width: frac*BAR_W, height: BAR_H))
        fill.wantsLayer = true; fill.layer?.backgroundColor = ramColor(proc.ramBytes).cgColor
        fill.layer?.cornerRadius = BAR_H/2; bg.addSubview(fill)

        let rl = NSTextField(labelWithString: fmtBytes(proc.ramBytes))
        rl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold); rl.textColor = .secondaryLabelColor
        rl.alignment = .right
        rl.frame = NSRect(x: barX + BAR_W + 4, y: (ROW_H - 14)/2, width: 58, height: 14); addSubview(rl)

        if !proc.isProtected {
            let b = NSButton(frame: NSRect(x: frame.width - PAD - BTN_SZ,
                                           y: (ROW_H - BTN_SZ)/2, width: BTN_SZ, height: BTN_SZ))
            b.bezelStyle = .inline; b.isBordered = false
            b.image = sf("xmark.circle.fill", 14, .medium); b.contentTintColor = .systemRed
            b.target = self; b.action = #selector(killTap); b.alphaValue = 0
            b.toolTip = "Kill \(proc.name)"; addSubview(b); killBtn = b
        }

        // Expanded section
        if isExpanded { buildExpanded(tx: tx) }

        let sep = NSView(frame: NSRect(x: PAD, y: frame.height - 0.5, width: frame.width - PAD*2, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor; addSubview(sep)

        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    private func buildExpanded(tx: CGFloat) {
        let ey = ROW_H
        let bg = NSView(frame: NSRect(x: 0, y: ey, width: frame.width, height: EXPAND_H))
        bg.wantsLayer = true; bg.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        addSubview(bg)

        let text = desc ?? "Unknown process — click Search to learn more"
        let dl = NSTextField(labelWithString: text)
        dl.font = .systemFont(ofSize: 10.5); dl.textColor = .secondaryLabelColor
        dl.lineBreakMode = .byTruncatingTail
        dl.frame = NSRect(x: tx, y: 4, width: frame.width - tx - (desc == nil ? 80 : PAD), height: 18)
        bg.addSubview(dl)

        if desc == nil {
            let sb = NSButton(title: " Search", target: self, action: #selector(searchTap))
            sb.bezelStyle = .rounded; sb.font = .systemFont(ofSize: 10, weight: .medium)
            sb.image = sf("magnifyingglass", 10, .medium); sb.imagePosition = .imageLeft
            sb.frame = NSRect(x: frame.width - PAD - 70, y: 2, width: 66, height: 22)
            bg.addSubview(sb)
        }
    }

    private func buildConfirm() {
        layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.08).cgColor
        let lbl = NSTextField(labelWithString: "Kill \"\(proc.name)\"?")
        lbl.font = .systemFont(ofSize: 12.5, weight: .semibold); lbl.textColor = .labelColor
        lbl.frame = NSRect(x: PAD, y: (ROW_H - 16)/2, width: 220, height: 16); addSubview(lbl)
        let fb = NSButton(title: "Force", target: self, action: #selector(forceTap))
        fb.bezelStyle = .rounded; fb.font = .systemFont(ofSize: 11, weight: .medium)
        fb.contentTintColor = .systemRed
        fb.frame = NSRect(x: frame.width-PAD-60, y: (ROW_H-24)/2, width: 56, height: 24); addSubview(fb)
        let kb = NSButton(title: "Kill", target: self, action: #selector(confirmTap))
        kb.bezelStyle = .rounded; kb.font = .systemFont(ofSize: 11, weight: .medium)
        kb.frame = NSRect(x: frame.width-PAD-120, y: (ROW_H-24)/2, width: 54, height: 24); addSubview(kb)
        let cb = NSButton(title: "Cancel", target: self, action: #selector(cancelTap))
        cb.bezelStyle = .rounded; cb.font = .systemFont(ofSize: 11, weight: .medium)
        cb.frame = NSRect(x: frame.width-PAD-190, y: (ROW_H-24)/2, width: 64, height: 24); addSubview(cb)
        let sep = NSView(frame: NSRect(x: PAD, y: ROW_H-0.5, width: frame.width-PAD*2, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor; addSubview(sep)
    }

    private func makeBadge(_ ai: AIRec, x: CGFloat) -> NSView {
        let txt: String; let col: NSColor; let sym: String
        switch ai.verdict {
        case .safe: txt="SAFE"; col = .systemGreen; sym="checkmark.shield"
        case .caution: txt="CAUTION"; col = .systemYellow; sym="exclamationmark.shield"
        case .critical: txt="KEEP"; col = .systemRed; sym="xmark.shield"
        }
        let bw: CGFloat = txt == "CAUTION" ? 78 : 58
        let c = NSView(frame: NSRect(x: x, y: 7, width: bw, height: 14))
        c.wantsLayer = true; c.layer?.backgroundColor = col.withAlphaComponent(0.15).cgColor; c.layer?.cornerRadius = 3
        let ic = NSImageView(frame: NSRect(x: 3, y: 0, width: 12, height: 14))
        ic.image = sf(sym, 9, .bold); ic.contentTintColor = col; c.addSubview(ic)
        let l = NSTextField(labelWithString: txt)
        l.font = .systemFont(ofSize: 9, weight: .bold); l.textColor = col
        l.frame = NSRect(x: 16, y: 0, width: bw-18, height: 14); c.addSubview(l)
        return c
    }

    override func mouseEntered(with e: NSEvent) {
        if !isConfirming {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15).cgColor
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; killBtn?.animator().alphaValue = 1 }
        }
    }
    override func mouseExited(with e: NSEvent) {
        if !isConfirming {
            layer?.backgroundColor = nil
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; killBtn?.animator().alphaValue = 0 }
        }
    }
    @objc private func killTap()    { onConfirm?(proc.pid) }
    @objc private func confirmTap() { onKill?(proc.pid, false) }
    @objc private func forceTap()   { onKill?(proc.pid, true) }
    @objc private func cancelTap()  { onCancel?() }
    @objc private func searchTap()  {
        let q = proc.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? proc.name
        if let url = URL(string: "https://www.google.com/search?q=macOS+process+%22\(q)%22+what+is+it") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Footer

class Footer: NSView {
    var refreshBtn: NSButton!; var settingsBtn: NSButton!; var copyBtn: NSButton!
    var aiBtn: NSButton!; var quitBtn: NSButton!
    init(w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: FTR_H))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let sep = NSView(frame: NSRect(x: 0, y: 0, width: w, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor; addSubview(sep)
        func btn(_ t: String, _ ic: String) -> NSButton {
            let b = NSButton(); b.bezelStyle = .inline; b.isBordered = false
            b.image = sf(ic, 12, .medium); b.title = " \(t)"; b.font = .systemFont(ofSize: 11, weight: .medium)
            b.imagePosition = .imageLeft; return b
        }
        let bh: CGFloat = 28; let by = (FTR_H - bh) / 2
        refreshBtn  = btn("Refresh",  "arrow.clockwise")
        settingsBtn = btn("Settings", "gearshape")
        copyBtn     = btn("Copy",     "doc.on.clipboard")
        aiBtn       = btn("AI",       "sparkles")
        quitBtn     = btn("Quit",     "power")
        refreshBtn.frame  = NSRect(x: PAD,        y: by, width: 76, height: bh)
        settingsBtn.frame = NSRect(x: PAD+80,     y: by, width: 82, height: bh)
        copyBtn.frame     = NSRect(x: PAD+166,    y: by, width: 62, height: bh)
        aiBtn.frame       = NSRect(x: PAD+232,    y: by, width: 48, height: bh)
        quitBtn.frame     = NSRect(x: w-PAD-52,   y: by, width: 52, height: bh)
        aiBtn.contentTintColor = .systemTeal; if !config.aiEnabled { aiBtn.isHidden = true }
        for b in [refreshBtn!, settingsBtn!, copyBtn!, aiBtn!, quitBtn!] { addSubview(b) }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Settings View

class SettingsView: Flipped {
    var onDone: (() -> Void)?
    private var displaySeg: NSSegmentedControl!; private var refreshSeg: NSSegmentedControl!
    private var thresholdPop: NSPopUpButton!; private var notifCheck: NSButton!
    private var maxProcPop: NSPopUpButton!; private var groupCheck: NSButton!
    private var cpuCheck: NSButton!; private var threadCheck: NSButton!
    private var aiCheck: NSButton!; private var autoKillCheck: NSButton!; private var modelField: NSTextField!
    init(w: CGFloat) { super.init(frame: NSRect(x: 0, y: 0, width: w, height: 420)); build(w) }
    required init?(coder: NSCoder) { fatalError() }
    private func build(_ w: CGFloat) {
        var y: CGFloat = 0
        let hdr = NSView(frame: NSRect(x: 0, y: y, width: w, height: 36))
        hdr.wantsLayer = true; hdr.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let hl = NSTextField(labelWithString: "SETTINGS")
        hl.font = .systemFont(ofSize: 13, weight: .bold); hl.textColor = .labelColor
        hl.frame = NSRect(x: PAD, y: 8, width: 100, height: 18); hdr.addSubview(hl)
        let done = NSButton(title: "Done", target: self, action: #selector(doneTap))
        done.bezelStyle = .rounded; done.font = .systemFont(ofSize: 12, weight: .medium)
        done.frame = NSRect(x: w-PAD-60, y: 4, width: 56, height: 28); hdr.addSubview(done)
        let hsep = NSView(frame: NSRect(x: 0, y: 35.5, width: w, height: 0.5))
        hsep.wantsLayer = true; hsep.layer?.backgroundColor = NSColor.separatorColor.cgColor; hdr.addSubview(hsep)
        addSubview(hdr); y += 36
        func sec(_ text: String) -> CGFloat {
            let l = NSTextField(labelWithString: text); l.font = .systemFont(ofSize: 11, weight: .bold)
            l.textColor = .secondaryLabelColor; l.frame = NSRect(x: PAD, y: y+8, width: w-PAD*2, height: 14)
            addSubview(l); y += 28; return y
        }
        y = sec("Status Bar Display")
        displaySeg = NSSegmentedControl(labels: ["Used RAM","Percent","Used/Total","Icon"],
                                        trackingMode: .selectOne, target: self, action: #selector(displayChanged))
        displaySeg.frame = NSRect(x: PAD, y: y, width: w-PAD*2, height: 24)
        displaySeg.selectedSegment = ["usedRam","percent","usedTotal","iconOnly"].firstIndex(of: config.displayMode) ?? 0
        addSubview(displaySeg); y += 32
        y = sec("Refresh Interval")
        refreshSeg = NSSegmentedControl(labels: ["2s","5s","10s","30s"],
                                        trackingMode: .selectOne, target: self, action: #selector(refreshChanged))
        refreshSeg.frame = NSRect(x: PAD, y: y, width: 200, height: 24)
        refreshSeg.selectedSegment = [2,5,10,30].firstIndex(of: config.refreshInterval) ?? 0
        addSubview(refreshSeg); y += 32
        y = sec("Alert Threshold")
        let tl = NSTextField(labelWithString: "Warn at:"); tl.font = .systemFont(ofSize: 12); tl.textColor = .labelColor
        tl.frame = NSRect(x: PAD, y: y, width: 60, height: 20); addSubview(tl)
        thresholdPop = NSPopUpButton(frame: NSRect(x: PAD+62, y: y-2, width: 70, height: 24), pullsDown: false)
        thresholdPop.font = .systemFont(ofSize: 11); thresholdPop.removeAllItems()
        thresholdPop.addItems(withTitles: ["60%","70%","80%","90%"])
        thresholdPop.selectItem(at: [60,70,80,90].firstIndex(of: config.alertThreshold) ?? 2)
        thresholdPop.target = self; thresholdPop.action = #selector(thresholdChanged); addSubview(thresholdPop)
        notifCheck = NSButton(checkboxWithTitle: "Notifications", target: self, action: #selector(notifChanged))
        notifCheck.state = config.showNotifications ? .on : .off; notifCheck.font = .systemFont(ofSize: 12)
        notifCheck.frame = NSRect(x: PAD+150, y: y, width: 120, height: 20); addSubview(notifCheck); y += 32
        y = sec("Process Display")
        let ml = NSTextField(labelWithString: "Show up to:"); ml.font = .systemFont(ofSize: 12); ml.textColor = .labelColor
        ml.frame = NSRect(x: PAD, y: y, width: 80, height: 20); addSubview(ml)
        maxProcPop = NSPopUpButton(frame: NSRect(x: PAD+82, y: y-2, width: 70, height: 24), pullsDown: false)
        maxProcPop.font = .systemFont(ofSize: 11); maxProcPop.removeAllItems()
        maxProcPop.addItems(withTitles: ["25","50","100","200"])
        maxProcPop.selectItem(at: [25,50,100,200].firstIndex(of: config.maxProcesses) ?? 1)
        maxProcPop.target = self; maxProcPop.action = #selector(maxProcChanged); addSubview(maxProcPop)
        groupCheck = NSButton(checkboxWithTitle: "Group helpers", target: self, action: #selector(groupChanged))
        groupCheck.state = config.groupHelpers ? .on : .off; groupCheck.font = .systemFont(ofSize: 12)
        groupCheck.frame = NSRect(x: PAD+170, y: y, width: 120, height: 20); addSubview(groupCheck); y += 24
        cpuCheck = NSButton(checkboxWithTitle: "Show CPU %", target: self, action: #selector(cpuChanged))
        cpuCheck.state = config.showCPU ? .on : .off; cpuCheck.font = .systemFont(ofSize: 12)
        cpuCheck.frame = NSRect(x: PAD, y: y, width: 110, height: 20); addSubview(cpuCheck)
        threadCheck = NSButton(checkboxWithTitle: "Show threads", target: self, action: #selector(threadChanged))
        threadCheck.state = config.showThreads ? .on : .off; threadCheck.font = .systemFont(ofSize: 12)
        threadCheck.frame = NSRect(x: PAD+120, y: y, width: 120, height: 20); addSubview(threadCheck); y += 32
        y = sec("AI Features")
        aiCheck = NSButton(checkboxWithTitle: "Enable AI recommendations (requires Ollama)", target: self, action: #selector(aiChanged))
        aiCheck.state = config.aiEnabled ? .on : .off; aiCheck.font = .systemFont(ofSize: 12)
        aiCheck.frame = NSRect(x: PAD, y: y, width: w-PAD*2, height: 20); addSubview(aiCheck); y += 24
        autoKillCheck = NSButton(checkboxWithTitle: "Allow AI auto-kill (background only)", target: self, action: #selector(autoKillChanged))
        autoKillCheck.state = config.aiAutoKill ? .on : .off; autoKillCheck.font = .systemFont(ofSize: 12)
        autoKillCheck.frame = NSRect(x: PAD+20, y: y, width: w-PAD*2-20, height: 20)
        autoKillCheck.isEnabled = config.aiEnabled; addSubview(autoKillCheck); y += 24
        let modLbl = NSTextField(labelWithString: "Model:"); modLbl.font = .systemFont(ofSize: 12); modLbl.textColor = .labelColor
        modLbl.frame = NSRect(x: PAD+20, y: y, width: 50, height: 20); addSubview(modLbl)
        modelField = NSTextField(frame: NSRect(x: PAD+72, y: y-2, width: 160, height: 22))
        modelField.font = .systemFont(ofSize: 12); modelField.stringValue = config.aiModel
        modelField.isEnabled = config.aiEnabled; modelField.target = self; modelField.action = #selector(modelChanged)
        addSubview(modelField); y += 32
        let pl = NSTextField(labelWithString: CONFIG_PATH)
        pl.font = .systemFont(ofSize: 10); pl.textColor = .tertiaryLabelColor
        pl.frame = NSRect(x: PAD, y: y+4, width: w-PAD*2, height: 14); addSubview(pl); y += 24
        frame.size.height = y
    }
    @objc private func doneTap() { saveConfig(config); onDone?() }
    @objc private func displayChanged() { config.displayMode = ["usedRam","percent","usedTotal","iconOnly"][displaySeg.selectedSegment]; rgApp.updateStatusBar() }
    @objc private func refreshChanged() { config.refreshInterval = [2,5,10,30][refreshSeg.selectedSegment]; rgApp.scheduleTimer() }
    @objc private func thresholdChanged() { config.alertThreshold = [60,70,80,90][thresholdPop.indexOfSelectedItem] }
    @objc private func notifChanged() { config.showNotifications = notifCheck.state == .on }
    @objc private func maxProcChanged() { config.maxProcesses = [25,50,100,200][maxProcPop.indexOfSelectedItem] }
    @objc private func groupChanged() { config.groupHelpers = groupCheck.state == .on }
    @objc private func cpuChanged() { config.showCPU = cpuCheck.state == .on }
    @objc private func threadChanged() { config.showThreads = threadCheck.state == .on }
    @objc private func aiChanged() { config.aiEnabled = aiCheck.state == .on; autoKillCheck.isEnabled = config.aiEnabled; modelField.isEnabled = config.aiEnabled }
    @objc private func autoKillChanged() { config.aiAutoKill = autoKillCheck.state == .on }
    @objc private func modelChanged() { config.aiModel = modelField.stringValue }
}

// MARK: - AI Manager

class AIManager {
    static let shared = AIManager()
    func analyze(procs: [ProcInfo], ram: SysRAM, completion: @escaping (AIResp?) -> Void) {
        guard let url = URL(string: "\(config.ollamaURL)/api/generate") else { completion(nil); return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.timeoutInterval = 120
        let sorted = procs.sorted { $0.ramBytes > $1.ramBytes }
        var list = ""; for p in sorted.prefix(30) { list += "\(p.pid),\(p.name),\(p.ramBytes/1_048_576)MB,\(typeLabel(p.type)),\(String(format:"%.1f",p.cpuPct))%\n" }
        let prompt = """
        You are a macOS process analyzer. Classify each process for safe termination.
        System: macOS, \(fmtBytes(ram.total)) RAM, \(fmtBytes(ram.used)) used (\(Int(ram.pct))%)
        Processes (pid,name,ram,type,cpu):
        \(list)
        Respond with JSON only:
        {"recommendations":[{"pid":N,"verdict":"safe|caution|critical","reason":"brief"}],"summary":"brief overall recommendation"}
        Rules: kernel_task/WindowServer/launchd/loginwindow/Finder/Dock = always critical. System = critical. User apps with unsaved data = caution. Background helpers = usually safe. When unsure = caution.
        """
        let body: [String: Any] = ["model": config.aiModel, "prompt": prompt, "format": "json", "stream": false, "options": ["temperature": 0.1], "keep_alive": "60s"]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, _, err in
            guard let data = data, err == nil else { DispatchQueue.main.async { completion(nil) }; return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rs = json["response"] as? String, let rd = rs.data(using: .utf8),
               let r = try? JSONDecoder().decode(AIResp.self, from: rd) { DispatchQueue.main.async { completion(r) } }
            else { DispatchQueue.main.async { completion(nil) } }
        }.resume()
    }
    func autoKill(recs: [AIRec], procs: [ProcInfo]) -> [(pid: pid_t, name: String, ram: UInt64)] {
        var killed: [(pid_t, String, UInt64)] = []
        for rec in recs where rec.verdict == .safe {
            if let p = procs.first(where: { $0.pid == rec.pid }), p.type == .background, !p.isProtected {
                if kill(rec.pid, SIGTERM) == 0 { killed.append((rec.pid, p.name, p.ramBytes))
                    let entry = "[\(ISO8601DateFormatter().string(from: Date()))] Killed \(p.name) (PID \(rec.pid)) - \(fmtBytes(p.ramBytes)) - \(rec.reason)\n"
                    try? FileManager.default.createDirectory(atPath: CONFIG_DIR, withIntermediateDirectories: true)
                    if let fh = FileHandle(forWritingAtPath: AI_LOG_PATH) { fh.seekToEndOfFile(); fh.write(entry.data(using: .utf8)!); fh.closeFile() }
                    else { try? entry.write(toFile: AI_LOG_PATH, atomically: true, encoding: .utf8) }
                }
            }
        }
        return killed
    }
}

// MARK: - Main View Controller

class MainVC: NSViewController, NSSearchFieldDelegate {
    var sysRAM: SysRAM = .zero; var diskInfo: DiskInfo = .zero
    var procs: [ProcInfo] = []; var search = ""
    var sort = SortMode.ramDesc; var filter = TypeFilter.all
    var confirmPID: pid_t? = nil; var expandedPID: pid_t? = nil
    var aiRecs: [pid_t: AIRec] = [:]; var aiSummary = ""; var aiLoading = false; var showSettings = false

    private var overview: RAMOverview!; private var toolbar: Toolbar!
    private var badgeLbl: NSTextField?; private var aiSumLbl: NSTextField?
    private var listScroll: NSScrollView!; private var listContent: Flipped!
    private var footer: Footer!; private var settingsView: SettingsView?

    override func loadView() {
        let v = Flipped(frame: NSRect(x: 0, y: 0, width: POP_W, height: POP_MAX_H)); v.wantsLayer = true
        overview = RAMOverview(w: POP_W, ram: sysRAM); v.addSubview(overview)
        toolbar = Toolbar(w: POP_W); toolbar.frame.origin.y = OVERVIEW_H
        toolbar.searchField.delegate = self
        toolbar.sortPopup.target = self; toolbar.sortPopup.action = #selector(sortChanged)
        toolbar.filterPopup.target = self; toolbar.filterPopup.action = #selector(filterChanged)
        v.addSubview(toolbar)
        listScroll = NSScrollView(); listScroll.hasVerticalScroller = true
        listScroll.autohidesScrollers = true; listScroll.drawsBackground = false
        listContent = Flipped(); listScroll.documentView = listContent; v.addSubview(listScroll)
        footer = Footer(w: POP_W)
        footer.refreshBtn.target = self; footer.refreshBtn.action = #selector(refreshTap)
        footer.settingsBtn.target = self; footer.settingsBtn.action = #selector(settingsTap)
        footer.copyBtn.target = self; footer.copyBtn.action = #selector(copyTap)
        footer.aiBtn.target = self; footer.aiBtn.action = #selector(aiTap)
        footer.quitBtn.target = self; footer.quitBtn.action = #selector(quitTap)
        v.addSubview(footer); self.view = v; rebuildList()
    }

    func update(ram: SysRAM, disk: DiskInfo, p: [ProcInfo]) {
        sysRAM = ram; diskInfo = disk; procs = p
        guard isViewLoaded, !showSettings else { return }
        overview.update(ram: ram); rebuildList()
    }

    func rebuildList() {
        let savedScroll = listScroll.contentView.bounds.origin
        listContent.subviews.forEach { $0.removeFromSuperview() }
        badgeLbl?.removeFromSuperview(); badgeLbl = nil; aiSumLbl?.removeFromSuperview(); aiSumLbl = nil
        var list = config.groupHelpers ? groupProcesses(procs) : procs
        if !search.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(search) || "\($0.pid)".contains(search) } }
        switch filter { case .all: break; case .user: list = list.filter { $0.type == .user }
        case .system: list = list.filter { $0.type == .system }
        case .background: list = list.filter { $0.type == .background }
        case .highRAM: list = list.filter { $0.ramBytes > 200_000_000 } }
        switch sort {
        case .ramDesc: list.sort { $0.ramBytes > $1.ramBytes }; case .ramAsc: list.sort { $0.ramBytes < $1.ramBytes }
        case .cpuDesc: list.sort { $0.cpuPct > $1.cpuPct }
        case .nameAsc: list.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDesc: list.sort { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .pid: list.sort { $0.pid < $1.pid }; case .runtime: list.sort { $0.startTime < $1.startTime } }
        var extraY: CGFloat = 0
        if !search.isEmpty || filter != .all {
            let bl = NSTextField(labelWithString: "Showing \(min(list.count, config.maxProcesses)) of \(procs.count) processes")
            bl.font = .systemFont(ofSize: 10); bl.textColor = .tertiaryLabelColor
            bl.frame = NSRect(x: PAD, y: OVERVIEW_H+TOOLBAR_H, width: POP_W-PAD*2, height: 16)
            view.addSubview(bl); badgeLbl = bl; extraY = 16
        }
        if !aiSummary.isEmpty {
            let al = NSTextField(labelWithString: "AI: \(aiSummary)")
            al.font = .systemFont(ofSize: 10, weight: .medium); al.textColor = .systemTeal; al.lineBreakMode = .byTruncatingTail
            al.frame = NSRect(x: PAD, y: OVERVIEW_H+TOOLBAR_H+extraY, width: POP_W-PAD*2, height: 16)
            view.addSubview(al); aiSumLbl = al; extraY += 16
        }
        if aiLoading {
            let ll = NSTextField(labelWithString: "Analyzing with \(config.aiModel)...")
            ll.font = .systemFont(ofSize: 11, weight: .medium); ll.textColor = .systemTeal; ll.alignment = .center
            ll.frame = NSRect(x: PAD, y: 20, width: POP_W-PAD*2, height: 16); listContent.addSubview(ll)
            let sp = NSProgressIndicator(frame: NSRect(x: (POP_W-24)/2, y: 44, width: 24, height: 24))
            sp.style = .spinning; sp.startAnimation(nil); listContent.addSubview(sp)
            listContent.frame = NSRect(x: 0, y: 0, width: POP_W, height: 80)
            layoutFrames(listH: 80, extraY: extraY); return
        }
        if list.isEmpty {
            let el = NSTextField(labelWithString: procs.isEmpty ? "No processes found" : "No matching processes")
            el.font = .systemFont(ofSize: 12); el.textColor = .tertiaryLabelColor; el.alignment = .center
            el.frame = NSRect(x: 0, y: 20, width: POP_W, height: 20); listContent.addSubview(el)
            listContent.frame = NSRect(x: 0, y: 0, width: POP_W, height: 60)
            layoutFrames(listH: 60, extraY: extraY); return
        }
        let maxRAM = list.max(by: { $0.ramBytes < $1.ramBytes })?.ramBytes ?? 1
        var y: CGFloat = 0
        for p in list.prefix(config.maxProcesses) {
            let isExp = expandedPID == p.pid
            let row = ProcessRow(y: y, w: POP_W, proc: p, maxRAM: maxRAM,
                                 confirming: confirmPID == p.pid, ai: aiRecs[p.pid],
                                 expanded: isExp, desc: descriptionFor(p))
            row.onToggleExpand = { [weak self] pid in
                self?.expandedPID = self?.expandedPID == pid ? nil : pid; self?.rebuildList()
            }
            row.onConfirm = { [weak self] pid in
                self?.confirmPID = pid; rgApp.popover.behavior = .semitransient; self?.rebuildList()
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard self?.confirmPID == pid else { return }
                    self?.confirmPID = nil; rgApp.popover.behavior = .transient; self?.rebuildList()
                }
            }
            row.onKill = { [weak self] pid, force in
                let ok = kill(pid, force ? SIGKILL : SIGTERM) == 0
                self?.confirmPID = nil; rgApp.popover.behavior = .transient
                if !ok { NSSound.beep() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { rgApp.refresh() }
            }
            row.onCancel = { [weak self] in self?.confirmPID = nil; rgApp.popover.behavior = .transient; self?.rebuildList() }
            listContent.addSubview(row)
            y += isExp ? ROW_H + EXPAND_H : ROW_H
        }
        listContent.frame = NSRect(x: 0, y: 0, width: POP_W, height: y)
        layoutFrames(listH: y, extraY: extraY)
        listScroll.contentView.scroll(to: NSPoint(x: 0, y: min(savedScroll.y, max(y - listScroll.frame.height, 0))))
        listScroll.reflectScrolledClipView(listScroll.contentView)
    }

    private func layoutFrames(listH: CGFloat, extraY: CGFloat) {
        let listTop = OVERVIEW_H + TOOLBAR_H + extraY; let maxLH = POP_MAX_H - listTop - FTR_H
        let lh = min(listH, maxLH); let total = listTop + max(lh, 60) + FTR_H
        listScroll.frame = NSRect(x: 0, y: listTop, width: POP_W, height: max(lh, 60))
        footer.frame = NSRect(x: 0, y: total - FTR_H, width: POP_W, height: FTR_H)
        view.frame.size.height = total; preferredContentSize = NSSize(width: POP_W, height: total)
    }

    func controlTextDidChange(_ n: Notification) { search = toolbar.searchField.stringValue; rebuildList() }
    @objc func sortChanged() { sort = SortMode(rawValue: toolbar.sortPopup.indexOfSelectedItem) ?? .ramDesc; rebuildList() }
    @objc func filterChanged() { filter = TypeFilter(rawValue: toolbar.filterPopup.indexOfSelectedItem) ?? .all; rebuildList() }
    @objc func refreshTap() { rgApp.refresh() }
    @objc func quitTap() { saveConfig(config); NSApp.terminate(nil) }

    @objc func copyTap() {
        let text = buildFootprintText(ram: sysRAM, disk: diskInfo, procs: procs)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        footer.copyBtn.title = " Copied!"; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.footer.copyBtn.title = " Copy" }
    }

    @objc func settingsTap() { if showSettings { switchToList() } else { switchToSettings() } }

    @objc func aiTap() {
        if !aiRecs.isEmpty { aiRecs.removeAll(); aiSummary = ""; rebuildList(); return }
        aiLoading = true; rebuildList()
        AIManager.shared.analyze(procs: procs, ram: sysRAM) { [weak self] resp in
            guard let self = self else { return }; self.aiLoading = false
            if let r = resp {
                self.aiRecs = Dictionary(uniqueKeysWithValues: r.recommendations.map { ($0.pid, $0) }); self.aiSummary = r.summary
                if config.aiAutoKill {
                    let killed = AIManager.shared.autoKill(recs: r.recommendations, procs: self.procs)
                    if !killed.isEmpty { self.aiSummary += " | Auto-killed \(killed.count), freed ~\(fmtBytes(killed.reduce(0 as UInt64) { $0 + $1.2 }))"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { rgApp.refresh() } }
                }
            } else { self.aiSummary = "Failed — is Ollama running at \(config.ollamaURL)?" }
            self.rebuildList()
        }
    }

    private func switchToSettings() {
        showSettings = true; overview.removeFromSuperview(); toolbar.removeFromSuperview()
        listScroll.removeFromSuperview(); badgeLbl?.removeFromSuperview(); aiSumLbl?.removeFromSuperview()
        let sv = SettingsView(w: POP_W); sv.onDone = { [weak self] in self?.switchToList() }
        view.addSubview(sv); settingsView = sv
        let h = sv.frame.height + FTR_H
        footer.frame = NSRect(x: 0, y: h-FTR_H, width: POP_W, height: FTR_H)
        footer.aiBtn.isHidden = !config.aiEnabled
        view.frame.size.height = h; preferredContentSize = NSSize(width: POP_W, height: h)
    }
    private func switchToList() {
        showSettings = false; settingsView?.removeFromSuperview(); settingsView = nil; saveConfig(config)
        footer.aiBtn.isHidden = !config.aiEnabled
        view.addSubview(overview); view.addSubview(toolbar); view.addSubview(listScroll)
        overview.update(ram: sysRAM); rebuildList(); rgApp.scheduleTimer(); rgApp.updateStatusBar()
    }
}

// MARK: - App Delegate

class RamGuardApp: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!; var popover: NSPopover!; var timer: Timer?
    var mainVC: MainVC!; var sysRAM: SysRAM = .zero; var diskInfo: DiskInfo = .zero
    var procs: [ProcInfo] = []; var lastPressure: MemPressure = .healthy

    func applicationDidFinishLaunching(_ n: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button { b.target = self; b.action = #selector(toggle) }
        popover = NSPopover(); popover.behavior = .transient; popover.delegate = self; popover.animates = true
        mainVC = MainVC(); popover.contentViewController = mainVC; _ = mainVC.view
        refresh(); scheduleTimer()
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.refreshInterval),
                                     target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }

    @objc func tick() {
        sysRAM = fetchSystemRAM(); diskInfo = fetchDiskUsage(); updateStatusBar(); checkNotif()
        if popover.isShown && !mainVC.showSettings { procs = fetchProcesses(); mainVC.update(ram: sysRAM, disk: diskInfo, p: procs) }
    }

    func refresh() {
        sysRAM = fetchSystemRAM(); diskInfo = fetchDiskUsage(); procs = fetchProcesses()
        updateStatusBar(); mainVC.update(ram: sysRAM, disk: diskInfo, p: procs)
    }

    @objc func toggle() {
        if popover.isShown { popover.close() }
        else { refresh(); popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY) }
    }

    func updateStatusBar() {
        guard let b = statusItem.button else { return }
        let ramPct = Int(sysRAM.pct); let diskPct = Int(diskInfo.pct)
        let lbl: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .baselineOffset: 1.0
        ]
        let val: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "RAM ", attributes: lbl))
        s.append(NSAttributedString(string: "\(ramPct)%", attributes: val))
        s.append(NSAttributedString(string: "   SSD ", attributes: lbl))
        s.append(NSAttributedString(string: "\(diskPct)%", attributes: val))
        b.attributedTitle = s
        b.image = nil
    }

    func checkNotif() {
        guard config.showNotifications else { return }
        let pr = sysRAM.pressure; guard pr != lastPressure else { return }
        let prev = lastPressure; lastPressure = pr
        if (pr == .critical || pr == .danger) && (prev == .healthy || prev == .elevated) {
            let c = UNMutableNotificationContent(); c.title = "RamGuard"
            c.body = "RAM at \(Int(sysRAM.pct))% — \(fmtBytes(sysRAM.used)) of \(fmtBytes(sysRAM.total))"
            c.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ram-\(Date().timeIntervalSince1970)", content: c, trigger: nil))
        }
    }
    func popoverDidClose(_ n: Notification) { mainVC.confirmPID = nil }
}

// MARK: - Entry Point

let app = NSApplication.shared
let rgApp = RamGuardApp()
app.delegate = rgApp
app.setActivationPolicy(.accessory)
app.run()
