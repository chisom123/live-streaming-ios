import Foundation

// Protocol defining core analytics operations
protocol AnalyticsService {
    func track(event: String, properties: [String: Any]?)
    func identify(userId: String, properties: [String: Any]?)
    func reset()
}

// Event name constants for standardized naming
struct AnalyticsEvent {
    // Screen events
    static let screenView = "screen_viewed"
    
    // User interaction events
    static let tap = "user_tapped"
    static let swipe = "user_swiped"
    static let scroll = "user_scrolled"
    
    // Competition events
    static let competitionView = "competition_viewed"
    static let competitionCreate = "competition_created"
    static let competitionJoin = "competition_joined"
    static let competitionLeave = "competition_left"
    static let competitionEdit = "competition_edited"
    
    // Entry events
    static let entryCreate = "entry_created"
    static let entryView = "entry_viewed"
    static let entryRate = "entry_rated"
    static let entryBoost = "entry_boosted"
    
    // Purchase events
    static let purchaseInitiate = "purchase_initiated"
    static let purchaseComplete = "purchase_completed"
    static let purchaseFail = "purchase_failed"
    static let purchaseRestore = "purchase_restored"
    
    // Account events
    static let accountCreate = "account_created"
    static let accountLogin = "user_logged_in"
    static let accountLogout = "user_logged_out"
    
    // Error events
    static let errorOccur = "error_occurred"
}

// Property name constants for standardized property naming
struct AnalyticsProperty {
    static let id = "id"
    static let name = "name"
    static let type = "type"
    static let source = "source"
    
    // Screen properties
    static let screenName = "screen_name"
    
    // Element properties
    static let elementId = "element_id"
    
    // Item properties
    static let competitionId = "competition_id"
    static let entryId = "entry_id"
    static let productId = "product_id"
    
    // Error properties
    static let errorMessage = "error_message"
}

// Central analytics class that forwards to current service
class Analytics {
    // Singleton instance
    static let shared = Analytics()
    
    private var service: AnalyticsService?
    private var enabled = true
    
    private init() {}
    
    func configure(with service: AnalyticsService) {
        self.service = service
    }
    
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }
    
    // Core tracking method
    func track(event: String, properties: [String: Any]? = nil) {
        guard enabled, let service = service else { return }
        service.track(event: event, properties: properties)
    }
    
    func identify(userId: String, properties: [String: Any]? = nil) {
        guard enabled, let service = service else { return }
        service.identify(userId: userId, properties: properties)
    }
    
    func reset() {
        guard let service = service else { return }
        service.reset()
    }
    
    // MARK: - Screen Tracking
    
    func trackScreen(name: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.screenName] = name
        track(event: AnalyticsEvent.screenView, properties: props)
    }
    
    // MARK: - User Interactions
    
    func trackTap(elementId: String, screenName: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.elementId] = elementId
        if let screenName = screenName {
            props[AnalyticsProperty.screenName] = screenName
        }
        track(event: AnalyticsEvent.tap, properties: props)
    }
    
    // MARK: - Competition Events
    
    func trackCompetition(action: String, competitionId: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.competitionId] = competitionId
        
        let event: String
        switch action.lowercased() {
        case "view", "viewed":
            event = AnalyticsEvent.competitionView
        case "create", "created":
            event = AnalyticsEvent.competitionCreate
        case "join", "joined":
            event = AnalyticsEvent.competitionJoin
        case "leave", "left":
            event = AnalyticsEvent.competitionLeave
        case "edit", "edited":
            event = AnalyticsEvent.competitionEdit
        default:
            event = action
        }
        
        track(event: event, properties: props)
    }
    
    // MARK: - Entry Events
    
    func trackEntry(action: String, entryId: String? = nil, competitionId: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        
        if let entryId = entryId {
            props[AnalyticsProperty.entryId] = entryId
        }
        
        if let competitionId = competitionId {
            props[AnalyticsProperty.competitionId] = competitionId
        }
        
        let event: String
        switch action.lowercased() {
        case "create", "created":
            event = AnalyticsEvent.entryCreate
        case "view", "viewed":
            event = AnalyticsEvent.entryView
        case "rate", "rated":
            event = AnalyticsEvent.entryRate
        case "boost", "boosted":
            event = AnalyticsEvent.entryBoost
        default:
            event = action
        }
        
        track(event: event, properties: props)
    }
    
    // MARK: - Purchase Events
    
    func trackPurchase(action: String, productId: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.productId] = productId
        
        let event: String
        switch action.lowercased() {
        case "initiate", "initiated", "attempt", "attempted":
            event = AnalyticsEvent.purchaseInitiate
        case "complete", "completed", "success", "successful":
            event = AnalyticsEvent.purchaseComplete
        case "fail", "failed":
            event = AnalyticsEvent.purchaseFail
        case "restore", "restored":
            event = AnalyticsEvent.purchaseRestore
        default:
            event = action
        }
        
        track(event: event, properties: props)
    }
    
    // MARK: - Error Events
    
    func trackError(message: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.errorMessage] = message
        track(event: AnalyticsEvent.errorOccur, properties: props)
    }
}
