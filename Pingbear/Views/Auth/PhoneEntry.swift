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
    func updateUIViewController(_ uiViewController: CountryPickerViewController, context: UIViewControllerRepresentableContext<CountryPickerViewControllerWrapper>) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, CountryPickerDelegate {
        var parent: CountryPickerViewControllerWrapper
        init(_ parent: CountryPickerViewControllerWrapper) { self.parent = parent }
        func countryPicker(didSelect country: Country) {
            parent.selectedCountry = country
            Analytics.shared.track(event: "country_selected", properties: ["country": country.isoCode])
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
        let closeButton = DismissButtonStyle.title(title: "Close", textColor: UIColor(AppTheme.primaryText), font: UIFont.systemFont(ofSize: 16, weight: .bold))
        CountryManager.shared.config.closeButtonStyle = closeButton
    }

    var formattedPhoneNumber: String {
        let phoneNumberKit = PhoneNumberKit()
        guard let country = selectedCountry else { return phoneNumber }
        let fullPhoneNumber = "+\(country.phoneCode)\(phoneNumber)"
        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(fullPhoneNumber)
            return phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
        } catch { return phoneNumber }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack {
                Spacer()
                VStack {
                    Text("Enter your phone number")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center).lineSpacing(10)
                        .foregroundColor(AppTheme.primaryText)
                        .padding(.top, 20).padding(.bottom, 25)
                        .onAppear { Analytics.shared.trackScreen(name: "phone_entry") }

                    HStack(spacing: 0) {
                        Button(action: { showCountryPicker.toggle() }) {
                            if let country = selectedCountry {
                                Text("\(country.isoCode.getFlag()) +\(country.phoneCode)").foregroundColor(AppTheme.primaryText)
                            } else {
                                Text("🇬🇧 +44").foregroundColor(AppTheme.primaryText)
                            }
                        }
                        .sheet(isPresented: $showCountryPicker) { CountryPickerViewControllerWrapper(selectedCountry: $selectedCountry) }
                        .padding().frame(height: 60)
                        .background(AppTheme.buttonBackground.clipShape(RoundedCorner(radius: 10, corners: [.topLeft, .bottomLeft])))
                        .font(.system(size: 16, weight: .bold, design: .default))

                        TextField("Enter phone number", text: $phoneNumber)
                            .keyboardType(.phonePad).padding().frame(height: 60)
                            .background(AppTheme.inputBackground.clipShape(RoundedCorner(radius: 10, corners: [.topRight, .bottomRight])))
                            .foregroundColor(AppTheme.primaryText)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .tint(AppTheme.accent)
                    }

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center).lineSpacing(10).padding(.top, 20).padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 20).tint(AppTheme.primaryText)
                    } else {
                        Button(action: { self.hideKeyboard(); self.sendVerificationCode() }) {
                            Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(AppTheme.accent).foregroundColor(.white).cornerRadius(200)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity).padding(20)
                .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal, 20)

                NavigationLink(destination: VerificationView(phoneNumber: formattedPhoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) { EmptyView() }.isDetailLink(false)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    func sendVerificationCode() {
        errorMessage = nil; isLoading = true
        let phoneNumberKit = PhoneNumberKit()
        guard let country = selectedCountry else {
            isLoading = false; errorMessage = "Please select a country."
            Analytics.shared.track(event: "country_not_selected", properties: ["error": errorMessage ?? ""]); return
        }
        let fullPhoneNumber = "+\(country.phoneCode)\(phoneNumber)"
        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(fullPhoneNumber)
            let formattedPhoneNumber = phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
            PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { (verificationID, error) in
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    Analytics.shared.track(event: "verification_code_sending_failed", properties: ["error": error.localizedDescription]); return
                }
                self.verificationID = verificationID; self.showVerificationView = true
                Analytics.shared.track(event: "verification_code_sent", properties: ["phone_number": formattedPhoneNumber])
            }
        } catch {
            isLoading = false; errorMessage = "Invalid phone number"
            Analytics.shared.track(event: "invalid_phone_number", properties: ["phone_number": fullPhoneNumber, "error": errorMessage ?? ""])
        }
    }
}
