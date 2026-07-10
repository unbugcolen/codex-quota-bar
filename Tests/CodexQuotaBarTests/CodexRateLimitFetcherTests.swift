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
}
