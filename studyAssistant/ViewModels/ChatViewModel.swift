import Foundation
import SwiftUI

// MARK: - OpenAI API 資料結構
struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
    let stream: Bool         // ← 串流旗標
}

// 非串流回傳格式（給 generateTitle 用）
struct OpenAIResponseChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
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

    // ----------------------------- 串流 GPT -----------------------------
    /// 對 GPT 串流，邊收到邊透過 onToken 回呼；結束後回傳完整內容
    func sendMessageToGPT(
        messages: [ChatMessage],
        onToken: ((String) -> Void)? = nil
    ) async -> String? {
        let apiMsgs = messages.map {
            OpenAIMessage(role: $0.isMe ? "user" : "assistant", content: $0.text)
        }
        let reqBody = OpenAIRequest(model: "gpt-4.1-mini",
                                  messages: apiMsgs,
                                  temperature: 0.7,
                                  stream: true)

        guard let data = try? encoder.encode(reqBody) else { return nil }

        var req = URLRequest(url: proxyURL)
        req.httpMethod = "POST"
        req.addValue(proxyToken, forHTTPHeaderField: "x-api-token")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = data

        do {
            let (bytes, resp) = try await URLSession.shared.bytes(for: req, delegate: nil)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            var full = ""
            for try await line in bytes.lines {
                // 檢查任務是否被取消
                try Task.checkCancellation()
                
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))

                if payload == "[DONE]" { break }

                if let json = payload.data(using: .utf8),
                   let chunk = try? decoder.decode(OpenAIStreamChunk.self, from: json),
                   let piece = chunk.choices.first?.delta.content {

                    full += piece
                    await onToken?(piece)
                }
            }
            return full
        } catch is CancellationError {
            // 任務被取消時，直接返回 nil
            return nil
        } catch {
            return nil
        }
    }

    // ----------------------------- 產生標題（非串流） -----------------------------
    func generateTitle(from firstUserMessage: String) async -> String? {
        let sys = OpenAIMessage(role: "system", content: "你是一個摘要大師，請根據使用者的第一句話，生成最多8個字的摘要。直接輸出名稱不要有簡體字。")
        let usr = OpenAIMessage(role: "user",   content: firstUserMessage)
        let body = OpenAIRequest(model: "gpt-4o-mini",
                                 messages: [sys, usr],
                                 temperature: 0.2,
                                 stream: false)
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