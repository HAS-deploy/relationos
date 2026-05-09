import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Tiny bridge for poking the widget timeline whenever the main app changes
/// data the widget renders. Wrapped in `canImport` so unit tests (which
/// link `RelationOS` but not `WidgetKit`) compile cleanly.
enum WidgetReloader {
    /// Kind that matches `DailyReconnectWidget.kind` in the extension. Kept
    /// as a string so the main app does not need to import the widget
    /// extension target.
    static let dailyReconnectKind = "RelationOSDailyReconnectWidget"

    static func reloadAllIfAvailable() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func reloadDailyReconnect() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: dailyReconnectKind)
        #endif
    }
}
