import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var showingDetail = false
    @State private var todos: [String] = ["買牛奶", "完成 Swift 專案", "運動 30 分鐘"]
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack {
                    DatePicker(
                        "選擇日期",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .onTapGesture {
                        showingDetail = true
                    }
                }
                .navigationTitle("日曆")
            }
            
            // 彈出視窗
            if showingDetail {
                Color.black.opacity(0.4) // 半透明背景
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingDetail = false
                    }
                
                TodoDetailView(date: selectedDate, todos: todos, isPresented: $showingDetail)
                    .transition(.scale)
                    .zIndex(1)
            }
        }
    }
}

// 彈出視窗視圖

#Preview{
    CalendarView()
}
