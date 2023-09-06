import SwiftUI
import Firebase
import CountryPicker

struct AddFriendsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var phoneNumber: String = ""
    @ObservedObject var viewModel: AddFriendsModel
    @State private var messageStatus: MessageStatus? = nil
    @State private var selectedCountry: Country?
    @State private var showCountryPicker = false

    enum MessageStatus {
        case error, success, none
    }
    
    init(viewModel: AddFriendsModel) {
        self.viewModel = viewModel

        if let countryCode = NSLocale.current.regionCode,
           let country = CountryManager.shared.getCountries().first(where: { $0.isoCode == countryCode }) {
            self._selectedCountry = State(initialValue: country)
        }

        let closeButton = DismissButtonStyle.title(title: "Close", textColor: UIColor(hex: "#1199FF"), font: UIFont.systemFont(ofSize: 16, weight: .bold))
        CountryManager.shared.config.closeButtonStyle = closeButton
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
                    
                    Spacer()
                }
                
                Spacer()

                Text("Add Friend")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                
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
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .medium, design: .default))

                    // Phone Number TextField
                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(5)
                        .font(.system(size: 16, weight: .medium, design: .default))
                }
                .padding(.horizontal)
                .keyboardType(.phonePad)

                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Failed to add friend")
                            .foregroundColor(Color(hex: "#CC2255"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                                    
                    case .success:
                        Text("Friend added successfully")
                            .foregroundColor(Color(hex: "#556B2F"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    case .none:
                        EmptyView()
                    }
                }
                
                Button(action: {
                    // Combine the country phone code and the phone number
                    let fullPhoneNumber: String
                    if let country = selectedCountry {
                        fullPhoneNumber = "+\(country.phoneCode)\(phoneNumber)"
                    } else {
                        // If the country hasn't been selected, default to the UK phone code.
                        // Alternatively, you can show an error message prompting the user to select a country.
                        fullPhoneNumber = "+44\(phoneNumber)"
                    }

                    viewModel.addFriend(byPhoneNumber: fullPhoneNumber) { (success, error) in
                        if success {
                            messageStatus = .success
                        } else {
                            messageStatus = .error
                        }
                    }
                }) {
                    Text("Add")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)

                Spacer()
            }
            
            Spacer()
        }
    }
}
