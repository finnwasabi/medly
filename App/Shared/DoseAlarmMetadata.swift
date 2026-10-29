import AlarmKit

/// Shared by the app and the widget: the alarm metadata type must match for the widget to draw the countdown.
nonisolated struct DoseAlarmMetadata: AlarmMetadata {
    /// The widget runs in its own process and cannot read the app's settings, so each alarm carries the language.
    var language = "vi"
}
