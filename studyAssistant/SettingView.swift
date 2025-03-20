import SwiftUICore
import SwiftUI

struct SettingsView: View {
    @State private var isDarkMode = true
    @State private var notificationsEnabled = true
    @State private var showingProfileSettings = false
    @State private var iscountdownnoti = true
    @State private var isshockEnabled = true
    @State private var showingStatistics = false
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    var body: some View {
        NavigationStack {
            List {
                Section("個人檔案") {
                    Button (action:{
                        showingProfileSettings = true
                    } ){
                        HStack {
                            Text("個人檔案設定")
                            Spacer()
                            Image(systemName:"chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section("數據分析") {
                    Button (action:{
                        showingStatistics = true
                    } ){
                        HStack {
                            Label("統計資料", systemImage: "chart.bar")
                            Spacer()
                            Image(systemName:"chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section("一般設定") {
                    Toggle("深色模式", isOn: $isDarkMode)
                    Toggle("通知", isOn: $notificationsEnabled)
                    Toggle("震動回饋", isOn: $isshockEnabled)
                }
                
                Section("計時器設定") {
                    Text("專注時長")
                    Text("休息時長")
                    Toggle("倒計時結束音效", isOn: $iscountdownnoti)
                }
                
                Section("關於") {
                    Text("版本 1.0.0")
                    Text("隱私政策")
                    Text("使用條款")
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showingProfileSettings){
                ProfileSettingsView()
            }
            .sheet(isPresented: $showingStatistics){
                StatisticsView(todos: todos)
            }
        }
    }
}

// 為了預覽提供一個初始化方法
extension SettingsView {
    init() {
        self.todos = [:]
    }
}

