//
//  testtododetailviews.swift
//  studyAssistant
//
//  Created by 李翊辰 on 2025/4/30.
//
import SwiftUI
import SwiftUICore
import FirebaseFirestore
import FirebaseAuth
// 添加 Date 擴展的引用

// MARK: - 任務詳情視圖
struct TodoDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TodoViewModel
    let date: Date
    @Binding var isPresented: Bool
    
    // Figma中使用的顏色
    let backgroundColor = Color.hex(hex: "FEECD8") // #FEECD8
    let dividerColor = Color.black
    let addButtonColor = Color.hex(hex: "E28A5F") // #E28A5F 約等於 rgb(226, 138, 95)
    
    var filteredTasks: [TodoTask] {
        viewModel.tasksForDate(date).sorted { task1, task2 in
            // 按照開始時間排序
            return task1.startDate < task2.startDate
        }
    }
    
    var body: some View {
        ZStack {
            Color.clear
            
            // 卡片式容器
            VStack(spacing: 0) {
                // 頭部日期和關閉按鈕
                HStack {
                    Text(dateFormatted)
                        .font(.system(size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPresented = false
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hex(hex: "F3D4B7"))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                                )
                            
                            Text("✕")
                                .font(.system(size: 20))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 15)
                .padding(.bottom, 10)
    
                // 分隔線
                Divider()
                    .background(dividerColor)
                    .padding(.horizontal, 16)
                
                // 沒有待辦事項時顯示的訊息
                if filteredTasks.isEmpty {
                    // 與有任務時同樣放在 ScrollView → LazyVStack，排版就完全一致
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            Text("沒有待辦事項")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)      // 想要一點緩衝就加這行
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    // 滾動事項列表
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredTasks) { task in
                                // 獲取該任務在當前日期的實例
                                let instances = viewModel.getInstancesForDate(date, task: task)
                                
                                if !instances.isEmpty {
                                    // 顯示每個實例
                                    ForEach(instances) { instance in
                                        todoInstanceCard(task: task, instance: instance)
                                            .frame(height: 90)
                                    }
                                } else {
                                    // 如果沒有實例但任務應該顯示在這一天，顯示任務本身
                                    todoCard(task: task)
                                        .frame(height: 90)
                                }
                            }
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(
                minWidth: 0,
                maxWidth: min(UIScreen.main.bounds.width * 0.95, 400),
                minHeight: 0,
                maxHeight: min(UIScreen.main.bounds.height * 0.7, 500)
            )
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // 待辦事項卡片視圖
    func todoCard(task: TodoTask) -> some View {
        HStack(spacing: 0) {
            // 背景色塊
            RoundedRectangle(cornerRadius: 16)
                .fill(task.color)
                .frame(maxWidth: 10, maxHeight: .infinity)
            
            // 內容
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(task.title)
                        .font(.system(size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(task.formattedTime)
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.top, 5)
                
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 15))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: 90)
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(16)
    }
    
    // 任務實例卡片視圖
    func todoInstanceCard(task: TodoTask, instance: TaskInstance) -> some View {
        HStack(spacing: 0) {
            // 背景色塊
            RoundedRectangle(cornerRadius: 16)
                .fill(task.color)
                .frame(maxWidth: 10, maxHeight: .infinity)
            
            // 內容
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(task.title)
                        .font(.system(size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(instance.isCompleted ? .gray : .black)
                        .strikethrough(instance.isCompleted)
                    
                    Spacer()
                    
                    Text(task.formattedTime)
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.top, 5)
                
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 15))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                // 實例完成狀態
                HStack {
                    Spacer()
                    Text(instance.isCompleted ? "已完成" : "未完成")
                        .font(.system(size: 12))
                        .foregroundColor(instance.isCompleted ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(instance.isCompleted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        )
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: 90)
        .background(Color.hex(hex: "FEECD8"))
        .cornerRadius(16)
    }
    
    // MARK: - 格式化日期
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// 預覽提供者
#if DEBUG
struct TodoDetailView_Previews: PreviewProvider {
    @State static var isPresented = true
    static var viewModel = TodoViewModel()
    
    static var previews: some View {
        ZStack {
            Color(.systemGray6)
                .edgesIgnoringSafeArea(.all)
            TodoDetailView(
                viewModel: viewModel,
                date: Date(),
                isPresented: $isPresented
            )
            .environmentObject(viewModel)
        }
        .previewDevice("iPhone 13")
    }
}
#endif

