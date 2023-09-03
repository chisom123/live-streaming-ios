import Foundation
import SwiftUI
import ChatGPTSwift

final class APICaller {
    static let shared = APICaller()
    
    @frozen enum Constants {
        // Remember, it's essential not to hard-code the API key like this. Consider a more secure approach.
        static let key = "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"
    }
    
    private var client: ChatGPTAPI?
    
    private init() {}
    
    public func setup() {
        self.client = ChatGPTAPI(apiKey: Constants.key)
        
        // Making sure no history is used
        self.client?.deleteHistoryList()
    }
    
    public func getResponse(input: String,
                            completion: @escaping (Result<String, Error>) -> Void) {
        
        Task {
            do {
                if let response = try await client?.sendMessage(text: "Chat history: \(input)", systemText: "You are a text-messaging assistant chatbot. Using the chat history as context, craft one continuation text for User-A to send to User-B. Focus on capturing the distinct nuances and tonality of User-A's communication style. The message should feel like a seamless extension of their earlier conversations") {
                    completion(.success(response))
                } else {
                    completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Response was nil"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
