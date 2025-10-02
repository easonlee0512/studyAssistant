import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var chatViewModel: ChatViewModel
    // 假設有一個共享的待辦事項數據
    @State private var todos: [Date: [(task: String, isCompleted: Bool)]] = [:]

    var body: some View {
        TabView {
            TodoView()
                .environmentObject(viewModel)
                .tabItem {
                    Image("home_icon")
                        .renderingMode(.original)
                }

            CalendarView()
                .environmentObject(viewModel)
                .tabItem {
                    Image("calendar_icon")
                        .renderingMode(.original)
                }

            ChatDemoDynamicView()
                .tabItem {
                    Image("chat_icon")
                        .renderingMode(.original)
                }

            TimerView()
                .environmentObject(viewModel)
                .tabItem {
                    Image("timer_icon")
                        .renderingMode(.original)
                }

            SettingsView(todos: todos)
                .environmentObject(authState)
                .tabItem {
                    Image("settings_icon")
                        .renderingMode(.original)
                }
        }
        .onAppear {
            // 確保 TimerManager 可以訪問 TodoViewModel
            timerManager.setTodoViewModel(viewModel)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(AuthState())
}
