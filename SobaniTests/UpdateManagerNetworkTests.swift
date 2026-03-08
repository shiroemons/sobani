import Foundation
import Testing
@testable import Sobani

/// checkForUpdateのネットワーク関連テストを検証するテスト
@Suite(.serialized) struct UpdateManagerNetworkTests {

    init() {
        MockURLProtocol.requestHandler = nil
    }

    /// メインRunLoopを回しながら条件が満たされるまで待機するヘルパー
    private func waitForState(
        of manager: UpdateManager,
        timeout: TimeInterval = 3.0,
        predicate: (UpdateState) -> Bool
    ) {
        // 前テストの pending DispatchQueue.main.async コールバックをフラッシュ
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            if predicate(manager.state) { return }
        }
        Issue.record("waitForState timed out after \(timeout)s. Current state: \(manager.state)")
    }

    /// ネットワークエラー時にerror stateが設定されることを検証
    @Test func checkForUpdate_NetworkError_SetsErrorState() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        manager.checkForUpdate(trigger: .manual)

        waitForState(of: manager) { state in
            if case .error = state { return true }
            return false
        }

        if case .error(let code, _) = manager.state {
            #expect(code == .networkError)
        } else if case .idle = manager.state {
            // Non-manual trigger sets idle on error - acceptable
        } else {
            Issue.record("Expected .error or .idle state, got \(manager.state)")
        }
    }

    /// 空データ時にparseError stateが設定されることを検証
    /// 注: URLProtocolはnilではなく空Dataを返すため、guard letを通過しパースエラーになる
    @Test func checkForUpdate_EmptyData_SetsParseError() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, nil)
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        manager.checkForUpdate(trigger: .manual)

        waitForState(of: manager) { state in
            if case .error = state { return true }
            return false
        }

        if case .error(let code, _) = manager.state {
            #expect(code == .parseError)
        } else if case .idle = manager.state {
            // Acceptable for non-manual
        } else {
            Issue.record("Expected .error or .idle state, got \(manager.state)")
        }
    }

    /// 不正JSONデータ時にparseError stateが設定されることを検証
    @Test func checkForUpdate_InvalidJSON_SetsParseError() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, Data("not json".utf8))
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        manager.checkForUpdate(trigger: .manual)

        waitForState(of: manager) { state in
            if case .error = state { return true }
            return false
        }

        if case .error(let code, _) = manager.state {
            #expect(code == .parseError)
        } else if case .idle = manager.state {
            // Acceptable
        } else {
            Issue.record("Expected .error or .idle state, got \(manager.state)")
        }
    }

    /// 新しいバージョンが検出された場合にavailable stateが設定されることを検証
    @Test func checkForUpdate_NewerVersion_SetsAvailable() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let responseJSON = """
        {
            "tag_name": "v202699.0",
            "assets": [
                {"name": "Sobani-universal.dmg", "browser_download_url": "https://example.com/Sobani.dmg"},
                {"name": "checksums.txt", "browser_download_url": "https://example.com/checksums.txt"}
            ]
        }
        """
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, Data(responseJSON.utf8))
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        manager.checkForUpdate(trigger: .manual)

        waitForState(of: manager) { state in
            if case .available = state { return true }
            return false
        }

        if case .available(let version, _, _, let format) = manager.state {
            #expect(version == "202699.0")
            #expect(format == .dmg)
        } else {
            Issue.record("Expected .available state, got \(manager.state)")
        }
    }

    /// 同じバージョンの場合にupToDate stateが設定されることを検証
    @Test func checkForUpdate_SameVersion_SetsUpToDate() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let responseJSON = """
        {
            "tag_name": "v202602.4",
            "assets": [
                {"name": "Sobani-universal.dmg", "browser_download_url": "https://example.com/Sobani.dmg"}
            ]
        }
        """
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, Data(responseJSON.utf8))
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        manager.checkForUpdate(trigger: .manual)

        waitForState(of: manager) { state in
            if case .upToDate = state { return true }
            return false
        }

        if case .upToDate = manager.state {
            // OK
        } else {
            Issue.record("Expected .upToDate state, got \(manager.state)")
        }
    }

    /// ダウンロード中にcheckForUpdateを呼んでも無視されることを検証
    @Test func checkForUpdate_WhileDownloading_Ignores() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, Data("{}".utf8))
        }

        let manager = UpdateManager(currentVersion: "202602.4", session: mockSession)
        // Force downloading state via setStateForTrigger workaround
        manager.setStateForTrigger(.manual, manualState: .downloading)

        manager.checkForUpdate(trigger: .manual)

        // State should still be downloading (check was ignored)
        if case .downloading = manager.state {
            // OK - check was correctly ignored
        } else {
            Issue.record("Expected .downloading state to be preserved, got \(manager.state)")
        }
    }

}

// MARK: - MockURLProtocol

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse?, Data?))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            if let response = response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
