import Foundation
import os

@MainActor @Observable
final class CodeService {
    private(set) var codes: [UUID: GeneratedCode] = [:]
    private(set) var copiedAccountId: UUID?

    private var secrets: [UUID: String] = [:]
    private var copiedCode: String?
    private var copiedResetTask: Task<Void, Never>?
    private var bufferUpdateTask: Task<Void, Never>?
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
                if account.id == LiveActivityService.activeAccountId,
                   account.type == .totp, let windowEnd = newCode.windowEnd
                {
                    let nextCode = generateNextCode(
                        accountId: account.id,
                        algorithm: account.algorithm,
                        digits: account.digits,
                        period: account.period,
                        after: windowEnd
                    )
                    LiveActivityService.update(
                        code: newCode.code,
                        nextCode: remainingSeconds(until: windowEnd) <= 20 ? nextCode : nil,
                        expiresAt: windowEnd
                    )
                    scheduleBufferUpdate(
                        accountId: account.id,
                        algorithm: account.algorithm,
                        digits: account.digits,
                        period: account.period,
                        windowEnd: windowEnd
                    )
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
        ClipboardService.copy(codeString)

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

    func startLiveActivity(for account: Account) {
        guard account.type == .totp else { return }
        guard let generated = codes[account.id], let windowEnd = generated.windowEnd else { return }

        let remaining = remainingSeconds(until: windowEnd)
        let nextCode = generateNextCode(
            accountId: account.id,
            algorithm: account.algorithm,
            digits: account.digits,
            period: account.period,
            after: windowEnd
        )
        let duration = ClipboardService.clearDuration
        let dismissAfter: TimeInterval? = duration > 0 ? TimeInterval(duration) : nil

        LiveActivityService.start(
            accountId: account.id,
            code: generated.code,
            nextCode: remaining <= 20 ? nextCode : nil,
            expiresAt: windowEnd,
            issuer: account.effectiveIssuer,
            dismissAfter: dismissAfter
        )

        scheduleBufferUpdate(
            accountId: account.id,
            algorithm: account.algorithm,
            digits: account.digits,
            period: account.period,
            windowEnd: windowEnd
        )
    }

    private func generateNextCode(
        accountId: UUID,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int,
        after windowEnd: Date
    ) -> String? {
        guard let secret = secret(for: accountId) else { return nil }
        return TOTPGenerator.generate(
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period,
            timestamp: windowEnd.addingTimeInterval(1)
        )?.code
    }

    private func scheduleBufferUpdate(
        accountId: UUID,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int,
        windowEnd: Date
    ) {
        bufferUpdateTask?.cancel()

        let bufferTime = windowEnd.addingTimeInterval(-20)
        let delay = bufferTime.timeIntervalSinceNow
        guard delay > 0 else { return }

        bufferUpdateTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard LiveActivityService.activeAccountId == accountId else { return }
            guard let generated = codes[accountId] else { return }

            let nextCode = generateNextCode(
                accountId: accountId,
                algorithm: algorithm,
                digits: digits,
                period: period,
                after: windowEnd
            )
            LiveActivityService.update(
                code: generated.code,
                nextCode: nextCode,
                expiresAt: windowEnd
            )
        }
    }

    private func remainingSeconds(until date: Date) -> TimeInterval {
        max(0, date.timeIntervalSinceNow)
    }
}
