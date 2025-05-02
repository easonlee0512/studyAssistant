//
//  testtodoaddview.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
//
//  testTodoaddView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/21.
//
import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth


struct TodoAddView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TodoViewModel
    @Binding var isPresented: Bool
    
    // 額外的資料欄位
    @State private var selectedCategory: String = "未分類"
    @State private var repeatOption: RepeatType = .none
    @State private var offset: CGFloat = UIScreen.main.bounds.height // 用於動畫
    @State private var isDismissing = false // 標記是否正在關閉
    
    // 重複選項 - 在初始化時將 viewModel 的值同步到 repeatOption
    let repeatOptions: [RepeatType] = [
        .none,
        .daily,
        .weekly([]),  // 空陣列，表示使用連續區段
        .monthly([])  // 空陣列，表示使用連續區段
    ]
    
    // Figma 設計中的顏色
    let backgroundColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255) // #BCAFA0
    let textColor = Color.black
    let placeholderColor = Color.black.opacity(0.2)
    let categoryColor = Color(red: 178/255, green: 41/255, blue: 34/255, opacity: 0.4)
    let mainBackgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    
    // 添加一個狀態變量保存 selectedDate
    @State private var selectedDate: Date
    
    init(viewModel: TodoViewModel, isPresented: Binding<Bool>, selectedDate: Date) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        // 暫時保存 selectedDate，稍後在 onAppear 中使用
        self._selectedDate = State(initialValue: selectedDate)
        self._repeatOption = State(initialValue: .none)
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            backgroundLayer
            
            // 主要表單容器
            mainContentView
        }
        .onAppear {
            // 在視圖出現時初始化表單
            viewModel.initNewTaskForm(selectedDate: selectedDate)
            repeatOption = viewModel.newTaskRepeatType
            
            // 動畫展示
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                offset = 0
            }
        }
    }
    
    // 背景層
    private var backgroundLayer: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                dismissWithAnimation()
            }
            .opacity(isDismissing ? 0 : 1)
    }
    
    // 表單容器
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 拖動指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 15)
            
            // 頭部標題區域
            headerView
            
            // 滾動內容區域
            ScrollView {
                VStack(spacing: 15) {
                    // 標題和備註
                    titleAndNoteFields
                    
                    // 全天開關
                    allDayToggle
                    
                    // 時間設定
                    dateSelectionView
                    
                    // 顏色選擇
                    colorPickerView
                    
                    // 類別選擇
                    categoryPickerView
                    
                    // 重複選項
                    repeatOptionView
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
        }
        .background(backgroundColor)
        .cornerRadius(25, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        .offset(y: offset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
        .edgesIgnoringSafeArea(.bottom)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let newOffset = max(0, gesture.translation.height)
                    offset = newOffset
                }
                .onEnded { gesture in
                    if gesture.translation.height > 100 {
                        dismissWithAnimation()
                    } else {
                        offset = 0
                    }
                }
        )
    }
    
    // 標題區域
    private var headerView: some View {
        HStack {
            Button("取消") {
                dismissWithAnimation()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("新增任務")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button("儲存") {
                saveTask()
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.blue.opacity(viewModel.newTaskTitle.isEmpty ? 0.5 : 1))
            .disabled(viewModel.newTaskTitle.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
    
    // 標題和備註欄位
    private var titleAndNoteFields: some View {
        VStack(spacing: 0) {
            TextField("標題", text: $viewModel.newTaskTitle)
                .font(.system(size: 24, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
            
            TextField("備註", text: $viewModel.newTaskNote)
                .font(.system(size: 18))
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 5)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 全天開關
    private var allDayToggle: some View {
        VStack(spacing: 0) {
            HStack {
                Text("整天")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Toggle("", isOn: $viewModel.newTaskIsAllDay)
                    .labelsHidden()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 日期選擇視圖
    private var dateSelectionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("開始")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if viewModel.newTaskIsAllDay {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $viewModel.newTaskStartDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 15)
            
            HStack {
                Text("結束")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if repeatOption == .daily {
                    Text("無限期重複")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                } else {
                    if viewModel.newTaskIsAllDay {
                        DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        DatePicker("", selection: $viewModel.newTaskEndDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 顏色選擇器
    private var colorPickerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("顏色")
                .font(.system(size: 18, weight: .medium))
                .padding(.horizontal, 15)
                .padding(.top, 12)
            
            HStack(spacing: 15) {
                ForEach(viewModel.colorOptions, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(viewModel.newTaskColor == color ? Color.black : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            viewModel.newTaskColor = color
                        }
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 類別選擇器
    private var categoryPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("類別")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                TextField("類別", text: $viewModel.newTaskCategory)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 重複選項視圖
    private var repeatOptionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("重複")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Picker("", selection: $repeatOption) {
                    Text("不重複").tag(RepeatType.none)
                    Text("每天").tag(RepeatType.daily)
                    Text("每週").tag(RepeatType.weekly([]))
                    Text("每月").tag(RepeatType.monthly([]))
                }
                .pickerStyle(.menu)
                .accentColor(.black)
                .onChange(of: repeatOption) { newValue in
                    updateEndDateBasedOnRepeatOption(newValue)
                    viewModel.newTaskRepeatType = newValue
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date, isDateOnly: Bool) -> String {
        let formatter = DateFormatter()
        if isDateOnly {
            formatter.dateFormat = "M月 d日 EEE"
        } else {
            formatter.dateFormat = "M月 d日 EEE HH:mm"
        }
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // 關閉視圖帶動畫
    private func dismissWithAnimation() {
        isDismissing = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = UIScreen.main.bounds.height
        }
        
        // 觸發資料重新載入，確保其他視圖能看到新增的任務
        Task {
            do {
                try await viewModel.loadTasks()
            } catch {
                print("Error reloading tasks: \(error)")
            }
        }
        
        // 延遲關閉以等待動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
    
    // 儲存任務
    private func saveTask() {
        // 已經在保存中，避免重複觸發
        if viewModel.isLoading {
            return
        }
        
        // 確保離線操作時 UI 不會卡住
        viewModel.isLoading = true
        
        Task {
            do {
                // 將重複選項資料傳遞給 viewModel
                viewModel.newTaskRepeatType = repeatOption
                try await viewModel.saveNewTask()
                
                // 任務保存成功後關閉視圖
                dismissWithAnimation()
            } catch {
                // 顯示錯誤訊息
                viewModel.errorMessage = error.localizedDescription
                viewModel.isLoading = false
                print("Error saving task: \(error.localizedDescription)")
            }
        }
    }
    
    // 更新結束日期基於重複選項
    private func updateEndDateBasedOnRepeatOption(_ option: RepeatType) {
        let calendar = Calendar.current
        
        switch option {
        case .daily:
            // 每天重複，是無限期的，使用與startDate相同的日期
            viewModel.newTaskEndDate = viewModel.newTaskStartDate
        case .weekly:
            // 每週重複，將結束日期設為startDate後一週
            if let oneWeekLater = calendar.date(byAdding: .day, value: 7, to: viewModel.newTaskStartDate) {
                viewModel.newTaskEndDate = oneWeekLater
            }
        case .monthly:
            // 每月重複，將結束日期設為startDate後一個月
            if let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: viewModel.newTaskStartDate) {
                viewModel.newTaskEndDate = oneMonthLater
            }
        default:
            // 不重複，若endDate在startDate之前，則設為startDate
            if viewModel.newTaskEndDate < viewModel.newTaskStartDate {
                viewModel.newTaskEndDate = viewModel.newTaskStartDate
            }
        }
    }
}

// 為了預覽提供空的任務列表
struct TodoAddView_Previews: PreviewProvider {
    @State static var isShown = true
    static var viewModel = TodoViewModel()
    
    static var previews: some View {
        TodoAddView(viewModel: viewModel, isPresented: $isShown, selectedDate: Date())
            .environmentObject(viewModel)
    }
}

// 擴展 View 以支援部分圓角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 自定義形狀以實現部分圓角
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

