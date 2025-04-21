// import SwiftUI

// /// 日历网格视图组件，负责显示日期和处理日期选择
// struct CalendarGridView: View {
//     let calendarData: [[String]]
//     let isCurrentMonth: (Int, Int) -> Bool
//     let selectDate: (Int, Int) -> Void
    
//     var body: some View {
//         GeometryReader { geometry in
//             ZStack {
//                 // 日期網格
//                 VStack(spacing: 8) {
//                     ForEach(0..<6) { row in
//                         HStack(spacing: 0) {
//                             ForEach(0..<7) { column in
//                                 VStack {
//                                     Text(calendarData[row][column])
//                                         .font(Font.custom("Roboto", size: 15))
//                                         .tracking(0.5)
//                                         .foregroundColor(isCurrentMonth(row, column) ? .black : Color.black.opacity(0.25))
//                                         .frame(maxWidth: .infinity, alignment: .top)
                                    
//                                     Spacer()
//                                 }
//                                 .frame(width: geometry.size.width / 7,
//                                        height: (geometry.size.height / 6) - 8)
//                                 .contentShape(Rectangle())
//                                 .onTapGesture {
//                                     selectDate(row, column)
//                                 }
//                             }
//                         }
//                     }
//                 }
//                 .padding(.top, 5)
//             }
//         }
//     }
// } 