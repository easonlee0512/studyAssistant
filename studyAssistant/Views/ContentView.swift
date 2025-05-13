import SwiftUI
import SwiftUICore

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var selectedTab = 0
    // 假設有一個共享的待辦事項數據
    @State private var todos: [Date: [(task: String, isCompleted: Bool)]] = [:]

    var body: some View {
        ZStack {
            // 背景色 - 与其他页面保持一致
            Color.hex(hex: "F3D4B7")
                .ignoresSafeArea()
            
            // 内容视图
            ZStack {
                // 根据选择的标签显示不同页面
                if selectedTab == 0 {
                    // 待辦事項頁面
                    TodoView()
                        .environmentObject(viewModel)
                }
                else if selectedTab == 1 {
                    // 日曆頁面
                    CalendarView()
                        .environmentObject(viewModel)
                }
                else if selectedTab == 2 {
                    // AI助手頁面
                    ChatDemoDynamicView()
                }
                else if selectedTab == 3 {
                    // 計時頁面
                    TimerView()
                        .environmentObject(viewModel)
                }
                else if selectedTab == 4 {
                    // 設定頁面
                    SettingsView(todos: todos)
                        .environmentObject(authState)
                }
            }
            
            // 底部导航栏
            VStack(spacing: 0) {
                Spacer()
                TabBarNew(selectedTab: $selectedTab)
                    .padding(.bottom, -20)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // 確保 TimerManager 可以訪問 TodoViewModel
            timerManager.setTodoViewModel(viewModel)
        }
    }
}

// 自定义TabBar - 从testSettingView.swift中复制的TabBarNew组件
struct TabBarNew: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                TabButtonNew(icon: "checklist", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                Spacer()
                
                TabButtonNew(icon: "calendar", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
                
                TabButtonNew(icon: "message.fill", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                
                Spacer()
                
                TabButtonNew(icon: "timer", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                
                Spacer()
                
                TabButtonNew(icon: "gearshape", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
                
                Spacer()
            }
            .padding(.vertical, 15)
            
            Rectangle()
                .fill(Color.clear)
                .frame(height: 45)
        }
        .background(
            Color.hex(hex: "FEECD8")
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
        )
    }
}

// 自定义标签按钮 - 从testSettingView.swift中复制的TabButtonNew组件
struct TabButtonNew: View {
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30) // 增加圖標尺寸
                .foregroundColor(isSelected ? .black : .black.opacity(0.5))
        }
        .frame(width: 44, height: 44) // 確保點擊區域足夠大
        .contentShape(Rectangle()) // 確保整個區域可點擊
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(AuthState())
}
