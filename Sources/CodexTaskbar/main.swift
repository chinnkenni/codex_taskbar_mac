import AppKit
import Foundation
import ServiceManagement

struct RateLimitWindow {
    let usedPercent: Int
    let windowMinutes: Int
    let resetAt: TimeInterval

    var remainingPercent: Int {
        min(100, max(0, 100 - usedPercent))
    }

    var shortName: String {
        switch windowMinutes {
        case 300:
            return "5h"
        case 10_080:
            return "1w"
        default:
            if windowMinutes % 1_440 == 0 {
                return "\(windowMinutes / 1_440)d"
            }
            if windowMinutes % 60 == 0 {
                return "\(windowMinutes / 60)h"
            }
            return "\(windowMinutes)m"
        }
    }

    var displayName: String {
        switch windowMinutes {
        case 300:
            return "5 小时"
        case 10_080:
            return "1 周"
        default:
            if windowMinutes % 1_440 == 0 {
                return "\(windowMinutes / 1_440) 天"
            }
            if windowMinutes % 60 == 0 {
                return "\(windowMinutes / 60) 小时"
            }
            return "\(windowMinutes) 分钟"
        }
    }
}

struct RateLimitSnapshot {
    let primary: RateLimitWindow
    let secondary: RateLimitWindow
    let observedAt: Date
    let databasePath: String
}

enum TitleMode: String {
    case compact
    case detailed
}

struct Preferences {
    private let defaults = UserDefaults.standard

    var titleMode: TitleMode {
        get {
            TitleMode(rawValue: defaults.string(forKey: "titleMode") ?? "") ?? .detailed
        }
        set {
            defaults.set(newValue.rawValue, forKey: "titleMode")
        }
    }

    var showPrimaryResetInTitle: Bool {
        get {
            if defaults.object(forKey: "showPrimaryResetInTitle") == nil {
                return true
            }
            return defaults.bool(forKey: "showPrimaryResetInTitle")
        }
        set {
            defaults.set(newValue, forKey: "showPrimaryResetInTitle")
        }
    }

    var showSecondaryResetInTitle: Bool {
        get {
            defaults.bool(forKey: "showSecondaryResetInTitle")
        }
        set {
            defaults.set(newValue, forKey: "showSecondaryResetInTitle")
        }
    }

    var refreshInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: "refreshInterval")
            return value > 0 ? value : 5
        }
        set {
            defaults.set(newValue, forKey: "refreshInterval")
        }
    }

    var lastUpdateCheckAt: TimeInterval {
        get {
            defaults.double(forKey: "lastUpdateCheckAt")
        }
        set {
            defaults.set(newValue, forKey: "lastUpdateCheckAt")
        }
    }
}

struct Version: Comparable {
    let parts: [Int]

