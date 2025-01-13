import SwiftUI

struct EventsView: View {
    @ObservedObject var viewModel: EventsModel
    @State private var selectedEvent: Event?
    @State private var isLoading = false
    
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
        VStack {
            HStack {
                Text("Event Competitions")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)

                Spacer()
                
                Button(action: {
                    
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color(hex: "#1199FF"))
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(.horizontal, 20)
                        .opacity(0)
                }
            }
            .padding(.vertical, 15)
            
            Spacer()
            
            if isLoading {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredEvents.isEmpty {
                EmptyEventsView()
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(viewModel.filteredEvents, id: \.id) { event in
                            EventGridCardView(event: event)
                                .onTapGesture {
                                    self.selectedEvent = event
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .fullScreenCover(item: $selectedEvent) { event in
            CompDetails(competition: event)
        }
        .onAppear {
            fetchData()
        }
    }
    
    private func fetchData() {
        guard !isLoading else { return }
        
        isLoading = true
        viewModel.fetchPublicEvents {
            isLoading = false
        }
    }
}

struct EventGridCardView: View {
    let event: Event
    
    private var eventStatus: (text: String, color: Color) {
        let now = Date()
        
        if let endDateTime = event.endDateTime {
            if now < event.startDateTime {
                return ("Starting Soon", Color(hex: "#DAA520"))
            } else if now <= endDateTime {
                return ("On Now", Color(hex: "#4CAF50"))
            } else {
                return ("Done", Color(hex: "#FF0000"))
            }
        } else {
            // For events without an end time
            if now < event.startDateTime {
                return ("Starting Soon", Color(hex: "#DAA520"))
            } else {
                return ("On Now", Color(hex: "#4CAF50"))
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Image using AsyncImage
                    AsyncImage(
                        url: URL(string: event.image),
                        transaction: Transaction(animation: .easeInOut)
                    ) { phase in
                        switch phase {
                        case .empty:
                            Color(hex: "#E0E0E0")
                        
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        
                        case .failure:
                            Color.gray.opacity(0.1)
                                .overlay(
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                )
                        
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width)
                    .frame(height: geometry.size.width / 0.55)
                    .clipped()
                    
                    // Status Label
                    HStack {
                        Spacer()
                        Text(eventStatus.text)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(eventStatus.color)
                            .cornerRadius(200)
                            .padding(10)
                            .lineLimit(1)
                    }
                    
                    // Gradient Overlay (only at the bottom)
                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.5),
                                Color.black.opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 250)
                    }
                    .frame(width: geometry.size.width)
                    .frame(height: geometry.size.width / 0.55)
                    
                    // Event Details Overlay
                    VStack(alignment: .leading, spacing: 5) {
                        Spacer()
                        
                        Text(event.description)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .lineSpacing(2)
                        
                        Text(event.location)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .transition(.opacity)
            }
        }
        .aspectRatio(0.55, contentMode: .fit)
        .cornerRadius(5)
    }
}

struct EmptyEventsView: View {
    var body: some View {
        VStack {
            Text("No Event Competitions Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.black)
                .padding(.bottom, 20)
            
            Text("Check back later for upcoming competitions")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 25)
                .padding(.horizontal, 5)
        }
        .padding(.horizontal, 20)
    }
}
