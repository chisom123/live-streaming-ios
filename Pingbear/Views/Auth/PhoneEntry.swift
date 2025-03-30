import SwiftUI
import FirebaseAuth
import CountryPicker
import PhoneNumberKit

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
            Analytics.shared.track(
                event: "country_selected",
                properties: ["country": country.isoCode]
            )
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

        let closeButton = DismissButtonStyle.title(title: "Close", textColor: UIColor.white, font: UIFont.systemFont(ofSize: 16, weight: .bold))
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
            
            Spacer()
            
            VStack {
                Text("Enter your phone number")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 25)
                    .onAppear {
                        Analytics.shared.trackScreen(name: "phone_entry")
                    }
                
                HStack(spacing: 0) {
                    // Country Picker Button
                    Button(action: {
                        showCountryPicker.toggle()
                    }) {
                        if let country = selectedCountry {
                            Text("\(country.isoCode.getFlag()) +\(country.phoneCode)")
                                .foregroundColor(Color.white)
                        } else {
                            Text("🇬🇧 +44")
                                .foregroundColor(Color.white)
                        }
                    }
                    .sheet(isPresented: $showCountryPicker) {
                        CountryPickerViewControllerWrapper(selectedCountry: $selectedCountry)
                    }
                    .padding()
                    .frame(height: 60) // Fixed height
                    .background(
                        Color(hex: "#323862")
                            .clipShape(
                                RoundedCorner(
                                    radius: 10,
                                    corners: [.topLeft, .bottomLeft]
                                )
                            )
                    )
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    
                    // Phone Number TextField
                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .frame(height: 60) // Same fixed height
                        .background(
                            Color(hex: "#3B4374")
                                .clipShape(
                                    RoundedCorner(
                                        radius: 10,
                                        corners: [.topRight, .bottomRight]
                                    )
                                )
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold, design: .default))
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#FF0000"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                }
            
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 20)
                        .tint(.white)
                } else {
                    Button(action: {
                        self.sendVerificationCode()
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(Color(hex: "#FF4081"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(hex: "#1A2245"))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            NavigationLink(destination: VerificationView(phoneNumber: formattedPhoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) {
                EmptyView()
            }.isDetailLink(false)
            
            Spacer()
            
        }
        .background(Color(hex: "#10183C"))
        .navigationBarBackButtonHidden(true)
    }

    func sendVerificationCode() {
        errorMessage = nil
        isLoading = true
        let phoneNumberKit = PhoneNumberKit()
        
        guard let country = selectedCountry else {
            self.isLoading = false
            errorMessage = "Please select a country."
            Analytics.shared.track(
                event: "country_not_selected",
                properties: ["error": errorMessage ?? "No error message"]
            )
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
                    Analytics.shared.track(
                        event: "verification_code_sending_failed",
                        properties: ["error": error.localizedDescription]
                    )
                    return
                }

                self.verificationID = verificationID
                self.showVerificationView = true
                Analytics.shared.track(
                    event: "verification_code_sent",
                    properties: ["phone_number": formattedPhoneNumber]
                )
            }

        } catch {
            self.isLoading = false
            errorMessage = "Invalid phone number"
            Analytics.shared.track(
                event: "invalid_phone_number",
                properties: [
                    "phone_number": fullPhoneNumber,
                    "error": errorMessage ?? ""
                ]
            )
        }
    }
}
