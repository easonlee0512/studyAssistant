import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var selectedTab = 0
    @State private var previousTab = 0  // 追蹤上一個選中的 tab
    @State private var isAnimating = false  // 防止動畫期間重複點擊
    // 假設有一個共享的待辦事項數據
    @State private var todos: [Date: [(task: String, isCompleted: Bool)]] = [:]

    var body: some View {
        if #available(iOS 26, *) {
            // iOS 26 以上使用原本的 TabView
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
        } else {
            // iOS 26 以下使用自定義玻璃效果菜單
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
                            .transition(slideTransition(isMovingRight: selectedTab > previousTab))
                    }
                    else if selectedTab == 1 {
                        CalendarView()
                            .environmentObject(viewModel)
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: 100)
                            }
                            .transition(slideTransition(isMovingRight: selectedTab > previousTab))
                    }
                    else if selectedTab == 2 {
                        ChatDemoDynamicView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: 72)
                            }
                            .transition(slideTransition(isMovingRight: selectedTab > previousTab))
                    }
                    else if selectedTab == 3 {
                        TimerView()
                            .environmentObject(viewModel)
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: 100)
                            }
                            .transition(slideTransition(isMovingRight: selectedTab > previousTab))
                    }
                    else if selectedTab == 4 {
                        SettingsView(todos: todos)
                            .environmentObject(authState)
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: 100)
                            }
                            .transition(slideTransition(isMovingRight: selectedTab > previousTab))
                    }
                }
                .ignoresSafeArea(edges: .bottom) // 內容延伸到底部

                // 底部导航栏 - 浮動在內容最上層，完全忽略系統安全區域
                VStack(spacing: 0) {
                    Spacer()
                    TabBarNew(selectedTab: $selectedTab, previousTab: $previousTab, isAnimating: $isAnimating)
                }
                .ignoresSafeArea(.all, edges: .bottom) // 完全忽略底部所有安全區域
            }
            .onAppear {
                // 確保 TimerManager 可以訪問 TodoViewModel
                timerManager.setTodoViewModel(viewModel)
            }
        }
    }

    // 計算滑動轉場效果
    private func slideTransition(isMovingRight: Bool) -> AnyTransition {
        // 加快動畫速度 + 減少回彈：dampingFraction 0.9 = 只有 10% 回彈
        let animation = Animation.spring(response: 0.3, dampingFraction: 0.9)

        // 往右切換：新頁面從右滑入，舊頁面往左滑出（同向移動，都往左 ←）
        // 往左切換：新頁面從左滑入，舊頁面往右滑出（同向移動，都往右 →）
        let insertion: AnyTransition = isMovingRight ? .move(edge: .trailing) : .move(edge: .leading)
        let removal: AnyTransition = isMovingRight ? .move(edge: .leading) : .move(edge: .trailing)

        return .asymmetric(insertion: insertion, removal: removal)
            .animation(animation)
    }
}

// 自定义TabBar - 从testSettingView.swift中复制的TabBarNew组件
struct TabBarNew: View {
    @Binding var selectedTab: Int
    @Binding var previousTab: Int
    @Binding var isAnimating: Bool
    @Namespace private var animation

    // 切換 tab 的輔助函數，防止動畫期間重複點擊
    private func switchTab(to newTab: Int) {
        // 如果已經是當前 tab 或正在動畫中，忽略點擊
        guard newTab != selectedTab && !isAnimating else { return }

        // 設置動畫狀態
        isAnimating = true
        previousTab = selectedTab

        // 執行切換動畫（更快的速度 + 減少回彈）
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            selectedTab = newTab
        }

        // 動畫結束後重置狀態（300ms 後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }

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
                        switchTab(to: 0)
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "calendar_icon", isSelected: selectedTab == 1) {
                        switchTab(to: 1)
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "chat_icon", isSelected: selectedTab == 2) {
                        switchTab(to: 2)
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "timer_icon", isSelected: selectedTab == 3) {
                        switchTab(to: 3)
                    }
                    .frame(width: tabWidth, height: 60)

                    TabButtonNew(icon: "settings_icon", isSelected: selectedTab == 4) {
                        switchTab(to: 4)
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
