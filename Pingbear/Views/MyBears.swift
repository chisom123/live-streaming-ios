//
//  MyBears.swift
//  Pingbear
//
//  Created by Ezi Agu on 13/06/1402 AP.
//
import SwiftUI
import SDWebImageSwiftUI

struct MyBearsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var viewModel = BearsViewModel()
    
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

                ScrollView {

                    VStack(spacing: 25) {
                        ForEach(viewModel.ownedBears, id: \.id) { bear in
                            Button(action: {
                                viewModel.updateUserIcon(with: bear.imageUrl)
                            }) {
                                HStack {
                                    WebImage(url: URL(string: bear.imageUrl))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 75, height: 75)
                                        .padding(.trailing, 20)

                                    VStack(alignment: .leading, spacing: 18) {
                                        Text(bear.name)
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundColor(.black)
                                        
                                        Text(bear.imageUrl == viewModel.currentUserIcon ? "Active" : "Activate")
                                            .font(.system(size: 15, weight: .bold, design: .default))
                                            .foregroundColor(bear.imageUrl == viewModel.currentUserIcon ? Color(hex: "#ababab") : Color(hex: "#1199FF"))
                                    }

                                    Spacer()
                                }
                            }
                            .padding(.vertical, 35)
                            .padding(.horizontal, 20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    .padding(.horizontal, 20)
                }
                
            }
        }
    }
}
