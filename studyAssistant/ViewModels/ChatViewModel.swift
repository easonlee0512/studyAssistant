import Foundation
import SwiftUI

// MARK: - OpenAI API 資料結構
struct OpenAIMessage: Codable {
    let role: String
    let content: String
    let name: String?
    
    init(role: String, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}

// Function calling 相關結構
struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: Parameters
    
    struct Parameters: Codable {
        let type: String
        let properties: [String: Property]
        
        struct Property: Codable {
            let type: String
            let description: String?
        }
    }
}

struct OpenAIFunctionCall: Codable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            self.name = stringValue
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
    }
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
    let stream: Bool
    let functions: [OpenAIFunction]?
    let function_call: OpenAIFunctionCall?
}

// 非串流回傳格式（給 generateTitle 用）
struct OpenAIResponseChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?
    let function_call: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
        case function_call
    }
}
struct OpenAIResponse: Decodable {
    let id: String
    let choices: [OpenAIResponseChoice]
}

// 串流 chunk 格式
struct OpenAIStreamDelta: Decodable {
    let role: String?
    let content: String?
    let function_call: FunctionCallDelta?
    
    struct FunctionCallDelta: Decodable {
        let name: String?
        let arguments: String?
    }
}
struct OpenAIStreamChoice: Decodable {
    let index: Int
    let delta: OpenAIStreamDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}
struct OpenAIStreamChunk: Decodable {
    let id: String
    let choices: [OpenAIStreamChoice]
}

// MARK: - 基本聊天資料結構
struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isMe: Bool
}

struct ChatRoom: Identifiable {
    let id = UUID()
    var name: String
    var messages: [ChatMessage]
}

// MARK: - 與 GPT 通訊的 View-Model
@MainActor
final class ChatViewModel: ObservableObject {
    private let proxyURL   = URL(string: "https://gpt-proxy-api.studyassistant.workers.dev")!
    private let proxyToken = "my-secret-token"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 聊天室資料
    @Published var chatRooms: [ChatRoom] = [
        ChatRoom(name: "新聊天室", messages: [
            ChatMessage(text: "我是讀書助手，有什麼可以幫您安排的讀書計劃嗎？", isMe: false)
        ])
    ]
    @Published var selectedRoomIndex: Int = 0

    // 定義 getTask 函數
    private let getTaskFunction = OpenAIFunction(
        name: "getTask",
        description: "Get all tasks from the system",
        parameters: OpenAIFunction.Parameters(
            type: "object",
            properties: [:]
        )
    )

    // 定義 getTime 函數
    private let getTimeFunction = OpenAIFunction(
        name: "getTime",
        description: "Get current time from the system",
        parameters: OpenAIFunction.Parameters(
            type: "object",
            properties: [:]
        )
    )

    // 檢查是否可以新增聊天室
    var canCreateNewChatRoom: Bool {
        let currentRoom = chatRooms[selectedRoomIndex]
        if currentRoom.name == "新聊天室" && currentRoom.messages.count <= 1 {
            return false
        }
        return true
    }

    // 新增聊天室
    func createNewChatRoom() {
        withAnimation {
            chatRooms.append(ChatRoom(name: "新聊天室", messages: [
                ChatMessage(text: "我是讀書助手，有什麼可以幫您安排的讀書計劃嗎？", isMe: false)
            ]))
            selectedRoomIndex = chatRooms.count - 1
        }
    }

