import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingCreateEventSheet = false
    @State private var showingEditEventSheet = false
    @State private var selectedEvent: Event?
    
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
                
                Text("Events Dashboard")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    showingCreateEventSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 33, height: 33)
                        .foregroundColor(Color(hex: "#1199FF"))
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            Spacer()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(viewModel.events) { event in
                        EventGridCardView(event: event)
                            .onTapGesture {
                                self.selectedEvent = event
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $showingCreateEventSheet) {
            CreateEditEventView(viewModel: viewModel)
        }
        .fullScreenCover(item: $selectedEvent) { event in
            CreateEditEventView(viewModel: viewModel, event: event)
        }
        .onAppear {
            fetchData()
        }
    }
    
    private func fetchData() {
        viewModel.fetchPublicEvents()
    }
}
