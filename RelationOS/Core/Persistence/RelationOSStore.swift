import Foundation

// TODO(SwiftData migration): Stub actor that will own the SwiftData
// `ModelContainer` once the v1.1 migration lands. For v1 scaffold the
// real store of record is `ContactsStore` (UserDefaults-JSON-backed
// ObservableObject). Keeping this actor in place means call sites that
// need an `await` boundary for future SwiftData reads/writes have a
// stable type to target.
actor RelationOSStore {
    static let shared = RelationOSStore()

    private init() {}

    /// Future: open a SwiftData ModelContainer for `Contact` and `Reminder`.
    func bootstrap() async {
        // No-op in v1.
    }
}
