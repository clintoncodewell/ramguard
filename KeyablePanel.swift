import AppKit

/// Keyboard focus for accessory (LSUIElement) menu-bar apps. Call `FocusKit.install()` once at launch.
///
/// Fixes two things the menu-bar apps share:
///  1. DEAD KEYBOARD AFTER HIDE. An accessory app that activated to show a window stays the
///     active app after that window hides or closes. It has no key window, so every key dings and
///     another app's visible panel cannot get the keyboard back. `handBackIfIdle()` gives activation
///     back to the app the user came from, when a panel is dismissed or any window (Settings, pop-out) closes.
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
        // Any window that closes (Settings, pop-outs) can leave us active with nothing to type into.
        // Not didResignKey: key can move to another app's nonactivating panel (Spotlight) while we stay
        // active, and handing activation away then would close that panel.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { scheduleHandBack() }
        }
    }

    private static func note(_ app: NSRunningApplication?) {
        if let app, app.processIdentifier != getpid() { returnTo = app }
    }

    /// Check on the next run-loop pass, once per burst, after the closing window is really gone,
    /// and once more after close animations (popovers, fades) have finished.
    static func scheduleHandBack() {
        guard !checkPending else { return }
        checkPending = true
        DispatchQueue.main.async { MainActor.assumeIsolated { checkPending = false; handBackIfIdle() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { MainActor.assumeIsolated { handBackIfIdle() } }
    }

    /// If we are the active app with no key window and nothing visible that could take the keyboard,
    /// give activation back to the app the user came from.
    static func handBackIfIdle() {
        // NSApp.isActive is our own state and updates synchronously, unlike NSWorkspace.frontmostApplication.
        // A visible window on another Space cannot take the keyboard here, so it does not count.
        guard NSApp.isActive, NSApp.keyWindow == nil, NSApp.modalWindow == nil,
              !NSApp.windows.contains(where: { $0.isVisible && $0.isOnActiveSpace && $0.canBecomeKey }) else { return }
        handBack()
    }

    /// Give activation back to the app the user came from now, whatever windows we have open.
    /// For flows that must leave this app at once, such as pasting into the previous app.
    static func handBack() {
        guard NSApp.isActive else { return }
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
        // Only ⌘ ⇧ ⌥ ⌃ count: Caps Lock, fn and the keypad flag must not stop ⌘C from matching.
        let m = modifiers.intersection([.command, .shift, .option, .control])
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
            // Pass only Sendable values into the main-actor block; NSEvent is not Sendable.
            guard let k = event.charactersIgnoringModifiers else { return event }
            let flags = event.modifierFlags, windowNumber = event.windowNumber
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let sel = editSelector(key: k, modifiers: flags),
                      let w = NSApp.window(withWindowNumber: windowNumber) ?? NSApp.keyWindow else { return false }
                return sendEditAction(sel, in: w)
            }
            return handled ? nil : event
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
    /// Pass `handBack: false` when the hide is a reaction to losing key (click outside, resign key):
    /// focus already went somewhere the user chose, possibly another app's nonactivating panel.
    func dismiss(handBack: Bool = true) {
        orderOut(nil)
        if handBack { FocusKit.scheduleHandBack() }
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
