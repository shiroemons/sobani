import Cocoa
import CryptoKit
import os.log

// MARK: - GitHub API Models

struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let assets: [GitHubAsset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

struct GitHubAsset: Decodable, Sendable {
    let name: String
    let browserDownloadURL: String
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

// MARK: - Update State

enum UpdateState: Sendable {
    case idle
    case checking
    case available(version: String, downloadURL: URL, checksumURL: URL?, format: UpdateAssetFormat)
    case downloading
    case upToDate
    case error(code: UpdateErrorCode, message: String)
}

// MARK: - Check Trigger

enum CheckTrigger: Equatable, Sendable {
    case manual    // メニューバーからの手動チェック → 全結果でダイアログ
    case startup   // 起動時チェック → 更新ありのみダイアログ
    case automatic // 周期/スリープ復帰 → ダイアログなし
}

// MARK: - Update Asset Format

enum UpdateAssetFormat: Sendable {
    case dmg
    case zip
}

// MARK: - Update Error Code

enum UpdateErrorCode: String, CaseIterable, Sendable {
    // Check phase
    case networkError       = "U-101"
    case fetchError         = "U-102"
    case parseError         = "U-103"
    // Download phase
    case downloadError      = "U-201"
    case fileNotFound       = "U-202"
    case checksumFailed     = "U-203"
    // Install phase - ZIP
    case zipExtractFailed   = "U-301"
    case zipAppNotFound     = "U-302"
    case zipPrepareFailed   = "U-303"
    // Install phase - DMG
    case dmgMountFailed     = "U-401"
    case dmgAppNotFound     = "U-402"
    case dmgPrepareFailed   = "U-403"
    // Replace & Restart phase
    case locationError      = "U-501"
    case backupFailed       = "U-502"
    case installFailed      = "U-503"

    var troubleshootingKey: String {
        switch self {
        case .networkError:     return "update.hint.U-101"
        case .fetchError:       return "update.hint.U-102"
        case .parseError:       return "update.hint.U-103"
        case .downloadError:    return "update.hint.U-201"
        case .fileNotFound:     return "update.hint.U-202"
        case .checksumFailed:   return "update.hint.U-203"
        case .zipExtractFailed: return "update.hint.U-301"
        case .zipAppNotFound:   return "update.hint.U-302"
        case .zipPrepareFailed: return "update.hint.U-303"
        case .dmgMountFailed:   return "update.hint.U-401"
        case .dmgAppNotFound:   return "update.hint.U-402"
        case .dmgPrepareFailed: return "update.hint.U-403"
        case .locationError:    return "update.hint.U-501"
        case .backupFailed:     return "update.hint.U-502"
        case .installFailed:    return "update.hint.U-503"
        }
    }
}

// MARK: - Update Manager Delegate

@MainActor
protocol UpdateManagerDelegate: AnyObject {
    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState)
}

// MARK: - Update Manager

final class UpdateManager: @unchecked Sendable {
    static let shared = UpdateManager()
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "UpdateManager")

    weak var delegate: UpdateManagerDelegate?

    private(set) var lastCheckTrigger: CheckTrigger = .automatic

    private(set) var state: UpdateState = .idle {
        didSet {
            DispatchQueue.main.async { @Sendable [weak self] in
                guard let self = self else { return }
                self.delegate?.updateManager(self, didChangeState: self.state)
            }
        }
    }

    private let session: URLSession

    private let currentVersion: String
    private let apiURL: URL
    private var checkTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let defaults: UserDefaults

    private static let lastCheckKey = "LastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private static let requestTimeoutInterval: TimeInterval = 15
    // swiftlint:disable:next force_unwrapping
    private static let defaultAPIURL = URL(string: "https://api.github.com/repos/shiroemons/sobani/releases/latest")!

    init(
        currentVersion: String? = nil,
        apiURL: URL? = nil,
        session: URLSession? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.currentVersion = currentVersion
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"
        self.apiURL = apiURL
            ?? Self.defaultAPIURL
        self.session = session ?? {
            let config = URLSessionConfiguration.default
            // TLS 1.3 を最低バージョンとして強制
            config.tlsMinimumSupportedProtocolVersion = .TLSv13
            return URLSession(configuration: config)
        }()
        self.defaults = defaults
    }

    deinit {
        checkTimer?.invalidate()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Periodic Checks

    func startPeriodicChecks() {
        // 起動時に常にアップデートを確認
        checkForUpdate(trigger: .startup)

        // 定期チェック（24時間ごと）
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkForUpdate(trigger: .automatic)
            }
        }
        checkTimer?.tolerance = 600 // 10分の許容で省電力

        // スリープ復帰時にチェック（queue: .main でメインスレッド配信を保証）
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleWake()
            }
        }
    }

    func handleWake() {
        let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(lastCheck) >= Self.checkInterval {
            checkForUpdate(trigger: .automatic)
        }
    }

    // MARK: - Asset Selection

    static func selectAsset(from release: GitHubRelease) -> (asset: GitHubAsset, format: UpdateAssetFormat)? {
        if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
            return (dmg, .dmg)
        } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
            return (zip, .zip)
        }
        return nil
    }

    // MARK: - Check for Update

    /// 手動トリガーのときだけ `manualState` を設定し、それ以外は `.idle` にする
    func setStateForTrigger(_ trigger: CheckTrigger, manualState: UpdateState) {
        state = trigger == .manual ? manualState : .idle
    }

    func checkForUpdate(trigger: CheckTrigger) {
        if case .downloading = state { return }
        lastCheckTrigger = trigger

        state = .checking

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Sobani/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.requestTimeoutInterval

        let task = session.dataTask(with: request) { @Sendable [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                // 内部エラー詳細はログのみ、ユーザーには汎用メッセージを表示
                logger.error("Check error: \(error.localizedDescription)")
                DispatchQueue.main.async { @Sendable in
                    self.setStateForTrigger(trigger, manualState: .error(code: .networkError, message: L("update.network_error")))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { @Sendable in
                    self.setStateForTrigger(trigger, manualState: .error(code: .fetchError, message: L("update.fetch_error")))
                }
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName.hasPrefix("v")
                    ? String(release.tagName.dropFirst())
                    : release.tagName

                DispatchQueue.main.async { @Sendable in
                    UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

                    if Self.isNewer(latestVersion, than: self.currentVersion),
                       let result = Self.selectAsset(from: release),
                       let downloadURL = URL(string: result.asset.browserDownloadURL) {
                        // チェックサムファイルの URL を探す
                        let checksumAsset = release.assets.first(where: { $0.name == "checksums.txt" })
                        let checksumURL = checksumAsset.flatMap { URL(string: $0.browserDownloadURL) }
                        self.state = .available(version: latestVersion, downloadURL: downloadURL, checksumURL: checksumURL, format: result.format)
                    } else {
                        self.setStateForTrigger(trigger, manualState: .upToDate)
                    }
                }
            } catch {
                // パース失敗の詳細はログのみ
                logger.error("Parse error: \(error.localizedDescription)")
                DispatchQueue.main.async { @Sendable in
                    self.setStateForTrigger(trigger, manualState: .error(code: .parseError, message: L("update.parse_error")))
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

    func downloadAndInstall(url: URL, checksumURL: URL?, format: UpdateAssetFormat) {
        state = .downloading

        // チェックサムファイルを先に取得してから ZIP をダウンロード
        if let checksumURL = checksumURL {
            let assetName = url.lastPathComponent
            fetchChecksum(from: checksumURL, assetName: assetName) { [weak self] expectedChecksum in
                guard let self = self else { return }
                self.downloadAsset(from: url, expectedChecksum: expectedChecksum, format: format)
            }
        } else {
            // チェックサムなし: 警告ダイアログを表示してユーザーに確認
            DispatchQueue.main.async { @Sendable [weak self] in
                guard let self = self else { return }
                let alert = NSAlert()
                alert.messageText = L("update.checksum_missing_title")
                alert.informativeText = L("update.checksum_missing_message")
                alert.addButton(withTitle: L("update.continue"))
                alert.addButton(withTitle: L("update.cancel"))
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    self.downloadAsset(from: url, expectedChecksum: nil, format: format)
                } else {
                    self.state = .idle
                }
            }
        }
    }

    // チェックサムファイルを取得
    private func fetchChecksum(from url: URL, assetName: String, completion: @Sendable @escaping (String?) -> Void) {
        let task = session.dataTask(with: url) { @Sendable [weak self] data, _, error in
            if let error = error {
                self?.logger.error("Checksum fetch error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(Self.parseChecksumLine(text, forAsset: assetName))
        }
        task.resume()
    }

    // アセットをダウンロードしてインストール
    private func downloadAsset(from url: URL, expectedChecksum: String?, format: UpdateAssetFormat) {
        let downloadTask = session.downloadTask(with: url) { @Sendable [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                // 内部エラーはログのみ
                logger.error("Download error: \(error.localizedDescription)")
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .downloadError, message: L("update.download_error"))
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .fileNotFound, message: L("update.file_not_found"))
                }
                return
            }

            // チェックサム検証
            if let expected = expectedChecksum {
                guard Self.verifySHA256(of: tempURL, expectedHex: expected) else {
                    logger.error("Checksum mismatch for downloaded file")
                    DispatchQueue.main.async { @Sendable in
                        self.state = .error(code: .checksumFailed, message: L("update.checksum_failed"))
                    }
                    return
                }
                logger.info("Checksum verified OK")
            }

            switch format {
            case .zip:
                self.installUpdateFromZip(tempURL)
            case .dmg:
                self.installUpdateFromDMG(tempURL)
            }
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

    /// チェックサムテキストから指定アセット名のチェックサムを解析して返す
    /// 形式: "<sha256hex>  <filename>" (複数行対応)
    static func parseChecksumLine(_ text: String, forAsset assetName: String) -> String? {
        guard !text.isEmpty else { return nil }
        let lines = text.components(separatedBy: .newlines)
        let matchedChecksum = lines
            .compactMap { line -> String? in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 2, String(parts[1]) == assetName else { return nil }
                return String(parts[0])
            }
            .first
        return matchedChecksum ?? lines
            .compactMap { line -> String? in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 1 else { return nil }
                return String(parts[0])
            }
            .first
    }

    // MARK: - Restart App

    // 独立した子プロセスで終了を待ってから再起動
    @MainActor private func restartApp(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appPath = appURL.path

        // terminate 前に子プロセスを起動（親終了後も launchd 配下で生存）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open \"\(appPath)\""
        ]
        do {
            try process.run()
        } catch {
            logger.error("Failed to launch restart process: \(error.localizedDescription)")
        }

        // 現在のアプリを終了
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.prepareShouldTerminate()
        }
        NSApp.terminate(nil)
    }
}

// MARK: - Install & Restart (private)

private extension UpdateManager {
    func installUpdateFromZip(_ zipURL: URL) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SobaniUpdate-\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

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
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .zipExtractFailed, message: L("update.zip_extract_failed"))
                }
                return
            }

            // Find the .app in extracted contents
            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .zipAppNotFound, message: L("update.app_not_found"))
                }
                return
            }

            replaceAndRestart(with: newAppURL)
        } catch {
            logger.error("Install preparation error: \(error.localizedDescription)")
            DispatchQueue.main.async { @Sendable in
                self.state = .error(code: .zipPrepareFailed, message: L("update.prepare_failed"))
            }
        }
    }

    func installUpdateFromDMG(_ dmgURL: URL) {
        let fm = FileManager.default
        let mountPoint = fm.temporaryDirectory.appendingPathComponent("SobaniMount-\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)

            // hdiutil attach でマウント
            let attachProcess = Process()
            attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            attachProcess.arguments = ["attach", dmgURL.path, "-mountpoint", mountPoint.path, "-nobrowse", "-readonly", "-noverify"]
            let attachPipe = Pipe()
            attachProcess.standardOutput = attachPipe
            attachProcess.standardError = Pipe()
            try attachProcess.run()
            attachProcess.waitUntilExit()

            guard attachProcess.terminationStatus == 0 else {
                try? fm.removeItem(at: mountPoint)
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .dmgMountFailed, message: L("update.dmg_mount_failed"))
                }
                return
            }

            // defer で確実にアンマウント＆クリーンアップ
            defer {
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", mountPoint.path, "-force"]
                try? detachProcess.run()
                detachProcess.waitUntilExit()
                try? fm.removeItem(at: mountPoint)
            }

            // マウントポイント内の .app を探す
            let contents = try fm.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
            guard let appInDMG = contents.first(where: { $0.pathExtension == "app" }) else {
                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .dmgAppNotFound, message: L("update.app_not_found"))
                }
                return
            }

            // .app を一時ディレクトリにコピー（マウント中は move 不可）
            let tempDir = fm.temporaryDirectory.appendingPathComponent("SobaniUpdate-\(UUID().uuidString)")
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let copiedAppURL = tempDir.appendingPathComponent(appInDMG.lastPathComponent)
            try fm.copyItem(at: appInDMG, to: copiedAppURL)

            replaceAndRestart(with: copiedAppURL)

            // コピー先のクリーンアップは replaceAndRestart 内で app が移動された後に行う
            try? fm.removeItem(at: tempDir)
        } catch {
            logger.error("DMG install error: \(error.localizedDescription)")
            DispatchQueue.main.async { @Sendable in
                self.state = .error(code: .dmgPrepareFailed, message: L("update.prepare_failed"))
            }
        }
    }

    func replaceAndRestart(with newAppURL: URL) {
        let fm = FileManager.default

        guard let currentAppURL = Bundle.main.bundleURL as URL? else {
            DispatchQueue.main.async { @Sendable in
                self.state = .error(code: .locationError, message: L("update.location_error"))
            }
            return
        }

        let parentDir = currentAppURL.deletingLastPathComponent()
        let backupURL = parentDir.appendingPathComponent("Sobani_backup.app")

        // Remove old backup if exists
        try? fm.removeItem(at: backupURL)

        do {
            // Backup current app
            try fm.moveItem(at: currentAppURL, to: backupURL)

            do {
                // Move new app to current location
                try fm.moveItem(at: newAppURL, to: currentAppURL)

                // Remove backup on success
                try? fm.removeItem(at: backupURL)

                // Restart
                DispatchQueue.main.async { @Sendable in
                    self.restartApp(at: currentAppURL)
                }
            } catch {
                // Restore from backup
                logger.error("Install error: \(error.localizedDescription)")
                try? fm.removeItem(at: currentAppURL)
                try? fm.moveItem(at: backupURL, to: currentAppURL)

                DispatchQueue.main.async { @Sendable in
                    self.state = .error(code: .installFailed, message: L("update.install_failed"))
                }
            }
        } catch {
            logger.error("Backup error: \(error.localizedDescription)")
            DispatchQueue.main.async { @Sendable in
                self.state = .error(code: .backupFailed, message: L("update.prepare_failed"))
            }
        }
    }
}

