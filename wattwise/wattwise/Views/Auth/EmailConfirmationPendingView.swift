import SwiftUI

struct EmailConfirmationPendingView: View {
    let pending: PendingEmailConfirmation

    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            Color.wwBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: WWSpacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.wwBlueDim)
                            .frame(width: 88, height: 88)
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.wwBlue)
                    }

                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text("Check your email")
                            .wwHeading()
                        Text("We sent a confirmation link to \(pending.email). Open it on this device to continue into WattWise.")
                            .wwBody(color: .wwTextSecondary)
                        Text("If you confirmed on another device, come back here and sign in.")
                            .wwBody(color: .wwTextSecondary)
                    }
                }

                Spacer().frame(height: WWSpacing.xl)

                if appVM.isHandlingAuthLink {
                    Text("Confirming your account…")
                        .font(WWFont.body(.medium))
                        .foregroundColor(.wwBlue)
                        .padding(.bottom, WWSpacing.m)
                }

                if let status = appVM.authStatusMessage {
                    Text(status)
                        .wwBody(color: .wwTextSecondary)
                        .padding(.bottom, WWSpacing.s)
                }

                if let error = appVM.authErrorMessage {
                    Text(error)
                        .font(WWFont.caption(.medium))
                        .foregroundColor(.wwError)
                        .padding(.bottom, WWSpacing.m)
                }

                VStack(spacing: WWSpacing.m) {
                    WWPrimaryButton(
                        title: appVM.isResendingConfirmation ? "Sending…" : "Resend Link",
                        isLoading: appVM.isResendingConfirmation,
                        isDisabled: appVM.isResendingConfirmation || appVM.isHandlingAuthLink
                    ) {
                        Task { await appVM.resendConfirmation(services: services) }
                    }

                    WWSecondaryButton(title: "Back to Sign In") {
                        appVM.showSignIn(email: pending.email)
                    }
                }

                Spacer()
            }
            .wwScreenPadding()
        }
    }
}

#Preview {
    EmailConfirmationPendingView(
        pending: PendingEmailConfirmation(
            email: "test@wattwiseapp.com",
            examType: .apprentice,
            state: "TX",
            studyGoal: .moderate,
            requestedAt: Date()
        )
    )
    .environment(ServiceContainer())
    .environment(AppViewModel())
}
