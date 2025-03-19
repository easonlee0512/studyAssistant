import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    // 假設有一個共享的待辦事項數據
    @State private var todos: [Date: [(task: String, isCompleted: Bool)]] = [:]
    
    private let tabs = [
        (title: "待辦", icon: "checklist"),
        (title: "日曆", icon: "calendar"),
        (title: "AI", icon: "message.fill"),
        (title: "計時", icon: "timer"),
        (title: "統計", icon: "chart.bar"),
        (title: "設定", icon: "gear")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // 待辦事項頁面
                TodoView()
                    .padding(.bottom, 60)
                    .tag(0)

                // 日曆頁面
                CalendarView()
                    .padding(.bottom, 60)
                    .tag(1)
                
                // AI 助手頁面
                ChatView()
                    .padding(.bottom, 60)
                    .tag(2)
                
                // 計時頁面
                TimerView()
                    .padding(.bottom, 60)
                    .tag(3)

                // 統計頁面
                StatisticsView(todos: todos)
                    .padding(.bottom, 60)
                    .tag(4)

                // 設定頁面
                SettingsView()
                    .padding(.bottom, 60)
                    .tag(5)
            }
            .tabViewStyle(.automatic)
            .ignoresSafeArea(.keyboard)
            
            // 自定義 TabBar
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 20))
                        Text(tabs[index].title)
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == index ? .blue : .gray)
                    .onTapGesture {
                        withAnimation {
                            selectedTab = index
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(radius: 1)
        }
        .onAppear {
            // 設置 UITabBar 的樣式
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .clear
            
            // 設置標籤欄項目的大小
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = .clear
            itemAppearance.selected.iconColor = .clear
            itemAppearance.normal.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 0)]
            itemAppearance.selected.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 0)]
            
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance
            
            // 設置 UITabBar 的樣式
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            // 隱藏原生 TabBar
            UITabBar.appearance().isHidden = true
            
            // 設置 UITabBarController 的樣式
            if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController {
                tabBarController.tabBar.items?.forEach { item in
                    item.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                    item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -2)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
