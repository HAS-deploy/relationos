import SwiftUI

extension View {
    /// Applies SwiftUI `.sensoryFeedback` only on iOS 17+. Older OSes get a
    /// no-op so the call site stays a single chained modifier.
    @ViewBuilder
    func hapticSuccess<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.success, trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func hapticError<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.error, trigger: trigger)
        } else {
            self
        }
    }
}
