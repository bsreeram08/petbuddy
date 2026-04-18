import Foundation

public actor SlackBotAdapter: IntegrationAdapter {
    public static var identifier: String { "slack.bot" }
    public static var displayName: String { "Slack" }

    private let botToken: String
    private let appToken: String
    private weak var eventBus: EventBus?

    private var continuation: AsyncStream<PetEvent>.Continuation?
    private var webSocketTask: URLSessionWebSocketTask?
    private var readTask: Task<Void, Never>?

    public nonisolated var status: IntegrationStatus { _status }
    private var _status: IntegrationStatus = .disconnected

    public var events: AsyncStream<PetEvent> {
        AsyncStream { [weak self] cont in
            self?.continuation = cont
        }
    }

    public init(botToken: String, appToken: String, eventBus: EventBus?) {
        self.botToken = botToken
        self.appToken = appToken
        self.eventBus = eventBus
    }

    public func connect() async throws {
        _status = .connecting

        let url = URL(string: "https:// slack.com/api/apps.connections.open")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await URLSession.shared.data(for: req)
        guard let http = httpResponse as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let wsUrl = json["url"] as? String,
              let socketURL = URL(string: wsUrl) else {
            _status = .error("Socket Mode handshake failed")
            throw SlackError.handshakeFailed
        }

        webSocketTask = URLSession.shared.webSocketTask(with: socketURL)
        webSocketTask?.resume()
        _status = .connected
        readTask = Task { await readLoop() }
    }

    public func disconnect() async {
        readTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        continuation?.finish()
        _status = .disconnected
    }

    private func readLoop() async {
        while !Task.isCancelled {
            do {
                guard let task = webSocketTask else { break }
                switch try await task.receive() {
                case .string(let t): await handleEnvelope(t)
                case .data(let d):  await handleEnvelope(String(data: d, encoding: .utf8) ?? "")
                @unknown default: break
                }
            } catch {
                await reconnect(attempt: 0)
                break
            }
        }
    }

    /// Exponential backoff: 1s → 2s → 4s → 8s → 16s. Max 5 attempts.
    private func reconnect(attempt: Int) async {
        guard attempt < 5 else {
            _status = .error("Slack reconnect failed after 5 attempts")
            return
        }
        let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
        try? await Task.sleep(nanoseconds: delay)
        do { try await connect() }
        catch { await reconnect(attempt: attempt + 1) }
    }

    private func handleEnvelope(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let envelopeId = json["envelope_id"] as? String else { return }

        let ack = ["envelope_id": envelopeId]
        if let d = try? JSONSerialization.data(withJSONObject: ack),
           let s = String(data: d, encoding: .utf8) {
            webSocketTask?.send(.string(s)) { _ in }
        }

        guard let payload = json["payload"] as? [String: Any],
              let event = payload["event"] as? [String: Any],
              let type = event["type"] as? String,
              type == "message" || type == "app_mention" else { return }

        let sender = event["user"] as? String ?? "someone"
        let content = event["text"] as? String ?? ""

        emit(.incomingMessage(IncomingMessage(
            platform: .slack,
            fromDisplay: String(sender.prefix(20)),
            preview: String(content.prefix(120)),
            timestamp: Date()
        )))
    }

    private func emit(_ event: PetEvent) {
        continuation?.yield(event)
        eventBus?.emit(event)
    }

    public enum SlackError: Error, LocalizedError {
        case handshakeFailed
        case connectionDropped
        public var errorDescription: String? {
            switch self {
            case .handshakeFailed: return "Failed to open Slack Socket Mode connection"
            case .connectionDropped: return "Slack WebSocket connection dropped"
            }
        }
    }
}
