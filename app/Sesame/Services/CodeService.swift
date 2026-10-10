import Foundation
import os

@MainActor @Observable
final class CodeService {
    private(set) var codes: [UUID: GeneratedCode] = [:]
    private(set) var copiedAccountId: UUID?

    private var secrets: [UUID: String] = [:]
    private var copiedCode: String?
    private var copiedResetTask: Task<Void, Never>?
    private var clipboardClearsAt: Date?
    private let keychain: KeychainServiceProtocol
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "CodeService")

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    // MARK: - Secrets

    func secret(for accountId: UUID) -> String? {
        if let cached = secrets[accountId] {
            return cached
        }
        do {
            let value = try keychain.read(for: accountId)
            secrets[accountId] = value
            return value
        } catch {
            logger.error("Failed to read secret for account \(accountId): \(error)")
            return nil
        }
    }

    func evictSecret(for accountId: UUID) {
        secrets.removeValue(forKey: accountId)
        codes.removeValue(forKey: accountId)
        if LiveActivityService.activeAccountId == accountId {
            LiveActivityService.end()
        }
    }

    func clearSecretCache() {
        secrets.removeAll()
    }

    // MARK: - Code Generation

    func refreshCodes(for accounts: [Account], at date: Date) {
        for account in accounts {
            if let existing = codes[account.id] {
                if account.type == .hotp, existing.counter == account.counter { continue }
                if let windowStart = existing.windowStart, let windowEnd = existing.windowEnd,
                   date >= windowStart, date < windowEnd { continue }
            }
            guard let secret = secret(for: account.id) else { continue }
            do {
                let newCode = try generate(for: account, secret: secret, at: date)
                codes[account.id] = newCode
                if account.id == copiedAccountId, newCode.code != copiedCode {
                    clearCopied()
                }
            } catch {
                logger.error("Failed to generate code for account \(account.id): \(error)")
            }
        }
    }

    func code(for accountId: UUID) -> GeneratedCode? {
        codes[accountId]
    }

    func incrementCounter(for account: Account) {
        account.counter += 1
        guard let secret = secret(for: account.id) else {
            account.counter -= 1
            return
        }
        do {
            codes[account.id] = try generate(for: account, secret: secret)
        } catch {
            logger.error("Failed to generate code after counter increment for account \(account.id): \(error)")
            account.counter -= 1
        }
    }

    // MARK: - Private

    private func generate(
        for account: Account,
        secret: String,
        at timestamp: Date = .now
    ) throws -> GeneratedCode {
        switch account.type {
        case .totp:
            guard let result = TOTPGenerator.generate(
                secret: secret,
                algorithm: account.algorithm,
                digits: account.digits,
                period: account.period,
                timestamp: timestamp
            ) else {
                throw CodeGenerationError.generationFailed
            }

            return GeneratedCode(
                code: result.code,
                type: .totp,
                counter: nil,
                windowStart: result.windowStart,
                windowEnd: result.windowEnd,
                remainingSeconds: result.remainingSeconds,
                progress: result.progress
            )

        case .hotp:
            guard let code = HOTPGenerator.generate(
                secret: secret,
                counter: account.counter,
                algorithm: account.algorithm,
                digits: account.digits
            ) else {
                throw CodeGenerationError.generationFailed
            }

            return GeneratedCode(
                code: code,
                type: .hotp,
                counter: account.counter,
                windowStart: nil,
                windowEnd: nil,
                remainingSeconds: nil,
                progress: nil
            )
        }
    }

    // MARK: - Copy

    func copyCode(for accountId: UUID, code: String? = nil) {
        let codeString = code ?? codes[accountId]?.code
        guard let codeString else { return }
        clipboardClearsAt = ClipboardService.copy(codeString)

        copiedResetTask?.cancel()
        copiedAccountId = accountId
        copiedCode = codeString
        copiedResetTask = Task {
            try? await Task.sleep(for: .seconds(CodeAnimation.copiedResetDelay))
            guard !Task.isCancelled else { return }
            clearCopied()
        }
    }

    private func clearCopied() {
        copiedResetTask?.cancel()
        copiedResetTask = nil
        copiedAccountId = nil
        copiedCode = nil
    }

    // MARK: - Live Activity

    /// Shows the copied code until the clipboard clears. Call after `copyCode`.
    func startLiveActivity(for account: Account) {
        guard account.type == .totp, account.id == copiedAccountId,
              let secret = secret(for: account.id)
        else { return }

        let algorithm = account.algorithm
        let digits = account.digits
        let period = account.period

        // Captures the secret so updates don't refill the cache after it's cleared in the background
        LiveActivityService.start(
            accountId: account.id,
            attributes: CopiedCodeAttributes(issuer: account.effectiveIssuer, name: account.effectiveName),
            dismissAt: clipboardClearsAt
        ) { date in
            Self.liveActivityState(secret: secret, algorithm: algorithm, digits: digits, period: period, at: date)
        }
    }

    static func liveActivityState(
        secret: String,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int,
        at date: Date
    ) -> CopiedCodeAttributes.ContentState? {
        guard let result = TOTPGenerator.generate(
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period,
            timestamp: date
        ) else { return nil }

        return CopiedCodeAttributes.ContentState(
            code: result.code,
            colorState: CodeColorState(
                code: result.code,
                isCopied: false,
                type: .totp,
                remainingSeconds: Int(ceil(result.remainingSeconds))
            ),
            expiresAt: result.windowEnd
        )
    }
}
