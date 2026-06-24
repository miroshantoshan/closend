import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var lastKnownAccessibilityPermission = false
    private var settingsWindow: SettingsWindowController?
    nonisolated private let clickInspector = AccessibilityClickInspector()

    private(set) var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }
    private(set) var showDockIcon: Bool {
        didSet { UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon") }
    }
    private(set) var toggleWindowsFromDock: Bool {
        didSet { UserDefaults.standard.set(toggleWindowsFromDock, forKey: "toggleWindowsFromDock") }
    }

    override init() {
        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }
        if UserDefaults.standard.object(forKey: "showDockIcon") == nil {
            showDockIcon = true
        } else {
            showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        }
        if UserDefaults.standard.object(forKey: "toggleWindowsFromDock") == nil {
            toggleWindowsFromDock = true
            UserDefaults.standard.set(true, forKey: "toggleWindowsFromDock")
        } else {
            toggleWindowsFromDock = UserDefaults.standard.bool(forKey: "toggleWindowsFromDock")
        }
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "showDockIcon") == nil ||
            UserDefaults.standard.bool(forKey: "showDockIcon") {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockVisibility()
        makeStatusMenu()
        lastKnownAccessibilityPermission = hasAccessibilityPermission
        synchronizeEventTapWithPermission()
        startPermissionTimer()

        if !hasAccessibilityPermission || !UserDefaults.standard.bool(forKey: "didShowFirstSettings") {
            UserDefaults.standard.set(true, forKey: "didShowFirstSettings")
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEventTap()
    }

    var isInstalledInApplications: Bool {
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL
        let locations = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        return locations.map(\.standardizedFileURL).contains(parent)
    }

    var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    var menuBarStatusDescription: String {
        guard let statusItem else { return "Menu bar: not created" }
        let title = statusItem.button?.title ?? ""
        let hasImage = statusItem.button?.image != nil
        return "Menu bar: created · title “\(title.isEmpty ? "none" : title)” · image \(hasImage ? "yes" : "no")"
    }

    var excludedBundleIdentifiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "excludedBundleIdentifiers") ?? [])
    }

    func setExcluded(_ excluded: Bool, bundleIdentifier: String) {
        var identifiers = excludedBundleIdentifiers
        if excluded {
            identifiers.insert(bundleIdentifier)
        } else {
            identifiers.remove(bundleIdentifier)
        }
        UserDefaults.standard.set(Array(identifiers).sorted(), forKey: "excludedBundleIdentifiers")
        settingsWindow?.refresh()
    }

    private func makeStatusMenu() {
        if statusItem != nil {
            NSStatusBar.system.removeStatusItem(statusItem)
            statusItem = nil
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        statusItem.length = NSStatusItem.squareLength
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Closend")
            icon?.isTemplate = true
            button.image = icon
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
            button.target = nil
            button.action = nil
            button.toolTip = "Closend"
        }
        rebuildMenu()
        settingsWindow?.refresh()
    }

    func recreateMenuBarItem() {
        makeStatusMenu()
    }

    @objc private func showStatusMenu() {
        statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: statusItem.button?.bounds.height ?? 0), in: statusItem.button)
    }

    private func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let mark = NSBezierPath()
        mark.lineWidth = 2.25
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.move(to: NSPoint(x: 12.9, y: 4.4))
        mark.curve(
            to: NSPoint(x: 5.25, y: 5.9),
            controlPoint1: NSPoint(x: 10.6, y: 3.3),
            controlPoint2: NSPoint(x: 7.1, y: 3.7)
        )
        mark.curve(
            to: NSPoint(x: 5.25, y: 12.1),
            controlPoint1: NSPoint(x: 3.55, y: 7.85),
            controlPoint2: NSPoint(x: 3.55, y: 10.15)
        )
        mark.curve(
            to: NSPoint(x: 12.9, y: 13.6),
            controlPoint1: NSPoint(x: 7.1, y: 14.3),
            controlPoint2: NSPoint(x: 10.6, y: 14.7)
        )
        mark.stroke()

        let arrow = NSBezierPath()
        arrow.lineWidth = 2.25
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 12.45, y: 13.55))
        arrow.line(to: NSPoint(x: 9.95, y: 16.0))
        arrow.move(to: NSPoint(x: 12.45, y: 13.55))
        arrow.line(to: NSPoint(x: 9.95, y: 11.1))
        arrow.stroke()

        NSBezierPath(ovalIn: NSRect(x: 12.2, y: 7.05, width: 2.7, height: 2.7)).fill()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Closend"
        return image
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: isEnabled ? "Closend включён" : "Closend выключен",
            action: #selector(toggleEnabledFromMenu),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = isEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Настройки…", action: #selector(showSettingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Выйти из Closend", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(app: self)
        }
        settingsWindow?.refresh()
        settingsWindow?.showSettingsPage(animated: false)
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showExclusions() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(app: self)
        }
        settingsWindow?.showExclusionsPage()
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setShowDockIcon(_ visible: Bool) {
        showDockIcon = visible
        applyDockVisibility()
        settingsWindow?.refresh()
    }

    private func applyDockVisibility() {
        if let iconURL = Bundle.main.url(forResource: "Closend", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        synchronizeEventTapWithPermission()
        rebuildMenu()
        settingsWindow?.refresh()
    }

    func setToggleWindowsFromDock(_ enabled: Bool) {
        toggleWindowsFromDock = enabled
        synchronizeEventTapWithPermission()
        settingsWindow?.refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
        settingsWindow?.refresh()
    }

    func requestAccessibilityPermission() {
        openAccessibilitySettings()
    }

    private func startPermissionTimer() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let permissionChanged = self.lastKnownAccessibilityPermission != self.hasAccessibilityPermission
                self.synchronizeEventTapWithPermission()
                if permissionChanged || self.settingsWindow?.window?.isVisible == true {
                    self.settingsWindow?.refresh()
                }
            }
        }
    }

    private func synchronizeEventTapWithPermission() {
        let trusted = hasAccessibilityPermission
        lastKnownAccessibilityPermission = trusted
        if trusted {
            startEventTapIfPossible()
        } else {
            stopEventTap()
            rebuildMenu()
        }
    }

    private func startEventTapIfPossible() {
        guard (isEnabled || toggleWindowsFromDock), AXIsProcessTrusted(), eventTap == nil else {
            if !isEnabled && !toggleWindowsFromDock { stopEventTap() }
            rebuildMenu()
            return
        }

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let userInfo {
                    let app = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
                    Task { @MainActor in app.enableEventTap() }
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .leftMouseDown, let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let app = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            app.inspectClick(at: event.location, frontmostPID: frontmostPID)
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        rebuildMenu()
    }

    nonisolated private func inspectClick(at point: CGPoint, frontmostPID: pid_t?) {
        clickInspector.inspect(at: point, frontmostPID: frontmostPID)
    }

    @objc private func toggleEnabledFromMenu() { setEnabled(!isEnabled) }
    @objc private func showSettingsAction() { showSettings() }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func enableEventTap() {
        guard hasAccessibilityPermission else {
            stopEventTap()
            return
        }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
    }

    private func stopEventTap() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        runLoopSource = nil
        eventTap = nil
    }
}

