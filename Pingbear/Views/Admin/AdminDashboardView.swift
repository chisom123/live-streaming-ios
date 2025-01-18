import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingCreateEventSheet = false
    @State private var showingEditEventSheet = false
    @State private var selectedEvent: Event?
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(Color.black)
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
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.events) { event in
                        HStack {
                            Text(event.description)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(2)
                                .lineSpacing(9)
                                .foregroundColor(.black)
                                .truncationMode(.tail)
                                .padding(.leading, 10)
                            
                            Spacer()
                            
                            if event.hasEnded {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            self.selectedEvent = event
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCreateEventSheet) {
            CreateEditEventView(viewModel: viewModel)
        }
        .fullScreenCover(item: $selectedEvent) { event in
            CreateEditEventView(viewModel: viewModel, event: event)
        }
        .task {
            await viewModel.fetchPublicEvents()
        }
    }
}
