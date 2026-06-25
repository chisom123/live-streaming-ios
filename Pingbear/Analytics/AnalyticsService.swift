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
    static let screenView                    = "screen_viewed"

    // MARK: User interactions
    static let tap                           = "user_tapped"

    // MARK: Account
    static let accountCreated                = "account_created"
    static let userLoggedIn                  = "user_logged_in"
    static let userLoggedOut                 = "user_logged_out"

    // MARK: Friends
    static let friendAdded                   = "friend_added"
    static let friendAddFailed               = "friend_add_failed"
    static let contactsPermissionGranted     = "contacts_permission_granted"
    static let contactsPermissionDenied      = "contacts_permission_denied"
    static let inviteContactSelected         = "invite_contact_selected"
    static let inviteContactDeselected       = "invite_contact_deselected"
    static let inviteComposerOpened          = "invite_composer_opened"
    static let invitesSent                   = "invites_sent"
    static let inviteComposerCancelled       = "invite_composer_cancelled"
    static let inviteComposerFailed          = "invite_composer_failed"
    static let inviteGroupResolved           = "invite_group_resolved"
    static let usernameSearchAttempted       = "username_search_attempted"

    // MARK: Top up
    static let topUpOpened                   = "top_up_opened"
    static let topUpCompleted                = "top_up_completed"
    static let topUpFailed                   = "top_up_failed"
    static let topUpCancelled                = "top_up_cancelled"

    // MARK: Wallet
    static let walletTopUpOpened             = "wallet_top_up_opened"
    static let walletCashOutOpened           = "wallet_cash_out_opened"
    static let walletWithdrawalRequested     = "wallet_withdrawal_requested"

    // MARK: Notifications
    static let notificationPermissionGranted = "notification_permission_granted"
    static let notificationPermissionDenied  = "notification_permission_denied"

    // MARK: Streams — session
    static let streamCreated                 = "stream_created"
    static let streamStarted                 = "stream_started"
    static let streamEnded                   = "stream_ended"
    static let streamJoined                  = "stream_joined"
    static let streamLeft                    = "stream_left"

    // MARK: Streams — invites
    static let streamInviteSent              = "stream_invite_sent"

    // MARK: Streams — requests
    static let streamRequestSent             = "stream_request_sent"
    static let streamRequestAccepted         = "stream_request_accepted"
    static let streamRequestDeclined         = "stream_request_declined"
    static let streamRequestCompleted        = "stream_request_completed"
    static let streamRequestRefunded         = "stream_request_refunded"

    // MARK: Streams — chat
    static let streamChatMessageSent         = "stream_chat_message_sent"

    // MARK: Errors
    static let errorOccurred                 = "error_occurred"
}

// ─────────────────────────────────────────────────────────────
// MARK: - Property Name Constants
// ─────────────────────────────────────────────────────────────

struct AnalyticsProperty {
    static let screenName        = "screen_name"
    static let elementId         = "element_id"
    static let amount            = "amount"
    static let username          = "username"
    static let errorMessage      = "error_message"
    static let userId            = "user_id"

    // Stream-specific
    static let streamId          = "stream_id"
    static let streamerId        = "streamer_id"
    static let requestId         = "request_id"
    static let invitedCount      = "invited_count"
    static let durationSecs      = "duration_secs"
    static let totalEarned       = "total_earned"
    static let requestCount      = "request_count"
    static let viewerCount       = "viewer_count"
    static let joinLatencyMs     = "join_latency_ms"
    static let watchDurationSecs = "watch_duration_secs"
    static let payout            = "payout"
    static let refundReason      = "refund_reason"
}

// ─────────────────────────────────────────────────────────────
// MARK: - Analytics
// ─────────────────────────────────────────────────────────────

class Analytics {

    static let shared = Analytics()

    private var service: AnalyticsService?
    private var enabled = true

    private init() {}

    func configure(with service: AnalyticsService) { self.service = service }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }

    func track(event: String, properties: [String: Any]? = nil) {
        guard enabled, let service else { return }
        service.track(event: event, properties: properties)
    }

    func identify(userId: String, properties: [String: Any]? = nil) {
        guard enabled, let service else { return }
        service.identify(userId: userId, properties: properties)
    }

    func reset() { service?.reset() }

    func trackScreen(name: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.screenName] = name
        track(event: AnalyticsEvent.screenView, properties: props)
    }

    func trackTap(elementId: String, screenName: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.elementId] = elementId
        if let screenName { props[AnalyticsProperty.screenName] = screenName }
        track(event: AnalyticsEvent.tap, properties: props)
    }

    func trackError(message: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props[AnalyticsProperty.errorMessage] = message
        track(event: AnalyticsEvent.errorOccurred, properties: props)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Stream tracking helpers
    // ─────────────────────────────────────────────────────────

    func trackStreamCreated(streamId: String, invitedCount: Int) {
        track(event: AnalyticsEvent.streamCreated, properties: [
            AnalyticsProperty.streamId:     streamId,
            AnalyticsProperty.invitedCount: invitedCount
        ])
    }

    func trackStreamStarted(streamId: String, invitedCount: Int) {
        track(event: AnalyticsEvent.streamStarted, properties: [
            AnalyticsProperty.streamId:     streamId,
            AnalyticsProperty.invitedCount: invitedCount
        ])
    }

    func trackStreamEnded(streamId: String, durationSecs: Int, totalEarned: Double, requestCount: Int, viewerCount: Int) {
        track(event: AnalyticsEvent.streamEnded, properties: [
            AnalyticsProperty.streamId:     streamId,
            AnalyticsProperty.durationSecs: durationSecs,
            AnalyticsProperty.totalEarned:  totalEarned,
            AnalyticsProperty.requestCount: requestCount,
            AnalyticsProperty.viewerCount:  viewerCount
        ])
    }

    func trackStreamJoined(streamId: String, streamerId: String, joinLatencyMs: Int? = nil) {
        var props: [String: Any] = [
            AnalyticsProperty.streamId:   streamId,
            AnalyticsProperty.streamerId: streamerId
        ]
        if let ms = joinLatencyMs { props[AnalyticsProperty.joinLatencyMs] = ms }
        track(event: AnalyticsEvent.streamJoined, properties: props)
    }

    func trackStreamLeft(streamId: String, watchDurationSecs: Int) {
        track(event: AnalyticsEvent.streamLeft, properties: [
            AnalyticsProperty.streamId:          streamId,
            AnalyticsProperty.watchDurationSecs: watchDurationSecs
        ])
    }

    func trackStreamRequest(action: String, streamId: String, requestId: String, amount: Double, payout: Double? = nil, refundReason: String? = nil) {
        var props: [String: Any] = [
            AnalyticsProperty.streamId:  streamId,
            AnalyticsProperty.requestId: requestId,
            AnalyticsProperty.amount:    amount
        ]
        if let p = payout       { props[AnalyticsProperty.payout]       = p }
        if let r = refundReason { props[AnalyticsProperty.refundReason]  = r }
        let event: String
        switch action {
        case "sent":      event = AnalyticsEvent.streamRequestSent
        case "accepted":  event = AnalyticsEvent.streamRequestAccepted
        case "declined":  event = AnalyticsEvent.streamRequestDeclined
        case "completed": event = AnalyticsEvent.streamRequestCompleted
        case "refunded":  event = AnalyticsEvent.streamRequestRefunded
        default:          event = action
        }
        track(event: event, properties: props)
    }
}
