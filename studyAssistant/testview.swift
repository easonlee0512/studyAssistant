import SwiftUI

struct HomeView: View {
    // 修改 TodoItem 的名稱，避免衝突
    struct HomeViewTodoItem: Identifiable {
        let id = UUID()
        var title: String
        var isCompleted: Bool = false
    }
    
    // 更新 HomeView 中的狀態變量
    @State private var todoItems: [HomeViewTodoItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主要內容區域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 鼓勵語句和日期區塊
                    VStack(alignment: .leading, spacing: 8) {
                        Text("鼓勵語句")
                            .font(.system(size: 28, weight: .bold))
                        Text("Mar 21, 2025")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // 星期和日期行 - 修改為每個星期和日期在同一個背景中
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            let dates = [13, 14, 15, 16, 17, 18, 19]
                            
                            VStack(spacing: 4) {
                                Text(weekdays[index])
                                    .font(.subheadline)
                                
                                Text("\(dates[index])")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 36, height: 36)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // To Do List 區域
                    HStack {
                        Text("To Do List")
                            .font(.system(size: 28, weight: .bold))
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(Color(UIColor.darkGray))
                                .frame(width: 30, height: 30)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // 空白的待辦事項列表 - 加厚框
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 80)
                            .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            
            // 底部導航欄
            HStack {
                Button(action: {}) {
                    Image(systemName: "play.circle")
                        .font(.title)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "calendar")
                        .font(.title)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "house.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.gray)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "message")
                        .font(.title)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.title)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 2, y: -1)
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
