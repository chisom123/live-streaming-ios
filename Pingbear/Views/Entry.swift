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

            // Top Left - Xmark button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding(5)
                        .shadow(radius: 10)
                }
                Spacer()
            }
            .padding([.top, .leading])

            // Top Right - "30 hearts left" button
            HStack {
                Spacer()
                Button(action: {
                    // Action for "30 hearts left"
                }) {
                    Text("30 hearts left")
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                        .background(Color(hex: "#fff"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(200)
                }
            }
            .padding([.top, .trailing])

            // Middle Right - Arrow.right button
            if viewModel.currentIndex < viewModel.entries.count - 1 {
                VStack {
                    Spacer()
                    Button(action: {
                        viewModel.currentIndex += 1
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(5)
                            .shadow(radius: 10)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing)
            }

            // Bottom - Heart button, horizontally centered
            VStack {
                Spacer() // Pushes the button to the bottom

                HStack {
                    Spacer() // Pushes the button to the center horizontally
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
                    }
                    Spacer() // Pushes the button to the center horizontally
                }
                .padding(.bottom) // Adjust padding as needed
            }

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
