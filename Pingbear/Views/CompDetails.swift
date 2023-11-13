import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    @State private var competitionTimestamp: Date
    @State private var isCameraPresented = false
    @State private var isVotingPresented = false

    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var competition: CustomPointAnnotation // this holds the selected competition details

    func timeLeft(until endTime: Date) -> String {
        let currentTime = Date()
        let timeInterval = endTime.timeIntervalSince(currentTime)

        // Ensure the time interval is not negative (event has not passed)
        if timeInterval > 0 {
            let hours = Int(timeInterval) / 3600
            let minutes = Int(timeInterval) / 60 % 60
            let seconds = Int(timeInterval) % 60

            // Return as a formatted string
            return String(format: "%02i : %02i : %02i", hours, minutes, seconds)
        } else {
            // If the event is over, you might want to return something relevant
            return "00:00:00"
        }
    }

    init(competition: CustomPointAnnotation) {
        self.competition = competition
        _competitionTimestamp = State(initialValue: competition.timestamp)  // Set initial timestamp
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                }
    
                
                Spacer()
                
                Text(competition.competitionDescription)
                    .font(.system(size: 21, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                    .padding(.horizontal)

                Text(timeRemaining)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(Color(hex: "#ababab"))
                    .padding(.bottom, 20)
                    .padding(.horizontal)
                    .onReceive(timer) { _ in
                        // Calculate the end time (i.e., competition timestamp + 12 hours)
                        let endTime = competitionTimestamp.addingTimeInterval(12 * 60 * 60)

                        // Update the time remaining
                        timeRemaining = timeLeft(until: endTime)
                    }
                    .onDisappear {
                        timer.upstream.connect().cancel()
                    }
        
                Button(action: {
                    joincomp()
                }) {
                    Text("Join Competition")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .padding(.horizontal)

                Button(action: {
                    vote()
                }) {
                    Text("Vote Now (5)")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#7B68EE"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                

                Spacer()
            }
        }
        .onAppear {
            // Now that the view has appeared, we can calculate the initial time remaining
            let endTime = competitionTimestamp.addingTimeInterval(12 * 60 * 60)  // 12 hours from timestamp
            timeRemaining = timeLeft(until: endTime)
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competitionId: competition.id)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id)
        })
    }
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
}
