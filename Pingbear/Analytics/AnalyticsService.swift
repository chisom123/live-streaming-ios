import Foundation

// ─────────────────────────────────────────────────────────────
// MARK: - Analytics Service Protocol
// ─────────────────────────────────────────────────────────────

protocol AnalyticsService {
    func track(event: String, properties: [String: Any]?)
    func identify(userId: String, properties: [String: Any]?)
    func reset()
}

// ─────────────────────────────────────────────────────────────
// MARK: - Event Name Constants
// ─────────────────────────────────────────────────────────────

struct AnalyticsEvent {

    // MARK: Screen views
    static let screenView               = "screen_viewed"

    // MARK: User interactions
    static let tap                      = "user_tapped"

    // MARK: Account
    static let accountCreated           = "account_created"
    static let userLoggedIn             = "user_logged_in"
    static let userLoggedOut            = "user_logged_out"

    // MARK: Friends
    static let friendAdded              = "friend_added"
    static let friendAddFailed          = "friend_add_failed"
    static let contactsPermissionGranted = "contacts_permission_granted"
    static let contactsPermissionDenied  = "contacts_permission_denied"
    static let inviteContactSelected    = "invite_contact_selected"
    static let inviteContactDeselected  = "invite_contact_deselected"
    static let inviteComposerOpened     = "invite_composer_opened"
    static let invitesSent              = "invites_sent"
    static let inviteComposerCancelled  = "invite_composer_cancelled"
    static let inviteComposerFailed     = "invite_composer_failed"
    static let inviteGroupResolved      = "invite_group_resolved"
    static let usernameSearchAttempted  = "username_search_attempted"

    // MARK: Transactions — requests
    static let requestSent              = "request_sent"
    static let requestAccepted          = "request_accepted"
    static let requestDeclined          = "request_declined"
    static let requestFulfilled         = "request_fulfilled"
    static let requestExpired           = "request_expired"
    static let requestCancelled         = "request_cancelled"

    // MARK: Top up
    static let topUpOpened              = "top_up_opened"
    static let topUpCompleted           = "top_up_completed"
    static let topUpFailed              = "top_up_failed"
    static let topUpCancelled           = "top_up_cancelled"

    // MARK: Content viewing
    static let photoViewed              = "photo_viewed"
    static let offerPhotoViewed         = "offer_photo_viewed"
    static let ratingSkipped            = "rating_skipped"

    // MARK: Inbox
    static let transactionDismissed     = "transaction_dismissed"

    // MARK: Transactions — offers
    static let offerSent                = "offer_sent"
    static let offerAccepted            = "offer_accepted"
    static let offerDeclined            = "offer_declined"
    static let offerExpired             = "offer_expired"

    // MARK: Transactions — shared
    static let contentUnlocked          = "content_unlocked"
    static let contentRated             = "content_rated"
    static let transactionViewed        = "transaction_viewed"

    // MARK: Wallet
    static let walletTopUpOpened        = "wallet_top_up_opened"
    static let walletCashOutOpened      = "wallet_cash_out_opened"
    static let walletWithdrawalRequested = "wallet_withdrawal_requested"
    static let escrowHeld               = "escrow_held"
    static let escrowReleased           = "escrow_released"
    static let escrowRefunded           = "escrow_refunded"

    // MARK: Notifications
    static let notificationPermissionGranted = "notification_permission_granted"
    static let notificationPermissionDenied  = "notification_permission_denied"

    // MARK: Errors
    static let errorOccurred            = "error_occurred"
}

// ─────────────────────────────────────────────────────────────
// MARK: - Property Name Constants
// ─────────────────────────────────────────────────────────────

struct AnalyticsProperty {
    static let screenName               = "screen_name"
    static let elementId                = "element_id"
    static let transactionId            = "transaction_id"
    static let transactionType          = "transaction_type"   // "request" | "offer"
    static let amount                   = "amount"
    static let recipientCount           = "recipient_count"
    static let method                   = "method"             // "contacts" | "username"
    static let username                 = "username"
    static let rating                   = "rating"
    static let errorMessage             = "error_message"
    static let userId                   = "user_id"
}

// ─────────────────────────────────────────────────────────────
// MARK: - Analytics
// ─────────────────────────────────────────────────────────────

class Analytics {

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

    // MARK: - Core

    func track(event: String, properties: [String: Any]? = nil) {
        guard enabled, let service else { return }
        service.track(event: event, properties: properties)
    }

    func identify(userId: String, properties: [String: Any]? = nil) {
        guard enabled, let service else { return }
        service.identify(userId: userId, properties: properties)
    }

    func reset() {
        service?.reset()
    }

    // MARK: - Screen

    func trackScreen(name: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.screenName] = name
        track(event: AnalyticsEvent.screenView, properties: props)
    }

    // MARK: - Tap

    func trackTap(elementId: String, screenName: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.elementId] = elementId
        if let screenName { props[AnalyticsProperty.screenName] = screenName }
        track(event: AnalyticsEvent.tap, properties: props)
    }

    // MARK: - Error

    func trackError(message: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.errorMessage] = message
        track(event: AnalyticsEvent.errorOccurred, properties: props)
    }

    // MARK: - Transactions

    func trackRequest(action: String, transactionId: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.transactionType] = "request"
        if let transactionId { props[AnalyticsProperty.transactionId] = transactionId }
        let event: String
        switch action {
        case "sent":      event = AnalyticsEvent.requestSent
        case "accepted":  event = AnalyticsEvent.requestAccepted
        case "declined":  event = AnalyticsEvent.requestDeclined
        case "fulfilled": event = AnalyticsEvent.requestFulfilled
        case "expired":   event = AnalyticsEvent.requestExpired
        case "cancelled": event = AnalyticsEvent.requestCancelled
        default:          event = action
        }
        track(event: event, properties: props)
    }

    func trackOffer(action: String, transactionId: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.transactionType] = "offer"
        if let transactionId { props[AnalyticsProperty.transactionId] = transactionId }
        let event: String
        switch action {
        case "sent":     event = AnalyticsEvent.offerSent
        case "accepted": event = AnalyticsEvent.offerAccepted
        case "declined": event = AnalyticsEvent.offerDeclined
        case "expired":  event = AnalyticsEvent.offerExpired
        default:         event = action
        }
        track(event: event, properties: props)
    }
}
