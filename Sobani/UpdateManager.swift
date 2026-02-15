import Cocoa

// MARK: - GitHub API Models

struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [GitHubAsset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

// MARK: - Update State

enum UpdateState {
    case idle
    case checking
    case available(version: String, downloadURL: URL)
    case downloading
    case upToDate
    case error(String)
}

// MARK: - Update Manager Delegate

protocol UpdateManagerDelegate: AnyObject {
    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState)
}

// MARK: - Update Manager

class UpdateManager {
    static let shared = UpdateManager()

    weak var delegate: UpdateManagerDelegate?

    private(set) var state: UpdateState = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.updateManager(self, didChangeState: self.state)
            }
        }
    }

    private let session: URLSession
    private let currentVersion: String
    private let apiURL: URL
    private var checkTimer: Timer?

    private static let lastCheckKey = "LastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    init(
        session: URLSession = .shared,
        currentVersion: String? = nil,
        apiURL: URL? = nil
    ) {
        self.session = session
        self.currentVersion = currentVersion
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"
        self.apiURL = apiURL
            ?? URL(string: "https://api.github.com/repos/shiroemons/sobani/releases/latest")!
    }

    // MARK: - Periodic Checks

    func startPeriodicChecks() {
        // 起動時に常にアップデートを確認
        checkForUpdate(manual: false)

        // 定期チェック（24時間ごと）
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.checkForUpdate(manual: false)
        }
        checkTimer?.tolerance = 600 // 10分の許容で省電力

        // スリープ復帰時にチェック
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    @objc private func handleWake() {
        let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(lastCheck) >= Self.checkInterval {
            checkForUpdate(manual: false)
        }
    }

    // MARK: - Check for Update

    func checkForUpdate(manual: Bool) {
        if case .downloading = state { return }

        state = .checking

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Sobani/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let task = session.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    if manual {
                        self.state = .error(error.localizedDescription)
                    } else {
                        self.state = .idle
                    }
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    if manual {
                        self.state = .error("データを取得できませんでした")
                    } else {
                        self.state = .idle
                    }
                }
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName.hasPrefix("v")
                    ? String(release.tagName.dropFirst())
                    : release.tagName

                DispatchQueue.main.async {
                    UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

                    if Self.isNewer(latestVersion, than: self.currentVersion),
                       let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
                       let downloadURL = URL(string: asset.browserDownloadURL) {
                        self.state = .available(version: latestVersion, downloadURL: downloadURL)
                    } else {
                        if manual {
                            self.state = .upToDate
                        } else {
                            self.state = .idle
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if manual {
                        self.state = .error("レスポンスの解析に失敗しました")
                    } else {
                        self.state = .idle
                    }
                }
            }
        }
        task.resume()
    }

    // MARK: - Version Comparison

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        guard candidateParts.count == 2, currentParts.count == 2 else {
            return false
        }

        if candidateParts[0] != currentParts[0] {
            return candidateParts[0] > currentParts[0]
        }
        return candidateParts[1] > currentParts[1]
    }

    // MARK: - Download and Install

    func downloadAndInstall(url: URL) {
        state = .downloading

        let downloadTask = session.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.state = .error("ダウンロードに失敗しました: \(error.localizedDescription)")
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.state = .error("ダウンロードファイルが見つかりません")
                }
                return
            }

            self.installUpdate(from: tempURL)
        }
        downloadTask.resume()
    }

    private func installUpdate(from zipURL: URL) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SobaniUpdate-\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Extract ZIP using ditto
            let extractProcess = Process()
            extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            extractProcess.arguments = ["-xk", zipURL.path, tempDir.path]
            try extractProcess.run()
            extractProcess.waitUntilExit()

            guard extractProcess.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    self.state = .error("ZIPの展開に失敗しました")
                }
                return
            }

            // Find the .app in extracted contents
            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                DispatchQueue.main.async {
                    self.state = .error("アプリが見つかりません")
                }
                return
            }

            // Current app location
            guard let currentAppURL = Bundle.main.bundleURL as URL? else {
                DispatchQueue.main.async {
                    self.state = .error("現在のアプリの場所を取得できません")
                }
                return
            }

            let parentDir = currentAppURL.deletingLastPathComponent()
            let backupURL = parentDir.appendingPathComponent("Sobani_backup.app")

            // Remove old backup if exists
            try? fm.removeItem(at: backupURL)

            // Backup current app
            try fm.moveItem(at: currentAppURL, to: backupURL)

            do {
                // Move new app to current location
                try fm.moveItem(at: newAppURL, to: currentAppURL)

                // Remove backup on success
                try? fm.removeItem(at: backupURL)

                // Clean up temp directory
                try? fm.removeItem(at: tempDir)

                // Restart
                DispatchQueue.main.async {
                    self.restartApp(at: currentAppURL.path)
                }
            } catch {
                // Restore from backup
                try? fm.removeItem(at: currentAppURL)
                try? fm.moveItem(at: backupURL, to: currentAppURL)
                try? fm.removeItem(at: tempDir)

                DispatchQueue.main.async {
                    self.state = .error("アプリの更新に失敗しました: \(error.localizedDescription)")
                }
            }
        } catch {
            try? fm.removeItem(at: tempDir)
            DispatchQueue.main.async {
                self.state = .error("更新の準備に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func restartApp(at appPath: String) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done
            open "\(appPath)"
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()

        // Terminate current app
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.shouldTerminate = true
        }
        NSApp.terminate(nil)
    }
}

// MARK: - AppDelegate Update Extension

extension AppDelegate: UpdateManagerDelegate {
    @objc func checkForUpdateManually() {
        UpdateManager.shared.checkForUpdate(manual: true)
    }

    @objc func performUpdate() {
        guard case .available(let version, let url) = UpdateManager.shared.state else { return }

        let alert = NSAlert()
        alert.messageText = "Sobani を v\(version) に更新しますか？"
        alert.informativeText = "アプリが再起動されます。"
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            UpdateManager.shared.downloadAndInstall(url: url)
        }
    }

    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState) {
        switch state {
        case .upToDate:
            let alert = NSAlert()
            alert.messageText = "最新バージョンです"
            alert.informativeText = "Sobani は最新の状態です。"
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational
            alert.runModal()
        case .error(let message):
            let alert = NSAlert()
            alert.messageText = "更新の確認に失敗しました"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        default:
            break
        }
    }
}
