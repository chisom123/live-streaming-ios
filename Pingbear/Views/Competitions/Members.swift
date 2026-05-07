import SwiftUI

struct MembersView: View {
    var competition: Competition
    @StateObject private var viewModel = MembersViewModel()
    @StateObject private var myFriendsModel = MyFriendsModel()
    @State private var showingJoinSelectView = false
    @State private var isEditingCompetition = false
    @State private var showingRaceSettings = false
    @State private var showingRaceHistory = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText)
                    }
                    Button(action: { dismiss() }) {
                        Text(competition.description).font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.primaryText).padding(.horizontal, 10).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 20)

                VStack(spacing: 0) {
                    Button(action: { showingJoinSelectView = true }) {
                        HStack {
                            Text("Add Players").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(AppTheme.secondaryText)
                                .font(.system(size: 15, weight: .bold)).padding(.trailing, 10)
                        }
                        .frame(maxWidth: .infinity).padding(20).padding(.vertical, 5)
                    }
                    Divider().background(AppTheme.divider)
                    Button(action: { showingRaceHistory = true }) {
                        HStack {
                            Text("History").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(AppTheme.secondaryText)
                                .font(.system(size: 15, weight: .bold)).padding(.trailing, 10)
                        }
                        .frame(maxWidth: .infinity).padding(20).padding(.vertical, 5)
                    }
                    Divider().background(AppTheme.divider)
                    Button(action: { showingRaceSettings = true }) {
                        HStack {
                            Text("Duration").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(AppTheme.secondaryText)
                                .font(.system(size: 15, weight: .bold)).padding(.trailing, 10)
                        }
                        .frame(maxWidth: .infinity).padding(20).padding(.vertical, 5)
                    }
                }
                .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal, 20)

                HStack {
                    Text("Players").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Spacer()
                }
                .padding(20).padding(.top, 5)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.members) { member in
                            VStack(spacing: 0) {
                                HStack {
                                    HStack(spacing: 20) {
                                        ProfilePictureView(url: member.profileurl, size: 40)
                                        Text(member.username).font(.system(size: 16, weight: .bold)).lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundColor(AppTheme.primaryText).truncationMode(.tail)
                                    }
                                    .padding(.leading, 30)
                                    if member.id != viewModel.currentUserId && !member.isAdded {
                                        Button(action: { viewModel.addFriend(member: member) { _, _ in } }) {
                                            Text("Add").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                                .padding(EdgeInsets(top: 3, leading: 15, bottom: 3, trailing: 15))
                                                .background(AppTheme.accent).cornerRadius(200)
                                        }
                                        .padding(.trailing, 30)
                                    } else if member.justAdded {
                                        HStack(spacing: 8) {
                                            Text("Added").font(.system(size: 17, weight: .bold)).foregroundColor(AppTheme.primaryText)
                                            Image(systemName: "checkmark.circle.fill").resizable().scaledToFit()
                                                .frame(width: 18, height: 18).foregroundColor(AppTheme.primaryText)
                                        }
                                        .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                        .background(AppTheme.green).cornerRadius(200).padding(.trailing, 30).opacity(0)
                                    }
                                }
                                .padding(.vertical, 20)
                                if member.id != viewModel.members.last?.id {
                                    Divider().background(AppTheme.divider)
                                }
                            }
                        }
                    }
                    .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal, 20)
                }
            }
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .onAppear { if viewModel.members.isEmpty { viewModel.fetchMembersDetails(for: competition) } }
        .sheet(isPresented: $isEditingCompetition) { EditCompetitionView(competition: competition) }
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: { viewModel.fetchMembersDetails(for: competition) }) {
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
        .navigationDestination(isPresented: $showingRaceHistory) { RaceHistoryView(competition: competition) }
        .navigationDestination(isPresented: $showingRaceSettings) { RaceSettingsView(competition: competition) }
    }
}
