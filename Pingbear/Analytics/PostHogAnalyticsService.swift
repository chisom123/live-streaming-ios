import Foundation
import PostHog

// Implementation using PostHog
class PostHogAnalyticsService: AnalyticsService {
    private let posthog = PostHogSDK.shared
    
    init(apiKey: String, host: String) {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        posthog.setup(config)
    }
    
    func track(event: String, properties: [String: Any]? = nil) {
        posthog.capture(event, properties: properties)
    }
    
    func identify(userId: String, properties: [String: Any]? = nil) {
        // Basic identity
        posthog.identify(userId)
        
        // Set properties if available
        if let properties = properties {
            posthog.capture("$identify", properties: [
                "$set": properties
            ])
        }
    }
    
    func reset() {
        posthog.reset()
    }
}
