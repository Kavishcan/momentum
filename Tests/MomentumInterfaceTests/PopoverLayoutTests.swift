import AppKit
import MomentumCore
import SwiftUI
import XCTest
@testable import Momentum

@MainActor
final class InterfaceReminderClient: LocalReminderClient {
    func authorization() async -> ReminderAuthorization { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func schedule(_ settings: NightSettings) async throws {}
    func cancel() async {}
    func sendTest() async throws {}
    func focusFinished() async {}
}
final class PopoverLayoutTests: XCTestCase {
    @MainActor
    private func database() throws -> MomentumDatabase {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumInterface-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try MomentumDatabase(url: directory.appendingPathComponent("db.sqlite"))
    }
    @MainActor
    func testAllPagesHaveUsableViewportAtMinimumWindowSize() async throws {
        let db = try database()
        let workspace = try Workspace(database: db, client: InterfaceReminderClient(), ticking: false)
        for n in 1...3 { XCTAssertTrue(workspace.store.addTask("Task \(n): " + String(repeating: "Long title ", count: 12))) }
        for page in WorkspacePage.allCases {
            workspace.page = page
            let host = NSHostingView(rootView: MomentumRoot(workspace: workspace))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 620), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: 840, height: 620)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(80))
            window.setContentSize(window.contentMinSize)
            host.layoutSubtreeIfNeeded()
            func findScroll(_ view: NSView) -> NSScrollView? {
                if let scroll = view as? NSScrollView { return scroll }
                return view.subviews.compactMap { findScroll($0) }.first
            }
            let scroll = try XCTUnwrap(findScroll(host), "\(page) needs a scrollable content area")
            XCTAssertGreaterThan(scroll.contentView.bounds.height, 450, "\(page) must not collapse")
            XCTAssertGreaterThan(scroll.contentView.bounds.width, 500)
            XCTAssertLessThanOrEqual(window.contentMinSize.height, 680)
            if let path = ProcessInfo.processInfo.environment["MOMENTUM_PREVIEW_DIR"],
               let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    try data.write(to: URL(fileURLWithPath: path).appendingPathComponent("\(page.rawValue).png"))
                }
            }
            window.contentView = nil
        }
    }
    @MainActor
    func testMenuHasStableHeightForIdleRunningPausedAndFinished() async throws {
        let db = try database()
        let start = Date.now
        for phase in 0..<4 {
            var session = FocusSession()
            if phase > 0 { session.start(minutes: 10, taskTitle: "Focus task", now: start) }
            if phase == 2 { session.pause(now: start.addingTimeInterval(10)) }
            if phase == 3 { session.reconcile(now: start.addingTimeInterval(601)) }
            try db.saveSession(session)
            let fixture = try Workspace(database: db, client: InterfaceReminderClient(), ticking: false)
            let host = NSHostingView(rootView: MomentumMenu(workspace: fixture))
            let size = host.fittingSize
            XCTAssertGreaterThan(size.height, 120)
            XCTAssertLessThan(size.height, 460)
            XCTAssertEqual(size.width, 320, accuracy: 1)
        }
    }
    @MainActor
    func testTimerControllerPersistsPauseResumeAndRecordsCompletionOnce() async throws {
        let db = try database()
        let timer = try FocusController(database: db, ticking: false)
        timer.start(minutes: 10, title: "Write")
        timer.pause()
        XCTAssertEqual(try db.session().phase, .paused)
        let restored = try FocusController(database: db, ticking: false)
        XCTAssertEqual(restored.session.phase, .paused)
        restored.resume()
        let deadline = try XCTUnwrap(restored.session.deadline)
        restored.tick(at: deadline.addingTimeInterval(1))
        restored.tick(at: deadline.addingTimeInterval(2))
        XCTAssertEqual(restored.session.phase, .finished)
        XCTAssertEqual(try db.focusHistory().count, 1)
        restored.reset()
        XCTAssertEqual(try db.session().phase, .idle)
        XCTAssertEqual(try db.focusHistory().count, 1)
    }
    @MainActor
    func testReopeningAfterExpiryRestoresFinishedState() async throws {
        let db = try database(), now = Date.now
        var session = FocusSession(); session.start(minutes: 10, taskTitle: "Recovered", now: now)
        try db.saveSession(session)
        let restored = try FocusController(database: db, now: now.addingTimeInterval(700), ticking: false)
        XCTAssertEqual(restored.session.phase, .finished)
        _ = try FocusController(database: db, now: now.addingTimeInterval(800), ticking: false)
        XCTAssertEqual(try db.focusHistory().count, 1)
        XCTAssertEqual(try XCTUnwrap(db.focusHistory().first).finishedAt.timeIntervalSince1970, now.addingTimeInterval(600).timeIntervalSince1970, accuracy: 0.001)
    }
    @MainActor
    func testEmptyTodayIsUsableInLightAndDarkAppearance() async throws {
        let db = try database()
        let app = try Workspace(database: db, client: InterfaceReminderClient(), ticking: false)
        for dark in [false, true] {
            let host = NSHostingView(rootView: MomentumRoot(workspace: app).preferredColorScheme(dark ? .dark : .light))
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: 980, height: 720)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(80))
            XCTAssertGreaterThan(host.fittingSize.width, 800)
            XCTAssertTrue(app.store.tasks.isEmpty)
            if let path = ProcessInfo.processInfo.environment["MOMENTUM_PREVIEW_DIR"], let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    try data.write(to: URL(fileURLWithPath: path).appendingPathComponent(dark ? "Today-Empty-Dark.png" : "Today-Empty-Light.png"))
                }
            }
            window.contentView = nil
        }
    }

}