    init(_ rawValue: String) {
        let cleaned = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        parts = cleaned
            .split(separator: ".")
            .map { segment in
                let digits = segment.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

struct UpdateInfo {
    let tagName: String
    let version: String
    let releaseURL: URL
    let downloadURL: URL?
}

enum UpdateState {
    case idle
    case checking
    case current(Date)
    case available(UpdateInfo)
    case failed(String)
}

final class UpdateChecker {
    private let releaseAPI = URL(string: "https://api.github.com/repos/chinnkenni/codex_taskbar_mac/releases/latest")!

    func check(currentVersion: String, completion: @escaping (Result<UpdateState, Error>) -> Void) {
        var request = URLRequest(url: releaseAPI)
        request.setValue("Codex-Taskbar", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(UpdateError.emptyResponse))
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard let releaseURL = URL(string: release.htmlURL) else {
                    completion(.failure(UpdateError.invalidReleaseURL))
                    return
                }

                let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let downloadURL = release.assets
                    .first(where: { $0.name.hasSuffix(".dmg") })
                    .flatMap { URL(string: $0.browserDownloadURL) }
                let info = UpdateInfo(
                    tagName: release.tagName,
                    version: version,
                    releaseURL: releaseURL,
                    downloadURL: downloadURL
                )

                if Version(version) > Version(currentVersion) {
                    completion(.success(.available(info)))
                } else {
                    completion(.success(.current(Date())))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum UpdateError: Error, LocalizedError {
    case emptyResponse
    case invalidReleaseURL

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "更新服务没有返回数据"
        case .invalidReleaseURL:
            return "更新地址无效"
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

final class CodexRateLimitReader {
    private let databaseCandidates: [String]

    init(homeDirectory: String = NSHomeDirectory()) {
        databaseCandidates = [
            "\(homeDirectory)/.codex/sqlite/logs_2.sqlite",
            "\(homeDirectory)/.codex/logs_2.sqlite"
        ]
    }

    func readLatest() throws -> RateLimitSnapshot {
        guard let databasePath = databaseCandidates.first(where: {
            FileManager.default.isReadableFile(atPath: $0)
        }) else {
            throw ReaderError.databaseNotFound
        }

        let sql = """
        with events as (
          select id, ts, feedback_log_body
          from logs
          where target = 'codex_client::default_client'
            and feedback_log_body like '%Request completed method=POST url=https://chatgpt.com/backend-api/codex/responses status=200 OK headers={%'
            and feedback_log_body like '%"x-codex-primary-used-percent"%'
            and feedback_log_body like '%"x-codex-secondary-used-percent"%'
          union all
          select id, ts, feedback_log_body
          from logs
          where target = 'codex_api::endpoint::responses_websocket'
            and feedback_log_body like '%websocket event: {"type":"codex.rate_limits"%'
            and feedback_log_body like '%"rate_limits"%'
        )
        select ts || char(9) || feedback_log_body
        from events
        order by id desc
        limit 1;
        """

        let output = try runSQLite(databasePath: databasePath, sql: sql)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            throw ReaderError.rateLimitEventNotFound
        }

        let parts = output.split(separator: "\t", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw ReaderError.unparseableEvent
        }

        let observedAt = TimeInterval(parts[0]).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let body = parts[1]

        if let snapshot = parseHeaderSnapshot(from: body, observedAt: observedAt, databasePath: databasePath) {
            return snapshot
        }

        if let eventJSON = extractEventJSON(from: body) {
            let decoded = try JSONDecoder().decode(CodexRateLimitEvent.self, from: Data(eventJSON.utf8))
            return RateLimitSnapshot(
                primary: decoded.rateLimits.primary.window,
                secondary: decoded.rateLimits.secondary.window,
                observedAt: observedAt,
                databasePath: databasePath
            )
        }

        throw ReaderError.unparseableEvent
    }

    private func runSQLite(databasePath: String, sql: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databasePath, sql]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ReaderError.sqliteUnavailable
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return output
        }

        let errorText = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw ReaderError.sqliteFailed(errorText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func extractEventJSON(from body: String) -> String? {
        let marker = "websocket event: "
        guard let markerRange = body.range(of: marker) else {
            return nil
        }

        let tail = body[markerRange.upperBound...]
        guard let startIndex = tail.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var inString = false
        var escaping = false

        for index in tail[startIndex...].indices {
            let char = tail[index]

            if escaping {
                escaping = false
                continue
            }

            if char == "\\" {
                escaping = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            guard !inString else {
                continue
            }

            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(tail[startIndex...index])
                }
            }
        }

        return nil
    }

    private func parseHeaderSnapshot(from body: String, observedAt: Date, databasePath: String) -> RateLimitSnapshot? {
        guard let primaryUsed = headerInt("x-codex-primary-used-percent", in: body),
              let secondaryUsed = headerInt("x-codex-secondary-used-percent", in: body),
              let primaryWindow = headerInt("x-codex-primary-window-minutes", in: body),
              let secondaryWindow = headerInt("x-codex-secondary-window-minutes", in: body),
              let primaryReset = headerInt("x-codex-primary-reset-at", in: body),
              let secondaryReset = headerInt("x-codex-secondary-reset-at", in: body) else {
            return nil
        }

        return RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: primaryUsed,
                windowMinutes: primaryWindow,
                resetAt: TimeInterval(primaryReset)
            ),
            secondary: RateLimitWindow(
                usedPercent: secondaryUsed,
                windowMinutes: secondaryWindow,
                resetAt: TimeInterval(secondaryReset)
            ),
            observedAt: observedAt,
            databasePath: databasePath
        )
    }

    private func headerInt(_ name: String, in body: String) -> Int? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #""\#(escapedName)"\s*:\s*"(\d+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return Int(body[capture])
    }
}

enum ReaderError: Error, LocalizedError {
    case databaseNotFound
    case rateLimitEventNotFound
    case unparseableEvent
    case sqliteUnavailable
    case sqliteFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Codex log database not found"
        case .rateLimitEventNotFound:
            return "No Codex rate-limit event found yet"
        case .unparseableEvent:
            return "Could not parse Codex rate-limit event"
        case .sqliteUnavailable:
            return "sqlite3 is not available"
        case .sqliteFailed(let message):
            return message.isEmpty ? "sqlite3 query failed" : message
        }
    }
}

private struct CodexRateLimitEvent: Decodable {
    let rateLimits: CodexRateLimits

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct CodexRateLimits: Decodable {
    let primary: CodexRateLimitValue
    let secondary: CodexRateLimitValue
}

private struct CodexRateLimitValue: Decodable {
    let usedPercent: Int
    let windowMinutes: Int
    let resetAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetAt = "reset_at"
    }

