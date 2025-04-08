import SwiftUI

// OpenAI API通信用的資料結構
struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
}

struct OpenAIResponseChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIResponseChoice]
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isMe: Bool
}

struct ChatRoom: Identifiable {
    let id = UUID()
    let name: String
    var messages: [ChatMessage]
}

class ChatViewModel: ObservableObject {
    // 你的OpenAI API Key
    private let apiKey = "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"
    
    func sendMessageToGPT(messages: [ChatMessage]) async -> String? {
        // 將ChatMessage轉換為OpenAI格式 並且可以記住對話
        let apiMessages = messages.map { message in
            OpenAIMessage(
                role: message.isMe ? "user" : "assistant",
                content: message.text
            )
        }
        
        let requestBody = OpenAIRequest(
            model: "gpt-4",
            messages: apiMessages,
            temperature: 0.7
        )
        
        guard let requestData = try? JSONEncoder().encode(requestBody) else {
            print("Failed to encode request")
            return nil
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Error response: \(response)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Response body: \(errorString)")
                }
                return nil
            }
            
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let choice = openAIResponse.choices.first {
                return choice.message.content
            } else {
                return nil
            }
        } catch {
            print("Network error: \(error)")
            return nil
        }
    }
}

struct ChatDemoDynamicView: View {
    
    // 定義常用顏色
    private let backgroundColor = Color(red: 0.98, green: 0.77, blue: 0.56) // 近似淺橘底色
    private let darkBubbleColor = Color(red: 0.85, green: 0.52, blue: 0.34) // 深橘對話框
    private let midBubbleColor  = Color(red: 0.96, green: 0.72, blue: 0.45) // 中橘對話框
    private let lightBubbleColor = Color(red: 1.00, green: 0.90, blue: 0.80) // 淺橘對話框
    private let textColor = Color(red: 0.62, green: 0.36, blue: 0.22)       // 深咖啡字色
    private let sidebarColor = Color(red: 0.90, green: 0.65, blue: 0.40)    // 側邊欄顏色
    
    // 建立多個聊天室
    @State private var chatRooms: [ChatRoom] = [
        ChatRoom(name: "GPT助手", messages: [
            ChatMessage(text: "您好，我是GPT助手，有什麼我可以幫您的嗎？", isMe: false)
        ]),
        ChatRoom(name: "家人群組", messages: [
            ChatMessage(text: "哈囉", isMe: false),
            ChatMessage(text: "你好嗎？", isMe: false),
            ChatMessage(text: "我還不錯，謝謝", isMe: true)
        ]),
    ]
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedRoomIndex: Int = 0
    @State private var inputText: String = ""
    @State private var showSidebar: Bool = false
    @State private var isLoading: Bool = false
    @State private var showNewChatModal: Bool = false
    @State private var newChatName: String = ""
    
