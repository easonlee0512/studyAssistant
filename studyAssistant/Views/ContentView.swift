import SwiftUI

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

            // 內容區域 - 延伸到底部讓玻璃效果可以透視
            ZStack {
                if selectedTab == 0 {
                    TodoView()
                        .environmentObject(viewModel)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 0)
                        }
                }
                else if selectedTab == 1 {
                    CalendarView()
                        .environmentObject(viewModel)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 100)
                        }
                }
                else if selectedTab == 2 {
                    ChatDemoDynamicView()
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 72)
                        }
                }
                else if selectedTab == 3 {
                    TimerView()
                        .environmentObject(viewModel)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 100)
                        }
                }
                else if selectedTab == 4 {
                    SettingsView(todos: todos)
                        .environmentObject(authState)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 100)
                        }
                }
            }
            .ignoresSafeArea(edges: .bottom) // 內容延伸到底部

            // 底部导航栏 - 浮動在內容最上層，完全忽略系統安全區域
            VStack(spacing: 0) {
                Spacer()
                TabBarNew(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom) // 完全忽略底部所有安全區域
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
    @Namespace private var animation

    var body: some View {
        // Liquid Glass 圓角形狀 - 四周都是圓角
        let shape = RoundedRectangle(cornerRadius: 25, style: .continuous)

        GeometryReader { geometry in
            let tabWidth = geometry.size.width / 5 // 5 個 tabs

            ZStack(alignment: .center) {
                // Liquid 流動指示器背景（更透明）
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.25),
                                .white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: tabWidth - 10, height: 44) // 寬度更寬，高度與內容區域相同
                    .offset(x: CGFloat(selectedTab) * tabWidth - geometry.size.width / 2 + tabWidth / 2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: selectedTab)

                HStack(spacing: 0) {
                    TabButtonNew(icon: "home_icon", isSelected: selectedTab == 0) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 0
                        }
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "calendar_icon", isSelected: selectedTab == 1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 1
                        }
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "chat_icon", isSelected: selectedTab == 2) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 2
                        }
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "timer_icon", isSelected: selectedTab == 3) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 3
                        }
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "settings_icon", isSelected: selectedTab == 4) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 4
                        }
                    }
                    .frame(width: tabWidth, height: 60)
                }
            }
        }
        .frame(height: 60) // 舒適高度，容納圖標 (28pt) + 上下 padding (12*2 + 餘裕)
        .padding(.horizontal, 10) // Liquid Glass: 調整水平間距
        .background( // Liquid Glass: 超透明多層玻璃背景效果
            ZStack {
                // 底層：極薄模糊玻璃層（更透明）
                shape
                    .fill(.ultraThinMaterial.opacity(0.6)) // 降低不透明度讓背景更清晰

                // 中層：非常淡的漸層層（增強玻璃質感但不遮擋內容）
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.06),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 0.5)
            }
        )
        .clipShape(shape) // Liquid Glass: 裁剪成圓角形狀
        .overlay( // Liquid Glass: 精緻描邊增加玻璃邊緣
            ZStack {
                // 外層白色高光邊緣（更細緻）
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),
                                .white.opacity(0.25),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )

                // 內層極細邊緣
                shape
                    .inset(by: 0.5)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
        )
        .padding(.horizontal, 8) // Liquid Glass: 與螢幕邊緣留極小距離
        .padding(.bottom, 19) // 與螢幕底部保持 19pt 距離
        .padding(.bottom, 0) // 貼緊螢幕底部
    }
}

// 自定义标签按钮 - 从testSettingView.swift中复制的TabButtonNew组件
struct TabButtonNew: View {
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // 觸發輕微震動反饋
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // 玻璃波紋動畫效果
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }

            // 執行原本的動作
            action()
        }) {
            Image(icon)  // 改為使用 Assets 中的圖片
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundColor(isSelected ? .black : .black.opacity(0.5))
                .shadow(color: isSelected ? .white.opacity(0.5) : .clear, radius: 8, x: 0, y: 0) // 選中時發光
                .opacity(isSelected ? 1.0 : 0.7) // 選中狀態的透明度變化
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 填滿整個區域，圖標會自動居中
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(AuthState())
}
