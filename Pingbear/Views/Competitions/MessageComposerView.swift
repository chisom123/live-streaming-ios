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
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText)
                }
                Spacer()
                Text("Send to Chat").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Spacer()
                Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText).opacity(0)
            }
            .padding(.horizontal, 20).padding(.vertical, 20)
            .background(AppTheme.cardBackground)

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        KFImage(URL(string: photo.photoUrl))
                            .placeholder {
                                RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardHighlight)
                                    .frame(width: 200, height: 200).overlay(ProgressView().tint(AppTheme.primaryText))
                            }
                            .resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200).clipped().cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.divider, lineWidth: 1))
                    }
                    .padding(.top, 10)

                    VStack {
                        HStack(alignment: .center, spacing: 0) {
                            HStack {
                                TextField("Add a message", text: $messageText)
                                    .padding().foregroundColor(AppTheme.primaryText)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .tint(AppTheme.accent).focused($isTextFieldFocused)
                            }
                            .frame(height: 70)
                            .background(AppTheme.cardHighlight.clipShape(RoundedCorner(radius: 10, corners: [.topLeft, .bottomLeft])))

                            Button(action: {
                                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photo.photoUrl.isEmpty {
                                    onSend(messageText); dismiss()
                                }
                            }) {
                                Image(systemName: "paperplane.fill").font(.system(size: 22, weight: .bold, design: .default))
                                    .frame(width: 60, height: 70).foregroundColor(.white)
                                    .background(AppTheme.accent.clipShape(RoundedCorner(radius: 10, corners: [.topRight, .bottomRight])))
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo.photoUrl.isEmpty)
                            .opacity((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo.photoUrl.isEmpty) ? 0.5 : 1)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 30)
            }
        }
        .background(AppTheme.pageBackground)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isTextFieldFocused = true }
            Analytics.shared.trackScreen(name: "message_composer_view")
        }
    }
}
