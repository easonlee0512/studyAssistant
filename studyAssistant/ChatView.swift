import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var focusedField: Field?
    @State private var isFormMode = true  // 添加狀態變量，控制是表單模式還是聊天模式
    @State private var chatMessage = ""   // 添加聊天消息輸入框的狀態
    
    private enum Field {
        case planTitle
        case subjectRange
        case preferredTime
        case note
        case chatInput  // 添加聊天輸入框的焦點狀態
    }
    
    // 初始化方法，接收 dataStore
    init(dataStore: AppDataStore) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(dataStore: dataStore))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 聊天記錄區域
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages, id: \.self) { message in
                            Text(message)
                                .padding()
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message
                                    }) {
                                        Label("複製全部", systemImage: "doc.on.doc")
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)

                if isFormMode {
                    // 表單輸入區域 - 只在表單模式顯示
                    formView
                } else {
                    // 聊天輸入區域 - 只在聊天模式顯示
                    chatInputView
                }
            }
            .navigationTitle(isFormMode ? "建立讀書計畫" : "讀書計畫聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isFormMode {
                        Button(action: {
                            withAnimation {
                                isFormMode = true
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onTapGesture {
                if isFormMode {
                    withAnimation {
                        isFormMode = false
                    }
                }
            }
        }
    }
    
    // 表單視圖
    private var formView: some View {
        VStack(spacing: 16) {
            // 計畫標題輸入
            VStack(alignment: .leading, spacing: 8) {
                Text("計畫標題")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("例如：國文", text: $viewModel.planTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .planTitle)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .subjectRange
                    }
                
                if viewModel.isPlanTitleEmpty {
                    Text("請輸入計畫標題")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            // 科目範圍輸入
            VStack(alignment: .leading, spacing: 8) {
                Text("科目範圍")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("例如：10個章節", text: $viewModel.subjectRange)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .subjectRange)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .preferredTime
                    }
                
                if viewModel.isSubjectRangeEmpty {
                    Text("請輸入科目範圍")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            // 讀書偏好時間
            VStack(alignment: .leading, spacing: 8) {
                Text("讀書偏好時間")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("例如：禮拜六晚上", text: $viewModel.preferredTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .preferredTime)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .note
                    }
            }
            .padding(.horizontal)
            
            // 其他補充
            VStack(alignment: .leading, spacing: 8) {
                Text("其他補充")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("例如：每個章節有哪幾小節", text: $viewModel.note)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .note)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        sendPlanMessage()
                    }
            }
            .padding(.horizontal)
            
            // 計畫期限
            VStack(alignment: .leading, spacing: 8) {
                Text("計畫期限")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                DatePicker("", selection: $viewModel.deadline, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            .padding(.horizontal)
            
            // 生成計畫按鈕
            Button(action: {
                sendPlanMessage()
            }) {
                Text("生成計畫")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    // 聊天輸入視圖
    private var chatInputView: some View {
        HStack {
            TextField("輸入訊息...", text: $chatMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .chatInput)
                .submitLabel(.send)
                .onSubmit {
                    sendChatMessage()
                }
            
            Button(action: {
                sendChatMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    // 發送計畫請求並切換到聊天模式
    private func sendPlanMessage() {
        viewModel.sendMessage()
        withAnimation {
            isFormMode = false  // 生成計畫後切換到聊天模式
        }
    }
    
    // 發送聊天消息
    private func sendChatMessage() {
        if !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.sendCustomMessage(chatMessage)
            chatMessage = ""
        }
    }
}

#Preview {
    ContentView()
}
