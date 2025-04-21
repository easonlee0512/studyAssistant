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
    @Binding var tasks: [TodoTask] // 添加对任务列表的绑定
    @Binding var isPresented: Bool // 添加绑定属性来控制显示状态
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 默认一小时后
    @State private var category: String = "未分類"
    @State private var repeat_option: String = "不重複"
    @State private var selectedColor: Color = Color(red: 178/255, green: 41/255, blue: 34/255, opacity: 0.4) // 默认颜色
    @State private var offset: CGFloat = UIScreen.main.bounds.height // 用于动画
    @State private var isDismissing = false // 标记是否正在关闭
    
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
            // 半透明背景覆盖整个屏幕，点击可关闭
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissWithAnimation()
                }
                .opacity(isDismissing ? 0 : 1) // 消失动画
            
            // 主内容区域 - 向下移动形成模态卡片
            VStack(spacing: 0) {
                // 顶部小横条，用于拖动
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 15)
                
                // 标题栏
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
                        saveTask() // 调用保存任务的方法
                        dismissWithAnimation()
                    }
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue.opacity(title.isEmpty ? 0.5 : 1))
                    .disabled(title.isEmpty) // 如果标题为空则禁用按钮
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 标题输入框
                        TextField("標題", text: $title)
                            .font(.system(size: 24, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        
                        Divider()
                            .background(dividerColor)
                            .padding(.horizontal, 20)
                        
                        // 全天开关
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
                        
                        // 开始时间选择器
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
                        
                        // 结束时间选择器
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
                        
                        // 颜色选择
                        VStack(alignment: .leading) {
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        
                        Divider()
                            .background(dividerColor)
                            .padding(.horizontal, 20)
                        
                        // 内容输入区域
                        VStack(alignment: .leading) {
                            Text("內容")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(placeholderColor)
                                .padding(.bottom, 10)
                            
                            TextEditor(text: $content)
                                .frame(minHeight: 120)
                                .font(.system(size: 18))
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        
                        Divider()
                            .background(dividerColor)
                            .padding(.horizontal, 20)
                        
                        // 重复选项
                        HStack {
                            Text("重複")
                                .font(.system(size: 18, weight: .medium))
                            
                            Spacer()
                            
                            Text(repeat_option)
                                .font(.system(size: 18, weight: .medium))
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 打开重复选项
                        }
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.7) // 控制最大高度
            }
            .background(backgroundColor)
            .cornerRadius(25, corners: [.topLeft, .topRight]) // 顶部圆角
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
            .offset(y: offset) // 应用偏移动画
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset) // 添加弹簧动画
            .edgesIgnoringSafeArea(.bottom) // 忽略底部安全区域
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
                            offset = 0 // 如果拖动不够长，恢复位置
                        }
                    }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            // 显示时从底部滑出
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
            startDate: startDate,
            color: selectedColor,
            isCompleted: false
        )
        
        // 将新任务添加到任务列表
        tasks.append(newTask)
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

// 为了预览提供空的任务列表
struct TodoAddView_Previews: PreviewProvider {
    @State static var mockTasks: [TodoTask] = []
    @State static var isShown = true
    
    static var previews: some View {
        TodoAddView(tasks: $mockTasks, isPresented: $isShown)
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
