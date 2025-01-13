import SwiftUI
import PhotosUI
import FirebaseAuth
import PostHog

struct TicketScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var verificationResult: TicketVerificationService.TicketVerificationResult?
    @State private var isVerifying = false
    @State private var verificationSuccess = false
    
    let event: Event
    
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
                
                Text("Verify Ticket")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(Color.black)
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                Spacer()
                
                VStack {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        VStack {
                            Text("Upload Ticket")
                                .font(.system(size: 21, weight: .bold, design: .default))
                                .foregroundColor(.black)
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                            
                            Text("Please upload a clear image of your full ticket")
                                .font(.system(size: 17, weight: .bold, design: .default))
                                .foregroundColor(.gray) // Set the text color as needed
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .padding(.bottom, 20)
                        }
                    }
                    
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if let result = verificationResult {
                        VStack(spacing: 15) {
                            Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isValid ? Color(hex: "#4CAF50") : .red)
                                .font(.system(size: 50))
                            
                            Text(result.isValid ? "Ticket Verified" : "Verification Failed")
                                .font(.system(size: 21, weight: .bold, design: .default))
                                .foregroundColor(.black)
                            
                            if let error = result.error {
                                Text(error)
                                    .font(.system(size: 17, weight: .bold, design: .default))
                                    .foregroundColor(.gray) // Set the text color as needed
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    
                    if verificationSuccess {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#4CAF50"))
                                .foregroundColor(.white)
                                .cornerRadius(200)
                                .padding(.bottom, 20)
                        }
                    } else {
                        PhotosPicker(selection: $selectedItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            Text("Select Image")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#1199FF"))
                                .foregroundColor(.white)
                                .cornerRadius(200)
                                .padding(.bottom, 20)
                        }
                                     .padding(.top, 10)
                                     .onChange(of: selectedItem) { _ in
                                         loadTransferable()
                                     }
                    }
                }
                .padding(20)
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(5)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    private func loadTransferable() {
        Task {
            do {
                if let imageData = try await selectedItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: imageData),
                   let cgImage = uiImage.cgImage {
                    
                    await MainActor.run {
                        selectedImage = uiImage
                        verifyTicket(cgImage: cgImage)
                    }
                }
            } catch {
                await MainActor.run {
                    verificationResult = TicketVerificationService.TicketVerificationResult(
                        isValid: false,
                        barcode: nil,
                        date: nil,
                        location: nil,
                        error: error.localizedDescription
                    )
                }
            }
        }
    }
    
    private func verifyTicket(cgImage: CGImage) {
        isVerifying = true
        
        Task {
            let result = await TicketVerificationService.shared.verifyTicket(image: cgImage, event: event)
            
            await MainActor.run {
                verificationResult = result
                isVerifying = false
                
                if result.isValid {
                    guard let userId = Auth.auth().currentUser?.uid else { return }
                    event.markUserAsVerified(userId: userId)
                    event.checkVerificationStatus()
                    PostHogSDK.shared.capture("Ticket Verified")
                    verificationSuccess = true
                }
            }
        }
    }
}
