import AppKit
import TypingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggle = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
    private let shortcut = GlobalShortcut()
    private let engine = TypingEngine()
    private var shortcutError: OSStatus = 0
    private var permissionTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var escapeMonitor: Any?
    private var localEscapeMonitor: Any?
    private var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled") }
    }

    override init() {
        UserDefaults.standard.register(defaults: ["enabled": true])
        enabled = UserDefaults.standard.bool(forKey: "enabled")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.setAccessibilityLabel("Clipboard Typer")
        menu.delegate = self
        menu.autoenablesItems = false
        status.isEnabled = false
        menu.addItem(status)
        let hint = NSMenuItem(title: "Type clipboard: ⌘⇧V", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        let escape = NSMenuItem(title: "Escape stops typing", action: nil, keyEquivalent: "")
        escape.isEnabled = false
        menu.addItem(escape)
        menu.addItem(.separator())
        toggle.target = self
        menu.addItem(toggle)
        let permission = NSMenuItem(title: "Accessibility Permission…", action: #selector(openPermission), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Clipboard Typer", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // NSStatusItem's native menu handles both left and right mouse clicks.
        statusItem.menu = menu

        shortcut.onPressed = { [weak self] in self?.typeClipboard() }
        engine.onStateChanged = { [weak self] in self?.refreshMenu() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.cancel() }
        }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                MainActor.assumeIsolated { self?.engine.cancel() }
            }
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.engine.cancel() }
            return event
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !AccessibilityPermission.isGranted { self.engine.cancel() }
                self.refreshMenu()
            }
        }
        updateShortcut()
        if !UserDefaults.standard.bool(forKey: "explainedAccessibility") {
            // Schedule after the status item is installed so the app is easy to find.
            DispatchQueue.main.async { [weak self] in self?.explainPermission() }
        }
    }

    private func explainPermission() {
        UserDefaults.standard.set(true, forKey: "explainedAccessibility")
        guard !AccessibilityPermission.isGranted else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow Clipboard Typer to type"
        alert.informativeText = "Clipboard Typer lives in your menu bar. Press ⌘⇧V to type clipboard text into the focused app. Enable Clipboard Typer in System Settings → Privacy & Security → Accessibility.\n\nText stays on your Mac. Press Escape to stop typing."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn { AccessibilityPermission.openSettings() }
    }

    private func updateShortcut() {
        engine.cancel()
        shortcut.unregister()
        shortcutError = enabled ? shortcut.register() : 0
        refreshMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Opening our menu cancels any pending or ongoing typing.
        engine.cancel()
        if enabled && shortcutError != 0 { shortcutError = shortcut.register() }
        refreshMenu()
    }

    private func refreshMenu() {
        let title: String
        let symbol: String
        if !enabled {
            title = "Paused"
            symbol = "pause.circle"
        } else if shortcutError != 0 {
            title = "Shortcut unavailable"
            symbol = "exclamationmark.triangle"
        } else if !AccessibilityPermission.isGranted {
            title = "Accessibility needed"
            symbol = "exclamationmark.triangle"
        } else if engine.isTyping {
            title = "Typing…"
            symbol = "keyboard.fill"
        } else {
            title = "Enabled"
            symbol = "keyboard"
        }
        status.title = title
        status.toolTip = shortcutError == 0 ? nil : "Could not register ⌘⇧V (error \(shortcutError)). Another app may be using it. Pause and re-enable to retry."
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Clipboard Typer: \(title)")
        statusItem.button?.toolTip = "Clipboard Typer — \(title)"
        toggle.title = enabled ? "Pause" : "Enable"
        toggle.state = enabled ? .on : .off
    }

    private func typeClipboard() {
        guard enabled, !engine.isTyping else { return }
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.request()
            refreshMenu()
            return
        }
        guard let target = NSWorkspace.shared.frontmostApplication,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        let pid = target.processIdentifier
        engine.start(text: text, canContinue: { [weak self] in
            guard let self else { return false }
            return self.enabled && AccessibilityPermission.isGranted
                && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
                && !KeyboardWriter.escapePressed
        }, modifiersReleased: { KeyboardWriter.modifiersReleased }, send: { KeyboardWriter.send($0) })
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        updateShortcut()
    }

    @objc private func openPermission() {
        engine.cancel()
        AccessibilityPermission.openSettings()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        engine.cancel()
        shortcut.stop()
        permissionTimer?.invalidate()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
