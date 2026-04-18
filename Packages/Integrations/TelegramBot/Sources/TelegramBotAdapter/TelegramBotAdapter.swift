import Foundation
import PetCore

public final class TelegramBotAdapter: IntegrationAdapter {
    public static var identifier: String { "telegram.bot" }
    public static var displayName: String { "Telegram" }

    private let token: String
    private weak var eventBus: EventBus?

    private var continuation: AsyncStream<PetEvent>.Continuation?
    private var pollingTask: Task<Void, Never>?
    private var offset: Int = 0

    public nonisolated var status: IntegrationStatus { _status }
    private var _status: IntegrationStatus = .disconnected

    public var events: AsyncStream<PetEvent> {
        AsyncStream { [weak self] cont in
            self?.continuation = cont
        }
    }

    public init(token: String, eventBus: EventBus?) {
        self.token = token
        self.eventBus = eventBus
    }

    public func connect() async throws {
        _status = .connected
        pollingTask = Task { await pollLoop() }
    }

    public func disconnect() async {
        pollingTask?.cancel()
        continuation?.finish()
        _status = .disconnected
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            do {
                let updates = try await getUpdates(timeout: 30)
                for update in updates {
                    offset = max(offset, update.updateId + 1)
                    if let msg = update.message {
                        emit(.incomingMessage(IncomingMessage(
                            platform: .telegram,
                            fromDisplay: msg.from?.firstName ?? "someone",
                            preview: String((msg.text ?? "").prefix(120)),
                            timestamp: Date(timeIntervalSince1970: TimeInterval(msg.date))
                        )))
                    }
                }
            } catch {
                var delay: UInt64 = 1_000_000_000
                for _ in 0..<5 {
                    try? await Task.sleep(nanoseconds: delay)
                    if Task.isCancelled { break }
                    delay *= 2
                }
            }
        }
    }

    private func getUpdates(timeout: Int) async throws -> [TelegramUpdate] {
        var components = URLComponents(string: "https://api.telegram.org/bot\(token)/getUpdates")!
        components.queryItems = [
            URLQueryItem(name: "timeout", value: String(timeout)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "allowed_updates", value: "message")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool, ok,
              let results = json["result"] as? [[String: Any]] else {
            throw TelegramError.apiError
        }

        return results.compactMap { try? TelegramUpdate(json: $0) }
    }

    private func emit(_ event: PetEvent) {
        continuation?.yield(event)
        eventBus?.emit(event)
    }

    public enum TelegramError: Error { case apiError }
}

struct TelegramUpdate {
    let updateId: Int
    let message: TelegramMessage?

    init(json: [String: Any]) throws {
        guard let id = json["update_id"] as? Int else { throw TelegramParseError.missingId }
        self.updateId = id
        self.message = (json["message"] as? [String: Any]).flatMap { try? TelegramMessage(json: $0) }
    }
}

struct TelegramMessage {
    let text: String?
    let date: Int
    let from: TelegramUser?

    init(json: [String: Any]) throws {
        self.text = json["text"] as? String
        self.date = json["date"] as? Int ?? 0
        self.from = (json["from"] as? [String: Any]).flatMap { try? TelegramUser(json: $0) }
    }
}

struct TelegramUser {
    let firstName: String
    init(json: [String: Any]) throws {
        guard let name = json["first_name"] as? String else { throw TelegramParseError.missingField }
        self.firstName = name
    }
}

enum TelegramParseError: Error { case missingId, missingField }
