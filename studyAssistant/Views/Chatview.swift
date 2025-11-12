import SwiftUI

// MARK: - iOS Version Detection
extension ChatDemoDynamicView {
    private var isIOS26OrLater: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}

// MARK: - 主要畫面
struct ChatDemoDynamicView: View {
    // 色票
    private let backgroundColor = Color.hex(hex: "F3D4B7")  // 與TodoView相同的背景色
    private let darkBubbleColor = Color.hex(hex: "E28A5F")  // 深橘色按鈕顏色
    private let midBubbleColor = Color.hex(hex: "FEECD8")  // 淺橙底色（輸入框）
    private let lightBubbleColor = Color.hex(hex: "FEECD8")  // 淺橙底色（對話框）
    private let textColor = Color.black.opacity(0.8)  // 深色文字
    private let sidebarColor = Color.hex(hex: "F3D4B8")  // 側邊欄顏色，改為與對話框相同的顏色
    private let titleColor = Color.hex(hex: "E27945")  // 聊天室名稱顏色

    // 任務卡片字體大小
    private let taskTitleSize: CGFloat = 16  // 任務標題字體大小
    private let taskContentSize: CGFloat = 14  // 任務內容字體大小
    private let taskHeaderSize: CGFloat = 17  // 任務卡片標題字體大小（如"原始資料"、"更新後資料"）
    private let taskCountSize: CGFloat = 15  // 任務計數字體大小（如"任務 1/3"）