    var body: some View {
        ZStack {
            // 背景
            backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            // 主聊天界面
            VStack(spacing: 0) {
                
                // 上方標題列
                HStack {
                    Button(action: {
                        withAnimation {
                            showSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(textColor)
                    }
                    
                    Spacer()
                    Text(chatRooms[selectedRoomIndex].name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(textColor)
                    Spacer()
                    Button(action: {
                        // 顯示新增聊天室對話框
                        showNewChatModal = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(textColor)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // 這個 ScrollView + LazyVStack 就是常用的聊天列表
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatRooms[selectedRoomIndex].messages) { msg in
                            // 依據 isMe 來判斷要靠左或靠右
                            if msg.isMe {
                                // 右邊訊息
                                HStack {
                                    Spacer()
                                    Text(msg.text)
                                        .font(.system(size: 20))
                                        .padding(16)
                                        .background(darkBubbleColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        // 加上陰影
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                                }
                                .padding(.horizontal)
                            } else {
                                // 左邊訊息
                                HStack {
                                    Text(msg.text)
                                        .font(.system(size: 20))
                                        .padding(16)
                                        .background(lightBubbleColor)
                                        .foregroundColor(textColor)
                                        .cornerRadius(12)
                                        // 加上陰影
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 顯示載入中動畫
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                                    .scaleEffect(1.5)
                                    .padding(16)
                                    .background(lightBubbleColor)
                                    .cornerRadius(12)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                
                // 底部輸入框
                HStack {
                    TextField("輸入訊息...", text: $inputText)
                        .font(.system(size: 18))
                        .padding(16)
                        .frame(height: 55)
                        .background(midBubbleColor)
                        .cornerRadius(12)
                        .foregroundColor(textColor)
                        .disabled(isLoading)
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrowshape.up")
                            .font(.system(size: 22))
                            .foregroundColor(textColor)
                            .padding()
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .offset(x: showSidebar ? 250 : 0)
            
            // 側邊欄
            if showSidebar {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 增加頂部空間避免被瀏海遮住
                            Color.clear
                                .frame(height: 90)
                            
                            Text("聊天室列表")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(textColor)
                                .padding(.vertical, 20)
                                .padding(.leading, 20)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(chatRooms.enumerated()), id: \.element.id) { index, room in
                                        Button(action: {
                                            selectedRoomIndex = index
                                            withAnimation {
                                                showSidebar = false
                                            }
                                        }) {
                                            Text(room.name)
                                                .font(.title2)
                                                .foregroundColor(textColor)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                                .background(index == selectedRoomIndex ? midBubbleColor : Color.clear)
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
                        .edgesIgnoringSafeArea(.vertical)
                        
                        Spacer()
                    }
                }
                .zIndex(1)
                .transition(.move(edge: .leading))
                
                // 背景遮罩，點擊可關閉側邊欄
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            showSidebar = false
                        }
                    }
            }
            
            // 新增聊天室對話框
            if showNewChatModal {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showNewChatModal = false
                        newChatName = ""
                    }
                
                VStack(spacing: 20) {
                    Text("新增聊天室")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    
                    TextField("聊天室名稱", text: $newChatName)
                        .font(.system(size: 18))
                        .padding(16)
                        .background(midBubbleColor)
                        .cornerRadius(12)
                        .foregroundColor(textColor)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showNewChatModal = false
                            newChatName = ""
                        }) {
                            Text("取消")
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(lightBubbleColor)
                                .foregroundColor(textColor)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            createNewChatRoom()
                        }) {
                            Text("建立")
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(darkBubbleColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(newChatName.isEmpty)
                        .opacity(newChatName.isEmpty ? 0.6 : 1.0)
                    }
                }
                .padding(30)
                .background(backgroundColor)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding(.horizontal, 30)
            }
        }
    }
    
    // 發送訊息並獲取GPT回應
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // 添加用戶訊息
        let userMessage = ChatMessage(text: inputText, isMe: true)
        chatRooms[selectedRoomIndex].messages.append(userMessage)
        
        // 清空輸入欄
        let userInput = inputText
        inputText = ""
        
        // 所有聊天室都連接到GPT
        isLoading = true
        
        Task {
            // 用所有歷史訊息呼叫API
            if let response = await viewModel.sendMessageToGPT(messages: chatRooms[selectedRoomIndex].messages) {
                // 回到主線程更新UI
                await MainActor.run {
                    let aiMessage = ChatMessage(text: response, isMe: false)
                    chatRooms[selectedRoomIndex].messages.append(aiMessage)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    let errorMessage = ChatMessage(text: "抱歉，無法連接到GPT服務。請稍後再試。", isMe: false)
                    chatRooms[selectedRoomIndex].messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
    
    private func createNewChatRoom() {
        guard !newChatName.isEmpty else { return }
        
        // 創建新聊天室
        let newRoom = ChatRoom(
            name: newChatName,
            messages: [
                ChatMessage(text: "歡迎來到「\(newChatName)」聊天室！", isMe: false)
            ]
        )
        
        // 添加到聊天室列表
        chatRooms.append(newRoom)
        
        // 自動選擇新聊天室
        selectedRoomIndex = chatRooms.count - 1
        
        // 關閉對話框並清除輸入
        showNewChatModal = false
        newChatName = ""
    }
}

#Preview {
    ChatDemoDynamicView()
}
