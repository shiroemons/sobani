import Cocoa
import CryptoKit

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
    case available(version: String, downloadURL: URL, checksumURL: URL?)
    case downloading
    case upToDate
    case error(String)
}

// MARK: - Check Trigger

enum CheckTrigger: Equatable {
    case manual    // メニューバーからの手動チェック → 全結果でダイアログ
    case startup   // 起動時チェック → 更新ありのみダイアログ
    case automatic // 周期/スリープ復帰 → ダイアログなし
}

// MARK: - Update Manager Delegate

protocol UpdateManagerDelegate: AnyObject {
    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState)
}

// MARK: - Update Manager

class UpdateManager {
    static let shared = UpdateManager()

    weak var delegate: UpdateManagerDelegate?

    private(set) var lastCheckTrigger: CheckTrigger = .automatic

    private(set) var state: UpdateState = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.updateManager(self, didChangeState: self.state)
            }
        }
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // TLS 1.3 を最低バージョンとして強制
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        return URLSession(configuration: config)
    }()

    private let currentVersion: String
    private let apiURL: URL
    private var checkTimer: Timer?

    private static let lastCheckKey = "LastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    init(
        currentVersion: String? = nil,
        apiURL: URL? = nil
    ) {
        self.currentVersion = currentVersion
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"
        self.apiURL = apiURL
            ?? URL(string: "https://api.github.com/repos/shiroemons/sobani/releases/latest")!
    }

    // MARK: - Periodic Checks

    func startPeriodicChecks() {
        // 起動時に常にアップデートを確認
        checkForUpdate(trigger: .startup)

        // 定期チェック（24時間ごと）
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.checkForUpdate(trigger: .automatic)
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
            checkForUpdate(trigger: .automatic)
        }
    }

    // MARK: - Check for Update

    func checkForUpdate(trigger: CheckTrigger) {
        if case .downloading = state { return }
        lastCheckTrigger = trigger

        state = .checking

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Sobani/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let task = session.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                // 内部エラー詳細はログのみ、ユーザーには汎用メッセージを表示
                NSLog("[UpdateManager] Check error: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    if trigger == .manual {
                        self.state = .error("更新の確認に失敗しました。ネットワーク接続を確認してください。")
                    } else {
                        self.state = .idle
                    }
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    if trigger == .manual {
                        self.state = .error("更新情報を取得できませんでした。しばらく後に再試行してください。")
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
                        // チェックサムファイルの URL を探す
                        let checksumAsset = release.assets.first(where: { $0.name == "checksums.txt" })
                        let checksumURL = checksumAsset.flatMap { URL(string: $0.browserDownloadURL) }
                        self.state = .available(version: latestVersion, downloadURL: downloadURL, checksumURL: checksumURL)
                    } else {
                        if trigger == .manual {
                            self.state = .upToDate
                        } else {
                            self.state = .idle
                        }
                    }
                }
            } catch {
                // パース失敗の詳細はログのみ
                NSLog("[UpdateManager] Parse error: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    if trigger == .manual {
                        self.state = .error("更新情報の解析に失敗しました。しばらく後に再試行してください。")
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

        guard candidateParts.count >= 2, currentParts.count >= 2 else {
            return false
        }

        if candidateParts[0] != currentParts[0] {
            return candidateParts[0] > currentParts[0]
        }
        return candidateParts[1] > currentParts[1]
    }

    // MARK: - Download and Install

    func downloadAndInstall(url: URL, checksumURL: URL?) {
        state = .downloading

        // チェックサムファイルを先に取得してから ZIP をダウンロード
        if let checksumURL = checksumURL {
            fetchChecksum(from: checksumURL) { [weak self] expectedChecksum in
                guard let self = self else { return }
                self.downloadZip(from: url, expectedChecksum: expectedChecksum)
            }
        } else {
            // チェックサムなし: 警告ダイアログを表示してユーザーに確認
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let alert = NSAlert()
                alert.messageText = "チェックサムファイルが見つかりません"
                alert.informativeText = "ダウンロードファイルの整合性を検証できません。続行しますか？"
                alert.addButton(withTitle: "続行")
                alert.addButton(withTitle: "キャンセル")
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    self.downloadZip(from: url, expectedChecksum: nil)
                } else {
                    self.state = .idle
                }
            }
        }
    }

    // チェックサムファイルを取得
    private func fetchChecksum(from url: URL, completion: @escaping (String?) -> Void) {
        let task = session.dataTask(with: url) { data, _, error in
            if let error = error {
                NSLog("[UpdateManager] Checksum fetch error: %@", error.localizedDescription)
                completion(nil)
                return
            }
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            // 形式: "<sha256hex>  Sobani-YYYYMM.N-universal.zip"
            let checksum = text.components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    guard parts.count >= 1 else { return nil }
                    return String(parts[0])
                }
                .first
            completion(checksum)
        }
        task.resume()
    }

    // ZIP をダウンロードしてインストール
    private func downloadZip(from url: URL, expectedChecksum: String?) {
        let downloadTask = session.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                // 内部エラーはログのみ
                NSLog("[UpdateManager] Download error: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    self.state = .error("ダウンロードに失敗しました。ネットワーク接続を確認してください。")
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.state = .error("ダウンロードファイルが見つかりません。")
                }
                return
            }

            // チェックサム検証
            if let expected = expectedChecksum {
                guard Self.verifySHA256(of: tempURL, expectedHex: expected) else {
                    NSLog("[UpdateManager] Checksum mismatch for downloaded file")
                    DispatchQueue.main.async {
                        self.state = .error("ダウンロードファイルの整合性検証に失敗しました。再試行してください。")
                    }
                    return
                }
                NSLog("[UpdateManager] Checksum verified OK")
            }

            self.installUpdate(from: tempURL)
        }
        downloadTask.resume()
    }

    // MARK: - Checksum Verification

    static func verifySHA256(of fileURL: URL, expectedHex: String) -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let digest = SHA256.hash(data: data)
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        return hexString == expectedHex.lowercased()
    }

    // MARK: - Install Update

    private func installUpdate(from zipURL: URL) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SobaniUpdate-\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // defer で確実にクリーンアップ
            defer {
                try? fm.removeItem(at: tempDir)
            }

            // Extract ZIP using ditto
            let extractProcess = Process()
            extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            extractProcess.arguments = ["-xk", zipURL.path, tempDir.path]
            try extractProcess.run()
            extractProcess.waitUntilExit()

            guard extractProcess.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    self.state = .error("ZIPの展開に失敗しました。")
                }
                return
            }

            // Find the .app in extracted contents
            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                DispatchQueue.main.async {
                    self.state = .error("アップデートのアプリが見つかりません。")
                }
                return
            }

            // Current app location
            guard let currentAppURL = Bundle.main.bundleURL as URL? else {
                DispatchQueue.main.async {
                    self.state = .error("現在のアプリの場所を取得できません。")
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

                // Restart
                DispatchQueue.main.async {
                    self.restartApp(at: currentAppURL)
                }
            } catch {
                // Restore from backup
                NSLog("[UpdateManager] Install error: %@", error.localizedDescription)
                try? fm.removeItem(at: currentAppURL)
                try? fm.moveItem(at: backupURL, to: currentAppURL)

                DispatchQueue.main.async {
                    self.state = .error("アプリの更新に失敗しました。再試行してください。")
                }
            }
        } catch {
            NSLog("[UpdateManager] Install preparation error: %@", error.localizedDescription)
            DispatchQueue.main.async {
                self.state = .error("更新の準備に失敗しました。再試行してください。")
            }
        }
    }

    // MARK: - Restart App

    // NSWorkspace で安全に再起動（/bin/sh を使わない）
    private func restartApp(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier

        DispatchQueue.global(qos: .utility).async {
            // 現在のプロセスが終了するまで待機（シェルを使わない）
            while kill(pid, 0) == 0 {
                Thread.sleep(forTimeInterval: 0.1)
            }
            DispatchQueue.main.async {
                NSWorkspace.shared.open(appURL)
            }
        }

        // 現在のアプリを終了
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.shouldTerminate = true
        }
        NSApp.terminate(nil)
    }
}

// MARK: - AppDelegate Update Extension

extension AppDelegate: UpdateManagerDelegate {
    @objc func checkForUpdateManually() {
        UpdateManager.shared.checkForUpdate(trigger: .manual)
    }

    @objc func performUpdate() {
        guard case .available(let version, let url, let checksumURL) = UpdateManager.shared.state else { return }

        let alert = NSAlert()
        alert.messageText = "Sobani を v\(version) に更新しますか？"
        alert.informativeText = "アプリが再起動されます。"
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            UpdateManager.shared.downloadAndInstall(url: url, checksumURL: checksumURL)
        }
    }

    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState) {
        switch state {
        case .available(let version, let url, let checksumURL):
            if manager.lastCheckTrigger != .automatic {
                let alert = NSAlert()
                alert.messageText = "新しいバージョンがあります"
                alert.informativeText = "Sobani v\(version) が利用可能です。"
                alert.addButton(withTitle: "更新")
                alert.addButton(withTitle: "後で")
                alert.alertStyle = .informational
                if alert.runModal() == .alertFirstButtonReturn {
                    UpdateManager.shared.downloadAndInstall(url: url, checksumURL: checksumURL)
                }
            }
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
