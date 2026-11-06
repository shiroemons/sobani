import Foundation
import os.log

// MARK: - JSON Persistence

enum JSONPersistence {
    /// 値を JSON にエンコードしてアトミックに書き込む。
    ///
    /// - Returns: 書き込みに成功したか。
    @discardableResult
    static func save<T: Encodable>(
        _ value: T,
        to url: URL,
        logger: Logger,
        errorMessage: String = "Failed to save data",
        configure: ((JSONEncoder) -> Void)? = nil
    ) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        configure?(encoder)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            logger.error("\(errorMessage): \(error.localizedDescription)")
            return false
        }
    }

    /// JSON ファイルを読み込んでデコードする。
    ///
    /// - Parameter backupOnDecodeFailure: true の場合、ファイルは読めたがデコードできなかったときに
    ///   `backupUnreadableFile(at:logger:)` で退避してから nil を返す（直後の保存で上書きされても元データを残すため）。
    static func load<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        logger: Logger,
        notFoundMessage: String? = nil,
        errorMessage: String = "Failed to decode data",
        backupOnDecodeFailure: Bool = false,
        configure: ((JSONDecoder) -> Void)? = nil
    ) -> T? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            if let msg = notFoundMessage {
                logger.debug("\(msg): \(error.localizedDescription)")
            }
            return nil
        }
        let decoder = JSONDecoder()
        configure?(decoder)
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error("\(errorMessage): \(error.localizedDescription)")
            if backupOnDecodeFailure {
                backupUnreadableFile(at: url, logger: logger)
            }
            return nil
        }
    }

    // MARK: - Corrupt File Backup

    /// 読み込めなかったファイルを同じディレクトリに `<basename>.corrupt-<yyyyMMdd-HHmmss>.<ext>` としてコピーする。
    ///
    /// - Returns: バックアップ先の URL。コピーに失敗した場合は nil。
    @discardableResult
    static func backupUnreadableFile(at url: URL, logger: Logger, date: Date = Date()) -> URL? {
        let backupURL = corruptBackupURL(for: url, date: date)
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            logger.notice("Backed up unreadable file to \(backupURL.path, privacy: .public)")
            return backupURL
        } catch {
            logger.error("Failed to back up unreadable file \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// `backupUnreadableFile` が使うバックアップ先 URL（例: `window_states.corrupt-20260101-120000.json`）。
    static func corruptBackupURL(for url: URL, date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let fileName = "\(baseName).corrupt-\(formatter.string(from: date))" + (ext.isEmpty ? "" : ".\(ext)")
        return url.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}

// MARK: - Lossy Array

/// 配列を要素ごとにデコードし、デコードできない要素だけを読み飛ばすラッパー。
///
/// 1 要素の破損で配列全体（＝全ウィンドウの状態）を失わないために使う。
struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]
    /// 読み飛ばした要素の数
    let skippedCount: Int

    /// 要素のデコード失敗を nil として受け止めるラッパー（それ自体のデコードは常に成功する）
    private struct FailableElement: Decodable {
        let value: Element?

        init(from decoder: Decoder) throws {
            value = try? Element(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let wrapped = try [FailableElement](from: decoder)
        elements = wrapped.compactMap(\.value)
        skippedCount = wrapped.count - elements.count
    }
}
