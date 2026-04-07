import SwiftUI

struct ManualEntryView: View {
    @Environment(\.profileTint) private var profileTint

    @Binding var input: String
    let parseError: String?
    let onSubmit: () -> Void

    private var inputIsEmpty: Bool {
        input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("otpauth:// URI or base32 secret", text: $input)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)
                    .sesameRowBackground()
            } header: {
                Text("Secret")
            } footer: {
                Text("Paste an otpauth:// URI or enter a raw base32 secret key.")
            }

            if let parseError {
                Section {
                    Text(parseError)
                        .foregroundStyle(.red)
                        .sesameRowBackground()
                }
            }

            Section {
                Button("Continue", action: onSubmit)
                    .bold()
                    .disabled(inputIsEmpty)
                    .tint(profileTint)
                    .sesameRowBackground()
            }
        }
        .sesameSheetContent()
        .navigationTitle("Manual Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}
