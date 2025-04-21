import SwiftUI

struct TimerView: View {
    @State private var timeRemaining: TimeInterval = 1800 // 默認為30分鐘
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var subject = "線性代數"
    @State private var selectedTab = 2 // 默認選中計時器頁簽
    @State private var progress: Double = 0.167 // 进度值，0.0-1.0之间，默認30分鐘(30/180)
    @State private var isCountUp = false // 控制是否為正向計時
    @State private var elapsedTime: TimeInterval = 0 // 正向計時已經過的時間
    @State private var isDragging = false // 是否正在拖動
    @State private var selectedTime: Int = 30 // 默認選中30分鐘
    
    // 時間範圍（10分鐘到3小時）
    let minTime: Int = 10 // 最少10分鐘
    let maxTime: Int = 180 // 最多3小時
    
    var body: some View {
        ZStack {
            // Background color - Figma 精確顏色
            Color(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Countdown/Countup toggle button in a fixed-height container
                VStack {
                    Button(action: {
                        // 切換倒數/正數計時模式
                        if !isRunning {
                            toggleCountMode()
                        }
                    }) {
                        ZStack {
                            // 外層陰影
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "E09772"))
//                                .shadow(color: .black, radius: 5)
                            
//                            // 上方亮光效果增加立體感
//                            RoundedRectangle(cornerRadius: 20)
//                                .fill(LinearGradient(
//                                    gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
//                                    startPoint: .top,
//                                    endPoint: .center
//                                ))
//                                .padding(1)
                            
                            Text(isCountUp ? "COUNT" : "COUNTDOWN")
                                .font(.custom("Inder", size: 20))
                                .tracking(0.5)
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 180, height: 50)
                    }
//                    // 為整個按鈕添加陰影 - 更集中
//                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .padding(.top, 40)
                    .disabled(isRunning) // 計時中不可切換模式
                }
                .frame(height: 100) // 固定頂部區域高度
                
                Spacer()
                
                // Timer circle group - 根據新圖片修改
                ZStack {
                    // 圓形外部陰影
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 280, height: 280)
                        /*.shadow(color: Color(hex: "D9BDA9").opacity(0.5), radius: 18, x: 0, y: 4) // 更集中的陰影*/
                    
                    // 淺色背景圓環 - 使用填充色而非描邊
                    Circle()
                        .fill(Color(hex: "F2D7CB"))
                        .frame(width: 280, height: 280)
//                        .shadow(color: .black, radius: 5)
                    
                    // 白色內圓
                    Circle()
                        .fill(Color(hex: "F5ECE3")) // 比原本的 #FDF8F3 更深，更接近圖中效果
                        .frame(width: 240, height: 240)
                    
                    // 灰色進度背景環
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(
                            Color(hex: "F2D7CB"),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)

                    // 進度指示圓環 - 使用橙色漸變描邊 - 遵循圖片
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "E09772"),
                                    Color(hex: "E87D45")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                    
                    // 時間標記
                    ForEach(0..<12) { i in
                        let angle = Double(i) * (Double.pi * 2) / 12
                        let length: CGFloat = i % 3 == 0 ? 110 : 118
                        let width: CGFloat = i % 3 == 0 ? 2 : 1
                        let color = Color(hex: i % 3 == 0 ? "E09772" : "D9BDA9").opacity(i % 3 == 0 ? 0.8 : 0.4)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: width, height: 8)
                            .offset(y: -length)
                            .rotationEffect(.radians(angle))
                    }
                    
                    // 進度圓點 - 白色小圓點在進度條末端 (可拖動)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2) // 更集中的陰影
                        .overlay(
                            // 橙色邊框
                            Circle()
                                .stroke(Color(hex: "E87D45"), lineWidth: 3)
                        )
                        .offset(
                            x: 130 * cos(2 * .pi * progress - .pi/2),
                            y: 130 * sin(2 * .pi * progress - .pi/2)
                        )
                        .gesture(
                            !isCountUp && !isRunning ?
                            DragGesture()
                                .onChanged { value in
                                    // 計算拖動後的角度
                                    isDragging = true
                                    let center = CGPoint(x: 0, y: 0)
                                    let dragPosition = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
                                    
                                    // 計算角度（弧度）
                                    var angle = atan2(dragPosition.y, dragPosition.x) + .pi/2
                                    if angle < 0 { angle += 2 * .pi }
                                    
                                    // 設置進度 (0-1)
                                    progress = angle / (2 * .pi)
                                    
                                    // 根據進度計算時間（10分鐘到3小時）
                                    let timeRange = Double(maxTime - minTime)
                                    selectedTime = minTime + Int(timeRange * progress)
                                    
                                    // 更新倒數時間
                                    timeRemaining = TimeInterval(selectedTime * 60)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                            : nil
                        )
                    
                    // 使用ZStack確保文字不受其他元素渲染影響
                    ZStack {
                        // 白色背景確保文字清晰
                        Circle()
                            .fill(Color(hex: "F5ECE3"))
                            .frame(width: 200, height: 200)
                        
                        // Timer text and subject
                        VStack(spacing: 5) {
                            // 時間顯示
                            Text(isCountUp ? timeString(time: elapsedTime) : timeString(time: timeRemaining))
                                .font(.custom("PingFang TC", size: 48))
                                .fontWeight(.semibold)
                                .lineSpacing(-16)
                                .foregroundColor(.black)
                            
                            Text(subject)
                                .font(.custom("PingFang TC", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "9F9A9A"))
                        }
                    }
                }
                
                Spacer()
                
                // 控制按鈕區域，固定高度
                VStack {
                    // Control buttons
                    HStack(spacing: 20) {
                        // Reset button
                        Button(action: resetTimer) {
                            ZStack {
                                // 外層陰影
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "E09772"))
//                                    .shadow(color: .black, radius: 5)
        
                                VStack{
                                    Text("重置")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 150, height: 60)
                        }
//                        // 為整個按鈕添加陰影 - 更集中
//                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        
                        // Start/Pause button
                        Button(action: toggleTimer) {
                            ZStack {
                                // 外層陰影
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "E09772"))
//                                    .shadow(color: .black, radius: 5)
                                
                                
                                Text(isRunning ? "暫停" : "開始")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 150, height: 60)
                        }
