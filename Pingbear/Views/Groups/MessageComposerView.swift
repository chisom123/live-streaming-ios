import SwiftUI
import Kingfisher

struct MessageComposerView: View {
    let photo: UserPhoto
    let userName: String
    let competitionId: String
    let onSend: (String) -> Void

    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }

                Spacer()

                Text("Send to Chat")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {

                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                        .opacity(0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#1A2245"))

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        KFImage(URL(string: photo.photoUrl))
                            .placeholder {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "#3B4374"))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        ProgressView().tint(.white)
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipped()
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.top, 10)

                    VStack {
                        HStack(alignment: .center, spacing: 0) {
                            HStack {
                                TextField("Add a message", text: $messageText)
                                    .padding()
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .accentColor(.white)
                                    .focused($isTextFieldFocused)
                            }
                            .frame(height: 70)
                            .background(
                                Color(hex: "#3B4374")
                                    .clipShape(
                                        RoundedCorner(
                                            radius: 10,
                                            corners: [.topLeft, .bottomLeft]
                                        )
                                    )
                            )
                            
                            Button(action: {
                                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photo.photoUrl.isEmpty {
                                    onSend(messageText)
                                    dismiss()
                                }
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 22, weight: .bold, design: .default))
                                    .frame(width: 60, height: 70)
                                    .foregroundColor(.white)
                                    .background(
                                        Color(hex: "#32CD32")
                                            .clipShape(
                                                RoundedCorner(
                                                    radius: 10,
                                                    corners: [.topRight, .bottomRight]
                                                )
                                            )
                                    )
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo.photoUrl.isEmpty)
                            .opacity((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo.photoUrl.isEmpty) ? 0.5 : 1)
                        }
                    }
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
            }
        }
        .background(Color(hex: "#10183C"))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            Analytics.shared.trackScreen(name: "message_composer_view")
        }
    }
}
