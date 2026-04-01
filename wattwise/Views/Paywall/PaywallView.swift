import SwiftUI

struct PaywallView: View {
    var context: PaywallContext = .general
    @State private var vm = PaywallViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, text: String)] = [
        ("books.vertical", "Full lesson access across your prep path"),
        ("list.bullet.clipboard", "More practice quizzes, weak-area review, and exam sessions"),
        ("bubble.left.and.exclamationmark.bubble.right", "Tutor help when you get stuck"),
        ("book.pages", "NEC explanations made simpler"),
        ("mappin.and.ellipse", "Study support shaped to your exam type and state")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WWSpacing.xl) {
                    headerSection
                    contextCard
                    valueSection
                    pricingSection
                    footerSection
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.l)
            }
            .background(Color.wwBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.wwTextSecondary)
                    }
                }
            }
            .alert(
                "Access Ready",
                isPresented: Binding(
                    get: { vm.successMessage != nil },
                    set: { if $0 == false { vm.successMessage = nil } }
                )
            ) {
                Button("Continue") {
                    vm.successMessage = nil
                    dismiss()
                }
            } message: {
                Text(vm.successMessage ?? "")
            }
            .alert(
                "Restore Access",
                isPresented: Binding(
                    get: { vm.restoreMessage != nil },
                    set: { if $0 == false { vm.restoreMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    vm.restoreMessage = nil
                }
            } message: {
                Text(vm.restoreMessage ?? "")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            Text(context.eyebrow)
                .wwLabel()
                .textCase(.uppercase)

            Text(context.headline)
                .wwDisplay()

            Text(context.subheadline)
                .wwBody(color: .wwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contextCard: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.s) {
                Text("Why paid access matters")
                    .wwLabel()
                    .textCase(.uppercase)
                Text(context.contextNote)
                    .wwBody(color: .wwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            Text("What you get")
                .wwSectionTitle()

            VStack(spacing: WWSpacing.s) {
                ForEach(benefits, id: \.text) { benefit in
                    HStack(alignment: .top, spacing: WWSpacing.m) {
                        Image(systemName: benefit.icon)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.wwBlue)
                            .frame(width: 20)
                        Text(benefit.text)
                            .wwBody()
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(WWSpacing.m)
                    .background(Color.wwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.s, style: .continuous))
                }
            }
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: WWSpacing.m) {
            Text("Choose your access")
                .wwSectionTitle()

            VStack(spacing: WWSpacing.m) {
                ForEach(vm.offers) { offer in
                    AccessOfferCard(
                        offer: offer,
                        isPurchasing: vm.isPurchasing(offer.productID),
                        action: {
                            Task {
                                await vm.purchase(
                                    productID: offer.productID,
                                    services: services,
                                    appVM: appVM
                                )
                            }
                        }
                    )
                }
            }

            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: WWSpacing.m) {
            WWGhostButton(title: vm.isRestoring ? "Restoring..." : "Restore Access") {
                Task { await vm.restore(services: services, appVM: appVM) }
            }
            .disabled(vm.isRestoring)

            Text(context.trustNote)
                .wwCaption(color: .wwTextSecondary)
                .multilineTextAlignment(.center)

            Text("Built for serious electrician exam prep. Clear access options. No gimmicks.")
                .wwCaption(color: .wwTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AccessOfferCard: View {
    let offer: AccessOffer
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        WWCard {
            VStack(alignment: .leading, spacing: WWSpacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.title)
                            .wwSectionTitle()
                        Text(offer.accessTerm)
                            .wwBody(color: .wwTextSecondary)
                    }

                    Spacer()

                    if offer.isRecommended {
                        Text("Recommended")
                            .wwLabel(color: .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.wwBlue)
                            .clipShape(Capsule())
                    }
                }

                Text(offer.price)
                    .font(WWFont.display(.bold))
                    .foregroundColor(.wwTextPrimary)

                Text(offer.description)
                    .wwBody(color: .wwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if offer.isRecommended {
                    WWPrimaryButton(title: offer.callToAction, isLoading: isPurchasing, action: action)
                } else {
                    WWSecondaryButton(title: offer.callToAction, isLoading: isPurchasing, action: action)
                }
            }
        }
        .background(offer.isRecommended ? Color.wwBlueDim : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                .strokeBorder(offer.isRecommended ? Color.wwBlue : Color.wwDivider, lineWidth: offer.isRecommended ? 1.5 : 1)
        )
    }
}

#Preview {
    PaywallView(context: .previewQuizComplete)
        .environment(ServiceContainer())
        .environment(AppViewModel())
}
