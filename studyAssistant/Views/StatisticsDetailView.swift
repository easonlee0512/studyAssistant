import SwiftUI

struct StatisticsDetailView: View {
    @EnvironmentObject var staticViewModel: StaticViewModel
    @EnvironmentObject var todoViewModel: TodoViewModel
    let category: String
    @State private var isSyncing: Bool = false
    
    var body: some View {
        ZStack {
            Color.hex(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // 標題
                Text("\(category) 統計詳情")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 同步指示器
                if isSyncing {
                    HStack {
                        ProgressView()
                            .padding(.horizontal, 5)
                        Text("更新統計資料中...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 5)
                }
                
                // 詳細統計內容
                ScrollView {
                    VStack(spacing: 20) {
                        // 顯示任務完成情況
                        let stat = getStatForCategory(category)
                        
                        if let stat = stat {
                            // 任務完成率
                            statisticCard(
                                title: "任務完成率",
                                content: {
                                    let completionRate = stat.taskcount > 0 ? Double(stat.taskcompletecount) / Double(stat.taskcount) : 0
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(Int(completionRate * 100))%")
                                            .font(.system(size: 40, weight: .bold))
                                        
                                        Text("完成 \(stat.taskcompletecount)/\(stat.taskcount) 個任務")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        // 進度條
                                        ProgressBar(value: completionRate)
                                            .frame(height: 15)
                                    }
                                    .padding()
                                }
                            )
                            
                            // 專注時間統計
                            statisticCard(
                                title: "總專注時間",
                                content: {
                                    let hours = stat.totalFocusTime / 60
                                    let minutes = stat.totalFocusTime % 60
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(hours)小時\(minutes)分鐘")
                                            .font(.system(size: 40, weight: .bold))
                                        
                                        if stat.taskcount > 0 {
                                            let avgMinutesPerTask = stat.totalFocusTime / stat.taskcount
                                            Text("平均每個任務專注 \(avgMinutesPerTask) 分鐘")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                }
                            )
                            
                            // 學習進度
                            statisticCard(
                                title: "學習進度",
                                content: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(Int(stat.progress * 100))%")
                                            .font(.system(size: 40, weight: .bold))
                                        
                                        // 進度條
                                        ProgressBar(value: stat.progress)
                                            .frame(height: 15)
                                    }
                                    .padding()
                                }
                            )
                        } else {
                            Text("無法載入此類別的統計資料")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            syncStatisticsForCategory()
        }
    }
    
    // 同步特定類別的統計數據
    private func syncStatisticsForCategory() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            // 1. 獲取所有統計記錄
            try? await staticViewModel.fetchStatistics()
            
            // 2. 獲取所有任務
            try? await todoViewModel.loadTasks()
            let allTasks = todoViewModel.tasks
            
            // 3. 計算當前類別的任務數量
            var totalCount = 0
            var completedCount = 0
            
            for task in allTasks {
                if task.category == category {
                    totalCount += 1
                    if task.isCompleted {
                        completedCount += 1
                    }
                }
            }
            
            // 4. 更新統計資料
            if totalCount > 0 {
                try? await staticViewModel.updateCategoryTaskStats(
                    category: category,
                    completedCount: completedCount,
                    totalCount: totalCount
                )
                print("已更新類別 \(category) 的任務統計: 完成 \(completedCount)/\(totalCount)")
            }
            
            // 5. 重新載入統計資料
            try? await staticViewModel.fetchStatistics()
        }
    }
    
    // 獲取特定類別的統計數據
    private func getStatForCategory(_ category: String) -> LearningStatistic? {
        return staticViewModel.statistics.first(where: { $0.category == category })
    }
    
    // 統計卡片視圖
    private func statisticCard<Content: View>(title: String, content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
        }
    }
}

// 進度條視圖
struct ProgressBar: View {
    var value: Double // 0到1之間
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                Rectangle()
                    .fill(Color.hex(hex: "E28A5F"))
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width))
                    .cornerRadius(10)
            }
        }
    }
}

#Preview {
    StatisticsDetailView(category: "數學")
        .environmentObject(StaticViewModel())
        .environmentObject(TodoViewModel())
} 