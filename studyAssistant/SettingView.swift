import SwiftUICore
import SwiftUI
struct SettingsView: View {
    @State private var isDarkMode = false
    @State private var notificationsEnabled = true
    
    var body: some View {
        NavigationStack {
            List {
                Section("一般設定") {
                    Toggle("深色模式", isOn: $isDarkMode)
                    Toggle("通知", isOn: $notificationsEnabled)
                }
                
                Section("計時器設定") {
                    Text("專注時長")
                    Text("休息時長")
                    Text("提示音效")
                }
                
                Section("關於") {
                    Text("版本 1.0.0")
                    Text("隱私政策")
                    Text("使用條款")
                }
            }
            .navigationTitle("設定")
        }
    }
}
