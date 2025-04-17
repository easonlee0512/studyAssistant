import SwiftUI

struct StudyTask: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let time: String?
    let color: Color
    var isCompleted: Bool = false
}

struct DailyTaskView: View {
    @State private var tasks = [
        StudyTask(title: "線性代數", note: "備註", time: "整天", color: Color(red: 0.7, green: 0.16, blue: 0.13).opacity(0.4)),
        StudyTask(title: "離散數學", note: "備註", time: "整天", color: Color(red: 0.7, green: 0.56, blue: 0).opacity(0.4)),
        StudyTask(title: "資料結構", note: "備註", time: "10:00 ~ 21:00", color: Color(red: 0.18, green: 0.7, blue: 0.31).opacity(0.4)),
        StudyTask(title: "計算機結構", note: "備註", time: "22:00 ~ 23:00", color: Color(red: 0.29, green: 0.28, blue: 0.7).opacity(0.4)),
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 5) {
                        Text("鼓勵語句")
                            .font(.system(size: 30, weight: .bold))
                        Text("Mar 3, 2025")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Week view
                    WeekView(selectedDay: 3)
                        .padding(.horizontal)
                    
                    // Task list header
                    HStack {
                        Text("To Do List")
                            .font(.system(size: 24, weight: .bold))
                        Spacer()
                        Button(action: {
                            // Add task action
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "E28A5F"))
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Task list
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach($tasks) { $task in
                            TaskRowView(task: $task)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 15)
                }
                .padding(.bottom, 0)
                
                // Bottom navigation
                HStack(spacing: 40) {
                    Button(action: {
                        // Timer action
                    }) {
                        Image("timer_icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Button(action: {
                        // Calendar action
                    }) {
                        Image("calendar_icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Button(action: {
                        // Home action
                    }) {
                        Image("home_icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                    
                    Button(action: {
                        // Message action
                    }) {
                        Image("chat_icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Button(action: {
                        // Settings action
                    }) {
                        Image("settings_icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                .padding(.top, 20)
                .padding(.vertical, 4)
                .padding(.horizontal, 27)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "FEECD8"))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -2)
            }
        }
    }
}

struct WeekView: View {
    let days = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]
    let dates = [2, 3, 4, 5, 6, 7, 8]
    let selectedDay: Int
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7) { index in
                VStack(spacing: 5) {
                    Text(days[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dates[index] == selectedDay ? .black : Color(hex: "222222"))
                    
                    Text("\(dates[index])")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(width: (373 - 24) / 7, height: 78)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(dates[index] == selectedDay ? Color(red: 0.86, green: 0.55, blue: 0.38, opacity: 0.9) : Color(hex: "FEECD8"))
                )
            }
        }
        .padding(.leading, 0)
        .padding(.trailing, 1)
        .padding(.vertical, 0.84615)
        .frame(width: 373, alignment: .center)
        .background(Color(hex: "FEECD8"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 1, y: 1)
    }
}

struct TaskRowView: View {
    @Binding var task: StudyTask
    
    var body: some View {
        HStack {
            
            Image("task")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 20, weight: .semibold))
                Text(task.note)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.6))
                if let time = task.time {
                    Text(time)
                        .font(.system(size: 15))
                }
            }
            .padding(.leading, 10)
            
            Spacer()
            
            Button(action: {
                task.isCompleted.toggle()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(task.color)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.09), radius: 10, x: 3, y: 3)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    DailyTaskView()
}
