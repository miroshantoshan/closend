import AppKit

private struct ApplicationEntry {
    let bundleIdentifier: String
    let name: String
    let url: URL
    let icon: NSImage
}

@MainActor
final class ExclusionsView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private unowned let app: AppDelegate
    private let backHandler: () -> Void
    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private var applications: [ApplicationEntry] = []
    private var visibleApplications: [ApplicationEntry] = []

    init(app: AppDelegate, backHandler: @escaping () -> Void) {
        self.app = app
        self.backHandler = backHandler
        super.init(frame: .zero)
        buildInterface()
        loadApplications()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        tableView.reloadData()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.125, alpha: 1).setFill()
        bounds.fill()
    }

    private func buildInterface() {
        let backButton = NSButton(title: "Назад", target: self, action: #selector(goBack))
        backButton.bezelStyle = .inline
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
        backButton.imagePosition = .imageLeading

        let title = NSTextField(labelWithString: "Исключения")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "Для выбранных приложений красная кнопка закрывает только окно.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        searchField.placeholderString = "Найти приложение"
        searchField.delegate = self

        let addButton = NSButton(title: "Добавить…", target: self, action: #selector(addApplication))
        addButton.bezelStyle = .rounded
        let tools = NSStackView(views: [searchField, addButton])
        tools.orientation = .horizontal
        tools.spacing = 10

        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("check"))
        checkColumn.width = 42
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("application"))
        appColumn.width = 450
        tableView.addTableColumn(checkColumn)
        tableView.addTableColumn(appColumn)
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = NSColor(calibratedWhite: 0.106, alpha: 1)
        tableView.delegate = self
        tableView.dataSource = self

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 16

        let stack = NSStackView(views: [backButton, title, subtitle, tools, scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            tools.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
    }

    private func loadApplications() {
        let fileManager = FileManager.default
        var urls = Set<URL>()
        let folders = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        for folder in folders {
            let contents = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            urls.formUnion(contents.filter { $0.pathExtension.lowercased() == "app" })
        }
        urls.insert(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true))
        urls.formUnion(NSWorkspace.shared.runningApplications.compactMap(\.bundleURL))

        var identifiers = Set<String>()
        applications = urls.compactMap { url in
            guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
                  identifier != Bundle.main.bundleIdentifier,
                  identifiers.insert(identifier).inserted else { return nil }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 30, height: 30)
            return ApplicationEntry(bundleIdentifier: identifier, name: name, url: url, icon: icon)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleApplications = query.isEmpty ? applications : applications.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
    }

    func controlTextDidChange(_ obj: Notification) { applyFilter() }
    func numberOfRows(in tableView: NSTableView) -> Int { visibleApplications.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = visibleApplications[row]
        if tableColumn?.identifier.rawValue == "check" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleApplication(_:)))
            checkbox.tag = row
            checkbox.state = app.excludedBundleIdentifiers.contains(entry.bundleIdentifier) ? .on : .off
            return checkbox
        }

        let icon = NSImageView(image: entry.icon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: entry.name)
        name.font = .systemFont(ofSize: 14, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        let bundle = NSTextField(labelWithString: entry.bundleIdentifier)
        bundle.font = .systemFont(ofSize: 10)
        bundle.textColor = .tertiaryLabelColor
        let labels = NSStackView(views: [name, bundle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        let rowView = NSStackView(views: [icon, labels])
        rowView.orientation = .horizontal
        rowView.alignment = .centerY
        rowView.spacing = 10
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return rowView
    }

    @objc private func goBack() { backHandler() }

    @objc private func toggleApplication(_ sender: NSButton) {
        guard visibleApplications.indices.contains(sender.tag) else { return }
        app.setExcluded(sender.state == .on, bundleIdentifier: visibleApplications[sender.tag].bundleIdentifier)
    }

    @objc private func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Выберите приложение"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }

        if !applications.contains(where: { $0.bundleIdentifier == identifier }) {
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            applications.append(ApplicationEntry(bundleIdentifier: identifier, name: name, url: url, icon: NSWorkspace.shared.icon(forFile: url.path)))
            applications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        app.setExcluded(true, bundleIdentifier: identifier)
        applyFilter()
    }
}
