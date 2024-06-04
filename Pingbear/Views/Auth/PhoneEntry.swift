import SwiftUI
import Firebase
import FirebaseAuth
import CountryPicker
import PhoneNumberKit
import PostHog

struct CountryPickerViewControllerWrapper: UIViewControllerRepresentable {
    
    @Binding var selectedCountry: Country?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CountryPickerViewControllerWrapper>) -> CountryPickerViewController {
        let countryPicker = CountryPickerViewController()
        countryPicker.selectedCountry = ""
        countryPicker.delegate = context.coordinator
        
        return countryPicker
    }

    func updateUIViewController(_ uiViewController: CountryPickerViewController, context: UIViewControllerRepresentableContext<CountryPickerViewControllerWrapper>) {
        
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CountryPickerDelegate {
        var parent: CountryPickerViewControllerWrapper

        init(_ parent: CountryPickerViewControllerWrapper) {
            self.parent = parent
        }

        func countryPicker(didSelect country: Country) {
            parent.selectedCountry = country
            PostHogSDK.shared.capture("Country Selected", properties: ["country": country.isoCode])
        }
    }
}

struct PhoneEntryView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationID: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showVerificationView = false
    @State private var selectedCountry: Country?
    @State private var showCountryPicker = false
    @State private var isLoading: Bool = false

    init() {
        if let countryCode = NSLocale.current.regionCode,
           let country = CountryManager.shared.getCountries().first(where: { $0.isoCode == countryCode }) {
            self._selectedCountry = State(initialValue: country)
        }

        // Customize the close button of the country picker
        let closeButton = DismissButtonStyle.title(title: "Close", textColor: UIColor(hex: "#1199FF"), font: UIFont.systemFont(ofSize: 16, weight: .bold))

        CountryManager.shared.config.closeButtonStyle = closeButton
    }

    var formattedPhoneNumber: String {
        let phoneNumberKit = PhoneNumberKit()

        guard let country = selectedCountry else {
            return phoneNumber
        }

        let fullPhoneNumber = "+\(country.phoneCode)\(phoneNumber)"

        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(fullPhoneNumber)
            let formattedPhoneNumber = phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
            return formattedPhoneNumber
        } catch {
            return phoneNumber
        }
    }

    
    var body: some View {
        VStack {
            
            Text("Enter your phone number")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
                .onAppear {
                    PostHogSDK.shared.capture("Phone Entry View Opened")
                }
            
            HStack {
                // Country Picker Button
                Button(action: {
                    showCountryPicker.toggle()
                }) {
                    if let country = selectedCountry {
                        Text("\(country.isoCode.getFlag()) +\(country.phoneCode)")
                    } else {
                        Text("🇬🇧 +44")
                    }
                }
                .sheet(isPresented: $showCountryPicker) {
                    CountryPickerViewControllerWrapper(selectedCountry: $selectedCountry)
                }
                .padding()   // Adjust the padding to match the TextField's
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .bold, design: .default))

                // Phone Number TextField
                TextField("Enter phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .bold, design: .default))
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
            }
        
            if isLoading {
                ProgressView()
                    .padding(.top, 30)
            } else {
                Button(action: {
                    self.sendVerificationCode()
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
            }
            
            NavigationLink(destination: VerificationView(phoneNumber: formattedPhoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) {
                EmptyView()
            }.isDetailLink(false)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    func sendVerificationCode() {
        errorMessage = nil
        isLoading = true
        let phoneNumberKit = PhoneNumberKit()
        
        guard let country = selectedCountry else {
            self.isLoading = false
            errorMessage = "Please select a country."
            PostHogSDK.shared.capture("Country Not Selected", properties: ["error": errorMessage ?? "No error message"])
            return
        }

        let fullPhoneNumber = "+\(country.phoneCode)\(phoneNumber)"

        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(fullPhoneNumber)
            let formattedPhoneNumber = phoneNumberKit.format(parsedPhoneNumber, toType: .e164)

            PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { (verificationID, error) in
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    PostHogSDK.shared.capture("Verification Code Sending Failed", properties: ["error": error.localizedDescription])
                    return
                }

                self.verificationID = verificationID
                self.showVerificationView = true
                PostHogSDK.shared.capture("Verification Code Sent", properties: ["phoneNumber": formattedPhoneNumber])
            }

        } catch {
            self.isLoading = false
            errorMessage = "Invalid phone number"
            PostHogSDK.shared.capture("Invalid Phone Number", properties: ["phoneNumber": fullPhoneNumber, "error": errorMessage ?? ""])
        }
    }
}
