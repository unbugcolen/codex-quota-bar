import AppKit
import Foundation

struct CodexExecutableLocator {
    static let bundleIdentifier = "com.openai.codex"
    static let relativeExecutablePaths = [
        "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "Contents/Resources/codex-cli/bin/codex",
        "Contents/Resources/codex"
    ]
    static let fallbackPaths = ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        .flatMap { applicationPath in
            relativeExecutablePaths.map { applicationPath + "/" + $0 }
        }

    private let applicationURL: (String) -> URL?
    private let isExecutable: (String) -> Bool

    init(
        applicationURL: @escaping (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        isExecutable: @escaping (String) -> Bool = {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    ) {
        self.applicationURL = applicationURL
        self.isExecutable = isExecutable
    }

    func resolve() throws -> String {
        var candidatePaths: [String] = []

        if let applicationURL = applicationURL(Self.bundleIdentifier) {
            candidatePaths.append(contentsOf: Self.relativeExecutablePaths.map {
                applicationURL.appendingPathComponent($0).path
            })
        }

        candidatePaths.append(contentsOf: Self.fallbackPaths)

        var seenPaths = Set<String>()
        let checkedPaths = candidatePaths.filter { seenPaths.insert($0).inserted }

        if let executablePath = checkedPaths.first(where: isExecutable) {
            return executablePath
        }

        throw CodexExecutableLocatorError.notFound(checkedPaths: checkedPaths)
    }
}

enum CodexExecutableLocatorError: LocalizedError, Equatable {
    case notFound(checkedPaths: [String])

    var errorDescription: String? {
        switch self {
        case let .notFound(checkedPaths):
            return "找不到 ChatGPT/Codex 内置的 codex 可执行文件。已检查：\(checkedPaths.joined(separator: "、"))"
        }
    }
}
