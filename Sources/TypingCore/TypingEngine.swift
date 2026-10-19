import Foundation

public enum TypingToken: Equatable {
    case text(String)
    case enter
    case tab

    public static func sequence(for text: String) -> [TypingToken] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .map { character in
                switch character {
                case "\n": return .enter
                case "\t": return .tab
                default: return .text(String(character))
                }
            }
    }
}

/// All callbacks and events are serialized on the main actor. Sleeping never blocks it.
@MainActor
public final class TypingEngine {
    public private(set) var isTyping = false
    public var onStateChanged: (() -> Void)?
    private var operation: Task<Void, Never>?
    private var generation = UUID()

    public init() {}

    @discardableResult
    public func start(
        text: String,
        canContinue: @escaping () -> Bool,
        modifiersReleased: @escaping () -> Bool,
        send: @escaping (TypingToken) -> Bool,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) -> Bool {
        guard !isTyping, !text.isEmpty, canContinue() else { return false }
        let id = UUID()
        generation = id
        isTyping = true
        onStateChanged?()
        operation = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == id {
                    self.operation = nil
                    self.isTyping = false
                    self.onStateChanged?()
                }
            }
            do {
                // Give up if a modifier is held for more than two seconds.
                var attempts = 0
                while !modifiersReleased() {
                    guard !Task.isCancelled, canContinue(), attempts < 200 else { return }
                    attempts += 1
                    try await sleep(.milliseconds(10))
                }
                for token in TypingToken.sequence(for: text) {
                    guard !Task.isCancelled, canContinue(), modifiersReleased() else { return }
                    guard send(token) else { return }
                    try await sleep(.milliseconds(10))
                }
            } catch { /* Cancellation and sleep failures end the current run. */ }
        }
        return true
    }

    public func cancel() {
        guard isTyping else { return }
        generation = UUID()
        operation?.cancel()
        operation = nil
        isTyping = false
        onStateChanged?()
    }
}
