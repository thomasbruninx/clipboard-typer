import XCTest
@testable import TypingCore

@MainActor
final class TypingEngineTests: XCTestCase {
    func testUnicodeAndLineEndingSequence() {
        XCTAssertEqual(TypingToken.sequence(for: "Aé👨‍👩‍👧‍👦e\u{301}\r\nB\rC\n\t"), [
            .text("A"), .text("é"), .text("👨‍👩‍👧‍👦"), .text("e\u{301}"),
            .enter, .text("B"), .enter, .text("C"), .enter, .tab
        ])
    }

    func testSequenceAndPacing() async {
        let engine = TypingEngine()
        var output: [TypingToken] = []
        var delays: [Duration] = []
        XCTAssertTrue(engine.start(text: "A\n\t🙂", canContinue: { true }, modifiersReleased: { true }, send: {
            output.append($0); return true
        }, sleep: { delays.append($0) }))
        await finish(engine)
        XCTAssertEqual(output, [.text("A"), .enter, .tab, .text("🙂")])
        XCTAssertEqual(delays, Array(repeating: .milliseconds(10), count: 4))
    }

    func testWaitsForModifiers() async {
        let engine = TypingEngine()
        var waits = 0
        var output: [TypingToken] = []
        engine.start(text: "a", canContinue: { true }, modifiersReleased: { waits >= 3 }, send: {
            XCTAssertGreaterThanOrEqual(waits, 3)
            output.append($0); return true
        }, sleep: { _ in waits += 1 })
        await finish(engine)
        XCTAssertEqual(output, [.text("a")])
    }

    func testHeldModifiersTimeOut() async {
        let engine = TypingEngine()
        var waits = 0
        engine.start(text: "a", canContinue: { true }, modifiersReleased: { false }, send: { _ in
            XCTFail("Should not type while modifiers are held"); return true
        }, sleep: { _ in waits += 1 })
        await finish(engine)
        XCTAssertEqual(waits, 200)
    }

    func testPermissionOrFocusLossStopsBeforeNextCharacter() async {
        let engine = TypingEngine()
        var allowed = true
        var output: [TypingToken] = []
        engine.start(text: "abc", canContinue: { allowed }, modifiersReleased: { true }, send: {
            output.append($0); return true
        }, sleep: { _ in allowed = false })
        await finish(engine)
        XCTAssertEqual(output, [.text("a")])
    }

    func testModifierPressedDuringTypingStopsRun() async {
        let engine = TypingEngine()
        var released = true
        var output: [TypingToken] = []
        engine.start(text: "abc", canContinue: { true }, modifiersReleased: { released }, send: {
            output.append($0); return true
        }, sleep: { _ in released = false })
        await finish(engine)
        XCTAssertEqual(output, [.text("a")])
    }

    func testFailedEventStopsRun() async {
        let engine = TypingEngine()
        var attempts = 0
        engine.start(text: "abc", canContinue: { true }, modifiersReleased: { true }, send: { _ in
            attempts += 1; return false
        }, sleep: { _ in })
        await finish(engine)
        XCTAssertEqual(attempts, 1)
    }

    func testExplicitCancellationStopsRun() async {
        let engine = TypingEngine()
        var output: [TypingToken] = []
        engine.start(text: "abc", canContinue: { true }, modifiersReleased: { true }, send: {
            output.append($0); return true
        }, sleep: { _ in engine.cancel() })
        await finish(engine)
        XCTAssertEqual(output, [.text("a")])
    }

    func testRepeatedTriggerIsIgnored() async {
        let engine = TypingEngine()
        var output: [TypingToken] = []
        XCTAssertTrue(engine.start(text: "first", canContinue: { true }, modifiersReleased: { true }, send: {
            output.append($0); return true
        }, sleep: { _ in }))
        XCTAssertFalse(engine.start(text: "second", canContinue: { true }, modifiersReleased: { true }, send: { _ in
            XCTFail("Second run should be ignored"); return true
        }))
        await finish(engine)
        XCTAssertEqual(output, TypingToken.sequence(for: "first"))
    }

    func testEmptyAndDisallowedTextDoNotStart() {
        let engine = TypingEngine()
        XCTAssertFalse(engine.start(text: "", canContinue: { true }, modifiersReleased: { true }, send: { _ in false }))
        XCTAssertFalse(engine.start(text: "a", canContinue: { false }, modifiersReleased: { true }, send: { _ in false }))
        XCTAssertFalse(engine.isTyping)
    }

    func testCancelledRunCannotClearReplacementRun() async {
        let engine = TypingEngine()
        var output: [TypingToken] = []
        engine.start(text: "old", canContinue: { true }, modifiersReleased: { true }, send: { _ in
            XCTFail("Cancelled run must not send input"); return true
        })
        engine.cancel()
        XCTAssertTrue(engine.start(text: "new", canContinue: { true }, modifiersReleased: { true }, send: {
            output.append($0); return true
        }, sleep: { _ in await Task.yield() }))
        await finish(engine)
        XCTAssertEqual(output, TypingToken.sequence(for: "new"))
    }

    private func finish(_ engine: TypingEngine) async {
        for _ in 0..<2_000 {
            if !engine.isTyping { return }
            await Task.yield()
        }
        XCTFail("Typing did not finish")
        engine.cancel()
    }
}
