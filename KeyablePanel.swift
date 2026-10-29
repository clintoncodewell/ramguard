import AppKit

/// Keyboard focus for accessory (LSUIElement) menu-bar apps. Call `FocusKit.install()` once at launch.
///
/// Fixes two things the menu-bar apps share:
///  1. DEAD KEYBOARD AFTER HIDE. An accessory app that activated to show a window stays the
///     active app after that window hides or closes. It has no key window, so every key dings and
///     another app's visible panel cannot get the keyboard back. `handBackIfIdle()` gives activation
///     back to the app the user came from, whichever window (panel, Settings, alert, pop-out) went away.
///  2. DEAD PANEL. A visible nonactivating panel that lost key ignores clicks. `KeyablePanel.sendEvent`
///     re-claims key on a left click.
/// ⌘X/C/V/A/Z (⇧⌘Z redo) also walk the panel's responder chain, so they do not depend on the main menu,
/// which an inactive app never consults.
@MainActor
enum FocusKit {
    static var log: (String) -> Void = { _ in }
    /// The last other app that was active. When we are active, that is the app we took focus from.
    private(set) static var returnTo: NSRunningApplication?
    private static var installed = false
    private static var checkPending = false
    private static var lastHandBack = Date.distantPast

    static func install() {
        guard !installed else { return }
        installed = true
        note(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { n in
            let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { note(app) }
        }
        // Any window that closes or loses key can leave us active with nothing to type into.
        for name in [NSWindow.willCloseNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { scheduleHandBack() }
            }
        }
    }

    private static func note(_ app: NSRunningApplication?) {
        if let app, app.processIdentifier != getpid() { returnTo = app }
    }

    /// Check on the next run-loop pass, once per burst, after the closing window is really gone.
    static func scheduleHandBack() {
        guard !checkPending else { return }
        checkPending = true
        DispatchQueue.main.async { MainActor.assumeIsolated { checkPending = false; handBackIfIdle() } }
    }

    /// If we are the active app with no key window and nothing visible that could take the keyboard,
    /// give activation back to the app the user came from.
    static func handBackIfIdle() {
        // NSApp.isActive is our own state and updates synchronously, unlike NSWorkspace.frontmostApplication.
        guard NSApp.isActive, NSApp.keyWindow == nil, NSApp.modalWindow == nil,
              !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeKey }),
              Date().timeIntervalSince(lastHandBack) > 0.5 else { return }
        lastHandBack = Date()
        if let back = returnTo, !back.isTerminated, !back.isHidden {
            NSApp.yieldActivation(to: back)
            back.activate()
            log("focus: handed activation back to \(back.localizedName ?? "?")")
        } else {
            NSApp.deactivate()
            log("focus: deactivated (no app to hand back to)")
        }
    }

    /// The edit action ⌘X/C/V/A/Z (and ⇧⌘Z redo) stands for, or nil for any other combo. ⇧⌘V is not paste.
    nonisolated static func editSelector(key: String, modifiers: NSEvent.ModifierFlags) -> Selector? {
        let m = modifiers.intersection(.deviceIndependentFlagsMask)
        guard m == .command || m == [.command, .shift] else { return nil }
        let k = key.lowercased()
        if k == "z" { return Selector(m.contains(.shift) ? "redo:" : "undo:") }
        guard m == .command else { return nil }
        return ["x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)),
                "a": #selector(NSText.selectAll(_:))][k]
    }

    /// Send an edit action up the window's responder chain (first responder, views, window, window delegate),
    /// the way a menu item would. Returns false when nothing handles it.
    static func sendEditAction(_ sel: Selector, in window: NSWindow) -> Bool {
        (window.firstResponder ?? window).tryToPerform(sel, with: nil)
    }

    /// For apps whose text fields live outside a KeyablePanel (an NSPopover, say): route edit keys
    /// to the key window's responder chain before the event is dispatched.
    static func installEditKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                guard let k = event.charactersIgnoringModifiers,
                      let sel = editSelector(key: k, modifiers: event.modifierFlags),
                      let w = event.window ?? NSApp.keyWindow, sendEditAction(sel, in: w) else { return event }
                return nil
            }
        }
    }
}

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Show the panel and give it the keyboard. `activate: false` keeps the user's app frontmost.
    func present(activate: Bool) {
        makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
    }

    /// Hide the panel; if that leaves us active with nothing to type into, give focus back.
    func dismiss() {
        orderOut(nil)
        FocusKit.scheduleHandBack()
    }

    override func sendEvent(_ event: NSEvent) {
        if !isKeyWindow, event.type == .leftMouseDown {
            makeKeyAndOrderFront(nil)
            if !isKeyWindow { NSApp.activate(ignoringOtherApps: true); makeKey() }
            FocusKit.log("focus: click re-claimed key -> isKey=\(isKeyWindow)")
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        guard event.type == .keyDown, let k = event.charactersIgnoringModifiers,
              let sel = FocusKit.editSelector(key: k, modifiers: event.modifierFlags) else { return false }
        return FocusKit.sendEditAction(sel, in: self)
    }
}
