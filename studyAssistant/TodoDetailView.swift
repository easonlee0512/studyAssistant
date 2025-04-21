import SwiftUI
import SwiftUICore

// MARK: - 任務詳情視圖
struct TodoDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let date: Date // 當前選中的日期
    let todos: [String] // 該日期的待辦事項列表
    @Binding var isPresented: Bool // 控制視圖顯示與隱藏
    
    // 待辦事項項目模型
    struct TodoItem: Identifiable {
        let id = UUID()
        let title: String
        let color: Color
        
        // 隨機生成顏色
        static func randomColor() -> Color {
            let colors: [Color] = [
                Color(red: 255/255, green: 59/255, blue: 48/255, opacity: 0.7),
                Color(red: 253/255, green: 218/255, blue: 75/255, opacity: 0.7),
                Color(red: 111/255, green: 214/255, blue: 137/255, opacity: 0.7),
                Color(red: 137/255, green: 135/255, blue: 225/255, opacity: 0.7),
                Color(red: 75/255, green: 160/255, blue: 253/255, opacity: 0.7)
            ]
            return colors[Int.random(in: 0..<colors.count)]
        }
    }
    
    // 將字符串轉換為帶有隨機顏色的TodoItem
    private var todoItems: [TodoItem] {
        return todos.map { TodoItem(title: $0, color: TodoItem.randomColor()) }
    }
    
    // Figma中使用的顏色
    let backgroundColor = Color(hex: "FEECD8") // #FEECD8
    let dividerColor = Color.black
    let addButtonColor = Color(hex: "E28A5F") // #E28A5F 約等於 rgb(226, 138, 95)
    
    var body: some View {
        ZStack {
            Color.clear
            
            // 卡片式容器
            VStack(spacing: 0) {
                // 頭部日期和關閉按鈕
                HStack {
                    Text(dateFormatted)
                        .font(.custom("PingFang TC", size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "F3D4B7")) // 淺棕色
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
                    
                    // 添加按鈕
                    Button(action: {
                        // 添加新事項的操作
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(addButtonColor)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                                )
                            
                            Text("+")
                                .font(.system(size: 26))
                                .foregroundColor(Color.black.opacity(0.7))
                                .offset(y: -2)
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
                if todoItems.isEmpty {
                    VStack {
                        Spacer()
                        Text("沒有待辦事項")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(height: 300)
                } else {
                    // 滾動事項列表
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(todoItems) { item in
                                todoCard(todo: item)
                                    .frame(height: 90)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(width: 353, height: 440)
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // 待辦事項卡片視圖
    func todoCard(todo: TodoItem) -> some View {
        ZStack(alignment: .topLeading) {
            // 背景色塊
            RoundedRectangle(cornerRadius: 16)
                .fill(todo.color)
                .frame(maxWidth: .infinity, maxHeight: 90)
            
            // 內容
            VStack(alignment: .leading, spacing: 5) {
                Text(todo.title)
                    .font(.custom("PingFang TC", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.top, 5)
                
                Spacer()
                
                // 日期顯示
                Text(timeFormatted)
                    .font(.custom("PingFang TC", size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))
                    .padding(.bottom, 5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 格式化日期
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    // MARK: - 格式化時間
    private var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

// 預覽提供者
#if DEBUG
struct TodoDetailView_Previews: PreviewProvider {
    @State static var isPresented = true
    
    static var previews: some View {
        ZStack {
            Color(.systemGray6)
                .edgesIgnoringSafeArea(.all)
            TodoDetailView(
                date: Date(),
                todos: ["完成數學作業", "準備英文演講", "讀完物理課本第五章", "健身1小時"],
                isPresented: $isPresented
            )
        }
        .previewDevice("iPhone 13")
    }
}
#endif
