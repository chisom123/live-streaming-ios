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
    @State private var isPresentingInfo = false // State to control the presentation of the New Competition View
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
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding(5)
                        .shadow(radius: 10)
                }
                
                Spacer()
                
                Button(action: {
                    isPresentingInfo = true
                }) {
                    Text("Turn on Superstar")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                        .background(AppColors.white.opacity(0.95)) // Adjust opacity value as needed
                        .foregroundColor(AppColors.primary)
                        .cornerRadius(200)

                }

            
            }
            .padding([.top, .leading, .trailing])



            // Bottom - Heart button, horizontally centered
            VStack {
                Spacer() // Pushes the content to the bottom

                // Container view for stars with background
                ZStack {
                    HStack(alignment: .center, spacing: 10) { // Add spacing between stars if needed
                        ForEach(1...4, id: \.self) { star in
                            Button(action: {
                                // Update the rating when a star is tapped
                                self.rating = star
                                let currentEntryId = viewModel.entries[viewModel.currentIndex].id
                                viewModel.updateStarRating(for: currentEntryId, with: star)
                            }) {
                                // Display the star
                                Image(systemName: star <= self.rating ? "star.fill" : "star")
                                    .foregroundColor(star <= self.rating ? Color(hex: "#FFD700") : Color.black)
                                    .font(.system(size: 33))
                                    .padding(5)
                            }
                        }
                    }
                    .padding(.horizontal) // Adds horizontal padding to the HStack
                    .padding(.vertical, 10) // Increase vertical padding of the HStack
                    .background(RoundedRectangle(cornerRadius: 200)
                        .foregroundColor(AppColors.white.opacity(0.95))) // Background color similar to the button
                    // Removed the shadow from the background
                }
                .padding(.bottom) // Adjusts the bottom padding of the entire block
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center) // Ensures the ZStack is as wide as possible and centered
        }
        .fullScreenCover(isPresented: $isPresentingInfo) {
            SuperstarInfoView(viewModel: PbillViewModel()) // Replace this with the actual view you want to present
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
