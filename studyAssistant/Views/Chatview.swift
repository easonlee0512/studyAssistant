import SwiftUI

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
    @State private var textEditorHeight: CGFloat = 40
    @FocusState private var isInputFocused: Bool
    @State private var bottomInset: CGFloat = 0

    var body: some View {
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
                header
                Rectangle()  // 添加分隔線
                    .frame(height: 0.2)  // 線條粗細
                    .foregroundColor(.black.opacity(0.2))  // 線條顏色
                messageList
                inputBar
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
            
            if showSidebar { sidebarOverlay }
            
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
        .onAppear {
            if let win = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows }).first {
                bottomInset = win.safeAreaInsets.bottom
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
            // 離開視圖時取消生成
            if isGenerating {
                cancelGeneration()
            }
            // 移除鍵盤通知觀察者
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: viewModel.selectedRoomIndex) { _ in
            // 切換聊天室時重設編輯狀態
            isEditingTitle = false
            editingTitleText = viewModel.chatRooms[viewModel.selectedRoomIndex].name
            
            // 切換聊天室時取消生成
            if isGenerating {
                cancelGeneration()
            }
        }
        .sheet(isPresented: $showSettings) {
            ChatSettingView()
                .environmentObject(viewModel)
        }
        .background(
            Color.hex(hex: "FEECD8")
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: Header
    private var header: some View {
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
                .frame(width: 40, height: 44)  // 改回原本的大小
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
                .frame(width: 28, height: 44)  // 改回原本的大小
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
                .frame(width: 28, height: 44)  // 改回原本的大小
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
        .padding(.top, 4) // 從8減少到4，讓標題條往上移
        .padding(.bottom, 8) // 從12減少到8，讓標題條往上移
    }

    // MARK: Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
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
                .padding(.top, 8)
                .padding(.bottom, 15)
                .id("messageBottom")  // 添加一個 ID 用於滾動
            }
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
    
    // 立即滾動到底部（無動畫，用於文字串流）
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

                    // 顯示載入動畫（當正在載入時且是最新的AI訊息）
                    if viewModel.isLoading && isLatestAIMessage {
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
                                Text(message.isTaskConfirmed ? "已新增的任務：" : "待新增的任務：")
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

                                // 只在任務未確認時顯示確認和取消按鈕
                                if !message.isTaskConfirmed {
                                    HStack {
                                        Button(action: {
                                            Task {
                                                await viewModel.confirmAndSaveTask(for: messageId)
                                            }
                                        }) {
                                            Text("確認新增")
                                                .foregroundColor( .white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.hex(hex: "74C3AF")
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)

                                        Button(action: {
                                            viewModel.rejectTask(for: messageId)
                                        }) {
                                            Text("取消")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.hex(hex: "F1A154")
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)
                                    }
                                    .padding(.top, 8)
                                } else {
                                    // 顯示任務新增結果
                                    if message.isTaskConfirmed {
                                        Text(
                                            message.successCount > 0
                                                ? " \(message.successCount) 個任務已成功新增"
                                                    + (message.failureCount > 0
                                                        ? "\n\(message.failureCount) 個任務新增失敗"
                                                        : "")
                                                : "新增任務失敗"
                                        )
                                        .foregroundColor(Color.black.opacity(0.6))

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
                                Text(message.isDeleteConfirmed ? "已刪除的任務：" : "待刪除的任務：")
                                    .font(.headline)
                                    .foregroundColor(Color.black)
                                
                                // 使用滾動視圖限制最大高度
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

                                // 只在任務未確認時顯示確認和取消按鈕
                                if !message.isDeleteConfirmed {
                                    HStack {
                                        Button(action: {
                                            Task {
                                                await viewModel.confirmAndDeleteTask(for: messageId)
                                            }
                                        }) {
                                            Text("確認刪除")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.red.opacity(0.8)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)
                                        
                                        Button(action: {
                                            viewModel.rejectDeleteTask(for: messageId)
                                        }) {
                                            Text("取消")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.hex(hex: "F1A154")
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)
                                    }
                                    .padding(.top, 8)
                                } else {
                                    // 顯示刪除結果
                                    Text(
                                        message.successCount > 0
                                            ? "\(message.successCount) 個任務已成功刪除"
                                                + (message.failureCount > 0
                                                    ? "\n\(message.failureCount) 個任務刪除失敗"
                                                    : "")
                                            : "刪除任務失敗"
                                    )
                                    .foregroundColor(Color.black.opacity(0.6))

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
                                Text(message.isUpdateConfirmed ? "已修改的任務：" : "待修改的任務：")
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

                                // 只在任務未確認時顯示確認和取消按鈕
                                if !message.isUpdateConfirmed {
                                    HStack {
                                        Button(action: {
                                            Task {
                                                await viewModel.confirmAndUpdateTask(for: messageId)
                                            }
                                        }) {
                                            Text("確認修改")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.blue.opacity(0.8)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)
                                        
                                        Button(action: {
                                            viewModel.rejectUpdateTask(for: messageId)
                                        }) {
                                            Text("取消")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    message.isProcessing
                                                        ? Color.gray.opacity(0.4)
                                                        : Color.hex(hex: "F1A154")
                                                )
                                                .cornerRadius(8)
                                        }
                                        .disabled(message.isProcessing)
                                    }
                                    .padding(.top, 8)
                                } else {
                                    // 顯示更新結果
                                    let totalTasks = message.successCount + message.failureCount
                                    Text(
                                        message.successCount > 0
                                            ? "\(message.successCount)/\(totalTasks) 個任務已成功修改"
                                                + (message.failureCount > 0
                                                    ? "\n\(message.failureCount) 個任務修改失敗"
                                                    : "")
                                            : "修改任務失敗"
                                    )
                                    .foregroundColor(Color.black.opacity(0.6))

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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
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

    // MARK: Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("輸入訊息...")
                            .foregroundColor(Color.black.opacity(0.4))
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $inputText)
                        .font(.system(size: 18))
                        .padding(.vertical, 10)
                        .frame(height: isInputFocused ? min(max(textEditorHeight, 43), 43*4) : 43)
                        .background(midBubbleColor)
                        .cornerRadius(12)
                        .foregroundColor(Color.black)
                        .disabled(isGenerating)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .onChange(of: isInputFocused) { focused in
                            if !focused {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    textEditorHeight = 43
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
                            .font(.system(size: 28))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .frame(width: 44, height: 44)
                } else {
                    Button(action: {}) {
                        Image(systemName: "mic")
                            .font(.system(size: 20))
                            .foregroundColor(Color.black)
                    }
                    .frame(width: 32, height: 32)
                    .padding(.trailing, 2)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrowshape.up")
                            .font(.system(size: 20))
                            .foregroundColor(Color.black)
                    }
                    .frame(width: 32, height: 32)
                    .disabled(inputText.isEmpty)
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
        .padding(.bottom, max(viewModel.keyboardHeight - bottomInset, 0))
        .animation(.easeOut(duration: 0.2), value: viewModel.keyboardHeight)
    }

    // MARK: Sidebar
    private var sidebarOverlay: some View {
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

    // MARK: - 發送訊息（串流）
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

