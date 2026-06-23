import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private unowned let app: AppDelegate
    private let enabledSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let dockSwitch = NSSwitch()
    private let exclusionsDetail = NSTextField(labelWithString: "")
    private let permissionTitle = NSTextField(labelWithString: "")
    private let permissionDetail = NSTextField(wrappingLabelWithString: "")
    private let permissionIcon = NSImageView()
    private let permissionButton = NSButton()
    private var permissionHero: NSView?
    private var lastPermissionGranted: Bool?
    private var collapseScheduled = false
    private var settingsPage: NSView!
    private var exclusionsPage: ExclusionsView!
    private var isShowingExclusions = false

    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 510),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Closend"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        super.init(window: window)
        buildInterface(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        enabledSwitch.state = app.isEnabled ? .on : .off
        loginSwitch.state = app.launchesAtLogin ? .on : .off
        dockSwitch.state = app.showDockIcon ? .on : .off
        let exclusionCount = app.excludedBundleIdentifiers.count
        exclusionsDetail.stringValue = exclusionCount == 0 ? "Нет исключений" : "Исключений: \(exclusionCount)"
        let granted = app.hasAccessibilityPermission

        if granted {
            permissionTitle.stringValue = "Всё готово"
            permissionDetail.stringValue = "Универсальный доступ разрешён. Closend уже следит за красной кнопкой."
            permissionIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Разрешено")
            permissionIcon.contentTintColor = .systemGreen
            permissionButton.isHidden = true
        } else {
            permissionTitle.stringValue = "Нужно одно разрешение"
            permissionDetail.stringValue = "Разрешите Closend управлять интерфейсом Mac — без этого он не сможет определить нажатие красной кнопки."
            permissionIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Требуется разрешение")
            permissionIcon.contentTintColor = .systemYellow
            permissionButton.title = "Разрешить…"
            permissionButton.isEnabled = true
            permissionButton.isHidden = false
        }

        if lastPermissionGranted == nil {
            granted ? collapsePermission(animated: false) : expandPermission(animated: false)
        } else if lastPermissionGranted == false && granted {
            showPermissionSuccessThenCollapse()
        } else if lastPermissionGranted == true && !granted {
            collapseScheduled = false
            expandPermission(animated: true)
        }
        lastPermissionGranted = granted
    }

    private func buildInterface(in window: NSWindow) {
        let background = DarkBackgroundView()
        window.contentView = background

        settingsPage = NSView()
        settingsPage.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(settingsPage)
        NSLayoutConstraint.activate([
            settingsPage.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            settingsPage.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            settingsPage.topAnchor.constraint(equalTo: background.topAnchor),
            settingsPage.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])

        let appIcon = NSImageView()
        appIcon.image = NSImage(named: NSImage.applicationIconName)
        appIcon.imageScaling = .scaleProportionallyUpOrDown

        let title = text("Closend", size: 30, weight: .bold)
        let subtitle = text("Красная кнопка. Настоящее закрытие.", size: 14, color: .secondaryLabelColor)
        let titleText = vertical([title, subtitle], spacing: 3)
        let header = horizontal([appIcon, titleText, NSView()], spacing: 16)

        permissionTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        permissionDetail.font = .systemFont(ofSize: 12)
        permissionDetail.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        permissionDetail.maximumNumberOfLines = 2
        permissionIcon.symbolConfiguration = .init(pointSize: 36, weight: .semibold)

        permissionButton.target = self
        permissionButton.action = #selector(permissionPressed)
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .regular

        let permissionText = vertical([permissionTitle, permissionDetail], spacing: 7)
        let heroContent = horizontal([permissionIcon, permissionText, NSView(), permissionButton], spacing: 14)
        heroContent.alignment = .centerY
        let permissionHero = flatPanel(content: heroContent, cornerRadius: 18)
        self.permissionHero = permissionHero
        permissionHero.heightAnchor.constraint(equalToConstant: 116).isActive = true
        permissionButton.widthAnchor.constraint(equalToConstant: 126).isActive = true
        permissionButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        permissionIcon.widthAnchor.constraint(equalToConstant: 38).isActive = true
        permissionIcon.heightAnchor.constraint(equalToConstant: 38).isActive = true

        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)
        loginSwitch.target = self
        loginSwitch.action = #selector(loginChanged)
        dockSwitch.target = self
        dockSwitch.action = #selector(dockChanged)

        exclusionsDetail.font = .systemFont(ofSize: 12)
        exclusionsDetail.textColor = .secondaryLabelColor
        let exclusionsButton = NSButton(title: "Настроить", target: self, action: #selector(showExclusions))
        exclusionsButton.bezelStyle = .inline
        exclusionsButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        exclusionsButton.imagePosition = .imageTrailing

        let behaviorRows = vertical([
            settingRow(title: "Закрывать приложения полностью", detail: "Красная кнопка работает как ⌘Q", control: enabledSwitch),
            separator(),
            settingRow(title: "Запускать вместе с macOS", detail: "Closend готов сразу после включения Mac", control: loginSwitch),
            separator(),
            settingRow(title: "Показывать значок в Dock", detail: "Быстрый доступ к настройкам", control: dockSwitch),
            separator(),
            settingRow(title: "Исключения", detailView: exclusionsDetail, control: exclusionsButton)
        ], spacing: 0)
        let behaviorCard = flatPanel(content: behaviorRows, cornerRadius: 18)
        behaviorCard.heightAnchor.constraint(equalToConstant: 292).isActive = true

        let content = vertical([header, permissionHero, behaviorCard], spacing: 18)
        content.translatesAutoresizingMaskIntoConstraints = false
        settingsPage.addSubview(content)

        let version = text("Версия 0.10.0", size: 11, color: .tertiaryLabelColor)
        version.translatesAutoresizingMaskIntoConstraints = false
        settingsPage.addSubview(version)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: settingsPage.leadingAnchor, constant: 36),
            content.trailingAnchor.constraint(equalTo: settingsPage.trailingAnchor, constant: -36),
            content.topAnchor.constraint(equalTo: settingsPage.topAnchor, constant: 52),
            appIcon.widthAnchor.constraint(equalToConstant: 50),
            appIcon.heightAnchor.constraint(equalToConstant: 50),
            permissionHero.widthAnchor.constraint(equalTo: content.widthAnchor),
            behaviorCard.widthAnchor.constraint(equalTo: content.widthAnchor),
            version.centerXAnchor.constraint(equalTo: settingsPage.centerXAnchor),
            version.bottomAnchor.constraint(equalTo: settingsPage.bottomAnchor, constant: -14)
        ])

        exclusionsPage = ExclusionsView(app: app) { [weak self] in
            self?.showSettingsPage(animated: true)
        }
        exclusionsPage.translatesAutoresizingMaskIntoConstraints = false
        exclusionsPage.isHidden = true
        background.addSubview(exclusionsPage)
        NSLayoutConstraint.activate([
            exclusionsPage.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            exclusionsPage.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            exclusionsPage.topAnchor.constraint(equalTo: background.topAnchor),
            exclusionsPage.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        refresh()
    }

    func showExclusionsPage() {
        exclusionsPage.refresh()
        isShowingExclusions = true
        resizeWindow(to: 560, animated: true)
        transition(from: settingsPage, to: exclusionsPage)
    }

    func showSettingsPage(animated: Bool) {
        guard isShowingExclusions else { return }
        isShowingExclusions = false
        refresh()
        transition(from: exclusionsPage, to: settingsPage, animated: animated)
        resizeWindow(to: app.hasAccessibilityPermission ? 475 : 635, animated: animated)
    }

    private func transition(from oldView: NSView, to newView: NSView, animated: Bool = true) {
        newView.isHidden = false
        if !animated {
            oldView.isHidden = true
            newView.alphaValue = 1
            return
        }
        newView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            oldView.animator().alphaValue = 0
            newView.animator().alphaValue = 1
        } completionHandler: {
            Task { @MainActor in
                oldView.isHidden = true
                oldView.alphaValue = 1
            }
        }
    }

    private func showPermissionSuccessThenCollapse() {
        guard !collapseScheduled else { return }
        collapseScheduled = true
        permissionHero?.isHidden = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.app.hasAccessibilityPermission else { return }
            self.collapsePermission(animated: true)
            self.collapseScheduled = false
        }
    }

    private func collapsePermission(animated: Bool) {
        permissionHero?.isHidden = true
        if !isShowingExclusions { resizeWindow(to: 475, animated: animated) }
    }

    private func expandPermission(animated: Bool) {
        permissionHero?.isHidden = false
        if !isShowingExclusions { resizeWindow(to: 635, animated: animated) }
    }

    private func resizeWindow(to height: CGFloat, animated: Bool) {
        guard let window, abs(window.frame.height - height) > 1 else { return }
        let oldFrame = window.frame
        let newFrame = NSRect(x: oldFrame.minX, y: oldFrame.maxY - height, width: oldFrame.width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
    }

    private func flatPanel(content: NSView, cornerRadius: CGFloat) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.106, green: 0.106, blue: 0.106, alpha: 1).cgColor
        container.layer?.cornerRadius = cornerRadius

        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -22)
        ])
        return container
    }

    private func settingRow(title: String, detail: String, control: NSView) -> NSView {
        settingRow(title: title, detailView: text(detail, size: 12, color: .secondaryLabelColor), control: control)
    }

    private func settingRow(title: String, detailView: NSView, control: NSView) -> NSView {
        let labels = vertical([
            text(title, size: 15, weight: .medium),
            detailView
        ], spacing: 4)
        labels.alignment = .leading
        let row = horizontal([labels, NSView(), control], spacing: 12)
        row.alignment = .centerY
        row.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return row
    }

    private func vertical(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func horizontal(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }

    private func separator() -> NSView {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1).cgColor
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func text(_ value: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    @objc private func enabledChanged() { app.setEnabled(enabledSwitch.state == .on) }

    @objc private func loginChanged() {
        do {
            try app.setLaunchAtLogin(loginSwitch.state == .on)
        } catch {
            loginSwitch.state = app.launchesAtLogin ? .on : .off
            let alert = NSAlert(error: error)
            alert.messageText = "Не удалось изменить автозапуск"
            alert.runModal()
        }
    }

    @objc private func permissionPressed() { app.requestAccessibilityPermission() }
    @objc private func showExclusions() { app.showExclusions() }
    @objc private func dockChanged() { app.setShowDockIcon(dockSwitch.state == .on) }
}

private final class DarkBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.125, green: 0.125, blue: 0.125, alpha: 1).setFill()
        bounds.fill()
    }
}