    @EnvironmentObject private var viewModel: ChatViewModel
    @EnvironmentObject private var staticViewModel: StaticViewModel
    @EnvironmentObject private var calendarAssistantViewModel: CalendarAssistantViewModel
    @State private var inputText = ""
    @State private var showSidebar = false
    @State private var latestMessageId: UUID?  // 追蹤最新訊息的 ID
    @State private var expandedTaskMessages: Set<UUID> = []  // 追蹤哪些訊息的任務列表被展開
    @State private var showSettings = false  // 控制設定頁面的展示
    @State private var isEditingTitle = false  // 是否正在編輯標題
    @State private var editingTitleText = ""  // 編輯中的標題文字
    @FocusState private var isTitleFocused: Bool  // 追蹤標題輸入框是否有焦點
    @State private var isGenerating = false   // 追蹤 GPT 是否正在生成回覆
    @State private var isUserScrolling = false  // 追蹤使用者是否正在滑動
    @State private var isConversationEnded = false  // 追蹤對話是否已結束
    @State private var textEditorHeight: CGFloat = 36
    @FocusState private var isInputFocused: Bool
    @State private var bottomInset: CGFloat = 0
    @State private var topInset: CGFloat = 0
    @State private var tabBarHeight: CGFloat = 0
    @State private var isAtBottom = true  // 追蹤聊天內容是否在底部
    // 【改動】新增狀態
    @State private var showManageSheet = false      // 是否顯示「管理聊天室」畫面
    @State private var selectedRoomIDs = Set<UUID>()// 已選取要刪除的聊天室 ID
    @State private var calendarStatusMessage: String?
    @State private var calendarStatusIsLoading = false
    @State private var calendarStatusDismissTask: Task<Void, Never>?
    @State private var isCalendarSending = false

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if isIOS26OrLater {
                    // iOS 26+ 使用目前的原生樣式
                    ios26PlusView
                } else {
                    // iOS 25 及以下使用自定義樣式
                    ios25MinusView
                }
            }

            if let message = calendarStatusMessage {
                calendarStatusBanner(message: message, isLoading: calendarStatusIsLoading)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.top, topInset + 12)
            }
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                if let window = windowScene.windows.first {
                    bottomInset = window.safeAreaInsets.bottom
                    topInset = window.safeAreaInsets.top
                    
                    // 尋找 UITabBarController 並獲取其高度
                    if let rootViewController = window.rootViewController {
                        if let tabBarController = findTabBarController(from: rootViewController) {
                            self.tabBarHeight = tabBarController.tabBar.frame.size.height
                        }
                    }
                }
            }
            // 添加鍵盤通知觀察者
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.16)) {
                        self.viewModel.keyboardHeight = keyboardFrame.height
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.easeOut(duration: 0.16)) {
                    self.viewModel.keyboardHeight = 0
                }
            }
            
            viewModel.staticViewModel = staticViewModel
            // 每次進入聊天室頁面時自動選擇最新聊天室
            if !viewModel.chatRooms.isEmpty {
                viewModel.selectedRoomIndex = viewModel.chatRooms.count - 1
            }
        }
        .onDisappear {
            // 注意：不再取消正在進行的對話，允許在後端繼續執行
            // 使用者可以透過以下方式取消對話：
            // 1. 切換聊天室（在 onChange(of: viewModel.selectedRoomIndex) 中處理）
            // 2. 點擊停止按鈕（在 cancelGeneration() 中處理）
            // 3. 發送新訊息（在 sendMessage() 中處理）

            // 重置日曆相關狀態
            isCalendarSending = false
            updateCalendarStatus(message: nil, isLoading: false, autoDismiss: false)

            // 移除鍵盤通知觀察者
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: viewModel.selectedRoomIndex) { _ in
            // 切換聊天室時重設編輯狀態
            isEditingTitle = false
            editingTitleText = viewModel.chatRooms[viewModel.selectedRoomIndex].name
            isCalendarSending = false
            updateCalendarStatus(message: nil, isLoading: false, autoDismiss: false)
            
            // 切換聊天室時取消生成
            if isGenerating {
                cancelGeneration()
            }
        }
        .sheet(isPresented: $showSettings) {
            ChatSettingView()
                .environmentObject(viewModel)
        }
        // 【改動】新增一個管理聊天室的 sheet
        .sheet(isPresented: $showManageSheet) {
            ZStack {
                // 使用與主畫面相同的背景色
                backgroundColor.ignoresSafeArea()
                
                NavigationView {
                    // 多選清單
                    List(selection: $selectedRoomIDs) {
                        ForEach(viewModel.chatRooms) { room in
                            HStack {
                                Text(room.name)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                Spacer()
                                // 顯示目前選取中的聊天室
                                if let idx = viewModel.chatRooms.firstIndex(where: { $0.id == room.id }),
                                   idx == viewModel.selectedRoomIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.hex(hex: "E27945"))
                                }
                            }
                            .padding(.vertical, 1)
                            .listRowBackground(
                                lightBubbleColor.opacity(0.6)
                            )
                            .tag(room.id) // 關鍵：讓 List(selection:) 能識別
                        }
                    }
                    .scrollContentBackground(.hidden)
                    // 讓 List 直接進入多選模式
                    .environment(\.editMode, .constant(.active))
                    .navigationTitle("管理聊天室")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(backgroundColor, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("關閉") { 
                                showManageSheet = false
                                selectedRoomIDs.removeAll()
                            }
                            .foregroundColor(textColor)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("刪除(\(selectedRoomIDs.count))", role: .destructive) {
                                // 批次刪除邏輯
                                let idsToDelete = selectedRoomIDs
                                selectedRoomIDs.removeAll()
                                
                                // 依 ID 找 index 刪除（由後往前較安全，避免索引位移）
                                let indices = viewModel.chatRooms.enumerated()
                                    .filter { idsToDelete.contains($0.element.id) }
                                    .map { $0.offset }
                                    .sorted(by: >)
                                for idx in indices {
                                    viewModel.deleteChatRoom(at: idx)
                                }
                                
                                // 調整目前選中的聊天室 index，避免越界
                                if viewModel.chatRooms.isEmpty {
                                    // 視你的 ViewModel 規則決定是否自動新增一個聊天室
                                    // viewModel.createNewChatRoom()
                                    viewModel.selectedRoomIndex = 0
                                } else {
                                    viewModel.selectedRoomIndex = min(viewModel.selectedRoomIndex, viewModel.chatRooms.count - 1)
                                }
                                
                                showManageSheet = false
                            }
                            .foregroundColor(Color.hex(hex: "E28A5F"))
                            .disabled(selectedRoomIDs.isEmpty)
                            .opacity(selectedRoomIDs.isEmpty ? 0.3 : 1.0)
                        }
                    }
                }
            }
        }
        .background(
            Color.hex(hex: "FEECD8")
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: calendarStatusMessage)
    }

    // MARK: - iOS 26+ View (原生樣式)
    private var ios26PlusView: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
                .onTapGesture {
                    // 點擊背景時取消編輯狀態並收起鍵盤
                    if isEditingTitle {
                        if !editingTitleText.isEmpty {
                            viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                        }
                        isEditingTitle = false
                        isTitleFocused = false
                    }
                    // 收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                // 標題欄固定在最上方
                header
                    .zIndex(2) // 確保標題欄在最上層

                // 訊息列表和輸入框區域
                ZStack(alignment: .bottom) {
                    messageList
                        .zIndex(0)

                    inputBar
                        .zIndex(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊聊天區域收起鍵盤並結束輸入
                if isEditingTitle {
                    if !editingTitleText.isEmpty {
                        viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                    }
                    isEditingTitle = false
                    isTitleFocused = false
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - iOS 25- View (自定義樣式)
    private var ios25MinusView: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
                .onTapGesture {
                    // 點擊背景時取消編輯狀態並收起鍵盤
                    if isEditingTitle {
                        if !editingTitleText.isEmpty {
                            viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                        }
                        isEditingTitle = false
                        isTitleFocused = false
                    }
                    // 收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                ios25Header
                Rectangle()  // 添加分隔線
                    .frame(height: 0.2)  // 線條粗細
                    .foregroundColor(.black.opacity(0.2))  // 線條顏色
                messageList
                ios25InputBar
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // 點擊聊天區域收起鍵盤並結束輸入
                if isEditingTitle {
                    if !editingTitleText.isEmpty {
                        viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                    }
                    isEditingTitle = false
                    isTitleFocused = false
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .offset(x: showSidebar ? 250 : 0) // 側邊欄的偏移量

            if showSidebar { ios25Sidebar }

            if showSidebar {  // 側邊欄的遮罩
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSidebar = false
                        }
                        // 收起鍵盤
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                     to: nil, from: nil, for: nil)
                    }
            }
        }
    }

    // MARK: - iOS 25- Header
    private var ios25Header: some View {
        ZStack {
            // 底層按鈕
            HStack {
                Button {
                    // 打開側邊欄時取消生成並收起鍵盤
                    if isGenerating {
                        cancelGeneration()
                    }
                    // 收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
                    withAnimation { showSidebar.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.hex(hex: "E27844"))
                }
                .frame(width: 40, height: 44)
                .padding(.leading, 8)
                Spacer()

                // 設定圖示
                Button(action: {
                    isEditingTitle = false  // 打開設定時取消編輯狀態
                    // 收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.hex(hex: "E27844"))
                }
                .frame(width: 28, height: 44)
                .padding(.trailing, 8)

                Button(action: {
                    // 創建新聊天室時取消生成並收起鍵盤
                    if isGenerating {
                        cancelGeneration()
                    }
                    // 收起鍵盤
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
                    isEditingTitle = false  // 創建新聊天室時取消編輯狀態
                    viewModel.createNewChatRoom()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.hex(hex: "E27844"))
                }
                .frame(width: 28, height: 44)
                .disabled(!viewModel.canCreateNewChatRoom)
                .opacity(viewModel.canCreateNewChatRoom ? 1.0 : 0.3)
            }
            .padding(.horizontal)

            // 中間層標題
            if !isEditingTitle {
                Text(viewModel.chatRooms[viewModel.selectedRoomIndex].name.count > 7 ?
                     viewModel.chatRooms[viewModel.selectedRoomIndex].name.prefix(7) + "..." :
                     viewModel.chatRooms[viewModel.selectedRoomIndex].name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.5, alignment: .center)
                    .onTapGesture {
                        editingTitleText = viewModel.chatRooms[viewModel.selectedRoomIndex].name
                        isEditingTitle = true
                    }
            }

            // 最上層編輯框
            if isEditingTitle {
                TextField("聊天室名稱", text: $editingTitleText, onCommit: {
                    if !editingTitleText.isEmpty {
                        viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                    }
                    isEditingTitle = false
                    isTitleFocused = false
                })
                .focused($isTitleFocused)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(titleColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                .padding(.horizontal, 10)
                .background(Color.hex(hex: "F3D4B8").opacity(0.7))
                .cornerRadius(8)
                .onAppear {
                    // 顯示輸入框時自動獲取焦點
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTitleFocused = true
                    }
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - iOS 25- Sidebar
    private var ios25Sidebar: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Spacer().frame(height: 3)
                    Text("聊天室列表")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(Color.black)
                        .padding(.vertical, 10)
                        .padding(.leading, 20)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(
                                Array(viewModel.chatRooms.enumerated().reversed()), id: \.element.id
                            ) { idx, room in
                                Button {
                                    viewModel.selectedRoomIndex = idx
                                    withAnimation { showSidebar = false }
                                } label: {
                                    Text(room.name)
                                        .font(.title3)
                                        .foregroundColor(Color.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            idx == viewModel.selectedRoomIndex
                                                ? midBubbleColor : Color.clear
                                        )
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteChatRoom(at: idx)
                                    } label: {
                                        Label("刪除聊天室", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .frame(width: 250)
                .background(sidebarColor)
                Spacer()
            }
        }
        .zIndex(1)
        .transition(.move(edge: .leading))
        .background(Color.clear)
    }

    // MARK: - iOS 25- Input Bar (無玻璃效果)
    private var ios25InputBar: some View {
        VStack(spacing: 0) {
            HStack {
                // 傳送到日曆按鈕 - 輸入框左方
                Button(action: { showCalendarConfirmationAlert() }) {
                    HStack {
                        Spacer()
                        Image("send_to_calendar")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .offset(x: 2)
                    .background(Color.hex(hex: "E27844"))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                }
                .disabled(isCalendarSending || isGenerating || viewModel.isRecording)
                .opacity((isCalendarSending || isGenerating || viewModel.isRecording) ? 0.5 : 1.0)


                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty && !viewModel.isRecording {
                        Text("輸入訊息...")
                            .foregroundColor(Color.black.opacity(0.4))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                    }
                    TextEditor(text: Binding(
                        get: { viewModel.isRecording ? viewModel.transcribedText : inputText },
                        set: { newValue in
                            if !viewModel.isRecording {
                                inputText = newValue
                            }
                        }
                    ))
                        .font(.system(size: 16))
                        .padding(.vertical, 8)
                        .frame(height: isInputFocused ? min(max(textEditorHeight, 36), 36*4) : 36)
                        .background(midBubbleColor)
                        .cornerRadius(12)
                        .foregroundColor(Color.black)
                        .disabled(isGenerating || viewModel.isRecording)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .onChange(of: isInputFocused) { focused in
                            if !focused {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    textEditorHeight = 36
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollTextToBottom()
                                }
                            }
                        }
                }
                .overlay(
                    Text(inputText)
                        .font(.system(size: 20))
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .opacity(0)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: ViewHeightKey.self,
                                    value: geometry.size.height
                                )
                            }
                        )
                )
                .onPreferenceChange(ViewHeightKey.self) { height in
                    textEditorHeight = height
                }

                if isGenerating {
                    Button(action: cancelGeneration) {
                        Image(systemName: "stop.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.black.opacity(0.5))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: {
                        Task {
                            if viewModel.isRecording {
                                await viewModel.stopRecording()
                                // 注意：自動發送會在 ViewModel 的靜音檢測中處理
                                // 這裡只需要將文字傳入輸入框並發送
                                await MainActor.run {
                                    if !viewModel.transcribedText.isEmpty {
                                        inputText = viewModel.transcribedText
                                        sendMessage()
                                    }
                                }
                            } else {
                                try? await viewModel.startRecording()
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.isRecording ? Color.red : Color.black)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Button(action: sendMessage) {
                        Image(systemName: "arrowshape.up")
                            .font(.system(size: 22))
                            .foregroundColor(Color.black)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(inputText.isEmpty && !viewModel.isRecording)
                    .opacity((inputText.isEmpty && !viewModel.isRecording) ? 0.3 : 1.0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                ZStack(alignment: .top) {
                    backgroundColor
                    Rectangle()
                        .frame(height: 0.2)
                        .foregroundColor(.black.opacity(0.2))
                }
            )
        }
        .padding(.bottom, max(viewModel.keyboardHeight - tabBarHeight, 0))
        .animation(.easeOut(duration: 0.2), value: viewModel.keyboardHeight)
    }

    // MARK: Header
    private var header: some View {
        ZStack {
            // 底層按鈕 - 使用 GlassEffectContainer 協調玻璃效果
            CompatibleGlassEffectContainer {
                HStack {
                    Menu {
                        // 【改動】在 Menu 內新增一個入口
                        Button {
                            showManageSheet = true
                        } label: {
                            Label("管理聊天室…", systemImage: "checklist")
                        }
                        
                        Divider()
                        
                        // 設定按鈕
                        Button(action: {
                            isEditingTitle = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                     to: nil, from: nil, for: nil)
                            showSettings = true
                        }) {
                            Label("設定", systemImage: "gearshape")
                        }
                        // 聊天室列表
                        ForEach(Array(viewModel.chatRooms.enumerated().reversed()), id: \.element.id) { idx, room in
                            Button(action: {
                                viewModel.selectedRoomIndex = idx
                                if isGenerating {
                                    cancelGeneration()
                                }
                            }) {
                                HStack {
                                    Text(room.name)
                                    Spacer()
                                    if idx == viewModel.selectedRoomIndex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .compatibleGlassEffect(color: Color.hex(hex: "E27844"), opacity: 0.8)
                    .clipShape(Rectangle())
                    .padding(.leading, 4)

                    Spacer()

                    Button(action: {
                        // 創建新聊天室時取消生成並收起鍵盤
                        if isGenerating {
                            cancelGeneration()
                        }
                        // 收起鍵盤
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil, from: nil, for: nil)
                        isEditingTitle = false  // 創建新聊天室時取消編輯狀態
                        viewModel.createNewChatRoom()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .compatibleGlassEffect(color: Color.hex(hex: "E27844"), opacity: 0.8)
                    .clipShape(Rectangle())
                    .disabled(!viewModel.canCreateNewChatRoom)
                    .opacity(viewModel.canCreateNewChatRoom ? 1.0 : 0.3)
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 4)
            }
            
            // 中間層標題 - 使用 Liquid Glass 效果
            if !isEditingTitle {
                Text(viewModel.chatRooms[viewModel.selectedRoomIndex].name.count > 7 ?
                     viewModel.chatRooms[viewModel.selectedRoomIndex].name.prefix(7) + "..." :
                     viewModel.chatRooms[viewModel.selectedRoomIndex].name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                   
        .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                    .compatibleGlassEffect(color: .clear, opacity: 0.1)
                    .padding(.vertical, 4)
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                    .onTapGesture {
                        editingTitleText = viewModel.chatRooms[viewModel.selectedRoomIndex].name
                        isEditingTitle = true
                    }
            }
            
            // 最上層編輯框 - 使用 Liquid Glass 效果
            if isEditingTitle {
                TextField("聊天室名稱", text: $editingTitleText, onCommit: {
                    if !editingTitleText.isEmpty {
                        viewModel.chatRooms[viewModel.selectedRoomIndex].name = editingTitleText
                    }
                    isEditingTitle = false
                    isTitleFocused = false
                })
                .focused($isTitleFocused)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                .compatibleGlassEffect(color: Color.hex(hex: "F3D4B8"), opacity: 0.6)
                .padding(.vertical, 4)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .onAppear {
                    // 顯示輸入框時自動獲取焦點
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTitleFocused = true
                    }
                }
            }
        }
        .padding(.top, 4) // 從8減少到4，讓標題條往上移
        .padding(.bottom, 16) // 增加底部空間讓陰影顯示
    }

    // MARK: Message List
    private var messageList: some View {
        let baseBottomPadding: CGFloat = 100
        let keyboardInset = max(viewModel.keyboardHeight - tabBarHeight, 0)
        let dynamicBottomPadding = baseBottomPadding + (isAtBottom ? keyboardInset : 0)

        return ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.chatRooms[viewModel.selectedRoomIndex].messages) { msg in
                            if msg.isMe {
                                userBubble(msg.text)
                            } else {
                                aiBubble(msg.text)
                                    .id("msg_\(msg.id)")  // 為每個消息添加唯一ID
                            }
                        }
                    }
                    .padding(.top, 16) // 減少頂部空間，因為 header 已經獨立了
                    .padding(.bottom, dynamicBottomPadding) // 根據鍵盤高度給底部留空間
                    .id("messageBottom")  // 添加一個 ID 用於滾動
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .named("scrollView")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    // 檢測是否接近底部（給予一些容差值）
                    let threshold: CGFloat = 50
                    isAtBottom = offset >= -threshold
                }
            }
            // 移除 offset 調整，讓訊息列表保持固定，不隨鍵盤移動
            .onChange(of: expandedTaskMessages) { newValue in
                // 找到最後一個展開/收起的消息
                if let lastChangedMessageId = viewModel.chatRooms[viewModel.selectedRoomIndex].messages
                    .last(where: { msg in
                        !msg.isMe && (msg.pendingTasks != nil || msg.pendingDeleteTasks != nil || msg.pendingUpdateTask != nil)
                    })?.id {
                    // 使用消息ID進行滾動
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("msg_\(lastChangedMessageId)", anchor: .center)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    // 使用者開始滑動時，設置標記為true
                    isUserScrolling = true
                    
                    // 設置定時器，如果3秒內沒有再次滑動，就重置標記
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isUserScrolling = false
                    }
                }
            )
            .onChange(of: viewModel.chatRooms[viewModel.selectedRoomIndex].messages.count) { _ in
                // 新增訊息時總是滾動到底部
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: latestMessageId) { _ in
                // 文字串流中，除非使用者手動滾動或對話已結束，否則始終跟隨最新文字
                if !isUserScrolling && !isConversationEnded {
                    scrollToBottomImmediate(proxy: proxy)
                }
            }
            .onChange(of: viewModel.conversationEndedSignal) { _ in
                // 當收到對話結束信號時，設置標記
                isConversationEnded = true
                
                // 最後滾動一次到底部然後不再自動滾動
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.selectedRoomIndex) { _ in
                // 當切換聊天室時，重置對話結束標記
                isConversationEnded = false
            }
            .onChange(of: viewModel.keyboardHeight) { _ in
                if isAtBottom {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: viewModel.shouldAutoSendTranscription) { shouldSend in
                // 監聽自動發送信號
                if shouldSend {
                    // 將轉錄文字填入輸入框並發送
                    if !viewModel.transcribedText.isEmpty {
                        inputText = viewModel.transcribedText
                        sendMessage()
                    }
                    // 重置信號
                    viewModel.shouldAutoSendTranscription = false
                }
            }
            .onAppear {
                // 每次進入聊天室頁面時直接滾動到底部（無動畫）
                proxy.scrollTo("messageBottom", anchor: .bottom)

                // 重置對話結束標記
                isConversationEnded = false
            }
        }
    }
    
    // 帶動畫的滾動到底部
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("messageBottom", anchor: .bottom)
        }
    }
    
    // 立即滾动到底部（無動畫，用於文字串流）
    private func scrollToBottomImmediate(proxy: ScrollViewProxy) {
        proxy.scrollTo("messageBottom", anchor: .bottom)
    }
    
    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 20))
                .padding(16)
                .background(darkBubbleColor)
                .foregroundColor(.black)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 1, y: 2)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.6, alignment: .trailing)
                .textSelection(.enabled)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = text
                    }) {
                        Label("複製", systemImage: "doc.on.doc")
                    }
                }
        }
        .padding(.horizontal)
    }
    private func aiBubble(_ text: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Check if this is the latest AI message
                let isLatestAIMessage =
                    viewModel.chatRooms[viewModel.selectedRoomIndex].messages.last?.text == text
                    && !viewModel.chatRooms[viewModel.selectedRoomIndex].messages.last!.isMe

                VStack(alignment: .leading, spacing: text.isEmpty ? 0 : 12) {
                    // 文字內容
                    if !text.isEmpty {
                        CustomMarkdownText(text, textColor: textColor)
                            .textSelection(.enabled)
                    }

                    // 顯示載入動畫（當正在載入時且是最新的AI訊息，但不在日曆傳送期間）
                    if viewModel.isLoading && isLatestAIMessage && !isCalendarSending {
                        HStack(spacing: 12) {
                            LoadingDots()
                                .padding(.vertical, 12)
                                .id(UUID()) // 強制視圖重新創建，確保動畫重新開始
                            if let messageIndex = viewModel.chatRooms[viewModel.selectedRoomIndex]
                                .messages.firstIndex(where: { $0.text == text }),
                                viewModel.chatRooms[viewModel.selectedRoomIndex].messages[
                                    messageIndex
                                ]
                                .isWaitingFunction
                            {
                                // 使用單一函數名稱顯示，如果有多個函數調用，只顯示最後一個
                                if let functionName = viewModel.chatRooms[
                                    viewModel.selectedRoomIndex
                                ].messages[messageIndex].currentExecutingFunction
                            {
                                Text("正在執行：\(functionName)")
                                    .foregroundColor(Color.black.opacity(0.7))
                                    .font(.system(size: 16))
                                        .id(UUID()) // 確保文字也會更新
                                }
                            }
                        }
                    }

                    // 任務預覽（如果有）
                    if let messageIndex = viewModel.chatRooms[viewModel.selectedRoomIndex].messages.firstIndex(where: { $0.text == text }) {
                        let message = viewModel.chatRooms[viewModel.selectedRoomIndex].messages[messageIndex]
                        
                        // 顯示待新增的任務
                        if let tasks = message.pendingTasks {
                            let messageId = message.id
                            let isExpanded = expandedTaskMessages.contains(messageId)
                            let displayTasks = isExpanded ? tasks : Array(tasks.prefix(1))

                            Divider()
                                .background(textColor.opacity(0.3))
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("已新增的任務：")
                                    .font(.headline)
                                    .foregroundColor(Color.black)

                                // 使用滾動視圖限制最大高度
                                if isExpanded && tasks.count > 3 {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(displayTasks) { task in
                                                taskAddItemView(task: task)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: min(CGFloat(tasks.count) * 180, 600))  // 每個任務預估高度180，最大600
                                } else {
                                    ForEach(displayTasks) { task in
                                        taskAddItemView(task: task)
                                    }
                                }

                                if tasks.count > 1 {
                                    Button(action: {
                                        withAnimation {
                                            if isExpanded {
                                                expandedTaskMessages.remove(messageId)
                                            } else {
                                                expandedTaskMessages.insert(messageId)
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Text(isExpanded ? "收起" : "展開全部 (\(tasks.count) 個任務)")
                                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        }
                                        .foregroundColor(Color.black)
                                        .opacity(0.8)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // 顯示待刪除的任務
                        if let tasksToDelete = message.pendingDeleteTasks {
                            let messageId = message.id
                            let isExpanded = expandedTaskMessages.contains(messageId)
                            let displayTasks = isExpanded ? tasksToDelete : Array(tasksToDelete.prefix(1))
                            
                            Divider()
                                .background(textColor.opacity(0.3))
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("已刪除的任務：")
                                    .font(.headline)
                                    .foregroundColor(Color.black)

                                // 使用滾动视图限制最大高度
                                if isExpanded && tasksToDelete.count > 3 {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(displayTasks) { task in
                                                taskDeleteItemView(task: task)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: min(CGFloat(tasksToDelete.count) * 180, 600))  // 每個任務預估高度180，最大600
                                } else {
                                    ForEach(displayTasks) { task in
                                        taskDeleteItemView(task: task)
                                    }
                                }

                                if tasksToDelete.count > 1 {
                                    Button(action: {
                                        withAnimation {
                                            if isExpanded {
                                                expandedTaskMessages.remove(messageId)
                                            } else {
                                                expandedTaskMessages.insert(messageId)
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Text(isExpanded ? "收起" : "展開全部 (\(tasksToDelete.count) 個任務)")
                                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        }
                                        .foregroundColor(Color.black)
                                        .opacity(0.8)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // 顯示待修改的任務
                        if let updateData = message.pendingUpdateTask {
                            let messageId = message.id
                            
                            Divider()
                                .background(textColor.opacity(0.3))
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("已修改的任務：")
                                    .font(.headline)
                                    .foregroundColor(Color.black)

                                // 使用一個通用函數來格式化原始和更新後的任務數據
                                if let updateDataList = message.pendingUpdateTasks {
                                    let isExpanded = expandedTaskMessages.contains(messageId)
                                    let displayTasks = isExpanded ? updateDataList : Array(updateDataList.prefix(1))

                                    // 使用滾動視圖限制最大高度
                                    if isExpanded && updateDataList.count > 3 {
                                        ScrollView {
                                            LazyVStack(alignment: .leading, spacing: 10) {
                                                ForEach(0..<displayTasks.count, id: \.self) { index in
                                                    taskUpdateItemView(updateData: displayTasks[index],
                                                                     index: index, total: updateDataList.count)
                                                }
                                            }
                                        }
                                        .frame(maxHeight: min(CGFloat(updateDataList.count) * 250, 800))  // 修改更新任務的高度限制，因為有兩個卡片
                                    } else {
                                        ForEach(0..<displayTasks.count, id: \.self) { index in
                                            taskUpdateItemView(updateData: displayTasks[index],
                                                             index: index, total: updateDataList.count)
                                        }
                                    }

                                    // 如果有多個任務，添加展開/收起按鈕
                                    if updateDataList.count > 1 {
                                        Button(action: {
                                            withAnimation {
                                                if isExpanded {
                                                    expandedTaskMessages.remove(messageId)
                                                } else {
                                                    expandedTaskMessages.insert(messageId)
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Text(isExpanded ? "收起" : "展開全部 (\(updateDataList.count) 個任務)")
                                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            }
                                            .foregroundColor(Color.black)
                                            .opacity(0.8)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(16)
            .background(lightBubbleColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 1, y: 2)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.95, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal)
    }

    // 格式化日期時間的輔助函數
    private func formatDate(_ date: Date?, isAllDay: Bool) -> String {
        guard let date = date else { return "未設定" }
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateFormat = "yyyy/MM/dd"
        } else {
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
        }
        return formatter.string(from: date)
    }

    // 顯示單個待刪除任務的視圖
    private func taskDeleteItemView(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("標題: " + task.title)
                .font(.system(size: taskTitleSize, weight: .medium))
            if !task.note.isEmpty {
                Text("備註: " + task.note)
                    .font(.system(size: taskContentSize))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("類別: " + task.category)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("開始時間: " + formatDate(task.startDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("結束時間: " + formatDate(task.endDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("全天: " + (task.isAllDay ? "是" : "否"))
                .font(.system(size: taskContentSize))
            Text("已完成: " + (task.isCompleted ? "是" : "否"))
                .font(.system(size: taskContentSize))
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .textSelection(.enabled)
        .contextMenu {
            Button(action: {
                let taskDetail = """
                標題: \(task.title)
                \(!task.note.isEmpty ? "備註: \(task.note)\n" : "")類別: \(task.category)
                開始時間: \(formatDate(task.startDate, isAllDay: task.isAllDay))
                結束時間: \(formatDate(task.endDate, isAllDay: task.isAllDay))
                全天: \(task.isAllDay ? "是" : "否")
                已完成: \(task.isCompleted ? "是" : "否")
                """
                UIPasteboard.general.string = taskDetail
            }) {
                Label("複製任務詳情", systemImage: "doc.on.doc")
            }
        }
    }
    
    // 顯示單個待修改任務的視圖
    private func taskUpdateItemView(updateData: (original: TodoTask, updated: PendingTask), index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if total > 1 {
                Text("任務 \(index + 1) / \(total)")
                    .font(.system(size: taskCountSize))
                    .foregroundColor(Color.black)
                    .padding(.bottom, 2)
            }
            
            HStack(alignment: .top, spacing: 15) {
                // 原始任務數據
                VStack(alignment: .leading, spacing: 5) {
                    Text("原始資料")
                        .font(.system(size: taskHeaderSize, weight: .semibold))
                        .foregroundColor(Color.black)
                        .padding(.bottom, 2)
                        
                    Text("標題: " + updateData.original.title)
                        .font(.system(size: taskTitleSize, weight: .medium))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("備註: " + updateData.original.note)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("類別: " + updateData.original.category)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("開始時間: " + formatDate(updateData.original.startDate, isAllDay: updateData.original.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("結束時間: " + formatDate(updateData.original.endDate, isAllDay: updateData.original.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("全天: " + (updateData.original.isAllDay ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                    Text("已完成: " + (updateData.original.isCompleted ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                // 更新後的任務數據
                VStack(alignment: .leading, spacing: 5) {
                    Text("更新後資料")
                        .font(.system(size: taskHeaderSize, weight: .semibold))
                        .foregroundColor(Color.black)
                        .padding(.bottom, 2)
                        
                    Text("標題: " + updateData.updated.title)
                        .font(.system(size: taskTitleSize, weight: .medium))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("備註: " + updateData.updated.note)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("類別: " + updateData.updated.category)
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("開始時間: " + formatDate(updateData.updated.startDate, isAllDay: updateData.updated.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("結束時間: " + formatDate(updateData.updated.endDate, isAllDay: updateData.updated.isAllDay))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("全天: " + (updateData.updated.isAllDay ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                    Text("已完成: " + (updateData.updated.isCompleted ? "是" : "否"))
                        .font(.system(size: taskContentSize))
                        .foregroundColor(Color.black)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
            .textSelection(.enabled)
            .contextMenu {
                Button(action: {
                    let taskDetail = """
                    【原始】
                    標題: \(updateData.original.title)
                    備註: \(updateData.original.note)
                    類別: \(updateData.original.category)
                    開始時間: \(formatDate(updateData.original.startDate, isAllDay: updateData.original.isAllDay))
                    結束時間: \(formatDate(updateData.original.endDate, isAllDay: updateData.original.isAllDay))
                    全天: \(updateData.original.isAllDay ? "是" : "否")
                    已完成: \(updateData.original.isCompleted ? "是" : "否")
                    
                    【更新後】
                    標題: \(updateData.updated.title)
                    備註: \(updateData.updated.note)
                    類別: \(updateData.updated.category)
                    開始時間: \(formatDate(updateData.updated.startDate, isAllDay: updateData.updated.isAllDay))
                    結束時間: \(formatDate(updateData.updated.endDate, isAllDay: updateData.updated.isAllDay))
                    全天: \(updateData.updated.isAllDay ? "是" : "否")
                    已完成: \(updateData.updated.isCompleted ? "是" : "否")
                    """
                    UIPasteboard.general.string = taskDetail
                }) {
                    Label("複製任務詳情", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // 顯示單個待新增任務的視圖
    private func taskAddItemView(task: PendingTask) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("標題: " + task.title)
                .font(.system(size: taskTitleSize, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("備註: " + task.note)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("類別: " + task.category)
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("開始時間: " + formatDate(task.startDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("結束時間: " + formatDate(task.endDate, isAllDay: task.isAllDay))
                .font(.system(size: taskContentSize))
                .fixedSize(horizontal: false, vertical: true)
            Text("全天: " + (task.isAllDay ? "是" : "否"))
                .font(.system(size: taskContentSize))
            Text("已完成: " + (task.isCompleted ? "是" : "否"))
                .font(.system(size: taskContentSize))
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .textSelection(.enabled)
        .contextMenu {
            Button(action: {
                let taskDetail = """
                標題: \(task.title)
                備註: \(task.note)
                類別: \(task.category)
                開始時間: \(formatDate(task.startDate, isAllDay: task.isAllDay))
                結束時間: \(formatDate(task.endDate, isAllDay: task.isAllDay))
                全天: \(task.isAllDay ? "是" : "否")
                已完成: \(task.isCompleted ? "是" : "否")
                """
                UIPasteboard.general.string = taskDetail
            }) {
                Label("複製任務詳情", systemImage: "doc.on.doc")
            }
        }
    }

    // 自定義 Markdown 文字視圖
    private struct CustomMarkdownText: View {
        let text: String
        let textColor: Color

        init(_ text: String, textColor: Color) {
            self.text = text
            self.textColor = Color.black
        }

        // 解析粗體文字
        private func parseText(_ text: String) -> Text {
            var result = Text("")
            var currentText = ""
            var isBold = false
            var index = text.startIndex

            while index < text.endIndex {
                let char = text[index]
                if char == "*" && index < text.index(before: text.endIndex)
                    && text[text.index(after: index)] == "*"
                {
                    // 處理當前累積的文字
                    if !currentText.isEmpty {
                        result =
                            result
                            + Text(currentText).font(
                                .system(size: 20, weight: isBold ? .bold : .regular))
                                .foregroundColor(Color.black)
                        currentText = ""
                    }
                    isBold.toggle()
                    index = text.index(after: index)  // 跳過第二個 *
                } else {
                    currentText.append(char)
                }
                index = text.index(after: index)
            }

            // 處理最後剩餘的文字
            if !currentText.isEmpty {
                result =
                    result
                    + Text(currentText).font(.system(size: 20, weight: isBold ? .bold : .regular))
                        .foregroundColor(Color.black)
            }

            return result
        }

        var body: some View {
            let components = text.components(separatedBy: .newlines)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(components.indices, id: \.self) { index in
                    let line = components[index].trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("#### ") {
                        parseText(String(line.dropFirst(5)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.black)
                    } else if line.hasPrefix("### ") {
                        parseText(String(line.dropFirst(4)))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.black)
                    } else if line.hasPrefix("## ") {
                        parseText(String(line.dropFirst(3)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.black)
                    } else if line.hasPrefix("# ") {
                        parseText(String(line.dropFirst(2)))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.black)
                    } else if line.hasPrefix("- ") {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 20))
                                .foregroundColor(Color.black)
                                .frame(width: 20, alignment: .center)
                            parseText(
                                String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                            )
                            .font(.system(size: 20))
                            .foregroundColor(Color.black)
                        }
                        .padding(.leading, 4)
                    } else {
                        parseText(line)
                            .foregroundColor(Color.black)
                    }
                }
            }
            .contextMenu {  // 添加長按選單
                Button(action: {
                    UIPasteboard.general.string = text
                }) {
                    Label("複製全文", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: Input Bar - 使用 Liquid Glass 效果
    private var inputBar: some View {
        VStack(spacing: 0) {
            CompatibleGlassEffectContainer {
                HStack {
                    // 傳送到日曆按鈕 - 輸入框左方
                    Button(action: { showCalendarConfirmationAlert() }) {
                        HStack {
                            Spacer()
                            Image("send_to_calendar")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                        .offset(x: 2)
                        .contentShape(Rectangle())
                    }
                    .compatibleGlassEffect(color: Color.hex(hex: "E27844"), opacity: 0.8)
                    .clipShape(Rectangle())
                    .disabled(isCalendarSending || isGenerating || viewModel.isRecording)
                    .opacity((isCalendarSending || isGenerating || viewModel.isRecording) ? 0.5 : 1.0)


                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty && !viewModel.isRecording {
                            Text("輸入訊息...")
                                .foregroundColor(Color.black.opacity(0.4))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                        }
                        TextEditor(text: Binding(
                            get: { viewModel.isRecording ? viewModel.transcribedText : inputText },
                            set: { newValue in
                                if !viewModel.isRecording {
                                    inputText = newValue
                                }
                            }
                        ))
                            .font(.system(size: 16))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .frame(height: isInputFocused ? min(max(textEditorHeight, 36), 36*4) : 36)
                            .foregroundColor(Color.black)
                            .disabled(isGenerating || viewModel.isRecording)
                            .scrollContentBackground(.hidden)
                            .focused($isInputFocused)
                            .onChange(of: isInputFocused) { focused in
                                if !focused {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        textEditorHeight = 36
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollTextToBottom()
                                    }
                                }
                            }
                    }
                    .compatibleGlassEffect(color: midBubbleColor, opacity: 0.6)
                    .clipShape(Rectangle())
                    .overlay(
                        Text(inputText)
                            .font(.system(size: 20))
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .opacity(0)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: ViewHeightKey.self,
                                        value: geometry.size.height
                                    )
                                }
                            )
                    )
                    .onPreferenceChange(ViewHeightKey.self) { height in
                        textEditorHeight = height
                    }

                    if isGenerating {
                        Button(action: cancelGeneration) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .compatibleGlassEffect(color: Color.red, opacity: 0.6)
                        .clipShape(Rectangle())
                    } else {
                        Button(action: {
                            Task {
                                if viewModel.isRecording {
                                    await viewModel.stopRecording()
                                    // 停止錄音後自動發送訊息
                                    await MainActor.run {
                                        if !viewModel.transcribedText.isEmpty {
                                            inputText = viewModel.transcribedText
                                            sendMessage()
                                        }
                                    }
                                } else {
                                    try? await viewModel.startRecording()
                                }
                            }
                        }) {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .compatibleGlassEffect(color: viewModel.isRecording ? Color.red : Color.hex(hex: "E27844"), opacity: 0.8)
                        .clipShape(Rectangle())
                        .padding(.trailing, 4)

                        Button(action: sendMessage) {
                            Image(systemName: "arrowshape.up.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .compatibleGlassEffect(color: Color.hex(hex: "E27844"), opacity: 0.8)
                        .clipShape(Rectangle())
                        .disabled(inputText.isEmpty && !viewModel.isRecording)
                        .opacity((inputText.isEmpty && !viewModel.isRecording) ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .offset(y: -2)
        .padding(.bottom, max(viewModel.keyboardHeight - tabBarHeight, 0))
        .animation(.easeOut(duration: 0.2), value: viewModel.keyboardHeight)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // 輔助函數：遞迴尋找 UITabBarController
    private func findTabBarController(from controller: UIViewController) -> UITabBarController? {
        if let tabBarController = controller as? UITabBarController {
            return tabBarController
        }
        for child in controller.children {
            if let found = findTabBarController(from: child) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - 輔助函數
    private func showCalendarConfirmationAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let alert = UIAlertController(
            title: "是否要把聊天室內容整理成日曆安排規則？",
            message: "這會把目前聊天室的內容整理成一段日曆更新指令，並套用到日曆助手。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "確定", style: .default) { _ in
            guard !self.isCalendarSending else { return }
            self.handleSendToCalendar()
        })

        // 找到最上層的 ViewController 來呈現 alert
        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        topController.present(alert, animated: true)
    }

    private func handleSendToCalendar() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isGenerating {
            cancelGeneration()
        }

        isConversationEnded = false
        isUserScrolling = false
        isCalendarSending = true

        withAnimation {
            updateCalendarStatus(message: "正在整理日曆規劃", isLoading: true, autoDismiss: false)
        }
        inputText = ""

        Task {
            let reply = await viewModel.sendMessageToCalendar(
                additionalInstruction: trimmed.isEmpty ? nil : trimmed
            )

            await MainActor.run {
                defer { isCalendarSending = false }

                if let reply {
                    let cleanedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanedReply.isEmpty {
                        calendarAssistantViewModel.autoUpdateInput = cleanedReply
                        withAnimation {
                            updateCalendarStatus(
                                message: "日曆的更新規則設定好了:\n\(cleanedReply)",
                                isLoading: false,
                                autoDismiss: true
                            )
                        }
                        return
                    }
                }

                withAnimation {
                    updateCalendarStatus(
                        message: "無法取得日曆建議，請稍後再試。",
                        isLoading: false,
                        autoDismiss: true
                    )
                }
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // 如果有正在進行的對話，先取消它
        if isGenerating {
            cancelGeneration()
        }
        
        // 重置對話結束標記
        isConversationEnded = false
        
        viewModel.resetSendToGPTCount()  // 每次使用者發送訊息時重設計數
        let userMsg = ChatMessage(text: inputText, isMe: true)
        let firstUserMessage = inputText
        viewModel.chatRooms[viewModel.selectedRoomIndex].messages.append(userMsg)
        inputText = ""
        
        // 重置使用者滾動標記，確保在發送新訊息後會自動滾動
        isUserScrolling = false

        // 插入一顆空白 AI 泡泡，用來即時累加
        let aiIndex: Int = {
            let empty = ChatMessage(text: "", isMe: false)
            viewModel.chatRooms[viewModel.selectedRoomIndex].messages.append(empty)
            return viewModel.chatRooms[viewModel.selectedRoomIndex].messages.count - 1
        }()

        // 首句話自動命名聊天室
        if viewModel.chatRooms[viewModel.selectedRoomIndex].name == "新聊天室" {
            Task {
                if let title = await viewModel.generateTitle(from: firstUserMessage) {
                    viewModel.chatRooms[viewModel.selectedRoomIndex].name = title
                }
            }
        }

        isGenerating = true  // 設置生成狀態為 true

        Task {
            _ = await viewModel.sendMessageToGPT(
                messages: viewModel.chatRooms[viewModel.selectedRoomIndex].messages
            ) { token in
                viewModel.chatRooms[viewModel.selectedRoomIndex].messages[aiIndex].text += token
                // 每收到一個新的token就更新latestMessageId觸發滾動
                latestMessageId = UUID()
            }
            
            // 對話完成後，重置生成狀態
            isGenerating = false
        }
    }

    private func calendarStatusBanner(message: String, isLoading: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func updateCalendarStatus(
        message: String?,
        isLoading: Bool,
        autoDismiss: Bool
    ) {
        calendarStatusDismissTask?.cancel()
        calendarStatusDismissTask = nil

        if let message {
            calendarStatusIsLoading = isLoading
            calendarStatusMessage = message

            if autoDismiss {
                let currentMessage = message
                calendarStatusDismissTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if calendarStatusMessage == currentMessage {
                            withAnimation {
                                calendarStatusIsLoading = false
                                calendarStatusMessage = nil
                            }
                            calendarStatusDismissTask = nil
                        }
                    }
                }
            }
        } else {
            calendarStatusIsLoading = isLoading
            calendarStatusMessage = nil
        }
    }

    // 添加取消生成的方法
    private func cancelGeneration() {
        viewModel.cancelCurrentTask()
        isGenerating = false
        
        // 不再添加「對話已被中斷」文字
        // 如果對話泡泡是空的，可以考慮移除它
        if let lastIndex = viewModel.chatRooms[viewModel.selectedRoomIndex].messages.indices.last,
           !viewModel.chatRooms[viewModel.selectedRoomIndex].messages[lastIndex].isMe,
           viewModel.chatRooms[viewModel.selectedRoomIndex].messages[lastIndex].text.isEmpty {
            // 如果是空的 AI 泡泡，則移除
            viewModel.chatRooms[viewModel.selectedRoomIndex].messages.remove(at: lastIndex)
        }
    }

    // 新增：載入動畫組件
    private struct LoadingDots: View {
        @State private var isAnimating = false

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animation
                                .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(0.2 * Double(index)),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                isAnimating = true
            }
            .onDisappear {
                // 確保動畫正確停止
                isAnimating = false
            }
        }
    }

    // 添加這個輔助方法到 ChatDemoDynamicView 結構體中
    private func scrollTextToBottom() {
        guard let textView = UITextView.findFirstResponder() else { return }
        let bottom = NSRange(location: textView.text.count - 1, length: 1)
        textView.scrollRangeToVisible(bottom)
    }
}

// MARK: - Preview
#Preview {
    ChatDemoDynamicView()
}

// 添加這個 PreferenceKey 到檔案頂部的其他結構定義附近
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ScrollView 偏移量追蹤
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 添加這個 UITextView 擴展到檔案底部
extension UITextView {
    static func findFirstResponder() -> UITextView? {
        let windows = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        
        for window in windows {
            if let textView = findFirstResponder(in: window) {
                return textView
            }
        }
        return nil
    }
    
    private static func findFirstResponder(in view: UIView) -> UITextView? {
        for subview in view.subviews {
            if let textView = subview as? UITextView {
                return textView
            }
            if let found = findFirstResponder(in: subview) {
                return found
            }
        }
        return nil
    }
}

// MARK: - 版本兼容性擴展
extension View {
    /// 兼容版本的玻璃效果修飾符
    @ViewBuilder
    func compatibleGlassEffect(color: Color, opacity: Double = 0.8) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(color.opacity(opacity)).interactive())
        } else {
            // iOS 26.0 以下使用替代的視覺效果
            self
                .background(
                    ZStack {
                        // 毛玻璃效果的替代方案
                        color.opacity(opacity * 0.7)
                        
                        // 添加輕微的模糊和光澤效果
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .cornerRadius(8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

/// 兼容版本的 GlassEffectContainer
struct CompatibleGlassEffectContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            // iOS 26.0 以下使用替代容器
            content
        }
    }
}