//                        // 為整個按鈕添加陰影 - 更集中
//                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 80)
                }
                .frame(height: 150) // 固定底部控制區域高度
                
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isCountUp)
    }
    
    // 顯示時間提示
    @State private var showTimeTooltip = false
    
    // 切換倒數/正數計時模式
    func toggleCountMode() {
        isCountUp.toggle()
        resetTimer() // 切換模式時重置計時器
        
        // 切換到正計時模式時
        if isCountUp {
            // 正計時模式下進度從0開始
            progress = 0.0
        } else {
            // 倒數模式下設置為預設30分鐘
            selectedTime = 30
            progress = Double(selectedTime - minTime) / Double(maxTime - minTime)
            timeRemaining = TimeInterval(selectedTime * 60)
        }
    }
    
    // Format time as HH:MM:SS
    func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        // 只有在時間大於等於一小時時才顯示小時部分
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Start or pause the timer
    func toggleTimer() {
        if isRunning {
            timer?.invalidate()
            timer = nil
        } else {
            if isCountUp {
                // 正向計時
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.elapsedTime += 1
                    // 更新正向計時的進度 (每小時為一個週期)
                    let hourInSeconds: TimeInterval = 3600
                    self.progress = (self.elapsedTime.truncatingRemainder(dividingBy: hourInSeconds)) / hourInSeconds
                }
            } else {
                // 倒數計時 - 從當前設置的進度開始倒數
                let initialProgress = progress
                let totalTime = TimeInterval(selectedTime * 60)
                
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                        // 更新倒數計時進度 - 從當前位置開始減少
                        self.progress = self.timeRemaining / totalTime * initialProgress
                    } else {
                        self.timer?.invalidate()
                        self.timer = nil
                        self.isRunning = false
                        self.progress = 0 // 倒數結束時進度歸零
                    }
                }
            }
        }
        
        isRunning.toggle()
    }
    
    // Reset the timer to initial value
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        if isCountUp {
            // 正向計時重置
            elapsedTime = 0
            progress = 0.0
        } else {
            // 倒數計時重置到目前設定的時間
            timeRemaining = TimeInterval(selectedTime * 60)
        }
    }
}

//// 新的底部標籤欄 - 圖標更大且完全置中
//struct TabBarNew: View {
//    @Binding var selectedTab: Int
//    
//    var body: some View {
//        HStack {
//            Spacer()
//            
//            TabButtonNew(icon: "play.circle", isSelected: selectedTab == 0) {
//                selectedTab = 0
//            }
//            
//            Spacer()
//            
//            TabButtonNew(icon: "calendar", isSelected: selectedTab == 1) {
//                selectedTab = 1
//            }
//            
//            Spacer()
//            
//            TabButtonNew(icon: "house.fill", isSelected: selectedTab == 2) {
//                selectedTab = 2
//            }
//            
//            Spacer()
//            
//            TabButtonNew(icon: "bubble.left", isSelected: selectedTab == 3) {
//                selectedTab = 3
//            }
//            
//            Spacer()
//            
//            TabButtonNew(icon: "gearshape.fill", isSelected: selectedTab == 4) {
//                selectedTab = 4
//            }
//            
//            Spacer()
//        }
//        .padding(.vertical, 15)
//        .frame(maxWidth: .infinity) // 確保佔據整個寬度
//        .background(Color(hex: "FEECD8"))
//    }
//}

//// 更大且置中的標籤按鈕
//@available(iOS 17.0, *)
//@available(iOS 17.0, *)
//struct TabButtonNew: View {
//    var icon: String
//    var isSelected: Bool
//    var action: () -> Void
//    
//    @available(iOS 17.0, *)
//    @available(iOS 17.0, *)
//    @available(iOS 17.0, *)
//    var body: some View {
//        Button(action: action) {
//            if #available(iOS 17.0, *) {
//                Image(systemName: icon)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 30, height: 30) // 增加圖標尺寸
//                    .foregroundColor(Color(isSelected ? .black : Color.black.opacity(0.5)))
//            } else {
//                // Fallback on earlier versions
//            }
//        }
//        .frame(width: 44, height: 44) // 確保點擊區域足夠大
//        .contentShape(Rectangle()) // 確保整個區域可點擊
//    }
//}

struct ClockViewWithTabBar_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}

//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue:  Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}
