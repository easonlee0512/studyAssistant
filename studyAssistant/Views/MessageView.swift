import SwiftUI

// MARK: - 主要畫面
struct ChatDemoDynamicView: View {
    // 色票
    private let backgroundColor  = Color.hex(hex: "F3D4B7") // 與TodoView相同的背景色
    private let darkBubbleColor  = Color.hex(hex: "E28A5F") // 深橘色按鈕顏色
    private let midBubbleColor   = Color.hex(hex: "FEECD8") // 淺橙底色（輸入框）
    private let lightBubbleColor = Color.hex(hex: "FEECD8") // 淺橙底色（對話框）
    private let textColor        = Color.black.opacity(0.8)   // 深色文字
    private let sidebarColor     = Color.hex(hex: "F3D4B7").opacity(0.7)  // 側邊欄顏色，與"開始"按鈕相似
    private let titleColor       = Color.hex(hex: "E27945") // 聊天室名稱顏色

    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showSidebar = false
    @State private var currentTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                messageList
                inputBar
            }
            .offset(x: showSidebar ? 250 : 0)
            if showSidebar { sidebarOverlay }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            Button { withAnimation { showSidebar.toggle() } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.hex(hex: "E27844"))
            }
            Spacer()
            Text(viewModel.chatRooms[viewModel.selectedRoomIndex].name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button(action: viewModel.createNewChatRoom) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.hex(hex: "E27844"))
            }
            .disabled(!viewModel.canCreateNewChatRoom)
            .opacity(viewModel.canCreateNewChatRoom ? 1.0 : 0.3)
        }
        .padding(.horizontal)
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    // MARK: Message List
    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.chatRooms[viewModel.selectedRoomIndex].messages) { msg in
                    if msg.isMe { userBubble(msg.text) } else { aiBubble(msg.text) }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }
    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 20))
                .padding(16)
                .background(darkBubbleColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
        }
        .padding(.horizontal)
    }
    private func aiBubble(_ text: String) -> some View {
        HStack {
            CustomMarkdownText(text, textColor: textColor)
                .padding(16)
                .background(lightBubbleColor)
                .foregroundColor(textColor)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal)
    }

    // 自定義 Markdown 文字視圖
    private struct CustomMarkdownText: View {
        let text: String
        let textColor: Color
        
        init(_ text: String, textColor: Color) {
            self.text = text
            self.textColor = textColor
        }
        
        // 解析粗體文字
        private func parseText(_ text: String) -> Text {
            var result = Text("")
            var currentText = ""
            var isBold = false
            var index = text.startIndex
            
            while index < text.endIndex {
                let char = text[index]
                if char == "*" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "*" {
                    // 處理當前累積的文字
                    if !currentText.isEmpty {
                        result = result + Text(currentText).font(.system(size: 20, weight: isBold ? .bold : .regular))
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
                result = result + Text(currentText).font(.system(size: 20, weight: isBold ? .bold : .regular))
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
                    } else if line.hasPrefix("### ") {
                        parseText(String(line.dropFirst(4)))
                            .font(.system(size: 22, weight: .semibold))
                    } else if line.hasPrefix("## ") {
                        parseText(String(line.dropFirst(3)))
                            .font(.system(size: 24, weight: .bold))
                    } else if line.hasPrefix("# ") {
                        parseText(String(line.dropFirst(2)))
                            .font(.system(size: 28, weight: .bold))
                    } else if line.hasPrefix("- ") {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 20))
                                .foregroundColor(textColor)
                                .frame(width: 20, alignment: .center)
                            parseText(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                                .font(.system(size: 20))
                        }
                        .padding(.leading, 4)
                    } else {
                        parseText(line)
                    }
                }
            }
        }
    }

    // MARK: Input Bar
    private var inputBar: some View {
        HStack {
            TextField("輸入訊息...", text: $inputText)
                .font(.system(size: 18))
                .padding(16)
                .frame(height: 55)
                .background(midBubbleColor)
                .cornerRadius(12)
                .foregroundColor(textColor)
            Button(action: sendMessage) {
                Image(systemName: "arrowshape.up")
                    .font(.system(size: 22))
                    .foregroundColor(textColor)
                    .padding()
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 90)
    }

    // MARK: Sidebar
    private var sidebarOverlay: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Spacer().frame(height: 40)
                    Text("聊天室列表")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(textColor)
                        .padding(.vertical, 10)
                        .padding(.leading, 20)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(viewModel.chatRooms.enumerated()), id: \.element.id) { idx, room in
                                Button {
                                    currentTask?.cancel()
                                    viewModel.selectedRoomIndex = idx
                                    withAnimation { showSidebar = false }
                                } label: {
                                    Text(room.name)
                                        .font(.title3)
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(idx == viewModel.selectedRoomIndex ? midBubbleColor : Color.clear)
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
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
        let userMsg = ChatMessage(text: inputText, isMe: true)
        let firstUserMessage = inputText
        viewModel.chatRooms[viewModel.selectedRoomIndex].messages.append(userMsg)
        inputText = ""

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

        // 取消舊的任務並創建新的
        currentTask?.cancel()
        currentTask = Task {
            _ = await viewModel.sendMessageToGPT(
                messages: viewModel.chatRooms[viewModel.selectedRoomIndex].messages
            ) { token in
                if !Task.isCancelled {
                    viewModel.chatRooms[viewModel.selectedRoomIndex].messages[aiIndex].text += token
                }
            }
            currentTask = nil
        }
    }
}

// MARK: - Preview
#Preview {
    ChatDemoDynamicView()
}
