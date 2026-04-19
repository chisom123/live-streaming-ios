//
//   CompetitionAnimationView.swift
//  Pingbear
//
//  Created by Ezi Agu on 30/01/1405 AP.
//

import SwiftUI

struct CompetitionAnimationView: View {

    struct Player: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        var score: Int
        let isMe: Bool
        var gems: Int { score * 14 }
    }

    @State private var players: [Player] = [
        Player(name: "Me",     emoji: "👩🏻", score: 12, isMe: true),
        Player(name: "Olivia", emoji: "👩🏽", score: 10, isMe: false),
        Player(name: "Emma",   emoji: "👩🏼", score: 9,  isMe: false),
        Player(name: "Jake",   emoji: "🧑🏻", score: 7,  isMe: false),
    ]
    @State private var sortedIds: [UUID] = []
    @State private var pulsingWinnerId: UUID? = nil
    @State private var animationTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedPlayers.enumerated()), id: \.element.id) { index, player in
                VStack(spacing: 0) {
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30)
                            .padding(.leading, 20)

                        HStack(spacing: 20) {
                            Text(player.emoji)
                                .font(.system(size: 26))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .scaleEffect(pulsingWinnerId == player.id ? 1.18 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: pulsingWinnerId)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .lineLimit(1)
                                    .foregroundColor(.white)

                                HStack(spacing: 4) {
                                    Text("\(player.gems)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .contentTransition(.numericText())
                                    Image("gem")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 15, height: 15)
                                }
                                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .background(Color(hex: "#6A5ACD"))
                                .cornerRadius(200)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Text("\(player.score)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Image(systemName: "star.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.white)
                        }
                        .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                        .background(Color(hex: "#DAA520"))
                        .cornerRadius(200)
                        .padding(.trailing, 20)
                        .scaleEffect(pulsingWinnerId == player.id ? 1.12 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: pulsingWinnerId)
                    }
                    .padding(.vertical, 20)
                    .background(player.isMe ? Color(hex: "#2A3255") : Color.clear)

                    if index < orderedPlayers.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.2))
                    }
                }
            }
        }
        .background(Color(hex: "#1A2245"))
        .cornerRadius(10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: sortedIds)
        .onAppear {
            sortedIds = players.sorted { $0.score > $1.score }.map { $0.id }
            startAnimation()
        }
        .onDisappear { animationTimer?.invalidate() }
    }

    var orderedPlayers: [Player] {
        sortedIds.compactMap { id in players.first { $0.id == id } }
    }

    func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
            DispatchQueue.main.async {
                awardRandomPlayer()
            }
        }
    }

    func awardRandomPlayer() {
        let weights: [Double] = [0.4, 0.22, 0.22, 0.16]
        let roll = Double.random(in: 0..<1)
        var cumulative = 0.0
        var idx = 0
        for (i, w) in weights.enumerated() {
            cumulative += w
            if roll < cumulative { idx = i; break }
        }

        let starsGained = Int.random(in: 8...20)
        let winnerId = players[idx].id

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            pulsingWinnerId = winnerId
            players[idx].score += starsGained
        }

        let newOrder = players.sorted { $0.score > $1.score }.map { $0.id }
        if newOrder != sortedIds {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                sortedIds = newOrder
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.2)) {
                pulsingWinnerId = nil
            }
        }
    }
}
