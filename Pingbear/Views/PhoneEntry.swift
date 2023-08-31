import SwiftUI
import Firebase
import FirebaseAuth
import CountryPicker

struct PhoneEntryView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationID: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showVerificationView = false

    // Country codes and their display names
    let countryCodes = ["+1": "USA", "+44": "UK", "+91": "India", "+61": "Australia", /* add more country codes and names as needed */ ]
    
    // This will be used to prefill the user's country code
    @State private var selectedCountryCode: String = "+1" // default to USA, for example

    var body: some View {
        VStack {
            Text("Enter your phone number")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            // Country code dropdown
            Picker("Select Country Code", selection: $selectedCountryCode) {
                ForEach(countryCodes.sorted(by: { $0.value < $1.value }), id: \.key) { (key: String, value: String) in
                    Text("\(value) (\(key))").tag(key)
                }
            }
            .pickerStyle(MenuPickerStyle())

            // Phone number entry with selected country code
            HStack {
                Text(selectedCountryCode)
                TextField("Enter phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }
            .padding()
            .border(Color.gray, width: 0.5)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
            }

            Button("Continue") {
                // Update phone number with selected country code
                let fullNumber = selectedCountryCode + phoneNumber
                self.sendVerificationCode(phoneNumber: fullNumber)
            }
            .padding(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#1199FF"))
            .foregroundColor(Color(hex: "#fff"))
            .font(.system(size: 18, weight: .bold, design: .default))
            .cornerRadius(200)
            .padding(.horizontal)
            .padding(.bottom, 20)

            NavigationLink(destination: VerificationView(phoneNumber: phoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) {
                EmptyView()
            }.isDetailLink(false)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // On appearance of the view, detect user's locale to prefill the country code
            if let countryCode = Locale.current.regionCode,
               let phoneCode = countryCodes.first(where: { $0.value == countryCode })?.key {
                selectedCountryCode = phoneCode
            }
        }
    }

    func sendVerificationCode(phoneNumber: String) {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }

            self.verificationID = verificationID
            self.showVerificationView = true
        }
    }
}
