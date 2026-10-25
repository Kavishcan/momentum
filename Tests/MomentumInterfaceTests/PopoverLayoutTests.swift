import AppKit
import MomentumCore
import SwiftData
import SwiftUI
import XCTest
@testable import Momentum

final class PopoverLayoutTests: XCTestCase {
    @MainActor
    func testMenuHostGivesContentAUsableViewport() async throws {
        let suite = "MomentumLayoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = try ModelContainer(for: DailyTask.self, RoutineStep.self,
                                         configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = MomentumStore(container: database, defaults: defaults)
        let focus = FocusController(defaults: defaults)
        let content = MomentumPopover(tab: .constant(0)) { TodayView(store: store, focus: focus) }
        let host = NSHostingView(rootView: content)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        // Allow SwiftUI's AppKit-backed scroll view to complete layout without showing a window.
        try await Task.sleep(for: .milliseconds(100))
        // NSHostingView publishes SwiftUI's minimum size to its containing window.
        // Reproduce MenuBarExtra's compressed measurement, rather than only its ideal size.
        window.setContentSize(window.contentMinSize)
        host.layoutSubtreeIfNeeded()

        func scrollViews(in view: NSView) -> [NSScrollView] {
            (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let viewport = try XCTUnwrap(scrollViews(in: host).first?.contentView.bounds)
        XCTAssertGreaterThan(window.contentMinSize.height, 450, "The menu must reserve space for its content.")
        XCTAssertGreaterThan(viewport.height, 250, "The task and timer controls must not collapse away.")
        XCTAssertGreaterThan(viewport.width, 300, "The content must fit a usable task input.")
        XCTAssertLessThanOrEqual(size.height, 650, "Keep the popover usable on laptop displays.")
        window.contentView = nil
    }
}
