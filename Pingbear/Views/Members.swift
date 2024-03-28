import SwiftUI

struct MembersView: View {
    
    @Environment(\.presentationMode) var presentationMode
    var competition: Competition
    @ObservedObject private var viewModel = MembersViewModel()
    
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
                    
                    Spacer()
                }
                .padding(.bottom, 15)
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Group Admin")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        
                        HStack {
                            Text(competition.username)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineSpacing(9)
                                .foregroundColor(.black)
                                .truncationMode(.tail)
                                .padding(.leading, 10)
                        }
                        .padding(20)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        
                        Text("Allowed to add images")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        
                        if viewModel.joinUsernames.isEmpty {
                            HStack {
                                Text("Everyone")
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        } else {
                            ForEach(viewModel.joinUsernames, id: \.self) { username in
                                Text(username)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                        
                        Text("Allowed to vote on images")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        
                        if viewModel.voteUsernames.isEmpty {
                            HStack {
                                Text("Everyone")
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        } else {
                            ForEach(viewModel.voteUsernames, id: \.self) { username in
                                Text(username)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .refreshable {
            viewModel.fetchMembersDetails(for: competition)
        }
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
        }
    }

}
