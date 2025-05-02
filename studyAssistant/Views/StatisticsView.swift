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
    
    if short {
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    } else {
        if hours > 0 {
            return "\(hours)小時\(minutes)分鐘"
        } else {
            return "\(minutes)分鐘"
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    @State private var selectedTab = 0
    @State private var timeRange: TimeRange = .week
    @State private var statistics: TimerStatistics?
    
    // 時間範圍選擇
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "週"
        case month = "月"
        case year = "年"
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
                    loadStatistics()
                }
                
                // 內容分頁
                TabView(selection: $selectedTab) {
                    // 總覽頁
                    overviewTab
                        .tag(0)
                    
                    // 科目分析頁
                    subjectAnalysisTab
                        .tag(1)
                    
                    // 時間分析頁
                    timeAnalysisTab
                        .tag(2)
                    
                    // 歷史記錄頁
                    historyTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // 底部選項卡
                HStack(spacing: 30) {
                    tabButton(title: "總覽", icon: "chart.pie.fill", tag: 0)
                    tabButton(title: "科目", icon: "book.fill", tag: 1)
                    tabButton(title: "時間", icon: "clock.fill", tag: 2)
                    tabButton(title: "歷史", icon: "list.bullet", tag: 3)
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 10)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadStatistics()
        }
    }
    
    // 載入統計數據
    private func loadStatistics() {
        Task {
            do {
                let now = Date()
                var startDate: Date
                
                switch timeRange {
                case .week:
                    startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                case .month:
                    startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
                case .year:
                    startDate = Calendar.current.date(byAdding: .year, value: -1, to: now)!
                case .all:
                    statistics = try await timerManager.getStatistics()
                    return
                }
                
                statistics = try await timerManager.getStatistics(from: startDate, to: now)
            } catch {
                print("Error loading statistics: \(error.localizedDescription)")
            }
        }
    }
    
    // 底部選項卡按鈕
    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button(action: {
            selectedTab = tag
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(selectedTab == tag ? Color.hex(hex: "E28A5F") : Color.gray)
        }
    }
    
    // MARK: - 總覽頁
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 總計時長卡片
                StatCard(title: "總計時長", value: formatDuration(statistics?.totalTime.toInt() ?? 0), icon: "timer")
                
                // 專注次數與完成率
                HStack(spacing: 15) {
                    StatCard(
                        title: "專注次數",
                        value: "\((statistics?.completedSessions ?? 0) + (statistics?.incompleteSessions ?? 0))次",
                        icon: "checkmark.circle"
                    )
                    .frame(maxWidth: .infinity)
                    
                    StatCard(
                        title: "完成率",
                        value: getCompletionRate(),
                        icon: "chart.bar.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                
                // 科目分布餅圖
                VStack(alignment: .leading, spacing: 10) {
                    Text("科目分布")
                        .font(.headline)
                        .padding(.leading)
                    
                    if let stats = statistics, !stats.subjectStats.isEmpty {
                        Chart {
                            ForEach(Array(stats.subjectStats.keys), id: \.self) { subject in
                                SectorMark(
                                    angle: .value("時長", stats.subjectStats[subject]?.totalDuration ?? 0),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("科目", subject))
                                .annotation(position: .overlay) {
                                    if (stats.subjectStats[subject]?.totalDuration ?? 0) > (stats.totalDuration / 10) {
                                        Text(subject)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .fixedSize()
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding()
                    } else {
                        Text("暫無數據")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    }
                }
                .background(Color.hex(hex: "FEECD8"))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 科目分析頁
    private var subjectAnalysisTab: some View {
        ScrollView {
            VStack(spacing: 15) {
                if let stats = statistics, !stats.subjectStats.isEmpty {
                    ForEach(Array(stats.subjectStats.keys).sorted(), id: \.self) { subject in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(subject)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(formatDuration(stats.subjectStats[subject]?.totalDuration ?? 0))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // 各科目完成率進度條
                            let completionRate = Float((stats.subjectStats[subject]?.completedCount ?? 0)) / 
                                                Float((stats.subjectStats[subject]?.sessionCount ?? 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("完成率: \(Int(completionRate * 100))%")
                                    .font(.caption)
                                
                                // 進度條
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // 背景
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)
                                        
                                        // 進度
                                        Rectangle()
                                            .fill(Color.hex(hex: "E28A5F"))
                                            .frame(width: geometry.size.width * CGFloat(completionRate), height: 8)
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: 8)
                            }
                            
                            HStack {
                                StatCircle(
                                    value: "\(stats.subjectStats[subject]?.sessionCount ?? 0)",
                                    label: "次數"
                                )
                                
                                Spacer()
                                
                                StatCircle(
                                    value: formatDuration(stats.subjectStats[subject]?.totalDuration ?? 0, short: true),
                                    label: "總計"
                                )
                                
                                Spacer()
                                
                                let avgDuration = (stats.subjectStats[subject]?.totalDuration ?? 0) / 
                                               max(1, (stats.subjectStats[subject]?.sessionCount ?? 1))
                                
                                StatCircle(
                                    value: formatDuration(avgDuration, short: true),
                                    label: "平均"
                                )
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color.hex(hex: "FEECD8"))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                } else {
                    Text("暫無科目數據")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 時間分析頁
    private var timeAnalysisTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 每日學習時長圖表
                VStack(alignment: .leading, spacing: 10) {
                    Text("每日學習時長")
                        .font(.headline)
                        .padding(.leading)
                    
                    if let stats = statistics, !stats.dailyStats.isEmpty {
                        let sortedDailyStats = Array(stats.dailyStats.keys).sorted()
                        
                        Chart {
                            ForEach(sortedDailyStats, id: \.self) { date in
                                BarMark(
                                    x: .value("日期", date, unit: .day),
                                    y: .value("時長(分鐘)", (stats.dailyStats[date]?.totalDuration ?? 0) / 60)
                                )
                                .foregroundStyle(Color.hex(hex: "E28A5F"))
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(date, format: .dateTime.day())
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding()
                    } else {
                        Text("暫無每日數據")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    }
                }
                .background(Color.hex(hex: "FEECD8"))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                .padding(.horizontal)
                
                // 時間分佈熱力圖（僅展示週視圖）
                if timeRange == .week {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("每日專注次數")
                            .font(.headline)
                            .padding(.leading)
                        
                        if let stats = statistics, !stats.dailyStats.isEmpty {
                            let sortedDailyStats = Array(stats.dailyStats.keys).sorted()
                            
                            HStack(spacing: 15) {
                                ForEach(sortedDailyStats, id: \.self) { date in
                                    let sessionCount = stats.dailyStats[date]?.sessionCount ?? 0
                                    let opacity = min(1.0, Double(sessionCount) / 5.0) // 最多5次顯示為全色
                                    
                                    VStack {
                                        Text("\(date, format: .dateTime.weekday(.narrow))")
                                            .font(.caption)
                                        
                                        Circle()
                                            .fill(Color.hex(hex: "E28A5F").opacity(opacity))
                                            .frame(width: 30, height: 30)
                                        
                                        Text("\(sessionCount)")
                                            .font(.caption)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            Text("暫無數據")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: 100)
                        }
                    }
                    .background(Color.hex(hex: "FEECD8"))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 歷史記錄頁
    private var historyTab: some View {
        ScrollView {
            VStack(spacing: 15) {
                let now = Date()
                let fromDate: Date = {
                    switch timeRange {
                    case .week:
                        return Calendar.current.date(byAdding: .day, value: -7, to: now)!
                    case .month:
                        return Calendar.current.date(byAdding: .month, value: -1, to: now)!
                    case .year:
                        return Calendar.current.date(byAdding: .year, value: -1, to: now)!
                    case .all:
                        return Date.distantPast
                    }
                }()
                
                AsyncContentView(loadData: {
                    try await timerManager.getAllTimerRecords()
                }) { records in
                    VStack(spacing: 15) {
                        ForEach(records.filter { record in
                            let recordDate = record.startTime
                            return recordDate >= fromDate && recordDate <= now
                        }.sorted(by: { $0.startTime > $1.startTime })) { record in
                            TimerRecordRow(record: record)
                        }
                    }
                } errorContent: { error in
                    Text("載入失敗：\(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    // 獲取完成率文字
    private func getCompletionRate() -> String {
        guard let stats = statistics, stats.totalSessions > 0 else {
            return "0%"
        }
        
        let rate = Double(stats.completedSessions) / Double(stats.totalSessions) * 100
        return "\(Int(rate))%"
    }
}

// MARK: - 輔助視圖

// 統計卡片
struct StatCard: View {
    var title: String
    var value: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color.hex(hex: "E28A5F"))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// 統計圓形指標
struct StatCircle: View {
    var value: String
    var label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(Color.hex(hex: "E28A5F"))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// 非同步內容視圖
struct AsyncContentView<T, Content: View, ErrorContent: View>: View {
    let loadData: () async throws -> T
    let content: (T) -> Content
    let errorContent: (Error) -> ErrorContent
    
    @State private var data: T?
    @State private var error: Error?
    @State private var isLoading = true
    
    init(
        loadData: @escaping () async throws -> T,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder errorContent: @escaping (Error) -> ErrorContent
    ) {
        self.loadData = loadData
        self.content = content
        self.errorContent = errorContent
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                errorContent(error)
            } else if let data = data {
                content(data)
            }
        }
        .task {
            do {
                data = try await loadData()
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}

// 預覽
#Preview {
    NavigationStack {
        StatisticsView(todos: [:])
            .environmentObject(TimerManager())
    }
}

struct TimerRecordRow: View {
    let record: TimerRecord
    
    var body: some View {
        HStack {
            // 狀態指示器
            Circle()
                .fill(record.isCompleted ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.subject)
                    .font(.headline)
                
                Text("\(record.startTime, format: .dateTime.hour().minute()) - \(record.endTime, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(formatDuration(record.duration))
                .font(.subheadline)
                .foregroundColor(.black)
        }
        .padding()
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
        .padding(.horizontal)
    }
} 
