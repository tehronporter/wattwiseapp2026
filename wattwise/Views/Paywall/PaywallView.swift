import SwiftUI

struct PaywallView: View {
    var reason: String = "Unlock unlimited access to all WattWise features."
    @State private var vm = PaywallViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, title: String, description: String)] = [
        ("infinity", "Unlimited AI Tutor", "Ask as many questions as you need, any time"),
        ("doc.text", "Full Practice Exams", "Complete 25-question timed practice exams"),
        ("chart.bar", "Weak Area Review", "AI-targeted quizzes on your problem topics"),
        ("books.vertical", "Full Curriculum", "All modules and lessons unlocked"),
        ("book.pages", "Deep NEC Explanations", "AI-powered explanations for any NEC article")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WWSpacing.l) {
                    // Header
                    VStack(spacing: WWSpacing.m) {
                        ZStack {
                            Circle()
                                .fill(Color.wwBlueDim)
                                .frame(width: 72, height: 72)
                            Image(systemName: "star")
                                .font(.system(size: 30))
                                .foregroundColor(.wwBlue)
                        }

                        Text("WattWise Pro")
                            .wwDisplay()

                        Text(reason)
                            .wwBody(color: .wwTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, WWSpacing.m)

                    // Benefits
                    VStack(spacing: 0) {
                        ForEach(benefits, id: \.title) { benefit in
                            BenefitRow(icon: benefit.icon, title: benefit.title, description: benefit.description)
                            if benefit.title != benefits.last?.title {
                                WWDivider()
                            }
                        }
                    }
                    .background(Color.wwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))

                    // Plan Selector
                    VStack(spacing: WWSpacing.s) {
                        Text("Choose a plan")
                            .wwSectionTitle()

                        HStack(spacing: WWSpacing.m) {
                            ForEach(PaywallViewModel.Plan.allCases, id: \.self) { plan in
                                PlanOption(
                                    plan: plan,
                                    isSelected: vm.selectedPlan == plan,
                                    monthlyPrice: vm.monthlyPrice,
                                    yearlyPrice: vm.yearlyPrice,
                                    savings: vm.yearlySavings
                                ) {
                                    vm.selectedPlan = plan
                                }
                            }
                        }
                    }

                    // Error message
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(WWFont.caption(.medium))
                            .foregroundColor(.wwError)
                            .multilineTextAlignment(.center)
                    }

                    // CTA
                    VStack(spacing: WWSpacing.m) {
                        WWPrimaryButton(
                            title: "Start Free Trial",
                            isLoading: vm.isPurchasing
                        ) {
                            Task { await vm.purchase(services: services, appVM: appVM) }
                        }

                        WWGhostButton(title: "Restore Purchases") {
                            Task { await vm.restore(services: services, appVM: appVM) }
                        }
                    }

                    // Fine print
                    Text("Subscription auto-renews. Cancel anytime in Settings. No dark patterns, no tricks.")
                        .font(WWFont.caption())
                        .foregroundColor(.wwTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, WWSpacing.m)
                }
                .wwScreenPadding()
                .padding(.vertical, WWSpacing.m)
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
            .onChange(of: appVM.subscriptionState.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.wwBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WWFont.body(.semibold))
                    .foregroundColor(.wwTextPrimary)
                Text(description)
                    .wwCaption()
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.wwSuccess)
        }
        .padding(WWSpacing.m)
    }
}

// MARK: - Plan Option

private struct PlanOption: View {
    let plan: PaywallViewModel.Plan
    let isSelected: Bool
    let monthlyPrice: String
    let yearlyPrice: String
    let savings: String
    let action: () -> Void

    var price: String { plan == .monthly ? monthlyPrice : yearlyPrice }
    var label: String { plan == .monthly ? "Monthly" : "Yearly" }

    var body: some View {
        Button(action: action) {
            VStack(spacing: WWSpacing.s) {
                if plan == .yearly {
                    Text(savings)
                        .wwLabel(color: .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.wwBlue)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 22)
                }

                Text(label)
                    .font(WWFont.body(.semibold))
                    .foregroundColor(.wwTextPrimary)

                Text(price)
                    .font(WWFont.caption(.medium))
                    .foregroundColor(.wwTextSecondary)
            }
            .padding(WWSpacing.m)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.wwBlueDim : Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WWSpacing.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Color.wwBlue : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environment(ServiceContainer())
        .environment(AppViewModel())
}
