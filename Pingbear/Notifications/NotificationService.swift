import UserNotifications
import PostHog

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published private(set) var isRegistered = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleEventNotifications(event: Event) async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        // Request authorization first
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                return false
            }
        } catch {
            print("Notification authorization failed: \(error)")
            return false
        }
        
        // Schedule start notification
        let startContent = UNMutableNotificationContent()
        startContent.title = "Competition Starting Now"
        startContent.body = "\(event.description) just started"
        startContent.sound = .default
        
        let startComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: event.startDateTime
        )
        
        let startRequest = UNNotificationRequest(
            identifier: "event-start-\(event.id)",
            content: startContent,
            trigger: UNCalendarNotificationTrigger(dateMatching: startComponents, repeats: false)
        )
        
        do {
            // Schedule start notification
            try await center.add(startRequest)
            
            // Schedule 15-minute warning if applicable
            let warningDate = event.startDateTime.addingTimeInterval(-900)
            if warningDate > Date() {
                let warningContent = UNMutableNotificationContent()
                warningContent.title = "Competition Starting Soon"
                warningContent.body = "\(event.description) starts in 15 minutes"
                warningContent.sound = .default
                
                let warningComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: warningDate
                )
                
                let warningRequest = UNNotificationRequest(
                    identifier: "event-warning-\(event.id)",
                    content: warningContent,
                    trigger: UNCalendarNotificationTrigger(dateMatching: warningComponents, repeats: false)
                )
                
                try await center.add(warningRequest)
            }
            
            PostHogSDK.shared.capture("Public Competition Notifications Scheduled",
                properties: ["eventId": event.id])
            return true
            
        } catch {
            PostHogSDK.shared.capture("Public Competition Notification Scheduling Failed",
                properties: ["error": error.localizedDescription])
            return false
        }
    }
}
