import SwiftData
import SwiftUI

struct CodeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore
    @Environment(AppClock.self) private var clock
    @Environment(CodeService.self) private var codeService

    let account: Account
    let title: String
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var codeSize: Double = 44
    @State private var hapticTrigger = 0

    private static let containerInset: CGFloat = 16
    private static var containerCornerRadius: CGFloat {
        let deviceRadius = DeviceCornerRadius.current
        return max(0, deviceRadius - containerInset)
    }

    init(account: Account, title: String = "Account Added", onDone: @escaping () -> Void) {
        self.account = account
        self.title = title
        self.onDone = onDone
    }

    // MARK: - Derived state

    private var generatedCode: GeneratedCode? {
        codeService.code(for: account.id)
    }

    private var rawCode: String {
        generatedCode?.code ?? ""
    }

    private var remainingSeconds: Int {
        guard let end = generatedCode?.windowEnd else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSince(clock.now))))
    }

    private var isCopied: Bool {
        codeService.copiedAccountId == account.id
    }

    private var colorState: CodeColorState {
        CodeColorState(code: rawCode, isCopied: isCopied, type: account.type, remainingSeconds: remainingSeconds)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            Button(action: copyCode) {
                VStack(spacing: 4) {
                    Spacer()

                    HStack(spacing: 12) {
                        Text(CodeFormatting.formatted(rawCode))
                            .font(.system(size: codeSize, design: .monospaced))
                            .foregroundStyle(colorState.color)
                            .contentTransition(.numericText())
                            .animation(isCopied || reduceMotion ? nil : .easeInOut(duration: CodeAnimation.duration), value: colorState)
                            .animation(reduceMotion ? nil : .easeInOut(duration: CodeAnimation.duration), value: rawCode)

                        if account.type == .hotp {
                            Button(
                                "Next Code",
                                systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill",
                                action: incrementCounter
                            )
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .foregroundStyle(profileTint)
                            .buttonStyle(.plain)
                        }
                    }

                    if account.type == .totp {
                        Text("\(remainingSeconds)s")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .easeInOut(duration: CodeAnimation.duration), value: remainingSeconds)
                    }

                    Text(account.effectiveIssuer)
                        .font(.title3)
                        .bold()
                        .padding(.top, 24)

                    Text(account.effectiveName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .safeAreaPadding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)
                .background(
                    Color.sesameSurface,
                    in: .rect(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: Self.containerCornerRadius,
                        bottomTrailingRadius: Self.containerCornerRadius,
                        topTrailingRadius: 16
                    )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Self.containerInset)
            .padding(.bottom, max(0, Self.containerInset - geometry.safeAreaInsets.bottom))
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sesameSheetContent()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark", action: onDone)
                    .labelStyle(.iconOnly)
            }
        }
        .sensoryFeedback(.impact, trigger: hapticTrigger) { _, _ in HapticService.isEnabled }
        .onAppear {
            codeService.refreshCodes(for: [account], at: clock.now)
        }
    }

    // MARK: - Actions

    private func incrementCounter() {
        codeService.incrementCounter(for: account)
        hapticTrigger += 1
        AccountService.update(account: account, modelContext: modelContext, backupStore: backupStore)
    }

    private func copyCode() {
        guard !rawCode.isEmpty else { return }
        codeService.copyCode(for: account.id)
        codeService.startLiveActivity(for: account)
        Toast.showCopied()
    }
}
