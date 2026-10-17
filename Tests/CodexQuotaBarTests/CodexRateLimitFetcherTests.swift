import XCTest
@testable import CodexQuotaBar

final class CodexRateLimitFetcherTests: XCTestCase {
    func testFetchReportsLocatorFailureWithoutStartingOperation() {
        let completionCalled = expectation(description: "Fetch completion called")
        let expected = CodexExecutableLocatorError.notFound(
            checkedPaths: ["/missing/codex"]
        )
        let fetcher = CodexRateLimitFetcher(resolveExecutable: {
            throw expected
        })

        fetcher.fetch { result in
            switch result {
            case .success:
                XCTFail("Expected locator failure")
            case .failure(let error):
                XCTAssertEqual(error as? CodexExecutableLocatorError, expected)
            }
            completionCalled.fulfill()
        }

        wait(for: [completionCalled], timeout: 1)
    }

    func testFetchCompletesHandshakeBeforeReadingLimits() throws {
        let executable = try makeExecutable(script: #"""
        #!/bin/sh
        IFS= read -r initialize
        printf '%s\n' '{"id":1,"result":{}}'
        IFS= read -r initialized
        case "$initialized" in
            *'"method":"initialized"'*) ;;
            *) printf '%s\n' '{"id":2,"error":{"code":-1,"message":"Missing initialized notification"}}'; exit 1 ;;
        esac
        IFS= read -r request
        case "$request" in
            *'"method":"account/rateLimits/read"'*) ;;
            *) printf '%s\n' '{"id":2,"error":{"code":-1,"message":"Missing rate limit request"}}'; exit 1 ;;
        esac
        printf '%s\n' '{"method":"account/updated","params":{}}'
        printf '%s\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":11,"windowDurationMins":10080,"resetsAt":1792475808},"secondary":null}}}'
        while IFS= read -r unused; do :; done
        """#)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let completed = expectation(description: "Quota read after handshake")
        let fetcher = CodexRateLimitFetcher(resolveExecutable: { executable.path })

        fetcher.fetch { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success(let snapshot):
                XCTAssertNil(snapshot.fiveHour.remainingPercent)
                XCTAssertEqual(snapshot.weekly.remainingPercent, 89)
            case .failure(let error):
                XCTFail("Expected quota snapshot, got \(error)")
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
    }

    func testFetchReportsInitializeRPCFailure() throws {
        let executable = try makeExecutable(script: #"""
        #!/bin/sh
        IFS= read -r initialize
        printf '%s\n' '{"id":1,"error":{"code":-32600,"message":"Initialize rejected"}}'
        while IFS= read -r unused; do :; done
        """#)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let completed = expectation(description: "Initialize failure reported")
        let fetcher = CodexRateLimitFetcher(resolveExecutable: { executable.path })

        fetcher.fetch { result in
            switch result {
            case .success:
                XCTFail("Expected initialize failure")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("Initialize rejected"))
            }
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
    }

    private func makeExecutable(script: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexQuotaBarTests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("codex")
        try (script + "\n").write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return executable
    }
}
