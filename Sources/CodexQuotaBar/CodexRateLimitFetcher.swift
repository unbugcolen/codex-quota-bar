import Foundation
import CFNetwork

final class CodexRateLimitFetcher {
    private let resolveExecutable: () throws -> String

    init(resolveExecutable: @escaping () throws -> String = CodexExecutableLocator().resolve) {
        self.resolveExecutable = resolveExecutable
    }

    func fetch(completion: @escaping (Result<QuotaSnapshot, Error>) -> Void) {
        do {
            let executablePath = try resolveExecutable()
            RateLimitFetchOperation(executablePath: executablePath, completion: completion).start()
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    static func appServerEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        proxySettings: [String: Any]? = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
    ) -> [String: String] {
        var environment = environment
        guard environment["ALL_PROXY"] == nil, environment["all_proxy"] == nil,
              let proxySettings else {
            return environment
        }

        var addedSystemProxy = false
        for scheme in ["HTTP", "HTTPS"] {
            let key = scheme + "_PROXY"
            guard environment[key] == nil, environment[key.lowercased()] == nil,
                  (proxySettings[scheme + "Enable"] as? NSNumber)?.boolValue == true,
                  let host = proxySettings[scheme + "Proxy"] as? String, !host.isEmpty,
                  let port = proxySettings[scheme + "Port"] as? Int, (1...65_535).contains(port) else {
                continue
            }

            var proxyURL = URLComponents()
            proxyURL.scheme = "http"
            proxyURL.host = host
            proxyURL.port = port
            if let url = proxyURL.url {
                environment[key] = url.absoluteString
                addedSystemProxy = true
            }
        }

        if addedSystemProxy, environment["NO_PROXY"] == nil, environment["no_proxy"] == nil,
           let exceptions = proxySettings["ExceptionsList"] as? [String], !exceptions.isEmpty {
            let hosts = exceptions.filter { $0 != "<local>" }.map {
                $0.hasPrefix("*.") ? String($0.dropFirst()) : $0
            }
            if !hosts.isEmpty {
                environment["NO_PROXY"] = hosts.joined(separator: ",")
            }
        }

        return environment
    }
}

private final class RateLimitFetchOperation {
    private let executablePath: String
    private let completion: (Result<QuotaSnapshot, Error>) -> Void
    private let queue = DispatchQueue(label: "CodexQuotaBar.RateLimitFetchOperation")
    private let timeout: TimeInterval = 20

    private var process: Process?
    private var standardInput: Pipe?
    private var standardOutput: Pipe?
    private var standardError: Pipe?
    private var stdoutBuffer = Data()
    private var stderrText = ""
    private var didFinish = false
    private var didInitialize = false

    init(executablePath: String, completion: @escaping (Result<QuotaSnapshot, Error>) -> Void) {
        self.executablePath = executablePath
        self.completion = completion
    }

    func start() {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            finish(
                .failure(
                    CodexExecutableLocatorError.notFound(checkedPaths: [executablePath])
                )
            )
            return
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.environment = CodexRateLimitFetcher.appServerEnvironment()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        self.process = process
        self.standardInput = stdin
        self.standardOutput = stdout
        self.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            consumeStdout(data)
        }

        stderr.fileHandleForReading.readabilityHandler = { [self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            queue.async {
                self.stderrText += text
            }
        }

        process.terminationHandler = { [self] process in
            queue.async {
                guard !self.didFinish else {
                    return
                }
                self.finishOnQueue(.failure(FetchError.processExited(process.terminationStatus, self.stderrText)))
            }
        }

        do {
            try process.run()
        } catch {
            finish(.failure(error))
            return
        }

        sendInitialize(to: stdin.fileHandleForWriting)

        queue.asyncAfter(deadline: .now() + timeout) { [self] in
            guard !self.didFinish else {
                return
            }
            self.finishOnQueue(.failure(FetchError.timeout))
        }
    }

    private func sendInitialize(to input: FileHandle) {
        let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-quota-bar","version":"0.1.0","title":"Codex Quota Bar"},"capabilities":{"optOutNotificationMethods":["account/rateLimits/updated","account/updated","remoteControl/status/changed"]}}}"# + "\n"

        do {
            try input.write(contentsOf: Data(initialize.utf8))
        } catch {
            finish(.failure(error))
        }
    }

    private func sendReadRequest() {
        guard let input = standardInput?.fileHandleForWriting else {
            finishOnQueue(.failure(FetchError.malformedResponse))
            return
        }
        let initialized = #"{"jsonrpc":"2.0","method":"initialized","params":{}}"# + "\n"
        let read = #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":null}"# + "\n"
        do {
            try input.write(contentsOf: Data(initialized.utf8))
            try input.write(contentsOf: Data(read.utf8))
        } catch {
            finishOnQueue(.failure(error))
        }
    }

    private func consumeStdout(_ data: Data) {
        queue.async {
            self.stdoutBuffer.append(data)

            while let newlineRange = self.stdoutBuffer.firstRange(of: Data([0x0A])) {
                let lineData = self.stdoutBuffer.subdata(in: self.stdoutBuffer.startIndex..<newlineRange.lowerBound)
                self.stdoutBuffer.removeSubrange(self.stdoutBuffer.startIndex..<newlineRange.upperBound)
                self.handleStdoutLine(lineData)
            }
        }
    }

    private func handleStdoutLine(_ lineData: Data) {
        guard !didFinish, !lineData.isEmpty else {
            return
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
            let id = object["id"] as? Int
        else {
            return
        }

        if id == 1, !didInitialize {
            if let error = object["error"] {
                finishOnQueue(.failure(FetchError.rpcError("initialize failed: \(error)")))
            } else if object["result"] is [String: Any] {
                didInitialize = true
                sendReadRequest()
            } else {
                finishOnQueue(.failure(FetchError.malformedResponse))
            }
            return
        }

        guard id == 2 else {
            return
        }

        if let error = object["error"] {
            finishOnQueue(.failure(FetchError.rpcError("\(error)")))
            return
        }

        guard let result = object["result"] else {
            finishOnQueue(.failure(FetchError.malformedResponse))
            return
        }

        do {
            let resultData = try JSONSerialization.data(withJSONObject: result)
            let response = try JSONDecoder().decode(AppServerRateLimitsResponse.self, from: resultData)
            let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)
            finishOnQueue(.success(snapshot))
        } catch {
            finishOnQueue(.failure(error))
        }
    }

    private func finish(_ result: Result<QuotaSnapshot, Error>) {
        queue.async {
            self.finishOnQueue(result)
        }
    }

    private func finishOnQueue(_ result: Result<QuotaSnapshot, Error>) {
        guard !didFinish else {
            return
        }

        didFinish = true
        process?.terminationHandler = nil
        standardOutput?.fileHandleForReading.readabilityHandler = nil
        standardError?.fileHandleForReading.readabilityHandler = nil
        try? standardInput?.fileHandleForWriting.close()

        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil

        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

private enum FetchError: LocalizedError {
    case malformedResponse
    case processExited(Int32, String)
    case rpcError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Codex app-server 返回格式不完整"
        case .processExited(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "Codex app-server 提前退出：\(code)" : "Codex app-server 提前退出：\(code) \(detail)"
        case .rpcError(let message):
            return "Codex app-server RPC 错误：\(message)"
        case .timeout:
            return "Codex app-server 请求超时"
        }
    }
}
