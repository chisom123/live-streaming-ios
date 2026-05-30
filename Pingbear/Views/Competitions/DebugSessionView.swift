import SwiftUI
import FirebaseFunctions
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - Debug Session
//
// Only compiled in DEBUG builds — zero code in release.
//
// Creates a persistent debug session via Cloud Function on first
// use, stores the ID in UserDefaults so both devices can reuse
// the same session across runs.
//
// Usage:
//   Device 1 — tap DEV → session created → share ID shown
//   Device 2 — tap DEV → enter Device 1's session ID → Join
//
// After first setup, both devices tap DEV and it opens directly.
// ─────────────────────────────────────────────────────────────

#if DEBUG

private let kDebugSessionKey = "debug_session_id"

struct DebugSessionButton: View {
    @State private var activeSessionId: String? = nil
    @State private var isLoading        = false
    @State private var showingJoinSheet = false
    @State private var errorMessage:    String? = nil

    private var savedSessionId: String? {
        UserDefaults.standard.string(forKey: kDebugSessionKey)
    }

    var body: some View {
        Button(action: handleTap) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                        .frame(width: 32, height: 22)
                } else {
                    Text("DEV")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
            .background(Color.purple)
            .cornerRadius(200)
        }
        .fullScreenCover(item: Binding(
            get: { activeSessionId.map { SessionItem(id: $0) } },
            set: { if $0 == nil { activeSessionId = nil } }
        )) { item in
            SessionView(sessionId: item.id)
        }
        .sheet(isPresented: $showingJoinSheet) {
            DebugJoinSheet { sessionId in
                UserDefaults.standard.set(sessionId, forKey: kDebugSessionKey)
                showingJoinSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    activeSessionId = sessionId
                }
            }
        }
        .alert("Debug Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleTap() {
        guard !isLoading else { return }

        if let sessionId = savedSessionId {
            // Already have a session — join it via Cloud Function then open
            AppLogger.session("[DEBUG] Joining saved session=\(sessionId)")
            isLoading = true
            Functions.functions().httpsCallable("joinSession").call(["sessionId": sessionId]) { _, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error {
                        AppLogger.session("[DEBUG] joinSession failed — \(error.localizedDescription)")
                        // Session may be gone — clear saved ID and show options
                        UserDefaults.standard.removeObject(forKey: kDebugSessionKey)
                        showingJoinSheet = true
                    } else {
                        AppLogger.session("[DEBUG] Joined session ✅")
                        activeSessionId = sessionId
                    }
                }
            }
        } else {
            // No saved session — show sheet to create or join
            showingJoinSheet = true
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - DebugJoinSheet
// ─────────────────────────────────────────────────────────────

struct DebugJoinSheet: View {
    let onJoined: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sessionIdInput = ""
    @State private var isCreating     = false
    @State private var isJoining      = false
    @State private var createdId:     String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                VStack(spacing: 20) {

                    // ── Create new session ────────────────────
                    VStack(spacing: 12) {
                        Text("Create New Debug Session")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let id = createdId {
                            VStack(spacing: 8) {
                                Text("Share this ID with Device 2:")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.secondaryText)

                                HStack {
                                    Text(id)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.primaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button(action: {
                                        UIPasteboard.general.string = id
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(AppTheme.accent)
                                    }
                                }
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)

                                Button(action: { onJoined(id) }) {
                                    Text("Open Session")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.accent)
                                        .cornerRadius(200)
                                }
                            }
                        } else {
                            Button(action: createSession) {
                                HStack(spacing: 8) {
                                    if isCreating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isCreating ? "Creating..." : "Create Session (Device 1)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .cornerRadius(200)
                            }
                            .disabled(isCreating)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(14)

                    // ── Join existing session ─────────────────
                    VStack(spacing: 12) {
                        Text("Join Existing Session")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("Paste session ID from Device 1", text: $sessionIdInput)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(12)
                            .background(AppTheme.pageBackground)
                            .cornerRadius(10)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button(action: joinSession) {
                            HStack(spacing: 8) {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isJoining ? "Joining..." : "Join Session (Device 2)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(sessionIdInput.isEmpty ? AppTheme.disabledBackground : Color.purple)
                            .cornerRadius(200)
                        }
                        .disabled(sessionIdInput.isEmpty || isJoining)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(14)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Debug Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createSession() {
        isCreating = true
        Functions.functions().httpsCallable("createSession").call(["friendIds": []]) { result, error in
            DispatchQueue.main.async {
                isCreating = false
                if let error {
                    AppLogger.session("[DEBUG] createSession FAILED — \(error.localizedDescription)")
                    return
                }
                guard let id = (result?.data as? [String: Any])?["session_id"] as? String else { return }
                AppLogger.session("[DEBUG] Session created — \(id)")
                createdId = id
            }
        }
    }

    private func joinSession() {
        let id = sessionIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        isJoining = true

        Functions.functions().httpsCallable("joinSession").call(["sessionId": id]) { _, error in
            DispatchQueue.main.async {
                isJoining = false
                if let error {
                    AppLogger.session("[DEBUG] joinSession FAILED — \(error.localizedDescription)")
                    return
                }
                AppLogger.session("[DEBUG] Joined session ✅")
                onJoined(id)
            }
        }
    }
}

#endif
