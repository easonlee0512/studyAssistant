//
//  testtodoviews.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth
// 添加 Date 擴展的引用

// TodoView 是主要的待辦事項視圖，顯示倒數計時、今日日期、一週的日曆以及待辦事項列表。
struct TodoView: View {
    @EnvironmentObject var viewModel: TodoViewModel
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingTodoDetail = false
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 用於倒數計時顯示
    @State private var userGoal: String = ""
    
    // Figma中使用的顏色
    let backgroundColor = Color.hex(hex: "F3D4B7")
    let bottomBarColor = Color.hex(hex: "FEECD8")
    
    // 計算距離目標日期剩餘天數
    var daysRemaining: Int {
        let targetDate = Calendar.current.date(byAdding: .day, value: 180, to: Date()) ?? Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day ?? 0
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    ZStack {
                        // 背景色
                        backgroundColor
                            .ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            VStack(spacing: 16) {
                                // 顯示用戶目標或默認倒數天數
                                VStack(alignment: .leading, spacing: 5) {
                                    if !userGoal.isEmpty {
                                        Text(userGoal)
                                            .font(.system(size: 30, weight: .bold))
                                    } else {
                                        Text("考試倒數 \(daysRemaining) 天")
                                            .font(.system(size: 30, weight: .bold))
                                    }
                                    
                                    // 顯示當前日期
                                    Text(formattedDate)
                                        .font(.system(size: 24, weight: .bold))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                
                                // 週曆視圖
                                WeekViewNew(selectedDate: $selectedDate)
                                    .padding(.horizontal)
                                
                                // 待辦事項標題
                                HStack {
                                    Text("To Do List")
                                        .font(.system(size: 24, weight: .bold))
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingAddTask = true // 顯示添加任務視圖
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color.hex(hex: "E28A5F"))
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // 任務列表
                            ScrollView {
                                VStack(spacing: 15) {
                                    let todayTasks = viewModel.tasksForDate(selectedDate)
                                    if todayTasks.isEmpty {
                                        // 如果没有任务，顯示空狀態
                                        Text("目前沒有任務")
                                            .foregroundColor(.gray)
                                            .padding()
                                    } else {
                                        // 顯示未完成的任務
                                        ForEach(todayTasks.filter { !$0.isCompleted }) { task in
                                            TaskRowNewView(task: task) { updatedTask in
                                                Task {
                                                    await viewModel.updateTask(updatedTask)
                                                }
                                            }
                                        }
                                        // 顯示已完成的任務
                                        ForEach(todayTasks.filter { $0.isCompleted }) { task in
                                            TaskRowNewView(task: task) { updatedTask in
                                                Task {
                                                    await viewModel.updateTask(updatedTask)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 15)
                            }
                            .padding(.bottom, 0)
                        }
                        
                        // 使用懶加載避免在條件判斷中創建視圖
                        Group {
                            if showingAddTask {
                                TodoAddView(viewModel: viewModel, isPresented: $showingAddTask, selectedDate: selectedDate)
                                    .transition(.move(edge: .bottom))
                                    .zIndex(1)
                            }
                        }
                        
                        Group {
                            if showingTodoDetail {
                                TodoDetailView(
                                    viewModel: viewModel,
                                    date: selectedDate,
                                    isPresented: $showingTodoDetail
                                )
                                .transition(.scale)
                                .zIndex(1)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline) // 將標題設為inline，不顯示大標題
        }
        .task {
            await loadTasks()
            
            // 添加通知觀察者，當資料變更時重新載入
            NotificationCenter.default.addObserver(
                forName: .todoDataDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await loadTasks()
                }
            }
        }
        .onDisappear {
            // 移除通知觀察者
            NotificationCenter.default.removeObserver(self, name: .todoDataDidChange, object: nil)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: selectedDate)
    }
    
    private func loadTasks() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await viewModel.loadTasks()
        } catch {
            print("Error loading tasks: \(error)")
        }
    }
}

// 新的任務行視圖 - 使用新的样式
struct TaskRowNewView: View {
    @State var task: TodoTask
    var isExample: Bool = false
    var onUpdate: ((TodoTask) -> Void)? = nil
    
    var body: some View {
        HStack {
            Image(systemName: "checklist")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 20, weight: .semibold))
                    .strikethrough(task.isCompleted)
                
                Text(task.note)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.6))
                
                Text(task.formattedTime)
                    .font(.system(size: 15))
            }
            .padding(.leading, 10)
            
            Spacer()
            
            if !isExample {
                Button(action: {
                    task.isCompleted.toggle()
                    if let onUpdate = onUpdate {
                        onUpdate(task)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            } else {
                Image(systemName: "square")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(task.color)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.09), radius: 10, x: 3, y: 3)
    }
}

// 新的週曆視圖 - 使用新的样式
struct WeekViewNew: View {
    @Binding var selectedDate: Date
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    // 取得本週的日期陣列（Date型別）
    var weekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1=Sunday
        // 計算本週的第一天（週日）
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday-1), to: calendar.startOfDay(for: today))!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: startOfWeek)! }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7) { index in
                let date = weekDates[index]
                let calendar = Calendar.current
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                VStack(spacing: 5) {
                    Text(days[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .black : Color.hex(hex: "222222"))
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(width: (373 - 24) / 7, height: 78)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color(red: 0.86, green: 0.55, blue: 0.38, opacity: 0.9) : Color.hex(hex: "FEECD8"))
                )
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.leading, 0)
        .padding(.trailing, 1)
        .padding(.vertical, 0.84615)
        .frame(width: 373, alignment: .center)
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 1, y: 1)
    }
    
    // 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }
}

#Preview {
    TodoView()
        .environmentObject(TodoViewModel())
}