// MARK: - AppDelegate Update Extension

extension AppDelegate: UpdateManagerDelegate {
    @objc func checkForUpdateManually() {
        UpdateManager.shared.checkForUpdate(trigger: .manual)
    }

    @objc func performUpdate() {
        guard case .available(let version, let url, let checksumURL, let format) = UpdateManager.shared.state else { return }

        let alert = NSAlert()
        alert.messageText = String(format: L("update.confirm_title"), version)
        alert.informativeText = L("update.confirm_message")
        alert.addButton(withTitle: L("update.button"))
        alert.addButton(withTitle: L("update.cancel"))
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            UpdateManager.shared.downloadAndInstall(url: url, checksumURL: checksumURL, format: format)
        }
    }

    func updateManager(_ manager: UpdateManager, didChangeState state: UpdateState) {
        switch state {
        case .available(let version, let url, let checksumURL, let format):
            if manager.lastCheckTrigger != .automatic {
                let alert = NSAlert()
                alert.messageText = L("update.new_version_title")
                alert.informativeText = String(format: L("update.new_version_message"), version)
                alert.addButton(withTitle: L("update.button"))
                alert.addButton(withTitle: L("update.later"))
                alert.alertStyle = .informational
                if alert.runModal() == .alertFirstButtonReturn {
                    UpdateManager.shared.downloadAndInstall(url: url, checksumURL: checksumURL, format: format)
                }
            }
        case .upToDate:
            let alert = NSAlert()
            alert.messageText = L("update.up_to_date_title")
            alert.informativeText = L("update.up_to_date_message")
            alert.addButton(withTitle: L("update.ok"))
            alert.alertStyle = .informational
            alert.runModal()
        case .error(let code, let message):
            let alert = NSAlert()
            alert.messageText = L("update.check_failed_title")
            let hint = L(code.troubleshootingKey)
            alert.informativeText = "\(message)\n\n\(L("update.hint_label"))\(hint)\n\n\(String(format: L("update.error_code_label"), code.rawValue))"
            alert.addButton(withTitle: L("update.ok"))
            alert.alertStyle = .warning
            alert.runModal()
        default:
            break
        }
    }
}
