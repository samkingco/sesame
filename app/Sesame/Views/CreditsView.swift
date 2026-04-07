import SwiftUI

struct CreditsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sesame")
                        .font(.headline)

                    Text("Made by Sam King, who couldn't find a 2FA app he actually\u{00A0}liked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .sesameRowBackground()

                sourceLink(label: "samking.co", destination: madeByURL)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Argon2")
                        .font(.headline)

                    Text(
                        "Reference C implementation of the Argon2 password hashing function. "
                            + "Used for key derivation in encrypted\u{00A0}backups."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(
                        "Daniel Dinu, Dmitry Khovratovich, "
                            + "Jean-Philippe Aumasson, Samuel\u{00A0}Neves"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("CC0 1.0 / Apache 2.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .sesameRowBackground()

                sourceLink(destination: argon2URL)
            }

            standardSection(
                "RFC 4226",
                title: "HOTP: HMAC-Based One-Time\u{00A0}Password",
                url: rfc4226URL
            )

            standardSection(
                "RFC 6238",
                title: "TOTP: Time-Based One-Time\u{00A0}Password",
                url: rfc6238URL
            )

            standardSection(
                "RFC 4648",
                title: "Base16, Base32, and Base64\u{00A0}Encodings",
                url: rfc4648URL
            )
        }
        .sesameSheetContent()
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func standardSection(
        _ number: String,
        title: String,
        url: URL
    ) -> some View {
        Section {
            Text(title)
                .font(.subheadline)
                .padding(.vertical, 4)
                .sesameRowBackground()

            sourceLink(label: "View \(number)", destination: url)
        }
    }

    private func sourceLink(
        label: String = "View Source",
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .sesameRowBackground()
    }

    private let madeByURL = URL(
        string: "https://samking.co"
    )!
    private let argon2URL = URL(
        string: "https://github.com/P-H-C/phc-winner-argon2"
    )!
    private let rfc4226URL = URL(
        string: "https://datatracker.ietf.org/doc/html/rfc4226"
    )!
    private let rfc6238URL = URL(
        string: "https://datatracker.ietf.org/doc/html/rfc6238"
    )!
    private let rfc4648URL = URL(
        string: "https://datatracker.ietf.org/doc/html/rfc4648"
    )!
}