private final class AccessibilityClickInspector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.closend.accessibility", qos: .userInitiated)
    private let lock = NSLock()
    private var isInspecting = false

    func inspect(at point: CGPoint, frontmostPID: pid_t?) {
        lock.lock()
        guard !isInspecting else {
            lock.unlock()
            return
        }
        isInspecting = true
        lock.unlock()

        queue.async { [self] in
            defer {
                lock.lock()
                isInspecting = false
                lock.unlock()
            }

            guard AXIsProcessTrusted(), let clickedElement = element(at: point) else { return }

            if UserDefaults.standard.bool(forKey: "isEnabled"),
               let pid = closeButtonApplicationPID(from: clickedElement) {
                DispatchQueue.main.async {
                    guard AXIsProcessTrusted(),
                          let application = NSRunningApplication(processIdentifier: pid) else { return }
                    if let bundleIdentifier = application.bundleIdentifier,
                       Set(UserDefaults.standard.stringArray(forKey: "excludedBundleIdentifiers") ?? []).contains(bundleIdentifier) {
                        return
                    }
                    application.forceTerminate()
                }
                return
            }

            if UserDefaults.standard.bool(forKey: "toggleWindowsFromDock"),
               let bundleIdentifier = dockApplicationBundleIdentifier(from: clickedElement) {
                toggleWindows(for: bundleIdentifier, frontmostPID: frontmostPID)
            }
        }
    }

    private func element(at point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.2)
        var hitElement: AXUIElement?
        guard AXIsProcessTrusted(),
              AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hitElement) == .success,
              let element = hitElement else { return nil }
        return element
    }

    private func closeButtonApplicationPID(from element: AXUIElement) -> pid_t? {
        AXUIElementSetMessagingTimeout(element, 0.2)
        guard isCloseButton(element) else { return nil }
        var pid: pid_t = 0
        guard AXIsProcessTrusted(),
              AXUIElementGetPid(element, &pid) == .success,
              pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        return pid
    }

    private func isCloseButton(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<4 {
            guard AXIsProcessTrusted(), let candidate = current else { return false }
            AXUIElementSetMessagingTimeout(candidate, 0.2)
            if attribute(kAXSubroleAttribute, of: candidate) == kAXCloseButtonSubrole as String { return true }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parent) == .success,
                  let parent else { return false }
            current = (parent as! AXUIElement)
        }
        return false
    }

    private func dockApplicationBundleIdentifier(from element: AXUIElement) -> String? {
        var current: AXUIElement? = element
        for _ in 0..<6 {
            guard AXIsProcessTrusted(), let candidate = current else { return nil }
            AXUIElementSetMessagingTimeout(candidate, 0.2)

            if attribute(kAXRoleAttribute, of: candidate) == "AXDockItem",
               attribute(kAXSubroleAttribute, of: candidate) == "AXApplicationDockItem",
               let url = urlAttribute(kAXURLAttribute, of: candidate) {
                return Bundle(url: url)?.bundleIdentifier
            }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parent) == .success,
                  let parent else { return nil }
            current = (parent as! AXUIElement)
        }
        return nil
    }

    private func toggleWindows(for bundleIdentifier: String, frontmostPID: pid_t?) {
        DispatchQueue.main.async {
            guard AXIsProcessTrusted(),
                  let application = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleIdentifier
                  ).first else { return }

            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.2)
            let windows = self.windows(of: appElement)
            let hasOpenWindow = windows.contains { !self.boolAttribute(kAXMinimizedAttribute, of: $0) }
            let wasFrontmost = application.processIdentifier == frontmostPID

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                guard let currentApplication = NSRunningApplication(
                    processIdentifier: application.processIdentifier
                ) else { return }
                let currentAppElement = AXUIElementCreateApplication(currentApplication.processIdentifier)
                AXUIElementSetMessagingTimeout(currentAppElement, 0.2)
                let currentWindows = self.windows(of: currentAppElement)

                if wasFrontmost && hasOpenWindow {
                    for window in currentWindows {
                        AXUIElementSetAttributeValue(
                            window,
                            kAXMinimizedAttribute as CFString,
                            kCFBooleanTrue
                        )
                    }
                } else {
                    for window in currentWindows {
                        AXUIElementSetAttributeValue(
                            window,
                            kAXMinimizedAttribute as CFString,
                            kCFBooleanFalse
                        )
                    }
                    currentApplication.activate(options: [.activateAllWindows])
                }
            }
        }
    }

    private func windows(of application: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func boolAttribute(_ name: String, of element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private func urlAttribute(_ name: String, of element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? URL
    }

    private func attribute(_ name: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
