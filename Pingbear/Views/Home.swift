//
//  HomeView.swift
//  Pingbear
//
//  Created by Ezi Agu on 20/05/1402 AP.
//

import SwiftUI

struct HomeView: View {
    @State private var showContactsView = false
    @State private var selectedContact: Contact? // This will hold the selected contact from ContactsView

    var body: some View {
        VStack {
            Text("Welcome to Home!")
                .padding()

            Button("Show Contacts") {
                showContactsView.toggle()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Handle Chat initiation here
            if let contact = selectedContact {
                // Here you'd implement and show your ChatView.
                Text("Chat with \(contact.givenName) \(contact.familyName)")
                    .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showContactsView) {
            ContactsView(isShown: $showContactsView, selectedContact: $selectedContact)  // Pass the binding to the ContactsView
        }
    }
}
