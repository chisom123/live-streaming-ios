// OnboardingCompView.swift
import SwiftUI

struct OnboardingCompView: View {
    var competition: Competition
    var onSkip: () -> Void

    @State private var isCustomShareSheetPresented = false
    @State private var hasShared = false

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header
                HStack {
                    Color.clear.frame(width: 27, height: 27)

                    Spacer()

                    Text("New Competition")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .lineLimit(1)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: hasShared ? "onboarding_comp_done" : "onboarding_comp_skip",
                            screenName: "onboarding_competition"
                        )
                        onSkip()
                    }) {
                        Text(hasShared ? "Done" : "Skip")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(hasShared ? .white : .white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)

                // MARK: - Prize Pool / Ends In bar (matches CompDetails race bar exactly)
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prize Pool")
                                .font(.system(size: 14))
                                .foregroundColor(hasShared ? .white : .white.opacity(0.7))
                                .padding(.bottom, 2)

                            HStack(spacing: 4) {
                                Text("450")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFF"))

                                Image("gem")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 23, height: 23)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#6A5ACD"))
                            .cornerRadius(12)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Ends In")
                                .font(.system(size: 14))
                                .foregroundColor(hasShared ? .white : .white.opacity(0.7))
                                .padding(.bottom, 2)

                            Text("24h")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(20)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)

                // MARK: - Leaderboard (matches NoPlayersView exactly)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(["Me", "Player 2", "Player 3"].enumerated()), id: \.element) { index, userName in
                            VStack(spacing: 0) {
                                if userName == "Me" {
                                    HStack {
                                        Text("\(index + 1)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 30)
                                            .padding(.leading, 20)

                                        HStack(spacing: 20) {
                                            ProfilePictureView(url: nil, size: 40)

                                            Text("Me")
                                                .font(.system(size: 16, weight: .bold))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .foregroundColor(.white)
                                        }

                                        Spacer()

                                        HStack(spacing: 6.5) {
                                            Text("0")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(Color(hex: "#FFF"))

                                            Image(systemName: "star.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                                .foregroundColor(Color(hex: "#FFF"))
                                        }
                                        .padding(EdgeInsets(top: 2.75, leading: 12.75, bottom: 2.75, trailing: 12.75))
                                        .background(Color(hex: "#DAA520"))
                                        .cornerRadius(200)
                                        .padding(.trailing, 30)
                                    }
                                    .padding(.vertical, 25)
                                    .background(Color(hex: "#2A3255"))
                                } else {
                                    HStack {
                                        Text("\(index + 1)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 30)
                                            .padding(.leading, 20)

                                        HStack(spacing: 20) {
                                            Circle()
                                                .fill(Color.white.opacity(0.15))
                                                .frame(width: 40, height: 40)

                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.15))
                                                .frame(width: 80, height: 16)
                                        }

                                        Spacer()

                                        HStack(spacing: 6.5) {
                                            Text("0")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(Color(hex: "#FFF"))

                                            Image(systemName: "star.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                                .foregroundColor(Color(hex: "#FFF"))
                                        }
                                        .padding(EdgeInsets(top: 2.75, leading: 12.75, bottom: 2.75, trailing: 12.75))
                                        .background(Color(hex: "#DAA520"))
                                        .cornerRadius(200)
                                        .padding(.trailing, 30)
                                    }
                                    .padding(.vertical, 25)
                                    .background(Color.clear)
                                }

                                if userName != "Player 3" {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }

                        // Add Players button flush inside the card (matches NoPlayersView exactly)
                        Button(action: {
                            isCustomShareSheetPresented = true
                            Analytics.shared.trackTap(
                                elementId: "onboarding_add_players",
                                screenName: "onboarding_competition"
                            )
                        }) {
                            Text("Add Players")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 25)
                                .background(Color(hex: "#4169E1"))
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isCustomShareSheetPresented, onDismiss: { hasShared = true }) {
            CustomShareSheet(
                shareText: "Hey i started a photo competition on SocialStar. Join it! \(DeepLinkHandler.shared.createShareableLink(for: competition.id))",
                shareLink: DeepLinkHandler.shared.createShareableLink(for: competition.id)
            )
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "onboarding_competition")
        }
    }

}
