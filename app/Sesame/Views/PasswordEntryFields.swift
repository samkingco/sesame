import SwiftUI

struct PasswordEntryFields: View {
    @Binding var password: String
    @Binding var confirmation: String
    var showValidation: Bool
    var emptyMessage: String = "Enter a password."
    var error: String?
    var hint: String

    private var validationError: String? {
        guard showValidation else { return nil }
        return PasswordValidation.validate(
            password: password,
            confirmation: confirmation,
            emptyMessage: emptyMessage
        )
    }

    var body: some View {
        Section {
            SecureField("Password", text: $password)
                .sesameRowBackground()
            SecureField("Confirm Password", text: $confirmation)
                .sesameRowBackground()
        } header: {
            Text("Encryption Password")
        } footer: {
            if let error = validationError ?? error {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                Text(hint)
            }
        }
    }
}
