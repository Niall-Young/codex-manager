import Foundation

public final class CodexAppServerClient: @unchecked Sendable {
    public typealias JSONDictionary = [String: Any]
    public typealias NotificationHandler = (String, JSONDictionary?) -> Void

    private let codexHome: URL
    private let codexExecutable: URL
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let queue = DispatchQueue(label: "CodexManager.AppServerClient")
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<JSONDictionary, Error>] = [:]
    private var outputBuffer = Data()

    public var notificationHandler: NotificationHandler?

    public init(codexHome: URL, codexExecutable: URL? = CodexLocator.executableURL()) throws {
        guard let codexExecutable else {
            throw CodexManagerError.codexExecutableNotFound
        }
        self.codexHome = codexHome
        self.codexExecutable = codexExecutable
    }

    deinit {
        stop()
    }

    public func start() throws {
        if process != nil { return }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = codexExecutable
        process.arguments = [
            "app-server",
            "--listen", "stdio://",
            "--disable", "plugins"
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        process.environment = environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.receive(data: data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        try process.run()
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    public func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        inputPipe?.fileHandleForWriting.closeFile()
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }

    public func initialize() async throws {
        _ = try await request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-manager",
                    "title": "Codex Manager",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "optOutNotificationMethods": []
                ]
            ]
        )
    }

    public func request(method: String, params: JSONDictionary? = nil) async throws -> JSONDictionary {
        try start()

        let id = queue.sync { () -> Int in
            let id = nextID
            nextID += 1
            return id
        }

        var message: JSONDictionary = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params {
            message["params"] = params
        }

        let data = try JSONSerialization.data(withJSONObject: message)
        guard var line = String(data: data, encoding: .utf8) else {
            throw CodexManagerError.invalidAppServerResponse("Unable to encode JSON-RPC request.")
        }
        line.append("\n")

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.pending[id] = continuation
                self.inputPipe?.fileHandleForWriting.write(Data(line.utf8))
            }
        }
    }

    private func receive(data: Data) {
        queue.async {
            self.outputBuffer.append(data)
            while let newline = self.outputBuffer.firstIndex(of: 0x0A) {
                let lineData = self.outputBuffer.subdata(in: 0..<newline)
                self.outputBuffer.removeSubrange(0...newline)
                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    line.hasPrefix("{")
                else {
                    continue
                }
                self.handleLine(line)
            }
        }
    }

    private func handleLine(_ line: String) {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? JSONDictionary
        else {
            return
        }

        if let id = object["id"] as? Int {
            let continuation = pending.removeValue(forKey: id)
            if let error = object["error"] as? JSONDictionary {
                let message = error["message"] as? String ?? "Codex app-server request failed."
                continuation?.resume(throwing: CodexManagerError.appServerError(message))
                return
            }
            if let result = object["result"] as? JSONDictionary {
                continuation?.resume(returning: result)
            } else {
                continuation?.resume(returning: [:])
            }
            return
        }

        if let method = object["method"] as? String {
            notificationHandler?(method, object["params"] as? JSONDictionary)
        }
    }
}
