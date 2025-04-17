import SwiftUI

struct TestCalenderView: View {
    // 簡化為靜態數據，不再需要日期計算邏輯
    let monthTitle = "2025 Mar"
    let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    
    // 預設2025年3月的日期數據（基於Figma设计）
    let days: [[String]] = [
        ["23", "24", "25", "26", "27", "28", "1"],
        ["2", "3", "4", "5", "6", "7", "8"],
        ["9", "10", "11", "12", "13", "14", "15"],
        ["16", "17", "18", "19", "20", "21", "22"],
        ["23", "24", "25", "26", "27", "28", "29"],
        ["30", "31", "1", "2", "3", "4", "5"]
    ]
    
    // 課程數據結構
    struct Course {
        let name: String
        let color: Color
        let row: Int
        let column: Int
        let shortName: String?
    }
    
    // 預設課程數據 - 根據Figma設計擺放
    let courses: [Course] = [
        Course(name: "線性代數", color: Color(red: 178/255, green: 41/255, blue: 34/255), row: 1, column: 2, shortName: nil),
        Course(name: "離散數學", color: Color(red: 178/255, green: 143/255, blue: 0/255), row: 1, column: 5, shortName: nil),
        Course(name: "資料結構", color: Color(red: 47/255, green: 178/255, blue: 80/255), row: 2, column: 3, shortName: nil),
        Course(name: "計算機結構", color: Color(red: 73/255, green: 72/255, blue: 178/255), row: 2, column: 5, shortName: "季節"),
        Course(name: "演算法作業", color: Color(red: 0/255, green: 178/255, blue: 170/255), row: 3, column: 1, shortName: "演算")
    ]
    
    // 附加日程標記
    struct ExtraMarker {
        let text: String
        let color: Color
        let row: Int
        let column: Int
    }
    
    let extraMarkers: [ExtraMarker] = [
        ExtraMarker(text: "+2", color: Color(.lightGray), row: 3, column: 5)
    ]
    
    // Figma 設計中的顏色
    let backgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255) // #F3D4B7
    let bottomBarColor = Color(red: 254/255, green: 236/255, blue: 216/255) // #FEECD8
    let weekdayBackgroundColor = Color(red: 243/255, green: 212/255, blue: 183/255, opacity: 0.32)
    
    var body: some View {
        VStack(spacing: 0) {
            // 月曆內容
            VStack(spacing: 0) {
                // 標題和加號按鈕
                HStack {
                    Spacer()
                    Text(monthTitle)
                        .font(Font.custom("PingFang TC", size: 24).weight(.medium))
                        .kerning(0.5)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.89, green: 0.54, blue: 0.37, opacity: 0.8))
                            .frame(width: 30, height: 30)
                        
                        Text("+")
                            .font(Font.custom("Inter", size: 30))
                            .foregroundColor(Color(red: 0.97, green: 0.87, blue: 0.78))
                            .offset(x: 0, y: -2)
                    }
                    .padding(.trailing, 30)
                }
                .padding(.top, 20)
                .padding(20)
                
                // 星期標題行
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 15))
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 5)
                .padding(.bottom, 0)
                
                // 日期網格
                GeometryReader { geometry in
                    ZStack {
                        // 日期文字
                        VStack(spacing: 0) {
                            ForEach(0..<6) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<7) { column in
                                        Text(days[row][column])
                                            .font(Font.custom("Roboto", size: 15))
                                            .tracking(0.5)
                                            .foregroundColor(isCurrentMonth(row, column) ? .black : Color.black.opacity(0.25))
                                            .frame(width: geometry.size.width / 7, height: geometry.size.height / 6)
                                    }
                                }
                            }
                        }
                        
                        // 課程方塊
                        ForEach(0..<courses.count, id: \.self) { index in
                            let course = courses[index]
                            let cellWidth = geometry.size.width / 7
                            let cellHeight = geometry.size.height / 6
                            
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(course.color.opacity(0.4))
                                    .shadow(color: Color.black.opacity(0.09), radius: 3, x: 3, y: 3)
                                
                                Text(course.shortName ?? course.name)
                                    .font(.system(size: 10))
                                    .tracking(0.5)
                                    .foregroundColor(.black)
                                    .padding(.leading, 5)
                                    .padding(.top, 3)
                            }
                            .frame(width: cellWidth * 0.9, height: cellHeight * 0.3)
                            .position(
                                x: cellWidth * (CGFloat(course.column) + 0.5),
                                y: cellHeight * (CGFloat(course.row) + 0.45)
                            )
                        }
                        
                        // 附加標記
                        ForEach(0..<extraMarkers.count, id: \.self) { index in
                            let marker = extraMarkers[index]
                            let cellWidth = geometry.size.width / 7
                            let cellHeight = geometry.size.height / 6
                            
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(marker.color.opacity(0.4))
                                    .shadow(color: Color.black.opacity(0.09), radius: 3, x: 3, y: 3)
                                
                                Text(marker.text)
                                    .font(.system(size: 10))
                                    .tracking(0.5)
                                    .foregroundColor(.black)
                                    .padding(.leading, 5)
                                    .padding(.top, 3)
                            }
                            .frame(width: cellWidth * 0.9, height: cellHeight * 0.3)
                            .position(
                                x: cellWidth * (CGFloat(marker.column) + 0.5),
                                y: cellHeight * (CGFloat(marker.row) + 0.45)
                            )
                        }
                    }
                }
                .padding(.top, -5) // 讓日期更接近星期標題
            }
            .padding(.horizontal)
            .background(backgroundColor)
            .frame(maxHeight: .infinity)
            
            // 底部工具列
            HStack(spacing: 36) {
                Button(action: {}) {
                    Image(systemName: "timer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.black.opacity(0.7))
                }
                
                Button(action: {}) {
                    Image(systemName: "calendar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.black)
                }
                
                Button(action: {}) {
                    Image(systemName: "house")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.black.opacity(0.7))
                }
                
                Button(action: {}) {
                    Image(systemName: "message")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.black.opacity(0.7))
                }
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.black.opacity(0.7))
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 27)
            .frame(maxWidth: .infinity)
            .background(bottomBarColor)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // 判斷是否為當前月份的日期
    private func isCurrentMonth(_ row: Int, _ column: Int) -> Bool {
        if (row == 0 && column < 6) ||
           (row == 5 && column > 1) {
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
