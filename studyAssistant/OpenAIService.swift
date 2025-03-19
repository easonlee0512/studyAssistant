import Foundation
import Alamofire

class OpenAIService {
    struct OpenAIChatRequest: Encodable {
        let model: String
        let messages: [[String: String]]
    }

    struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            let message: Message
        }
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let choices: [Choice]
    }

    static func fetchGPTResponse(prompt: String, completion: @escaping (String?) -> Void) {
        let url = "https://api.openai.com/v1/chat/completions"

        let parameters = OpenAIChatRequest(
            model: "gpt-4o",
            messages: [
                ["role": "system", "content": " "],
                ["role": "user", "content": prompt]
            ]
        )

        AF.request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: [
            "Authorization": "Bearer \(Config.openAIKey)",
            "Content-Type": "application/json"
        ]).responseDecodable(of: OpenAIChatResponse.self) { response in
            switch response.result {
            case .success(let data):
                completion(data.choices.first?.message.content)
            case .failure(let error):
                print("❌ 錯誤: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}
