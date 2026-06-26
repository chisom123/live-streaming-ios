import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import LiveKit

// MARK: - Container

struct SendStreamRequestSheet: View {

    let stream:    StreamModel
    let onDismiss: () -> Void

    @State private var step        = 1
    @State private var description = ""
    @State private var price       = ""

    var body: some View {
        Group {
            if step == 1 {
                StreamRequestStep1View(
                    description: $description,
                    onContinue:  { withAnimation { step = 2 } },
                    onDismiss:   onDismiss
                )
            } else {
                StreamRequestStep2View(
                    stream:      stream,
                    description: description,
                    onBack:      { withAnimation { step = 1 } },
                    onDismiss:   onDismiss,
                    price:       $price
                )
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "send_stream_request")
        }
    }
}

// MARK: - Step 1: Make a request

private struct StreamRequestStep1View: View {

    @Binding var description: String
    let onContinue: () -> Void
    let onDismiss:  () -> Void

    @FocusState private var isFocused: Bool

    private let presetRequests = [
        "Tell a joke", "Scream super loud", "Sing a song", "Go eat some food"
    ]

    private var descFilled: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Text("Make a request")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                TextField("Type your request...", text: $description, axis: .vertical)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(5...10)
                    .padding(14)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .tint(Color(hex: "#FF6B00"))
                    .focused($isFocused)
                    .onChange(of: description) {
                        if $0.count > 120 {
                            description = String($0.prefix(120))
                        }
                    }
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(presetRequests, id: \.self) { preset in
                            Button {
                                description = preset
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(preset)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(description == preset ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        description == preset
                                            ? Color(hex: "#FF6B00")
                                            : .white.opacity(0.08)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)
                .padding(.bottom, 40)

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(descFilled ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(descFilled ? Color(hex: "#FF6B00") : .white.opacity(0.07))
                        .clipShape(Capsule())
                }
                .disabled(!descFilled)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

// MARK: - Step 2: Set your reward

private struct StreamRequestStep2View: View {

    let stream:      StreamModel
    let description: String
    let onBack:      () -> Void
    let onDismiss:   () -> Void

    @Binding var price: String
    @State private var isSending    = false
    @State private var errorMessage: String? = nil
    @State private var showWallet   = false
    @StateObject private var walletVM = WalletViewModel()

    private let presetPrices = ["0.50", "1.00", "2.00", "5.00", "10.00", "20.00"]
    private let functions    = Functions.functions()

    private var priceDouble: Double { Double(price) ?? 0 }
    private var priceValid:  Bool   { priceDouble >= 0.50 && priceDouble <= 50.00 }
    private var hasFunds:    Bool   { walletVM.balance >= priceDouble }
    private var canSend:     Bool   { priceValid && hasFunds && !isSending }

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("Set your reward")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Text(description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(presetPrices, id: \.self) { preset in
                        Button {
                            price = preset
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("$\(preset)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(price == preset ? .white : .white.opacity(0.65))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    price == preset
                                        ? Color(hex: "#FF6B00")
                                        : .white.opacity(0.07)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                HStack {
                    Text("Balance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    if !hasFunds && priceValid {
                        Text("Insufficient funds")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#E24B4A"))
                            .padding(.trailing, 6)
                    }
                    Text("$\(String(format: "%.2f", walletVM.balance))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(hasFunds ? .white : Color(hex: "#E24B4A"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#E24B4A"))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }

                Spacer()

                if !hasFunds && priceValid {
                    Button {
                        Analytics.shared.trackTap(
                            elementId: "top_up_from_stream_request",
                            screenName: "send_stream_request"
                        )
                        showWallet = true
                    } label: {
                        Text("Top Up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color(hex: "#FF6B00"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                } else {
                    Button(action: sendRequest) {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .white.opacity(0.5))
                                    )
                                    .scaleEffect(0.8)
                            }
                            Text(isSending ? "Sending..." : "Send Request")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(canSend ? .white : .white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(canSend ? Color(hex: "#FF6B00") : .white.opacity(0.07))
                        .clipShape(Capsule())
                    }
                    .disabled(!canSend)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
            }
        }
        .fullScreenCover(isPresented: $showWallet) {
            WalletView(onDismiss: { showWallet = false })
        }
        .preferredColorScheme(.dark)
        .onAppear { walletVM.startListening() }
        .onDisappear { walletVM.stopListening() }
    }

    private func sendRequest() {
        guard canSend else { return }
        isSending    = true
        errorMessage = nil

        Task {
            do {
                let result = try await functions.httpsCallable("sendStreamRequest").call([
                    "streamId":    stream.id,
                    "description": description.trimmingCharacters(in: .whitespaces),
                    "price":       priceDouble
                ])
                guard let data      = result.data as? [String: Any],
                      let requestId = data["requestId"] as? String
                else { throw NSError(domain: "Stream", code: -1) }

                Analytics.shared.trackStreamRequest(
                    action:    "sent",
                    streamId:  stream.id,
                    requestId: requestId,
                    amount:    priceDouble
                )
                await MainActor.run { onDismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending    = false
                }
            }
        }
    }
}
