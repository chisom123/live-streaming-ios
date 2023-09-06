import SwiftUI
import Contacts
import Firebase
import UIKit
import SDWebImageSwiftUI
import FirebaseFirestore

struct AppUser: Identifiable, Equatable {
    var id: String // UID of the user
    var name: String
    var phoneNumber: String
    var icon: String? // The URL of the user's icon
    var lastMessageTimestamp: Timestamp?
}

extension UIDevice {
    static var isNotched: Bool {
        let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        return bottom > 0
    }
}

struct HomeView: View {
    
    @State private var logoutSuccess = false
    @StateObject private var viewModel = HomeViewModel()

    var topPadding: CGFloat {
        return UIDevice.isNotched ? 75 : 50
    }
    
    var body: some View {
        VerticalPager(pageCount: viewModel.appUsers.count, currentIndex: $viewModel.currentIndex) {
            ForEach(viewModel.appUsers, id: \.id) { user in
                ZStack {
                    Color.white.edgesIgnoringSafeArea(.all) // You can change this to any background color you like

                    ZStack {
                            RoundedRectangle(cornerRadius: 2000) // Gray container
                                .fill(Color(hex: "#F5F5F5"))
                                .frame(width: 220, height: 220) // A bit bigger than the bear image

                            if let iconURL = user.icon, !iconURL.isEmpty {
                                WebImage(url: URL(string: iconURL))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                            } else {
                                Image("teddy-bear") // Use teddy bear image if no icon exists.
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                            }
                        }
                    
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(.leading, 30)
                            .padding(.top, self.topPadding)
                            .foregroundColor(.black)
                        Text("Tap to view")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(.leading, 30)
                            .padding(.top, 8)
                            .foregroundColor(Color(hex: "#1199FF"))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onTapGesture {
                    viewModel.selectUser(user)
                }
            }
        }
        .onAppear {
            viewModel.fetchFriends()
        }
        .navigationBarHidden(true)
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        viewModel.showBearsView()
                    }) {
                        Image("Shop") // Replace with your image name
                            .resizable()
                            .frame(width: 50, height: 50)
                            .padding(.leading, 30)
                            .padding(.bottom, 20)
                    }
                    Spacer()
                    Button(action: {
                        viewModel.activeSheet = .searchView
                    }) {
                        Image("Search") // Replace with your image name
                            .resizable()
                            .frame(width: 50, height: 50)
                            .padding(.trailing, 30)
                            .padding(.bottom, 20)
                    }
                }
            }
        )
        .fullScreenCover(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .chatView:
                ChatView(viewModel: ChatModel(), friend: viewModel.selectedUser!)
            case .searchView:
                SearchView(selectedUserIndex: $viewModel.selectedUserIndex, isPresented: .constant(true), users: viewModel.appUsers)
            case .bearsView:
                   BearsView()
            }
        }
    }
}

struct VerticalPager<Content: View>: View {
    let pageCount: Int
    @Binding var currentIndex: Int
    let content: Content

    @GestureState private var translation: CGFloat = 0

    init(pageCount: Int, currentIndex: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            LazyVStack(spacing: 0) {
                self.content.frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.000000001))
            .offset(y: -CGFloat(self.currentIndex) * geometry.size.height)
            .offset(y: self.translation)
            .animation(.interactiveSpring(response: 0.3), value: currentIndex)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture(minimumDistance: 1).updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let offset = -Int(value.translation.height)
                    if abs(offset) > 20 {
                        let newIndex = currentIndex + min(max(offset, -1), 1)
                        if newIndex >= 0 && newIndex < pageCount {
                            self.currentIndex = newIndex
                        }
                    }
                }
            )
        }
        .edgesIgnoringSafeArea(.all)
    }
}
