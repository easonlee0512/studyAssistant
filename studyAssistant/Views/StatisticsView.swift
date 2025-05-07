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
    
    @State private var timeRange: TimeRange = .day
    @State private var timerRecords: [TimerRecord] = []
    @State private var todayTasks: [(task: String, isCompleted: Bool)] = []
    @State private var formattedDate: String = ""
    @State private var maxFocusTime: Int = 0
    @State private var earliestStartTime: Date?
    @State private var latestEndTime: Date?
    @State private var hourlyDistribution: [Int: Int] = [:] // 小時:總秒數
    @State private var isSyncing: Bool = false
    
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
            loadData()
            syncStatisticsWithTasks()
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
            }
        }
    }
    
    // 同步任務與統計數據
    private func syncStatisticsWithTasks() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            // 1. 獲取所有統計記錄
            try? await staticViewModel.fetchStatistics()
            
            // 2. 獲取所有任務
            try? await todoViewModel.loadTasks()
            let allTasks = todoViewModel.tasks
            
            // 3. 按類別分組計算任務數量
            var categoryTaskCounts: [String: (total: Int, completed: Int)] = [:]
            
            for task in allTasks {
                let category = task.category
                
                // 忽略空類別或「未分類」
                guard !category.isEmpty && category != "未分類" else { continue }
                
                // 更新該類別的任務總數和已完成數量
                var currentCount = categoryTaskCounts[category] ?? (total: 0, completed: 0)
                currentCount.total += 1
                if task.isCompleted {
                    currentCount.completed += 1
                }
                categoryTaskCounts[category] = currentCount
            }
            
            // 4. 遍歷每個類別，更新統計資料
            for (category, counts) in categoryTaskCounts {
                try? await staticViewModel.updateCategoryTaskStats(
                    category: category,
                    completedCount: counts.completed,
                    totalCount: counts.total
                )
                print("已更新類別 \(category) 的任務統計: 完成 \(counts.completed)/\(counts.total)")
            }
            
            // 5. 重新載入統計資料以確保顯示最新數據
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
        
        // 獲取當天的任務
        let dayTasks = todoViewModel.tasksForDate(today)
        todayTasks = dayTasks.map { ($0.title, $0.isCompleted) }
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
                .background(Color.hex(hex: "576CBC"))
                .cornerRadius(12)
                .padding(.horizontal)
            
            // 總計學習時間卡片
            VStack(spacing: 10) {
                // 總學習時間
                VStack(spacing: 5) {
                    Text("總學習時間")
                        .font(.title3)
                        .foregroundColor(Color.hex(hex: "8B9DFA"))
                    
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
                        .foregroundColor(Color.hex(hex: "8B9DFA"))
                    
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
                                .foregroundColor(Color.hex(hex: "E28A5F"))
                            
                            Text("專注次數")
                                .font(.headline)
                                .foregroundColor(Color.hex(hex: "8B9DFA"))
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
                                .foregroundColor(Color.hex(hex: "E28A5F"))
                            
                            Text("完成率")
                                .font(.headline)
                                .foregroundColor(Color.hex(hex: "8B9DFA"))
                        }
                        
                        let completionRate = getCompletionRateValue()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(completionRate * 100))%")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color.hex(hex: "333333"))
                                
                                Spacer()
                            }
                                
                                // 進度條
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // 背景
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                        .frame(height: 12)
                                        .cornerRadius(6)
                                        
                                        // 進度
                                        Rectangle()
                                            .fill(Color.hex(hex: "E28A5F"))
                                        .frame(width: geometry.size.width * CGFloat(completionRate), height: 12)
                                        .cornerRadius(6)
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
            
            // 時間分布長條圖
            VStack(alignment: .leading, spacing: 10) {
                Text("專注時長")
                    .font(.headline)
                    .padding(.leading)
                
                VStack(spacing: 12) {
                    // 時間標記
                    HStack(spacing: 0) {
                        ForEach([15, 30, 45, 60, 75, 90, 150, 180], id: \.self) { minute in
                            Text("\(minute)")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 小時分布
                    ForEach(Array(hourlyDistribution.keys.sorted()), id: \.self) { hour in
                        HStack(spacing: 10) {
                            // 小時標籤
                            Text("\(hour)")
                                .font(.caption)
                                .frame(width: 20)
                            
                            // 長條圖
                            let duration = hourlyDistribution[hour] ?? 0
                            let minutes = duration / 60
                            let maxWidth = UIScreen.main.bounds.width - 80
                            let width = min(maxWidth * CGFloat(minutes) / 180.0, maxWidth)
                            
                            Capsule()
                                .fill(getColorForHour(hour))
                                .frame(width: width, height: 25)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
            }
            .background(Color.hex(hex: "FEECD8"))
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
                    .padding(.leading)
                
                VStack(spacing: 20) {
                    let taskCompletionRates = staticViewModel.getCategoryTaskCompletionRate()
                    
                    if taskCompletionRates.isEmpty {
                        Text("暫無任務數據")
                            .foregroundColor(.gray)
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
                                    
                                    Spacer()
                                    
                                    Text("\(completedTasks)/\(totalTasks)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                ZStack(alignment: .leading) {
                                    // 背景
                                    Capsule()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 25)
                                    
                                    // 進度
                                    Capsule()
                                        .fill(Color.hex(hex: "E28A5F"))
                                        .frame(width: max(60, UIScreen.main.bounds.width - 80) * CGFloat(completionRate), height: 25)
                                        .overlay(
                                            Text("\(Int(completionRate * 100))%")
                                                .foregroundColor(.black)
                                                .padding(.leading, 20)
                                                .opacity(completionRate > 0.05 ? 1 : 0)
                                            , alignment: .leading
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
            
            // 分類總專注時長區塊
            VStack(alignment: .leading, spacing: 15) {
                Text("總專注時長")
                    .font(.headline)
                    .padding(.leading)
                
                let categoryTimes = staticViewModel.totalFocusTimeByCategory()
                let totalCategories = staticViewModel.categoryCount()
                
                HStack {
                    VStack(spacing: 15) {
                        Text("總時長：")
                            .font(.title3)
                            .foregroundColor(Color.hex(hex: "8B9DFA"))
                        
                        let totalMinutes = categoryTimes.values.reduce(0, +)
                        let hours = totalMinutes / 60
                        let minutes = totalMinutes % 60
                        
                        Text("\(hours)h\(minutes)m")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    VStack(spacing: 15) {
                        Text("專注次數：")
                            .font(.title3)
                            .foregroundColor(Color.hex(hex: "8B9DFA"))
                        
                        Text("\(totalCategories)個")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color.hex(hex: "333333"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                VStack(spacing: 15) {
                    if categoryTimes.isEmpty {
                        Text("暫無分類數據")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    } else {
                        ForEach(Array(categoryTimes.keys.sorted()), id: \.self) { category in
                            let minutes = categoryTimes[category] ?? 0
                            let hours = minutes / 60
                            let mins = minutes % 60
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category)
                                        .font(.headline)
                                }
                                
                                Spacer()
                                
                                Text("\(hours)小時\(mins)分鐘")
                                    .font(.title3)
                                    .bold()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
            .background(Color.hex(hex: "FEECD8"))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // 底部間距
            Spacer(minLength: 80)
        }
        .padding(.vertical)
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
