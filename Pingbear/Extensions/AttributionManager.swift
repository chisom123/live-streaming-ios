import Foundation
import FirebaseFirestore
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - AttributionManager
//
// Handles web-to-app attribution by calling recordAppOpen
// in the marketing project (ss-web-rate) when appropriate.
//
// Called from three places:
//   1. VerificationView.verifyCode() — covers all onboarding paths
//   2. DeepLinkHandler — socialstar://web-attribution deep link
//   3. PingbearApp.setupApp() — catches stragglers
//
// All three are safe to call repeatedly — checkAndRecord reads
// webRatingOpenedApp before making the HTTP call, so if it's
// already true it returns immediately without doing anything.
// ─────────────────────────────────────────────────────────────

class AttributionManager {
    static let shared = AttributionManager()

    private let db = Firestore.firestore()
    private let recordAppOpenURL = URL(string: "https://us-central1-ss-web-rate.cloudfunctions.net/recordAppOpen")!

    private init() {}

    // ─────────────────────────────────────────────────────────
    // MARK: - Check and Record
    //
    // Reads the user doc first. If webRatingLinkId exists and
    // webRatingOpenedApp is false, fires recordAppOpen.
    // Safe to call multiple times — idempotent.
    // ─────────────────────────────────────────────────────────

    func checkAndRecord() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("AttributionManager: Error reading user doc: \(error)")
                return
            }

            guard let data = document?.data() else { return }

            let linkId = data["webRatingLinkId"] as? String
            let fingerprint = data["webFingerprint"] as? String
            let alreadyAttributed = data["webRatingOpenedApp"] as? Bool ?? false

            guard let linkId = linkId,
                  let fingerprint = fingerprint,
                  !alreadyAttributed else {
                return
            }

            self.callRecordAppOpen(
                linkId: linkId,
                fingerprint: fingerprint,
                userId: userId
            )
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - HTTP Call to recordAppOpen
    //
    // Plain POST to the marketing project's Cloud Function.
    // Fire and forget — never blocks the caller.
    // ─────────────────────────────────────────────────────────

    private func callRecordAppOpen(linkId: String, fingerprint: String, userId: String) {
        var request = URLRequest(url: recordAppOpenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "data": [
                "linkId":      linkId,
                "fingerprint": fingerprint,
                "userId":      userId
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("AttributionManager: Failed to serialise request body")
            return
        }

        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("AttributionManager: recordAppOpen request failed: \(error)")
                return
            }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                print("AttributionManager: recordAppOpen succeeded — marking user doc attributed")

                // ── Write webRatingOpenedApp: true to product project user doc ──
                guard let userId = Auth.auth().currentUser?.uid else { return }
                self?.db.collection("users").document(userId).updateData([
                    "webRatingOpenedApp": true,
                    "webRatingOpenedAppAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("AttributionManager: Failed to update webRatingOpenedApp: \(error)")
                    } else {
                        print("AttributionManager: webRatingOpenedApp set to true for \(userId)")
                    }
                }
            }
        }.resume()
    }
}
