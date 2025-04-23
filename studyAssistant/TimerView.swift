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
    
    // 新增用於時間滾輪選擇器的狀態
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0
    @State private var lastDragValue: Int = 0
    
    // 更改為記住上一次設定時間的變數
    @State private var lastUsedHours: Int = 0
    @State private var lastUsedMinutes: Int = 30
    @State private var lastUsedSeconds: Int = 0
    @State private var hasUsedBefore: Bool = false // 標記是否已經使用過
    
    // 時間範圍（10分鐘到3小時）
    let minTime: Int = 0 // 最少10分鐘
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
                                    
                                    // 更新時分秒
                                    updateTimeComponents()
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
                            // 統一使用HStack顯示時間，確保計時前後格式一致
                            HStack(spacing: 1) {
                                // 小時部分
                                if isRunning || isCountUp {
                                    // 運行時或正計時模式顯示固定數字
                                    Text(String(format: "%02d", isCountUp ? Int(elapsedTime) / 3600 : hours))
                                        .font(.custom("PingFang TC", size: 35))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(width: 60)
                                        .transition(.opacity)
                                } else {
                                    // 倒數計時非運行狀態 - 可滑動調整
                                    TimePickerWheel(
                                        value: $hours,
                                        range: 0...3, // 確保小時範圍為0-3
                                        isEnabled: !isRunning && !isCountUp,
                                        timeComponent: .hours
                                    )
                                    .transition(.opacity)
                                }
                                
                                Text(":")
                                    .font(.custom("PingFang TC", size: 35))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                
                                // 分鐘部分
                                if isRunning || isCountUp {
                                    // 運行時或正計時模式顯示固定數字
                                    Text(String(format: "%02d", isCountUp ? (Int(elapsedTime) / 60) % 60 : minutes))
                                        .font(.custom("PingFang TC", size: 35))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(width: 60)
                                        .transition(.opacity)
                                } else {
                                    // 倒數計時非運行狀態 - 可滑動調整
                                    TimePickerWheel(
                                        value: $minutes,
                                        range: 0...59,
                                        isEnabled: !isRunning && !isCountUp && hours < 3, // 當小時為3時禁用分鐘選擇
                                        timeComponent: .minutes
                                    )
                                    .transition(.opacity)
                                }
                                
                                Text(":")
                                    .font(.custom("PingFang TC", size: 35))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                
                                // 秒數部分
                                if isRunning || isCountUp {
                                    // 運行時或正計時模式顯示固定數字
                                    Text(String(format: "%02d", isCountUp ? Int(elapsedTime) % 60 : seconds))
                                        .font(.custom("PingFang TC", size: 35))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(width: 60)
                                        .transition(.opacity)
                                } else {
                                    // 倒數計時非運行狀態 - 可滑動調整
                                    TimePickerWheel(
                                        value: $seconds,
                                        range: 0...59,
                                        isEnabled: !isRunning && !isCountUp && hours < 3, // 當小時為3時禁用秒數選擇
                                        timeComponent: .seconds
                                    )
                                    .transition(.opacity)
                                }
                            }
                            .onChange(of: hours) { newValue in
                                // 當小時數變更為3以上時，自動將分鐘和秒數歸零
                                if newValue > 3 {
                                    hours = 3
                                    minutes = 0
                                    seconds = 0
                                }
                                // 當小時數等於3時，也需要將分鐘和秒數歸零
                                else if newValue == 3 {
                                    minutes = 0
                                    seconds = 0
                                }
                                updateTimer()
                            }
                            .onChange(of: minutes) { _ in updateTimer() }
                            .onChange(of: seconds) { _ in updateTimer() }
                            
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
        .animation(nil, value: isCountUp) // 不使用自動動畫，而是在toggleCountMode中手動控制
        .animation(.easeInOut(duration: 0.2), value: isRunning)
        .onAppear {
            // 初始化時分秒
            updateTimeComponents()
        }
    }
    
    // 更新時間組件
    func updateTimeComponents() {
        hours = Int(timeRemaining) / 3600
        minutes = (Int(timeRemaining) / 60) % 60
        seconds = Int(timeRemaining) % 60
    }
    
    // 根據時間組件更新計時器
    func updateTimer() {
        // 限制小時數最大為3，超過時重置分鐘和秒數為0
        if hours > 3 {
            hours = 3
            minutes = 0
            seconds = 0
        }
        // 當小時數為3時，分鐘和秒數也必須為0
        else if hours == 3 {
            minutes = 0
            seconds = 0
        }
        
        timeRemaining = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        selectedTime = Int(timeRemaining / 60)
        
        // 更新進度條
        let totalSeconds = Double(maxTime - minTime) * 60
        progress = (timeRemaining - Double(minTime * 60)) / totalSeconds
        
        // 進度條範圍檢查
        if progress < 0 { progress = 0 }
        if progress > 1 { progress = 1 }
    }
    
    // 顯示時間提示
    @State private var showTimeTooltip = false
    
    // 切換倒數/正數計時模式
    func toggleCountMode() {
        // 如果從正計時切換回倒數計時，且已經有初始設定過的時間，則使用初始設定的時間
        let shouldUseInitialTime = isCountUp && hasUsedBefore
        
        // 使用淡出淡入過渡
        withAnimation(.easeOut(duration: 0.2)) {
            // 先使文字淡出
            isCountUp.toggle()
        }
        
        // 延遲後重置計時器並更新時間
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            resetTimer() // 切換模式時重置計時器
            
            // 切換到正計時模式時
            if isCountUp {
                // 正計時模式下進度從0開始
                withAnimation(.easeIn(duration: 0.2)) {
                    progress = 0.0
                }
            } else {
                if shouldUseInitialTime {
                    // 使用初始設定的時間
                    hours = lastUsedHours
                    minutes = lastUsedMinutes
                    seconds = lastUsedSeconds
                    updateTimer() // 更新timeRemaining和progress
                } else {
                    // 未使用過，設置為預設30分鐘
                    selectedTime = 30
                    withAnimation(.easeIn(duration: 0.2)) {
                        progress = Double(selectedTime - minTime) / Double(maxTime - minTime)
                    }
                    timeRemaining = TimeInterval(selectedTime * 60)
                    updateTimeComponents()
                }
            }
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
            
            // 每次暫停時都更新最後使用的時間
            if !isCountUp {
                lastUsedHours = hours
                lastUsedMinutes = minutes
                lastUsedSeconds = seconds
                hasUsedBefore = true
            }
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
                // 如果是開始計時，記住當前設定的時間
                lastUsedHours = hours
                lastUsedMinutes = minutes
                lastUsedSeconds = seconds
                hasUsedBefore = true
                
                // 倒數計時 - 從當前設置的進度開始倒數
                let initialProgress = progress
                let totalTime = TimeInterval(selectedTime * 60)
                
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                        // 更新時間組件
                        self.updateTimeComponents()
                        // 更新倒數計時進度 - 從當前位置開始減少
                        self.progress = self.timeRemaining / totalTime * initialProgress
                    } else {
                        self.timer?.invalidate()
                        self.timer = nil
                        self.isRunning = false
                        self.progress = 0 // 倒數結束時進度歸零
                        // 更新時間組件
                        self.updateTimeComponents()
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
            // 倒數計時重置到第一次設定的時間（如果已經開始過）或當前設定的時間
            if hasUsedBefore {
                hours = lastUsedHours
                minutes = lastUsedMinutes
                seconds = lastUsedSeconds
                updateTimer() // 更新timeRemaining和progress
            } else {
                // 未開始過，保持當前設定
                timeRemaining = TimeInterval(selectedTime * 60)
                updateTimeComponents()
            }
        }
    }
}

