import SwiftUICore
import SwiftUI
struct CalendarView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "選擇日期",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                List {
                    Text("當日事項")
                    Text("當日待辦")
                    Text("當日筆記")
                }
            }
            .navigationTitle("日曆")
        }
    }
}