    var window: RateLimitWindow {
        RateLimitWindow(usedPercent: usedPercent, windowMinutes: windowMinutes, resetAt: resetAt)
    }
}

final class CodexTaskbarApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reader = CodexRateLimitReader()
    private let loginItem = LoginItemController()
    private let updateChecker = UpdateChecker()
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    private var preferences = Preferences()
    private var timer: Timer?
    private var latestSnapshot: RateLimitSnapshot?
    private var latestError: Error?
    private var updateState: UpdateState = .idle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setStatusTitle("5h -- | 1w --", tooltip: "Codex Taskbar")
        refresh()
        scheduleTimer()
        scheduleAutomaticUpdateCheck()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: preferences.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        do {
            let snapshot = try reader.readLatest()
            latestSnapshot = snapshot
            latestError = nil
            setStatusTitle(title(for: snapshot), tooltip: tooltip(for: snapshot))
        } catch {
            latestSnapshot = nil
            latestError = error
            setStatusTitle("5h -- | 1w --", tooltip: error.localizedDescription)
        }

        rebuildMenu()
    }

    private func setStatusTitle(_ title: String, tooltip: String) {
        statusItem.length = NSStatusItem.variableLength

        guard let button = statusItem.button else {
            return
        }

        button.image = nil
        button.alternateImage = nil
        button.title = title
        button.attributedTitle = NSAttributedString(string: title)
        button.toolTip = tooltip
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let snapshot = latestSnapshot {
            menu.addItem(disabledItem(title: "Codex 用量"))
            addWindow(snapshot.primary, to: menu)
            menu.addItem(.separator())
            addWindow(snapshot.secondary, to: menu)
            menu.addItem(.separator())
            menu.addItem(disabledItem(title: "更新: \(relativeTime(snapshot.observedAt))"))
        } else {
            menu.addItem(disabledItem(title: latestError?.localizedDescription ?? "No data"))
            menu.addItem(disabledItem(title: "Open Codex /status or send one message to refresh limits"))
        }

        menu.addItem(.separator())
        addTitleModeItems(to: menu)
        addResetToggles(to: menu)
        addRefreshIntervalItems(to: menu)
        menu.addItem(.separator())
        addLaunchAtLoginItem(to: menu)
        menu.addItem(.separator())
        addUpdateItems(to: menu)
        menu.addItem(.separator())

        let copyItem = NSMenuItem(title: "复制状态", action: #selector(copyStatus), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        let refreshItem = NSMenuItem(title: "刷新", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "退出 Codex Taskbar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func addWindow(_ window: RateLimitWindow, to menu: NSMenu) {
        menu.addItem(disabledItem(title: window.displayName))
        menu.addItem(disabledItem(title: "剩余: \(window.remainingPercent)%"))
        menu.addItem(disabledItem(title: "已用: \(window.usedPercent)%"))
        menu.addItem(disabledItem(title: "重置: \(resetLabel(for: window))"))
    }

    private func addTitleModeItems(to menu: NSMenu) {
        menu.addItem(disabledItem(title: "标题样式"))
        let compact = NSMenuItem(title: "紧凑", action: #selector(setCompactTitle), keyEquivalent: "")
        compact.target = self
        compact.state = preferences.titleMode == .compact ? .on : .off
        menu.addItem(compact)

        let detailed = NSMenuItem(title: "详细", action: #selector(setDetailedTitle), keyEquivalent: "")
        detailed.target = self
        detailed.state = preferences.titleMode == .detailed ? .on : .off
        menu.addItem(detailed)
    }

    private func addResetToggles(to menu: NSMenu) {
        menu.addItem(disabledItem(title: "标题重置时间"))

        let primary = NSMenuItem(title: "显示 5h 重置时间", action: #selector(togglePrimaryReset), keyEquivalent: "")
        primary.target = self
        primary.state = preferences.showPrimaryResetInTitle ? .on : .off
        menu.addItem(primary)

        let secondary = NSMenuItem(title: "显示 1w 重置时间", action: #selector(toggleSecondaryReset), keyEquivalent: "")
        secondary.target = self
        secondary.state = preferences.showSecondaryResetInTitle ? .on : .off
        menu.addItem(secondary)
    }

    private func addRefreshIntervalItems(to menu: NSMenu) {
        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "刷新间隔"))

        for interval in [5.0, 15.0, 60.0] {
            let item = NSMenuItem(title: "\(Int(interval)) 秒", action: #selector(setRefreshInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = preferences.refreshInterval == interval ? .on : .off
            menu.addItem(item)
        }
    }

    private func addLaunchAtLoginItem(to menu: NSMenu) {
        let item = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        item.target = self
        item.state = loginItem.isEnabled ? .on : .off
        menu.addItem(item)

        if loginItem.needsApproval {
            menu.addItem(disabledItem(title: "需要在系统设置里批准登录项"))
        }
    }

    private func addUpdateItems(to menu: NSMenu) {
        menu.addItem(disabledItem(title: "版本: \(currentVersion)"))

        switch updateState {
        case .idle:
            break
        case .checking:
            menu.addItem(disabledItem(title: "正在检查更新..."))
        case .current(let checkedAt):
            menu.addItem(disabledItem(title: "已是最新版 · \(relativeTime(checkedAt))"))
        case .available(let info):
            let item = NSMenuItem(title: "发现新版本 \(info.tagName)", action: #selector(openLatestRelease), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        case .failed(let message):
            menu.addItem(disabledItem(title: "检查更新失败: \(message)"))
        }

        let checkItem = NSMenuItem(title: "检查更新", action: #selector(checkUpdatesFromMenu), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)
    }

    private func scheduleAutomaticUpdateCheck() {
        let now = Date().timeIntervalSince1970
        guard now - preferences.lastUpdateCheckAt > 86_400 else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkForUpdates()
        }
    }

    private func checkForUpdates() {
        updateState = .checking
        rebuildMenu()

        updateChecker.check(currentVersion: currentVersion) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.preferences.lastUpdateCheckAt = Date().timeIntervalSince1970
                switch result {
                case .success(let state):
                    self.updateState = state
                case .failure(let error):
                    self.updateState = .failed(error.localizedDescription)
                }
                self.rebuildMenu()
            }
        }
    }

    private func latestReleaseURL() -> URL? {
        if case .available(let info) = updateState {
            return info.releaseURL
        }
        return URL(string: "https://github.com/chinnkenni/codex_taskbar_mac/releases/latest")
    }

    private func title(for snapshot: RateLimitSnapshot) -> String {
        let primary = titlePart(for: snapshot.primary)

        switch preferences.titleMode {
        case .compact:
            return primary
        case .detailed:
            return "\(primary) | \(titlePart(for: snapshot.secondary, includeReset: preferences.showSecondaryResetInTitle))"
        }
    }

    private func titlePart(for window: RateLimitWindow, includeReset: Bool? = nil) -> String {
        let shouldIncludeReset = includeReset ?? preferences.showPrimaryResetInTitle
        var text = "\(window.shortName) \(window.remainingPercent)%"
        if shouldIncludeReset {
            text += " \(resetLabel(for: window))"
        }
        return text
    }

    private func tooltip(for snapshot: RateLimitSnapshot) -> String {
        "\(snapshot.primary.displayName) 剩余 \(snapshot.primary.remainingPercent)%, \(snapshot.secondary.displayName) 剩余 \(snapshot.secondary.remainingPercent)%"
    }

    private func resetLabel(for window: RateLimitWindow) -> String {
        let date = Date(timeIntervalSince1970: window.resetAt)
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if window.windowMinutes == 300 || calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "M月d日"
        }

        return formatter.string(from: date)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 {
            return "\(seconds) 秒前"
        }
        if seconds < 3_600 {
            return "\(seconds / 60) 分钟前"
        }
        return "\(seconds / 3_600) 小时前"
    }

    private func statusText() -> String {
        if let snapshot = latestSnapshot {
            return [
                title(for: snapshot),
                "\(snapshot.primary.displayName): 剩余 \(snapshot.primary.remainingPercent)%, 已用 \(snapshot.primary.usedPercent)%, 重置 \(resetLabel(for: snapshot.primary))",
                "\(snapshot.secondary.displayName): 剩余 \(snapshot.secondary.remainingPercent)%, 已用 \(snapshot.secondary.usedPercent)%, 重置 \(resetLabel(for: snapshot.secondary))"
            ].joined(separator: "\n")
        }

        return latestError?.localizedDescription ?? "Codex --"
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func copyStatus() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(statusText(), forType: .string)
    }

    @objc private func setCompactTitle() {
        preferences.titleMode = .compact
        refresh()
    }

    @objc private func setDetailedTitle() {
        preferences.titleMode = .detailed
        refresh()
    }

    @objc private func togglePrimaryReset() {
        preferences.showPrimaryResetInTitle.toggle()
        refresh()
    }

    @objc private func toggleSecondaryReset() {
        preferences.showSecondaryResetInTitle.toggle()
        refresh()
    }

    @objc private func setRefreshInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else {
            return
        }
        preferences.refreshInterval = interval
        scheduleTimer()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
        } catch {
            latestError = error
        }
        refresh()
    }

    @objc private func checkUpdatesFromMenu() {
        checkForUpdates()
    }

    @objc private func openLatestRelease() {
        guard let url = latestReleaseURL() else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

final class LoginItemController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

let app = NSApplication.shared
let delegate = CodexTaskbarApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