// 時間滾輪選擇元件
struct TimePickerWheel: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let isEnabled: Bool
    let timeComponent: TimeComponent
    
    // 定義枚舉類型區分時間組件
    enum TimeComponent {
        case hours, minutes, seconds
    }
    
    // 檢查是否應該禁用交互（例如當小時為3時禁用分鐘和秒數的滾輪）
    var shouldDisable: Bool {
        if timeComponent == .hours || timeComponent == .minutes || timeComponent == .seconds {
            return !isEnabled
        }
        return false
    }
    
    // 滑動相關狀態
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0
    @State private var lastDragValue: Int = 0
    
    // 調整滑動靈敏度
    private let offsetThreshold: CGFloat = 80.0 // 需要累積多少偏移量才會改變數值
    
    // 安全地將數字轉換為兩位數字串
    private func formatNumber(_ number: Int) -> String {
        return String(format: "%02d", number)
    }
    
    // 計算前後數值
    private func previousValue() -> Int {
        let prev = value - 1
        return prev >= range.lowerBound ? prev : range.upperBound
    }
    
    private func nextValue() -> Int {
        let next = value + 1
        return next <= range.upperBound ? next : range.lowerBound
    }
    
    var body: some View {
        // 只顯示當前數字
        Text(formatNumber(value))
            .font(.custom("PingFang TC", size: 35))
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .frame(width: 60, height: 45)
            // 使用改進的滑動手勢處理
            .gesture(
                !shouldDisable ?
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        // 計算當前滑動偏移量
                        dragOffset = gesture.translation.height
                        accumulatedOffset += gesture.translation.height - gesture.predictedEndTranslation.height // 使用差值判斷用戶持續滑動的意圖
                        
                        // 根據累積偏移量判斷是否需要調整數值
                        if accumulatedOffset > offsetThreshold {
                            // 向下滑動，減少數值
                            let newValue = previousValue()
                            
                            // 檢查是否已經處理過這個值
                            if lastDragValue != newValue {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    value = newValue
                                }
                                lastDragValue = newValue
                                // 重置累積偏移量，但保留一部分以保持流暢感
                                accumulatedOffset -= offsetThreshold
                            }
                        } else if accumulatedOffset < -offsetThreshold {
                            // 向上滑動，增加數值
                            let newValue = nextValue()
                            
                            // 檢查是否已經處理過這個值
                            if lastDragValue != newValue {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    value = newValue
                                }
                                lastDragValue = newValue
                                // 重置累積偏移量，但保留一部分以保持流暢感
                                accumulatedOffset += offsetThreshold
                            }
                        }
                    }
                    .onEnded { _ in
                        // 重置滑動狀態
                        dragOffset = 0
                        accumulatedOffset = 0
                        lastDragValue = 0
                    }
                : nil
            )
            .onAppear {
                // 初始化最後處理的滑動值
                lastDragValue = value
            }
    }
}

struct ClockViewWithTabBar_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}
