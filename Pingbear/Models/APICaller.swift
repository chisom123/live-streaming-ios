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
                if let response = try await client?.sendMessage(text: input, systemText: "Your role is to provide Me with a text-message response using the conversation history as context") {
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
