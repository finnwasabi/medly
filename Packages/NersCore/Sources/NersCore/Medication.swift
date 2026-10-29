import Foundation

/// One medication with its own schedule, pill count and history. The name is shown in every reminder.
public struct Medication: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Index into the app's swatches. The package stays free of UI types.
    public var color: Int
    /// SF Symbol name chosen in the app.
    public var icon: String
    public var settings: ReminderSettings
    public var history: [DoseRecord]

    /// Long names would push alarm titles past what the lock screen shows.
    public static let nameLimit = 40
    /// More than this would crowd the alarm budget and the server snapshot.
    public static let limit = 20

    public init(
        id: UUID = UUID(), name: String, color: Int = 0, icon: String = "pills.fill",
        settings: ReminderSettings = ReminderSettings(), history: [DoseRecord] = []
    ) {
        self.id = id
        self.name = String(name.prefix(Self.nameLimit))
        self.color = color
        self.icon = icon
        self.settings = settings
        self.history = history
    }

    /// The scheduling logic over this medication's settings and history. Writing it back keeps both in sync.
    public var planner: Planner {
        get { Planner(settings: settings, history: history) }
        set {
            settings = newValue.settings
            history = newValue.history
        }
    }

    // Tolerant decoding: fields added later fall back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        color = try c.decodeIfPresent(Int.self, forKey: .color) ?? 0
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "pills.fill"
        settings = try c.decodeIfPresent(ReminderSettings.self, forKey: .settings) ?? ReminderSettings()
        history = try c.decodeIfPresent([DoseRecord].self, forKey: .history) ?? []
    }
}