    // 執行 getTime 函數並將結果添加到聊天記錄
    private func executeGetTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let currentTime = formatter.string(from: Date())
        return "現在時間是：\(currentTime)"
    }

    // 執行 getTask 函數並將結果添加到聊天記錄
    private func executeGetTask() async -> String {
        let firebaseService = FirebaseService.shared
        do {
            // 從 Firebase 獲取任務
            let tasks = try await firebaseService.fetchTodoTasks()
            
            var taskString: String
            if tasks.isEmpty {
                taskString = "目前沒有任何任務。"
            } else {
                // 加入今日時間
                let today = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd HH:mm"
                let todayString = formatter.string(from: today)
                taskString = "今日日期: \(todayString)\n"
                taskString += "allTasks\n"
                for task in tasks {
                    taskString += "\(task.title) "
                    taskString += "isCompleted:\(task.isCompleted) "
                    if !task.note.isEmpty {
                        taskString += "note:\(task.note) "
                    }
                    taskString += "startTime:\(formatDate(task.startDate)) "
                    taskString += "endTime:\(formatDate(task.endDate))\n\n"
                }
                print("taskString: \(taskString)")
            }
            return taskString
        } catch {
            return "抱歉，無法獲取任務列表。請確保您已登入並且網路連接正常。"
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    // ----------------------------- 串流 GPT -----------------------------
    /// 對 GPT 串流，邊收到邊透過 onToken 回呼；結束後回傳完整內容
    func sendMessageToGPT(
        messages: [ChatMessage],
        onToken: ((String) -> Void)? = nil
    ) async -> String? {
        print("開始發送訊息到 GPT")
        let apiMsgs = messages.map {
            OpenAIMessage(role: $0.isMe ? "user" : "assistant", content: $0.text)
        }
        
        let tone = "霸道總裁的語氣，要叫使用者：過來！坐下！"
        // 添加 system message 來指導 GPT 使用 function
        let systemMsg = OpenAIMessage(
            role: "system",
            content: "你現在是安排計畫的大師，問使用者最少的問題去安排計畫，並且要有具體的計畫安排時間。當需要任務資訊時，請使用 getTask 函數來獲取資訊。當需要任務資訊時，請使用 getTime 函數來獲取當前時間。並且語氣為：\(tone)"
        )
        var allMessages = [systemMsg] + apiMsgs
        
        let reqBody = OpenAIRequest(
            model: "gpt-4.1",
            messages: allMessages,
            temperature: 0.7,
            stream: true,
            functions: [getTaskFunction, getTimeFunction],
            function_call: nil
        )

        print("請求內容：\(String(describing: try? JSONEncoder().encode(reqBody)))")

        guard let data = try? encoder.encode(reqBody) else {
            print("編碼請求失敗")
            return nil
        }

        var req = URLRequest(url: proxyURL)
        req.httpMethod = "POST"
        req.addValue(proxyToken, forHTTPHeaderField: "x-api-token")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = data

        do {
            print("開始發送請求")
            let (bytes, resp) = try await URLSession.shared.bytes(for: req, delegate: nil)
            guard let httpResponse = resp as? HTTPURLResponse else {
                print("回應不是 HTTP 回應")
                return nil
            }
            print("收到回應，狀態碼：\(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else { return nil }

            var full = ""
            var hasFunctionCall = false

            for try await line in bytes.lines {
                // 檢查任務是否被取消
                try Task.checkCancellation()
                
                guard line.hasPrefix("data: ") else {
                    print("跳過非資料行：\(line)")
                    continue
                }
                let payload = String(line.dropFirst(6))
                print("收到資料：\(payload)")

                if payload == "[DONE]" {
                    print("收到完成標記")
                    break
                }

                if let json = payload.data(using: .utf8),
                   let chunk = try? decoder.decode(OpenAIStreamChunk.self, from: json) {
                    print("解析 chunk：\(String(describing: chunk.choices.first?.delta))")
                    
                    if let functionCall = chunk.choices.first?.delta.function_call,
                       let functionName = functionCall.name {
                        print("檢測到 function call：\(functionName)")
                        if functionName == "getTask" {
                            print("執行 getTask 函數")
                            hasFunctionCall = true
                            let result = await executeGetTask()
                            
                            // 將結果發送回 GPT 繼續對話
                            allMessages.append(OpenAIMessage(role: "function", content: result, name: "getTask"))
                            allMessages.append(OpenAIMessage(role: "system", content: "請分析上面的任務列表，並用自然語言回答"))
                            
                            // 創建新的請求
                            let newReqBody = OpenAIRequest(
                                model: "gpt-4.1",
                                messages: allMessages,
                                temperature: 0.7,
                                stream: true,
                                functions: [getTaskFunction, getTimeFunction],
                                function_call: nil
                            )
                            
                            if let newData = try? encoder.encode(newReqBody) {
                                print("發送新請求給 GPT")
                                req.httpBody = newData
                                let (newBytes, newResp) = try await URLSession.shared.bytes(for: req, delegate: nil)
                                guard let httpResponse = newResp as? HTTPURLResponse else {
                                    print("回應不是 HTTP 回應")
                                    continue
                                }
                                print("收到新回應，狀態碼：\(httpResponse.statusCode)")
                                guard httpResponse.statusCode == 200 else {
                                    print("HTTP 狀態碼不是 200")
                                    continue
                                }
                                
                                for try await newLine in newBytes.lines {
                                    guard newLine.hasPrefix("data: ") else {
                                        print("跳過非資料行：\(newLine)")
                                        continue
                                    }
                                    let newPayload = String(newLine.dropFirst(6))
                                    print("收到新資料：\(newPayload)")
                                    
                                    if newPayload == "[DONE]" {
                                        print("收到完成標記")
                                        break
                                    }
                                    
                                    if let newJson = newPayload.data(using: .utf8),
                                       let newChunk = try? decoder.decode(OpenAIStreamChunk.self, from: newJson),
                                       let piece = newChunk.choices.first?.delta.content {
                                        print("解析到內容：\(piece)")
                                        full += piece
                                        await onToken?(piece)
                                    }
                                }
                            }
                        } else if functionName == "getTime" {
                            print("執行 getTime 函數")
                            hasFunctionCall = true
                            let result = executeGetTime()
                            print("getTime 結果：\(result)")
                            
                            // 將結果發送回 GPT 繼續對話
                            allMessages.append(OpenAIMessage(role: "function", content: result, name: "getTime"))
                            allMessages.append(OpenAIMessage(role: "system", content: "請根據當前時間，用自然語言回應用戶，並根據時間給出合適的建議。"))
                            
                            // 創建新的請求
                            let newReqBody = OpenAIRequest(
                                model: "gpt-4.1",
                                messages: allMessages,
                                temperature: 0.7,
                                stream: true,
                                functions: [getTaskFunction, getTimeFunction],
                                function_call: nil
                            )
                            
                            if let newData = try? encoder.encode(newReqBody) {
                                print("發送新請求給 GPT")
                                req.httpBody = newData
                                let (newBytes, newResp) = try await URLSession.shared.bytes(for: req, delegate: nil)
                                guard let httpResponse = newResp as? HTTPURLResponse else {
                                    print("回應不是 HTTP 回應")
                                    continue
                                }
                                print("收到新回應，狀態碼：\(httpResponse.statusCode)")
                                guard httpResponse.statusCode == 200 else {
                                    print("HTTP 狀態碼不是 200")
                                    continue
                                }
                                
                                for try await newLine in newBytes.lines {
                                    guard newLine.hasPrefix("data: ") else {
                                        print("跳過非資料行：\(newLine)")
                                        continue
                                    }
                                    let newPayload = String(newLine.dropFirst(6))
                                    print("收到新資料：\(newPayload)")
                                    
                                    if newPayload == "[DONE]" {
                                        print("收到完成標記")
                                        break
                                    }
                                    
                                    if let newJson = newPayload.data(using: .utf8),
                                       let newChunk = try? decoder.decode(OpenAIStreamChunk.self, from: newJson),
                                       let piece = newChunk.choices.first?.delta.content {
                                        print("解析到內容：\(piece)")
                                        full += piece
                                        await onToken?(piece)
                                    }
                                }
                            } else {
                                print("編碼新請求失敗")
                            }
                        }
                    } else if let piece = chunk.choices.first?.delta.content {
                        print("收到內容：\(piece)")
                        full += piece
                        await onToken?(piece)
                    }
                } else {
                    print("無法解析 JSON 或 chunk")
                }
            }

            print("對話結束，hasFunctionCall: \(hasFunctionCall), full: \(full)")
            

            return full
        } catch is CancellationError {
            print("任務被取消")
            return nil
        } catch {
            print("發生錯誤：\(error)")
            return nil
        }
    }

    // ----------------------------- 產生標題（非串流） -----------------------------
    func generateTitle(from firstUserMessage: String) async -> String? {
        let sys = OpenAIMessage(role: "system", content: "你是一個摘要大師，請根據使用者的第一句話，生成最多8個字的摘要。直接輸出名稱不要有簡體字。")
        let usr = OpenAIMessage(role: "user",   content: firstUserMessage)
        let body = OpenAIRequest(model: "gpt-4.1-mini",
                                 messages: [sys, usr],
                                 temperature: 0.2,
                                 stream: false,
                                 functions: nil,
                                 function_call: nil)
        return await callOpenAIOnce(with: body)
    }

    // ----------------------------- Helper (一次回整段) -----------------------------
    private func callOpenAIOnce(with body: OpenAIRequest) async -> String? {
        guard let data = try? encoder.encode(body) else { return nil }
        var req = URLRequest(url: proxyURL)
        req.httpMethod = "POST"
        req.addValue(proxyToken, forHTTPHeaderField: "x-api-token")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        do {
            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            if let res = try? decoder.decode(OpenAIResponse.self, from: respData),
               let choice = res.choices.first {
                return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch { }
        return nil
    }
} 