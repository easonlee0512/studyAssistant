import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    // 假設有一個共享的待辦事項數據
    @State private var todos: [Date: [(task: String, isCompleted: Bool)]] = [:]

    var body: some View {
        TabView(selection: $selectedTab) {

            // 待辦事項頁面
            TodoView()
                .tabItem {
                    Label("待辦", systemImage: "checklist")
                }
                .tag(0)

            // 計時頁面
            TimerView()
                .tabItem {
                    Label("計時", systemImage: "timer")
                }
                .tag(1)
            
            // 日曆頁面
            CalendarView()
                .tabItem {
                    Label("日曆", systemImage: "calendar")
                }
                .tag(2)
            
            // 統計頁面 (新增)
            StatisticsView(todos: todos)
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }
                .tag(3)

            // 設定頁面
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
}
