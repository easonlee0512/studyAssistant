import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    // 創建共享的數據存儲
    @StateObject private var dataStore = AppDataStore()
    
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
                
            // 日曆頁面
            CalendarView()
                .tabItem {
                    Label("日曆", systemImage: "calendar")
                }
                .tag(1)

            
            // 聊天頁面
            ChatView(dataStore: dataStore)
                .tabItem {
                    Label("AI助手", systemImage: "message.fill")
                }
                .tag(2)
            
            
            // 計時頁面
            TimerView()
                .tabItem {
                    Label("計時", systemImage: "timer")
                }
                .tag(3)

            // 設定頁面
            SettingsView(todos: todos)
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(4)
        }
        .environmentObject(dataStore) // 將數據存儲添加到環境中
    }
}

#Preview {
    ContentView()
}
