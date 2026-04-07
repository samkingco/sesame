enum PasswordValidation {
    static func validate(
        password: String,
        confirmation: String,
        emptyMessage: String = "Enter a password."
    ) -> String? {
        if password.isEmpty { return emptyMessage }
        if password.count < 8 { return "Password must be at least 8 characters." }
        if password != confirmation { return "Passwords do not match." }
        return nil
    }

    static func isValid(password: String, confirmation: String) -> Bool {
        password.count >= 8 && password == confirmation
    }
}
