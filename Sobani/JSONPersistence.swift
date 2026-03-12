import Foundation
import os.log

// MARK: - JSON Persistence

enum JSONPersistence {
    static func save<T: Encodable>(
        _ value: T,
        to url: URL,
        logger: Logger,
        errorMessage: String = "Failed to save data",
        configure: ((JSONEncoder) -> Void)? = nil
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        configure?(encoder)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("\(errorMessage): \(error.localizedDescription)")
        }
    }

    static func load<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        logger: Logger,
        notFoundMessage: String? = nil,
        errorMessage: String = "Failed to decode data",
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
            return nil
        }
    }
}
