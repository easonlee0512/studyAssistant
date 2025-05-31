import SwiftUI
import Charts

extension TimeInterval {
    func toInt() -> Int {
        return Int(self)
    }
}

// 格式化時間顯示
func formatDuration(_ seconds: Int, short: Bool = false) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    
    if short {
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    } else {
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var todoViewModel: TodoViewModel
    @EnvironmentObject var staticViewModel: StaticViewModel
    @Environment(\.dismiss) var dismiss
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    init(todos: [Date: [(task: String, isCompleted: Bool)]] = [:]) {
        self.todos = todos
    }
    
    @State private var timeRange: TimeRange = .day
    @State private var timerRecords: [TimerRecord] = []
    @State private var todayTasks: [(task: String, isCompleted: Bool)] = []
    @State private var formattedDate: String = ""
    @State private var maxFocusTime: Int = 0
    @State private var earliestStartTime: Date?
    @State private var latestEndTime: Date?
    @State private var hourlyDistribution: [Int: Int] = [:] // 小時:總秒數
    @State private var isSyncing: Bool = false
    
    // 新增：用於格式化最後更新時間的計算屬性
    private var lastUpdateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
    
    // 時間範圍選擇
    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "每日"
        case all = "全部"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            Color.hex(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // 自定義導航欄
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Text("統計")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    
                    // 平衡佈局的空按鈕
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.clear)
                        .padding(.trailing)
                }
                .padding(.top, 10)
                
                // 頂部時間範圍選擇器
                Picker("時間範圍", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: timeRange) { _ in
                    loadData()
                }
                .colorScheme(.light)
                .accentColor(.black)
                
                // 顯示同步指示器
                if isSyncing {
                    HStack {
                        ProgressView()
                            .padding(.horizontal, 5)
                        Text("正在更新統計資料...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 5)
                }
                
                // 根據選擇的時間範圍顯示不同內容
                ScrollView {
                    if timeRange == .day {
                        dailyStatisticsView
                    } else {
                        allTimeStatisticsView
                    }
                }
            }
            .padding(.top, 10)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                // 先同步和清理統計資料
                await syncStatisticsWithTasks()
                // 再載入顯示資料
                loadData()
            }
        }
    }
    
    // 載入所有需要的資料
    private func loadData() {
        Task {
            if timeRange == .day {
                loadTimerRecords()
                loadTodayTasks()
                updateDateDisplay()
            } else {
                try? await staticViewModel.fetchStatistics()
                // 明確加載token使用量統計
                await staticViewModel.fetchTokenUsageStats()
            }
        }
    }
    
    // 同步任務與統計數據
    private func syncStatisticsWithTasks() async {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            // 1. 獲取所有統計記錄
            try? await staticViewModel.fetchStatistics()
            
            // 2. 獲取所有任務
            try? await todoViewModel.loadTasks()
            let allTasks = todoViewModel.tasks
            
            // 3. 按類別分組計算任務數量和專注時間
            var categoryStats: [String: (total: Int, completed: Int, focusTime: Int)] = [:]
            
            for task in allTasks {
                let category = task.category
                
                // 忽略空類別、「未分類」和重複任務
                guard !category.isEmpty && 
                      category != "未分類" && 
                      task.repeatType == .none else { continue }
                
                // 更新該類別的任務總數、已完成數量和專注時間
                var currentStats = categoryStats[category] ?? (total: 0, completed: 0, focusTime: 0)
                currentStats.total += 1
                if task.isCompleted {
                    currentStats.completed += 1
                }
                currentStats.focusTime += task.focusTime
                categoryStats[category] = currentStats
                
                print("計入統計的任務：\(task.title), 類別：\(category), 專注時間：\(task.focusTime)分鐘")
            }
            
            // 4. 檢查並刪除沒有任務的類別統計
            let existingCategories = Set(categoryStats.keys)
            for statistic in staticViewModel.statistics {
                if !existingCategories.contains(statistic.category) {
                    // 如果統計中的類別在實際任務中不存在，則刪除該統計
                    if let statisticId = statistic.id {
                        print("刪除無效統計類別：\(statistic.category)")
                        await staticViewModel.deleteStatistic(statisticId)
                    }
                }
            }
            
            // 5. 更新或創建有效的類別統計
            for (category, stats) in categoryStats {
                print("更新類別 \(category) 的統計資料：完成 \(stats.completed)/\(stats.total), 總專注時間：\(stats.focusTime)分鐘")
                
                try? await staticViewModel.updateCategoryStats(
                    category: category,
                    completedCount: stats.completed,
                    totalCount: stats.total,
                    totalFocusTime: stats.focusTime
                )
            }
            
            // 6. 重新載入統計資料以確保顯示最新數據
            try? await staticViewModel.fetchStatistics()
        }
    }
    
    // 載入計時記錄
    private func loadTimerRecords() {
        Task {
            do {
                // 取得所有計時記錄
                let allRecords = try await timerManager.getAllTimerRecords()
                
                let calendar = Calendar.current
                let now = Date()
                
                // 篩選當天記錄
                let filteredRecords = allRecords.filter { record in
                    calendar.isDate(record.startTime, inSameDayAs: now)
                }
                
                // 計算最長專注時間
                let maxDuration = filteredRecords.map { $0.duration }.max() ?? 0
                
                // 計算最早開始和最晚結束時間
                if !filteredRecords.isEmpty {
                    earliestStartTime = filteredRecords.min(by: { $0.startTime < $1.startTime })?.startTime
                    latestEndTime = filteredRecords.max(by: { $0.endTime < $1.endTime })?.endTime
                } else {
                    earliestStartTime = nil
                    latestEndTime = nil
                }
                
                // 計算小時分布
                var hourlyData = [Int: Int]()
                for record in filteredRecords {
                    let hour = calendar.component(.hour, from: record.startTime)
                    hourlyData[hour, default: 0] += record.duration
                }
                
                await MainActor.run {
                    timerRecords = filteredRecords
                    maxFocusTime = maxDuration
                    hourlyDistribution = hourlyData
                }
            } catch {
                print("Error loading timer records: \(error.localizedDescription)")
            }
        }
    }
    
    // 載入今日任務
    private func loadTodayTasks() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 獲取當天的所有任務
        let dayTasks = todoViewModel.tasksForDate(today)
        var todayTasksStatus: [(task: String, isCompleted: Bool)] = []
        
        for task in dayTasks {
            if task.repeatType == .none {
                // 非重複任務直接使用任務的完成狀態
                todayTasksStatus.append((task.title, task.isCompleted))
            } else {
                // 對於重複任務，檢查當天的實例狀態
                let instances = todoViewModel.getInstancesForDate(today, task: task)
                if let instance = instances.first {
                    // 使用實例的完成狀態
                    todayTasksStatus.append((task.title, instance.isCompleted))
                } else {
                    // 如果沒有找到實例，使用任務的預設狀態
                    todayTasksStatus.append((task.title, false))
                }
            }
        }
        
        todayTasks = todayTasksStatus
    }
    
    // 更新日期顯示
    private func updateDateDisplay() {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日 EEEE"
        dateFormatter.locale = Locale(identifier: "zh_TW")
        formattedDate = dateFormatter.string(from: now)
    }
    
    // 獲取時間格式化
    private func getFormattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm a"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // 獲取總專注時間
    private func getTotalFocusTime() -> Int {
        return timerRecords.reduce(0) { $0 + $1.duration }
    }
    
    // 獲取其他應用專注時間（如有記錄）
    private func getOtherAppsFocusTime() -> Int? {
        // 假設有記錄的話，這裡可以實現獲取其他應用時間的邏輯
        return nil
    }
    
    // 根據小時獲取顏色
    private func getColorForHour(_ hour: Int) -> Color {
        switch hour {
        case 0..<6:
            return Color.hex(hex: "8B9DFA") // 午夜到早晨
        case 6..<12:
            return Color.hex(hex: "9AD0B7") // 早晨到中午
        case 12..<18:
            return Color.hex(hex: "E3B587") // 中午到晚上
        default:
            return Color.hex(hex: "D896C7") // 晚上到午夜
        }
    }
    
    // 獲取完成率數值（0-1之間）
    private func getCompletionRateValue() -> Double {
        guard !todayTasks.isEmpty else {
            return 0.0
        }
        
        let completedCount = todayTasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(todayTasks.count)
    }
    
    // MARK: - 每日統計視圖
    private var dailyStatisticsView: some View {
        VStack(spacing: 20) {
            // 日期顯示
            Text(formattedDate)
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.hex(hex: "E09772"))
                .cornerRadius(12)
                .padding(.horizontal)
            
            // 總計學習時間卡片
            VStack(spacing: 10) {
                // 總學習時間
                VStack(spacing: 5) {
                    Text("總學習時間")
                        .font(.title3)
                        .foregroundColor(Color.black)
                    
                    Text(formatDuration(getTotalFocusTime()))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(Color.hex(hex: "333333"))
                    
                    if let otherAppsTime = getOtherAppsFocusTime(), otherAppsTime > 0 {
                        Text("(允許APP \(formatDuration(otherAppsTime)))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // 最長集中時間
                VStack(spacing: 5) {
                    Text("最長集中時間")
                        .font(.title3)
                        .foregroundColor(.black)
                    
                    Text(formatDuration(maxFocusTime))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(Color.hex(hex: "333333"))
                }
                
                Divider()
                    .padding(.horizontal)
                
                // 專注次數和完成率
                HStack(spacing: 20) {
                    // 專注次數
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 24))
                                .foregroundColor(Color.hex(hex: "E09772"))
                            
                            Text("專注次數")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        
                        Text("\(timerRecords.count)次")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                    
                    // 完成率
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color.hex(hex: "E09772"))
                            
                            Text("完成率")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        
                        let completionRate = getCompletionRateValue()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(completionRate * 100))%")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color.hex(hex: "333333"))
                                
                                Spacer()
                            }
                                
                            // 進度條 - 修改為新的實現方式
                            GeometryReader { geo in
                                let filledW = geo.size.width * CGFloat(completionRate)

                                ZStack(alignment: .leading) {
                                    // 灰底
                                    Capsule()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 12)

                                    // 橙色條 & 文字
                                    Capsule()
                                        .fill(Color.hex(hex: "E09772"))
                                        .frame(width: filledW, height: 12)
                                        .overlay(
                                            Text("\(Int(completionRate*100))%")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: filledW, alignment: .center)
                                        )
                                }
                            }
                            .frame(height: 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing)
                }
                .padding(.vertical, 10)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
            .padding(.horizontal)
            
            // 底部間距
            Spacer(minLength: 80)
        }
        .padding(.vertical)
    }
    
    // MARK: - 全部時間統計視圖
    private var allTimeStatisticsView: some View {
        VStack(spacing: 20) {
            // 任務完成情況區塊
            VStack(alignment: .leading, spacing: 15) {
                Text("任務完成情況")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    let taskCompletionRates = staticViewModel.getCategoryTaskCompletionRate()
                    
                    if taskCompletionRates.isEmpty {
                        Text("暫無任務數據")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(Array(taskCompletionRates.keys.sorted()), id: \.self) { category in
                            let completionRate = taskCompletionRates[category] ?? 0
                            let stat = staticViewModel.statistics.first(where: { $0.category == category })
                            let totalTasks = stat?.taskcount ?? 0
                            let completedTasks = stat?.taskcompletecount ?? 0
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(category)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                        .foregroundColor(Color.black)
                                    
                                    Spacer()
                                    
                                    Text("\(completedTasks)/\(totalTasks)")
                                        .font(.subheadline)
                                        .background(Color.hex(hex: "F5F5F5"))
                                        .foregroundColor(Color.black)
                                }
                                
                                // 修改進度條和百分比顯示
                                GeometryReader { geo in
                                    let filledW = geo.size.width * CGFloat(completionRate)

                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 25)

                                        Capsule()
                                            .fill(Color.hex(hex: "E09772"))
                                            .frame(width: filledW, height: 25)
                                            .overlay(
                                                Text("\(Int(completionRate*100))%")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.black)
                                                    .frame(width: filledW, alignment: .center)
                                            )
                                    }
                                }
                                .frame(height: 25)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 15)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 5)
            
            // 分類總專注時長區塊 - 修改配色
            VStack(alignment: .leading, spacing: 15) {
                Text("總專注時長")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.black)
                
                let categoryTimes = staticViewModel.totalFocusTimeByCategory()
                let totalCategories = staticViewModel.categoryCount()
                
                HStack {
                    VStack(spacing: 15) {
                        Text("總時長：")
                            .font(.title3)
                            .foregroundColor(.black)
                        
                        let totalMinutes = categoryTimes.values.reduce(0, +)
                        let hours = totalMinutes / 60
                        let minutes = totalMinutes % 60
                        
                        Text("\(hours)h\(minutes)m")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.hex(hex: "F5F5F5"))
                    .cornerRadius(12)
                    
                    VStack(spacing: 15) {
                        Text("專注次數：")
                            .font(.title3)
                            .foregroundColor(.black)
                        
                        Text("\(totalCategories)個")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.hex(hex: "F5F5F5"))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 5)
                
                VStack(spacing: 15) {
                    if categoryTimes.isEmpty {
                        Text("暫無分類數據")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.hex(hex: "F5F5F5"))
                            .cornerRadius(12)
                            .padding(.horizontal, 5)
                    } else {
                        ForEach(Array(categoryTimes.keys.sorted()), id: \.self) { category in
                            let minutes = categoryTimes[category] ?? 0
                            let hours = minutes / 60
                            let mins = minutes % 60
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                }
                                
                                Spacer()
                                
                                Text("\(hours)小時\(mins)分鐘")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.black)
                            }
                            .padding()
                            .background(Color.hex(hex: "F5F5F5"))
                            .cornerRadius(12)
                            .padding(.horizontal, 5)
                        }
                    }
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 15)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 5)
            
            // 新增：Token使用量區塊
            VStack(alignment: .leading, spacing: 15) {
                Text("API Token 使用量")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.black)
                
                // 總使用量
                HStack {
                    VStack(spacing: 15) {
                        Text("總計使用量：")
                            .font(.title3)
                            .foregroundColor(.black)
                        
                        Text("\(staticViewModel.tokenUsage.totalTokens) tokens")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.hex(hex: "F5F5F5"))
                    .cornerRadius(12)
                    
                    VStack(spacing: 15) {
                        Text("最後更新：")
                            .font(.title3)
                            .foregroundColor(Color.black)
                        
                        Text(lastUpdateTimeFormatter.string(from: staticViewModel.tokenUsage.lastUpdated))
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.hex(hex: "F5F5F5"))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 5)
                
                // 各模型使用量
                VStack(spacing: 15) {
                    if staticViewModel.tokenUsage.modelUsage.isEmpty {
                        Text("暫無模型使用數據")
                            .foregroundColor(Color.black)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.hex(hex: "F5F5F5"))
                            .cornerRadius(12)
                            .padding(.horizontal, 5)
                    } else {
                        ForEach(Array(staticViewModel.tokenUsage.modelUsage.keys.sorted()), id: \.self) { model in
                            let modelUsage = staticViewModel.tokenUsage.modelUsage[model]!
                            
                            VStack(spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model)
                                            .font(.headline)
                                            .foregroundColor(Color.black)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(modelUsage.total) tokens")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.black)
                                }
                                
                                // 顯示詳細的提示詞和回應tokens
                                HStack(spacing: 10) {
                                    if let promptTokens = modelUsage.prompt {
                                        HStack {
                                            Text("提示詞:")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Text("\(promptTokens) tokens")
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.black)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.hex(hex: "E5F1FF"))
                                        .cornerRadius(8)
                                    }
                                    
                                    if let completionTokens = modelUsage.completion {
                                        HStack {
                                            Text("回應:")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Text("\(completionTokens) tokens")
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.black)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.hex(hex: "F5E5FF"))
                                        .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.hex(hex: "F5F5F5"))
                            .cornerRadius(12)
                            .padding(.horizontal, 5)
                        }
                    }
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 15)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 5)
            
            // 底部間距
            Spacer(minLength: 80)
        }
        .padding(.vertical)
        .padding(.horizontal, 5)
    }
}

// MARK: - 預覽
#Preview {
    NavigationStack {
        StatisticsView(todos: [:])
            .environmentObject(TimerManager())
            .environmentObject(TodoViewModel())
            .environmentObject(StaticViewModel())
    }
} 
