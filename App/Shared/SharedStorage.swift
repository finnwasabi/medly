import Foundation

/// The App Group shared by the app and its widget, so the widget can read the medications.
/// SideStore and AltStore re-sign the app under the user's own team and rename the group; they list the real name in
/// `ALTAppGroups` in Info.plist, so that comes first. Without a usable group, `container` is nil and the app keeps its
/// data in Application Support as before; only the widget goes without.
nonisolated enum SharedStorage {
    static let defaultGroup = "group.io.github.finnwasabi.nersdaily"

    static var groupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String])?.first ?? defaultGroup
    }

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// The data file in the group, or `nil` without one.
    static var sharedStateURL: URL? { container?.appending(path: "state.json") }

    /// Settings the widget needs (the language), mirrored by the app.
    static var defaults: UserDefaults? { container == nil ? nil : UserDefaults(suiteName: groupID) }
}
