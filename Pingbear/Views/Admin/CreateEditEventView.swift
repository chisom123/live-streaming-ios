import SwiftUI

struct CreateEditEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AdminDashboardModel
    @State private var showDeleteAlert = false
    
    let event: Event?
    
    @State private var description = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    init(viewModel: AdminDashboardModel, event: Event? = nil) {
        self.viewModel = viewModel
        self.event = event
        
        if let event = event {
            _description = State(initialValue: event.description)
            _location = State(initialValue: event.location)
            _startDate = State(initialValue: event.startDateTime)
            _endDate = State(initialValue: event.endDateTime ?? Date())
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Description", text: $description)
                    TextField("Location", text: $location)
                }
                
                Section(header: Text("Date and Time")) {
                    DatePicker("Start Date", selection: $startDate)
                    DatePicker("End Date", selection: $endDate)
                }
                
                if event != nil {
                    Section {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Event")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(event == nil ? "Create Event" : "Edit Event")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    
                    if let event = event {
                        viewModel.updateEvent(
                            eventId: event.id,
                            description: description,
                            location: location,
                            startDate: startDate,
                            endDate: endDate
                        )
                    } else {
                        viewModel.createEvent(
                            description: description,
                            location: location,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(
                    description.isEmpty ||
                    location.isEmpty ||
                    endDate <= startDate
                )
                
            )
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let event = event {
                            viewModel.deleteEvent(eventId: event.id)
                        }
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
