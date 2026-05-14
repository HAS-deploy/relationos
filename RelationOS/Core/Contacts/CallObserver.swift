import Foundation
import CallKit

/// `CXCallObserver` is the only sanctioned third-party hook into call
/// state, and it has hard limits we can't engineer around:
///
///   * Visible only while the **app is running** (foregrounded, or
///     briefly in the background between observer setup and process
///     suspension). There is no "load yesterday's calls" API. There
///     never has been.
///   * No counterparty identification. iOS does NOT expose the remote
///     phone number or contact for privacy reasons. We get start, end,
///     duration, and direction — that's it.
///
/// So this observer doesn't try to backfill history. It surfaces a
/// "you just had a call — log it against which contact?" notification
/// the next time the user opens the app's contact detail view. The
/// actual hooking is done at app launch from `RelationOSApp`, posting
/// a `.relationOSCallEnded` Notification that views can subscribe to.
@MainActor
final class CallObserver: NSObject, ObservableObject {
    static let callEndedNotification = Notification.Name("relationos.callObserver.callEnded")

    /// Most recent ended call. UI can read this to pre-seed the
    /// "log this call?" prompt with at least a duration.
    @Published private(set) var lastEndedCall: EndedCall?

    struct EndedCall: Equatable {
        let endedAt: Date
        let isOutgoing: Bool
        /// CallKit gives us connectedDate; we record duration when the
        /// call ended in-app. nil if the call had no connected window
        /// (declined / failed).
        let duration: TimeInterval?
    }

    private let observer = CXCallObserver()
    // Tracks when each tracked CXCall first connected, so we can compute
    // duration on the `hasEnded` transition.
    private var connectedAt: [UUID: Date] = [:]

    func start() {
        observer.setDelegate(self, queue: nil)
    }
}

extension CallObserver: CXCallObserverDelegate {
    nonisolated func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        let id = call.uuid
        Task { @MainActor in
            if call.hasConnected, self.connectedAt[id] == nil {
                self.connectedAt[id] = Date()
            }
            guard call.hasEnded else { return }
            let connected = self.connectedAt.removeValue(forKey: id)
            let duration = connected.map { Date().timeIntervalSince($0) }
            let ended = EndedCall(
                endedAt: Date(),
                isOutgoing: call.isOutgoing,
                duration: duration
            )
            self.lastEndedCall = ended
            NotificationCenter.default.post(
                name: Self.callEndedNotification,
                object: nil,
                userInfo: [
                    "endedAt": ended.endedAt,
                    "isOutgoing": ended.isOutgoing,
                    "duration": ended.duration as Any,
                ]
            )
        }
    }
}
