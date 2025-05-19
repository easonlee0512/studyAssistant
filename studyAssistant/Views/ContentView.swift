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
            
            VStack(spacing: 0) {
                // 內容區域
                ZStack {
                    if selectedTab == 0 {
                        TodoView()
                            .environmentObject(viewModel)
                    }
                    else if selectedTab == 1 {
                        CalendarView()
                            .environmentObject(viewModel)
                    }
                    else if selectedTab == 2 {
                        ChatDemoDynamicView()
                    }
                    else if selectedTab == 3 {
                        TimerView()
                            .environmentObject(viewModel)
                    }
                    else if selectedTab == 4 {
                        SettingsView(todos: todos)
                            .environmentObject(authState)
                    }
                }
                .frame(maxHeight: .infinity) // 讓內容自動填滿
                
                // 底部导航栏
                TabBarNew(selectedTab: $selectedTab)
                    .background(
                        Color.hex(hex: "FEECD8")
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
                
                TabButtonNew(icon: "home_icon", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                Spacer()
                
                TabButtonNew(icon: "calendar_icon", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
                
                TabButtonNew(icon: "chat_icon", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                
                Spacer()
                
                TabButtonNew(icon: "timer_icon", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                
                Spacer()
                
                TabButtonNew(icon: "settings_icon", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .background(
            Color.hex(hex: "FEECD8")
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// 自定义标签按钮 - 从testSettingView.swift中复制的TabButtonNew组件
struct TabButtonNew: View {
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            // 觸發輕微震動反饋
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 執行原本的動作
            action()
        }) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 37)  // 增加頂部間距，讓圖標往下移
                Image(icon)  // 改為使用 Assets 中的圖片
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(isSelected ? .black : .black.opacity(0.5))
                Spacer()
                    .frame(height: 20)  // 增加底部間距，保持平衡
            }
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(AuthState())
}
