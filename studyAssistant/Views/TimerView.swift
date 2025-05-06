import SwiftUI

// 提取計時器圓環為單獨的子視圖
struct TimerCircle: View {
    @EnvironmentObject var timerManager: TimerManager
    @Binding var isDragging: Bool
    
    var body: some View {
        ZStack {
            // 圓形外部陰影
            Circle()
                .fill(Color.clear)
                .frame(width: 280, height: 280)
            
            // 淺色背景圓環 - 使用填充色而非描邊
            Circle()
                .fill(Color.hex(hex: "F2D7CB"))
                .frame(width: 280, height: 280)
            
            // 白色內圓
            Circle()
                .fill(Color.hex(hex: "F5ECE3")) // 比原本的 #FDF8F3 更深，更接近圖中效果
                .frame(width: 240, height: 240)
            
            // 灰色進度背景環
            Circle()
                .trim(from: 0, to: 1)
                .stroke(
                    Color.hex(hex: "F2D7CB"),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 260, height: 260)

            // 進度指示圓環 - 使用橙色漸變描邊 - 遵循圖片
            Circle()
                .trim(from: 0, to: timerManager.progress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.hex(hex: "E09772"),
                            Color.hex(hex: "E87D45")
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
                let color = (i % 3 == 0 ? Color.hex(hex: "E09772") : Color.hex(hex: "D9BDA9")).opacity(i % 3 == 0 ? 0.8 : 0.4)
                
                Rectangle()
                    .fill(color)
                    .frame(width: width, height: 8)
                    .offset(y: -length)
                    .rotationEffect(.radians(angle))
            }
            
            // 進度圓點 - 白色小圓點在進度條末端 (可拖動)
            DraggablePoint(isDragging: $isDragging)
        }
    }
}

// 提取可拖動的進度點為獨立組件
struct DraggablePoint: View {
    @EnvironmentObject var timerManager: TimerManager
    @Binding var isDragging: Bool
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 28, height: 28)
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2) // 更集中的陰影
            .overlay(
                // 橙色邊框
                Circle()
                    .stroke(Color.hex(hex: "E87D45"), lineWidth: 3)
            )
            .offset(
                x: 130 * cos(2 * .pi * timerManager.progress - .pi/2),
                y: 130 * sin(2 * .pi * timerManager.progress - .pi/2)
            )
            .gesture(
                !timerManager.isCountUp && !timerManager.isRunning ?
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
                        let newProgress = angle / (2 * .pi)
                        
                        // 更新全局計時器管理器的進度和時間
                        timerManager.updateProgressFromDrag(progress: newProgress)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
                : nil
            )
    }
}

// 提取時間顯示部分為獨立組件
struct TimerDisplay: View {
    @EnvironmentObject var timerManager: TimerManager
    
    var body: some View {
        ZStack {
            // 白色背景確保文字清晰
            Circle()
                .fill(Color.hex(hex: "F5ECE3"))
                .frame(width: 200, height: 200)
            
            // Timer text and subject
            VStack(spacing: 5) {
                // 時間顯示
                // 統一使用HStack顯示時間，確保計時前後格式一致
                HStack(spacing: 1) {
                    // 小時部分
                    if timerManager.isRunning || timerManager.isCountUp {
                        // 運行時或正計時模式顯示固定數字
                        Text(String(format: "%02d", timerManager.isCountUp ? Int(timerManager.elapsedTime) / 3600 : timerManager.hours))
                            .font(.custom("PingFang TC", size: 35))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 60)
                            .transition(.opacity)
                    } else {
                        // 倒數計時非運行狀態 - 可滑動調整
                        TimePickerWheel(
                            value: $timerManager.hours,
                            range: 0...3, // 確保小時範圍為0-3
                            isEnabled: !timerManager.isRunning && !timerManager.isCountUp,
                            timeComponent: .hours
                        )
                        .transition(.opacity)
                    }
                    
                    Text(":")
                        .font(.custom("PingFang TC", size: 35))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    // 分鐘部分
                    if timerManager.isRunning || timerManager.isCountUp {
                        // 運行時或正計時模式顯示固定數字
                        Text(String(format: "%02d", timerManager.isCountUp ? (Int(timerManager.elapsedTime) / 60) % 60 : timerManager.minutes))
                            .font(.custom("PingFang TC", size: 35))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 60)
                            .transition(.opacity)
                    } else {
                        // 倒數計時非運行狀態 - 可滑動調整
                        TimePickerWheel(
                            value: $timerManager.minutes,
                            range: 0...59,
                            isEnabled: !timerManager.isRunning && !timerManager.isCountUp && timerManager.hours < 3, // 當小時為3時禁用分鐘選擇
                            timeComponent: .minutes
                        )
                        .transition(.opacity)
                    }
                    
                    Text(":")
                        .font(.custom("PingFang TC", size: 35))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    // 秒數部分
                    if timerManager.isRunning || timerManager.isCountUp {
                        // 運行時或正計時模式顯示固定數字
                        Text(String(format: "%02d", timerManager.isCountUp ? Int(timerManager.elapsedTime) % 60 : timerManager.seconds))
                            .font(.custom("PingFang TC", size: 35))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 60)
                            .transition(.opacity)
                    } else {
                        // 倒數計時非運行狀態 - 可滑動調整
                        TimePickerWheel(
                            value: $timerManager.seconds,
                            range: 0...59,
                            isEnabled: !timerManager.isRunning && !timerManager.isCountUp && timerManager.hours < 3, // 當小時為3時禁用秒數選擇
                            timeComponent: .seconds
                        )
                        .transition(.opacity)
                    }
                }
                .onChange(of: timerManager.hours) { newValue in
                    // 當小時數變更為3以上時，自動將分鐘和秒數歸零
                    if newValue > 3 {
                        timerManager.hours = 3
                        timerManager.minutes = 0
                        timerManager.seconds = 0
                    }
                    // 當小時數等於3時，也需要將分鐘和秒數歸零
                    else if newValue == 3 {
                        timerManager.minutes = 0
                        timerManager.seconds = 0
                    }
                    timerManager.updateTimer()
                }
                .onChange(of: timerManager.minutes) { _ in timerManager.updateTimer() }
                .onChange(of: timerManager.seconds) { _ in timerManager.updateTimer() }
                
