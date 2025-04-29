//
//  testTodoaddView.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/21.
//
import SwiftUI
import SwiftUICore

struct TodoAddView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var allTasks: AllTasks // 全域任務環境物件
    @Binding var isPresented: Bool // 添加绑定属性来控制显示状态
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 默认一小时后
    @State private var category: String = "未分類"
    @State private var repeat_option: RepeatType = .none
    @State private var selectedColor: Color = Color(red: 178/255, green: 41/255, blue: 34/255, opacity: 0.4) // 默认颜色
    @State private var offset: CGFloat = UIScreen.main.bounds.height // 用于动画
    @State private var isDismissing = false // 标记是否正在关闭
    
    // 重複選項
    let repeatOptions: [RepeatType] = [
        .none,
        .daily,
        .weekly([Calendar.current.component(.weekday, from: Date())]),  // 當前星期幾
        .monthly([Calendar.current.component(.day, from: Date())])      // 當前日期
    ]
    
    // 预定义的颜色选项
    let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)
    ]
    
    // Figma 设计中的颜色
    let backgroundColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255) // #BCAFA0
    let textColor = Color.black
    let placeholderColor = Color.black.opacity(0.2)
    let categoryColor = Color(red: 178/255, green: 41/255, blue: 34/255, opacity: 0.4)
    let mainBackgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    
    var body: some View {
        ZStack {
            BackgroundView(isDismissing: $isDismissing, dismissAction: dismissWithAnimation)
            
            MainContentView(
                title: $title,
                content: $content,
                isAllDay: $isAllDay,
                startDate: $startDate,
                endDate: $endDate,
                selectedColor: $selectedColor,
                repeat_option: $repeat_option,
                repeatOptions: repeatOptions,
                offset: $offset,
                isDismissing: $isDismissing,
                dismissAction: dismissWithAnimation,
                saveAction: saveTask
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                offset = 0
            }
        }
    }
    
    // 关闭视图带动画
    private func dismissWithAnimation() {
        isDismissing = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = UIScreen.main.bounds.height
        }
        
        // 延迟关闭以等待动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false // 更新父视图中的状态
        }
    }
    
    // 保存任务的方法
    private func saveTask() {
        // 创建新任务
        let newTask = TodoTask(
            title: title,
            note: content,
            color: selectedColor,
            focusTime: 0,  // 默认专注时间为0
            category: category,
            isAllDay: isAllDay,
            isCompleted: false,
            repeatType: repeat_option,
            startDate: startDate,
            endDate: endDate,
            createdAt: Date()  // 使用当前时间作为创建时间
        )
        // 将新任务添加到全域任务列表
        allTasks.tasks.append(newTask)
        // 新增後自動關閉新增視窗
        isPresented = false
    }
    
    // 格式化日期
    private func formatDate(_ date: Date, isDateOnly: Bool) -> String {
        let formatter = DateFormatter()
        if isDateOnly {
            formatter.dateFormat = "M月 d日 EEE"
        } else {
            formatter.dateFormat = "HH:mm"
        }
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 背景視圖
private struct BackgroundView: View {
    @Binding var isDismissing: Bool
    let dismissAction: () -> Void
    
    var body: some View {
        Color.black.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture(perform: dismissAction)
            .opacity(isDismissing ? 0 : 1)
    }
}

// 主要內容視圖
private struct MainContentView: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var isAllDay: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedColor: Color
    @Binding var repeat_option: RepeatType
    let repeatOptions: [RepeatType]
    @Binding var offset: CGFloat
    @Binding var isDismissing: Bool
    let dismissAction: () -> Void
    let saveAction: () -> Void
    
    // Figma 设计中的颜色
    let backgroundColor = Color(red: 254/255, green: 236/255, blue: 216/255)
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    
    var body: some View {
        VStack(spacing: 0) {
            DragIndicator()
            HeaderView(title: $title, dismissAction: dismissAction, saveAction: saveAction)
            
            ScrollView {
                VStack(spacing: 0) {
                    InputFieldsView(title: $title, content: $content)
                    AllDayToggleView(isAllDay: $isAllDay)
                    DatePickersView(isAllDay: $isAllDay, startDate: $startDate, endDate: $endDate)
                    ColorPickerView(selectedColor: $selectedColor)
                    RepeatOptionView(repeat_option: $repeat_option, repeatOptions: repeatOptions)
                }
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
                        dismissAction()
                    } else {
                        offset = 0
                    }
                }
        )
    }
}

// 拖動指示器
private struct DragIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.gray.opacity(0.6))
            .frame(width: 40, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 15)
    }
}

// 頭部視圖
private struct HeaderView: View {
    @Binding var title: String
    let dismissAction: () -> Void
    let saveAction: () -> Void
    
    var body: some View {
        HStack {
            Button("取消", action: dismissAction)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
            
            Spacer()
            
            Text("新增任務")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button("儲存", action: saveAction)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue.opacity(title.isEmpty ? 0.5 : 1))
                .disabled(title.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
}

// 輸入欄位視圖
private struct InputFieldsView: View {
    @Binding var title: String
    @Binding var content: String
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("標題", text: $title)
                .font(.system(size: 24, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 20)
            
            TextField("內容", text: $content)
                .font(.system(size: 18))
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 20)
        }
    }
}

// 全天切換視圖
private struct AllDayToggleView: View {
    @Binding var isAllDay: Bool
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("整天")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                Toggle("", isOn: $isAllDay)
                    .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 20)
        }
    }
}

// 日期選擇器視圖
private struct DatePickersView: View {
    @Binding var isAllDay: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("開始")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if isAllDay {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 20)
            
            HStack {
                Text("結束")
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
                
                if isAllDay {
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 20)
        }
    }
}

// 顏色選擇器視圖
private struct ColorPickerView: View {
    @Binding var selectedColor: Color
    let dividerColor = Color(red: 188/255, green: 175/255, blue: 160/255)
    
    let colorOptions: [Color] = [
        Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4),
        Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4),
        Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4),
        Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("顏色")
                .font(.system(size: 18, weight: .medium))
                .padding(.bottom, 10)
            
            HStack(spacing: 15) {
                ForEach(colorOptions, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
            
            Divider()
                .background(dividerColor)
                .padding(.horizontal, 10)
                .padding(.top, 15)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

// 重複選項視圖
private struct RepeatOptionView: View {
    @Binding var repeat_option: RepeatType
    let repeatOptions: [RepeatType]
    
    func getRepeatOptionText(_ option: RepeatType) -> String {
        switch option {
        case .none:
            return "不重複"
        case .daily:
            return "每天"
        case .weekly(let days):
            return "每週"
        case .monthly(let days):
            return "每月"
        }
    }
    
    var body: some View {
        HStack {
            Text("重複")
                .font(.system(size: 18, weight: .medium))
            
            Spacer()
            
            Picker("", selection: $repeat_option) {
                ForEach(repeatOptions, id: \.self) { option in
                    Text(getRepeatOptionText(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.black)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

// 为了预览提供空的任务列表
struct TodoAddView_Previews: PreviewProvider {
    @State static var mockTasks: [TodoTask] = []
    @State static var isShown = true
    
    static var previews: some View {
        TodoAddView(isPresented: $isShown)
    }
}

// 扩展View以支持部分圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 自定义形状以实现部分圆角
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
