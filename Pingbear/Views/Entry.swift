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
    @State private var rating: Int = 0

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
                
                // Middle Right - Arrow.right button
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



            // Bottom - Heart button, horizontally centered
            VStack {
                Spacer() // Pushes the button to the bottom

                HStack {
                    Spacer() // Pushes the button to the center horizontally
 
                    // Creating 4 star buttons
                    ForEach(1...4, id: \.self) { star in
                        Button(action: {
                            // Update the rating when a star is tapped
                            self.rating = star
                             
                            let currentEntryId = viewModel.entries[viewModel.currentIndex].id
                            viewModel.updateStarRating(for: currentEntryId, with: star)
                        }) {
                            // Display the star, filled if it's less than or equal to the current rating
                            Image(systemName: star <= self.rating ? "star.fill" : "star")
                                .foregroundColor(star <= self.rating ? Color(hex: "#FFD700") : Color.white)
                                .font(.system(size: 35))
                                .padding(5)
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
