import SwiftUI

// MARK: - 任務詳情視圖
struct TodoDetailView: View {
    let date: Date // 當前選中的日期
    let todos: [String] // 該日期的待辦事項列表
    @Binding var isPresented: Bool // 控制視圖顯示與隱藏

    var body: some View {
        VStack(spacing: 20) {
            // 顯示日期
            Text(dateFormatted)
                .font(.title)
                .fontWeight(.bold)

            // MARK: - 待辦事項列表
            List(todos, id: \.self) { todo in
                Text(todo) // 顯示每個待辦事項
            }
            .frame(height: 200) // 限制列表高度
            .clipShape(RoundedRectangle(cornerRadius: 15)) // 圓角設計

            // MARK: - 關閉按鈕
            Button("關閉") {
                isPresented = false // 點擊按鈕後關閉視圖
            }
            .padding()
            .background(Color.blue) // 設置按鈕背景顏色
            .foregroundColor(.white) // 設置按鈕文字顏色
            .clipShape(RoundedRectangle(cornerRadius: 10)) // 設置圓角

        }
        .padding()
        .frame(width: 300, height: 350) // 設置視圖大小
        .background(Color.white) // 設置視圖背景顏色
        .clipShape(RoundedRectangle(cornerRadius: 20)) // 設置視圖圓角
        .shadow(radius: 10) // 添加陰影效果
    }

    // MARK: - 格式化日期
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long // 設置日期顯示格式（長格式，如 2025年3月18日）
        return formatter.string(from: date)
    }
}
