import SwiftUI

struct TestCalenderView: View {
    // 簡化為靜態數據，不再需要日期計算邏輯
    let monthTitle = "2025 Mar"
    let weekdays = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
    
    // 預設2025年3月的日期數據（基於截圖）
    let days: [[String]] = [
        ["30", "31", "1", "2", "3", "4", "5"],
        ["6", "7", "8", "9", "10", "11", "12"],
        ["13", "14", "15", "16", "17", "18", "19"],
        ["20", "21", "22", "23", "24", "25", "26"],
        ["27", "28", "29", "30", "1", "2", "3"],
        ["4", "5", "6", "7", "8", "9", "10"]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 添加頂部空間，將年份月份往下移
            Spacer()
                .frame(height: 40)
                
            // 頂部月份標題
            HStack {
                Text(monthTitle)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            // 在星期標題前添加額外空間
            Spacer()
                .frame(height: 20)
                
            // 星期標題行
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(Color(UIColor.systemGray6))
            
            // 日期網格 - 占滿剩餘空間
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ForEach(0..<6) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7) { column in
                                Text(days[row][column])
                                    .font(.body)
                                    .fontWeight(isCurrentMonth(row, column) ? .medium : .light)
                                    .foregroundColor(isCurrentMonth(row, column) ? .primary : .gray)
                                    .frame(width: geometry.size.width / 7, height: geometry.size.height / 6)
                            }
                        }
                    }
                }
            }
            
            // 底部工具列
            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "calendar")
                        .font(.title)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "house.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "message")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 15)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 3, y: -3)
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all) // 讓視圖佔滿全螢幕
    }
    
    // 簡單判斷是否為當前月份的日期（根據固定數據）
    private func isCurrentMonth(_ row: Int, _ column: Int) -> Bool {
        let day = days[row][column]
        if (row == 0 && (column == 0 || column == 1)) || 
           (row == 4 && column >= 4) || 
           (row == 5) {
            return false
        }
        return true
    }
}

struct TestCalenderView_Previews: PreviewProvider {
    static var previews: some View {
        TestCalenderView()
    }
}
