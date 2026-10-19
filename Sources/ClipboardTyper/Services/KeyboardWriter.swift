import AppKit
import Carbon
import TypingCore

@MainActor
enum KeyboardWriter {
    static var modifiersReleased: Bool {
        CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty
    }

    static var escapePressed: Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Escape))
    }

    static func send(_ token: TypingToken) -> Bool {
        switch token {
        case .enter: return post(key: CGKeyCode(kVK_Return))
        case .tab: return post(key: CGKeyCode(kVK_Tab))
        case .text(let text):
            // Keep each Unicode event small without splitting UTF-16 surrogate pairs.
            var chunk: [UniChar] = []
            for scalar in text.unicodeScalars {
                let units = Array(String(scalar).utf16)
                if chunk.count + units.count > 20 {
                    guard post(key: 0, unicode: chunk) else { return false }
                    chunk.removeAll(keepingCapacity: true)
                }
                chunk.append(contentsOf: units)
            }
            return chunk.isEmpty || post(key: 0, unicode: chunk)
        }
    }

    private static func post(key: CGKeyCode, unicode: [UniChar]? = nil) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return false }
        down.flags = []
        up.flags = []
        if let unicode {
            unicode.withUnsafeBufferPointer { buffer in
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            }
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
