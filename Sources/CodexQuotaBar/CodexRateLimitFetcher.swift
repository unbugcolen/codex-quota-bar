import Foundation

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

        sendRequests(to: stdin.fileHandleForWriting)

        queue.asyncAfter(deadline: .now() + timeout) { [self] in
            guard !self.didFinish else {
                return
            }
            self.finishOnQueue(.failure(FetchError.timeout))
        }
    }

    private func sendRequests(to input: FileHandle) {
        let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-quota-bar","version":"0.1.0","title":"Codex Quota Bar"},"capabilities":{"optOutNotificationMethods":["account/rateLimits/updated","account/updated","remoteControl/status/changed"]}}}"# + "\n"
        let read = #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":null}"# + "\n"

        do {
            try input.write(contentsOf: Data(initialize.utf8))
            try input.write(contentsOf: Data(read.utf8))
        } catch {
            finish(.failure(error))
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
        guard !lineData.isEmpty else {
            return
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
            let id = object["id"] as? Int
        else {
            return
        }

        guard id == 2 else {
            if id == 1, object["error"] != nil {
                finishOnQueue(.failure(FetchError.rpcError("initialize failed: \(object)")))
            }
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
