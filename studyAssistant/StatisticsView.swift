import SwiftUI
import Charts
import SwiftUICore

struct StatisticsView: View {
    @Environment(\.presentationMode) var presentationMode
    var todos: [Date: [(task: String, isCompleted: Bool)]]
    
    var totalTasks: Int {
        todos.values.flatMap { $0 }.count
    }
    
    var completedTasks: Int {
        todos.values.flatMap { $0 }.filter { $0.isCompleted }.count
    }
    
    var remainingTasks: Int {
        totalTasks - completedTasks
    }
    
    var dailyStats: [(date: Date, count: Int)] {
        todos.map { (date: Calendar.current.startOfDay(for: $0.key), count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }
    
    // 计算学习进度（这里假设完成的任务除以总任务数来计算进度）
    var learningProgress: Double {
        totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
    }
    
    // 为每个学科计算进度（示例数据，实际应根据实际数据计算）
    var discreteMathProgress: Double {
        return 0.34 // 示例值，可以根据实际数据计算
    }
    
    var linearAlgebraProgress: Double {
        return 0.45 // 示例值，可以根据实际数据计算
    }
    
    // 计算总专注时长（这里为示例数据，实际应用中可能需要从其他地方获取）
    var totalFocusTime: String {
        return "5h38m" // 示例数据
    }
    
    // 计算专注次数
    var focusCount: String {
        return "\(completedTasks)次" // 使用已完成任务数作为专注次数示例
    }

    var body: some View {
        ZStack {
            // 背景色
            Color(red: 0.95, green: 0.83, blue: 0.72)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部导航栏
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.leading, 0)
                        
                        
                        Spacer()
                        
                        // 添加一个空视图保持对称
                        Text("")
                            .frame(width: 60)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    // 頂部標題
                    Text("統計分析")
                        .font(.system(size: 32, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                    
                    // 學習進度卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("學習進度")
                            .font(.system(size: 20, weight: .bold))
                        
                        // 離散數學進度
                        HStack {
                            Text("離散數學")
                                .font(.system(size: 16))
                                .frame(width: 80, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(height: 10)
                                        .cornerRadius(5)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: CGFloat(discreteMathProgress) * 300, height: 10)
                                        .cornerRadius(5)
                                }
                                
                                Text("\(Int(discreteMathProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // 線性代數進度
                        HStack {
                            Text("線性代數")
                                .font(.system(size: 16))
                                .frame(width: 80, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(height: 10)
                                        .cornerRadius(5)
                                    
                                    Rectangle()
                                        .fill(Color.purple)
                                        .frame(width: CGFloat(linearAlgebraProgress) * 300, height: 10)
                                        .cornerRadius(5)
                                }
                                
                                Text("\(Int(linearAlgebraProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // 整体任务完成进度
                        HStack {
                            Text("任務完成")
                                .font(.system(size: 16))
                                .frame(width: 80, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(height: 10)
                                        .cornerRadius(5)
                                    
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: CGFloat(learningProgress) * 300, height: 10)
                                        .cornerRadius(5)
                                }
                                
                                Text("\(Int(learningProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 1, green: 0.93, blue: 0.85))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                    
                    // 專注時長統計卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("專注時長統計")
                            .font(.system(size: 20, weight: .bold))
                        
                        HStack(spacing: 15) {
                            // 總專注時長
                            VStack(spacing: 5) {
                                Text("總專注時長")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(totalFocusTime)
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                            
                            // 專注次數
                            VStack(spacing: 5) {
                                Text("專注次數")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(focusCount)
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                        }
                        
                        HStack(spacing: 15) {
                            // 总任务数
                            VStack(spacing: 5) {
                                Text("總任務數")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(totalTasks)")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                            
                            // 已完成任务
                            VStack(spacing: 5) {
                                Text("已完成")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(completedTasks)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                            
                            // 未完成任务
                            VStack(spacing: 5) {
                                Text("未完成")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(remainingTasks)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(red: 1, green: 0.93, blue: 0.85))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                    
                    // 每日專注時長分布 - 用Chart替换
                    VStack(alignment: .leading, spacing: 16) {
                        Text("每日任務分布")
                            .font(.system(size: 20, weight: .bold))
                        
                        // 使用原来的Chart组件来显示每日任务数量
                        Chart(dailyStats, id: \.date) { data in
                            LineMark(
                                x: .value("日期", data.date),
                                y: .value("任務數量", data.count)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 200)
                        .padding(.vertical)
                    }
                    .padding()
                    .background(Color(red: 1, green: 0.93, blue: 0.85))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                }
                .padding()
                .padding(.top, 20)  // 增加頂部邊距
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }
}

// MARK: - 預覽數據
#Preview {
    let calendar = Calendar.current
    let mockTodos: [Date: [(task: String, isCompleted: Bool)]] = [
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!): [
            ("買牛奶", false), ("運動", true)
        ],
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 16))!): [
            ("完成 Swift 專案", false)
        ],
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2025, month: 3, day: 17))!): [
            ("讀書", true), ("跑步", false), ("整理房間", false)
        ]
    ]
    
    return NavigationStack {
        StatisticsView(todos: mockTodos)
    }
}
