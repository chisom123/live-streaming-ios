//
//  Entry.swift
//  Pingbear
//
//  Created by Ezi Agu on 22/08/1402 AP.
//

import SwiftUI
import SDWebImageSwiftUI

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel // Initialize with a competition ID
    @Environment(\.presentationMode) var presentationMode
    @State private var heartColor: Color = .white

    init(competitionId: String) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VerticalPager(pageCount: viewModel.entries.count, currentIndex: $viewModel.currentIndex) {
                ForEach(viewModel.entries, id: \.id) { entry in
                    ZStack {
                        // Your existing layout code
                        if let imageURL = URL(string: entry.imageUrl) {
                            WebImage(url: imageURL)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        } else {
                            Image("placeholder")
                                .resizable()
                                .scaledToFit()
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    // Xmark button on the left
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(5)
                            .shadow(radius: 10)
                    }

                    Spacer() // This spacer separates the two buttons

                    // Arrow.right button on the right, shown conditionally
                    if viewModel.currentIndex < viewModel.entries.count - 1 {
                        Button(action: {
                            viewModel.currentIndex += 1
                        }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(5)
                                .shadow(radius: 10)
                        }
                    }
                }
                .padding([.top, .leading, .trailing])
                
                Spacer()

                // Heart button at the bottom
                Button(action: {
                    heartColor = Color(hex: "#FFD700")
                    
                    // Delay to reset the color back to white
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation {
                            heartColor = .white
                        }
                    }
                }) {
                    ZStack {
                        Circle() // Outer circle
                            .stroke(lineWidth: 8)
                            .frame(width: 100, height: 100)
                            .foregroundColor(heartColor)
                            .shadow(radius: 10)

                        Image(systemName: "heart.fill") // Heart symbol
                            .font(.system(size: 35))
                            .foregroundColor(heartColor)
                            .shadow(radius: 10)
                    }
                    .padding(.bottom) // Adjust padding as needed
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        }
    }
}


struct VerticalPagerPics<Content: View>: View {
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