                Text(timerManager.subject)
                    .font(.custom("PingFang TC", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(Color.hex(hex: "9F9A9A"))
            }
        }
    }
}

// 提取控制按鈕為獨立組件
struct TimerControls: View {
    @EnvironmentObject var timerManager: TimerManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Reset button
            Button(action: { timerManager.resetTimer() }) {
                ZStack {
                    // 外層陰影
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.hex(hex: "E09772"))

                    VStack{
                        Text("重置")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 150, height: 60)
            }
            
            // Start/Pause button
            Button(action: { timerManager.toggleTimer() }) {
                ZStack {
                    // 外層陰影
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.hex(hex: "E09772"))
                    
                    
                    Text(timerManager.isRunning ? "暫停" : "開始")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(width: 150, height: 60)
            }
        }
        .padding(.bottom, 80)
    }
}

// 主視圖
struct TimerView: View {
    // 使用環境物件而不是本地狀態
    @EnvironmentObject var timerManager: TimerManager
    // 添加TodoViewModel環境物件
    @EnvironmentObject var todoViewModel: TodoViewModel
    
    // 僅保留視圖相關的本地狀態
    @State private var isDragging = false // 是否正在拖動
    @State private var showTimeTooltip = false // 顯示時間提示
    
    var body: some View {
        ZStack {
            // Background color - Figma 精確顏色
            Color.hex(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Countdown/Countup toggle button in a fixed-height container
                VStack {
                    Button(action: {
                        // 切換倒數/正數計時模式
                        if !timerManager.isRunning {
                            timerManager.toggleCountMode()
                        }
                    }) {
                        ZStack {
                            // 外層陰影
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.hex(hex: "E09772"))
                            
                            Text(timerManager.isCountUp ? "COUNT" : "COUNTDOWN")
                                .font(.custom("Inder", size: 20))
                                .tracking(0.5)
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 180, height: 50)
                    }
                    .padding(.top, 40)
                    .disabled(timerManager.isRunning) // 計時中不可切換模式
                }
                .frame(height: 100) // 固定頂部區域高度
                
                Spacer()
                
                // Timer circle group - 根據新圖片修改
                ZStack {
                    TimerCircle(isDragging: $isDragging)
                    TimerDisplay()
                }
                
                Spacer()
                
                // 控制按鈕區域，固定高度
                VStack {
                    // Control buttons
                    TimerControls()
                }
                .frame(height: 150) // 固定底部控制區域高度
                
            }
        }
        .onAppear {
            // 當視圖出現時，設置TodoViewModel並更新當前任務
            timerManager.setTodoViewModel(todoViewModel)
            
            // 如果計時器正在運行，觸發一次更新
            if timerManager.isRunning {
                timerManager.appWillEnterForeground()
            }
        }
        // 每當視圖重新顯示時更新當前任務
        .onReceive(NotificationCenter.default.publisher(for: .todoDataDidChange)) { _ in
            timerManager.updateCurrentTask()
        }
        .animation(nil, value: timerManager.isCountUp) // 不使用自動動畫
        .animation(.easeInOut(duration: 0.2), value: timerManager.isRunning)
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

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
            .environmentObject(TimerManager())
            .environmentObject(TodoViewModel())
    }
}

// 使用新的預覽API
#Preview {
    TimerView()
        .environmentObject(TimerManager())
        .environmentObject(TodoViewModel())
}

