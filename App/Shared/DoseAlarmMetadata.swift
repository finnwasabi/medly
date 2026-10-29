import AlarmKit

/// Dùng chung giữa app và widget: kiểu metadata của báo thức phải trùng để widget vẽ được đếm ngược.
nonisolated struct DoseAlarmMetadata: AlarmMetadata {
    /// Widget chạy tiến trình riêng, không đọc được cài đặt của app, nên ngôn ngữ đi kèm từng báo thức.
    var language = "vi"
}
