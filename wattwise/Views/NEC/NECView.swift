import SwiftUI

// MARK: - NEC Search View (tab entry point)

struct NECView: View {
    @State private var vm = NECViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    private let suggestedSearches = [
        "210.8",
        "210.52",
        "250.50",
        "310.16",
        "110.26"
    ]

    private let starterReferences: [(code: String, title: String, summary: String)] = [
        ("210.8", "GFCI Protection", "Where GFCI protection is required for personnel safety."),
        ("210.52", "Dwelling Receptacle Requirements", "Core outlet-spacing rules that appear often on exams."),
        ("250.50", "Grounding Electrode System", "How available electrodes must be bonded together."),
        ("310.16", "Ampacity Table", "One of the most tested conductor-ampacity references."),
        ("110.26", "Working Space", "Required clearance around electrical equipment.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            WWSearchField(
                placeholder: "Search NEC code or topic…",
                text: $vm.searchQuery,
                onSubmit: { vm.search(services: services) },
                onClear: { vm.search(services: services) }
            )
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
            .onChange(of: vm.searchQuery) { _, _ in
                vm.search(services: services)
            }

            WWDivider()

            // Results
            if vm.isSearching {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = vm.searchError {
                WWEmptyState(
                    icon: "wifi.slash",
                    title: "Search unavailable",
                    message: error,
                    actionTitle: "Retry"
                ) {
                    vm.search(services: services)
                }
            } else if vm.results.isEmpty && !vm.searchQuery.isEmpty {
                WWEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "No results",
                    message: "Try a different search term or NEC article number."
                )
            } else {
                ScrollView {
                    if vm.searchQuery.isEmpty {
                        VStack(alignment: .leading, spacing: WWSpacing.l) {
                            VStack(alignment: .leading, spacing: WWSpacing.s) {
                                Text("Suggested Searches")
                                    .wwLabel()
                                    .textCase(.uppercase)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: WWSpacing.s) {
                                        ForEach(suggestedSearches, id: \.self) { suggestion in
                                            Button {
                                                vm.searchQuery = suggestion
                                                vm.search(services: services)
                                            } label: {
                                                Text(suggestion)
                                                    .wwCaption(color: .wwBlue)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.wwBlueDim)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                Text("Starter References")
                                    .wwLabel()
                                    .textCase(.uppercase)
                                    .padding(.bottom, WWSpacing.s)

                                ForEach(starterReferences, id: \.code) { reference in
                                    NavigationLink {
                                        NECDetailView(
                                            necId: WattWiseContentRuntimeAdapter.uuid(for: "nec:\(reference.code)"),
                                            code: reference.code
                                        )
                                        .environment(services)
                                        .environment(appVM)
                                    } label: {
                                        NECResultRow(result: NECSearchResult(
                                            id: WattWiseContentRuntimeAdapter.uuid(for: "nec:\(reference.code)"),
                                            code: reference.code,
                                            title: reference.title,
                                            summary: reference.summary
                                        ))
                                    }
                                    .buttonStyle(.plain)

                                    if reference.code != starterReferences.last?.code {
                                        WWDivider().padding(.leading, WWSpacing.m)
                                    }
                                }
                            }
                        }
                        .wwScreenPadding()
                        .padding(.vertical, WWSpacing.m)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.results) { result in
                                NavigationLink {
                                    NECDetailView(necId: result.id, code: result.code)
                                        .environment(services)
                                        .environment(appVM)
                                } label: {
                                    NECResultRow(result: result)
                                }
                                .buttonStyle(.plain)

                                WWDivider().padding(.leading, WWSpacing.m)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.wwBackground)
        .navigationTitle("NEC Lookup")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.search(services: services) }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(context: .necLimit)
                .environment(services)
                .environment(appVM)
        }
    }
}

// MARK: - NEC Result Row

private struct NECResultRow: View {
    let result: NECSearchResult

    var body: some View {
        HStack(spacing: WWSpacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                // Code badge on its own line so title always has full width
                Text("NEC \(result.code)")
                    .font(WWFont.caption(.semibold))
                    .foregroundColor(.wwBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.wwBlueDim)
                    .clipShape(Capsule())
                Text(result.title)
                    .font(WWFont.body(.medium))
                    .foregroundColor(.wwTextPrimary)
                    .lineLimit(1)
                Text(result.summary)
                    .wwBody(color: .wwTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: WWSpacing.s)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wwTextMuted)
        }
        .padding(WWSpacing.m)
    }
}

// MARK: - NEC Detail View

struct NECDetailView: View {
    let necId: UUID
    let code: String
    @State private var vm = NECViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM
    @State private var showTutor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WWSpacing.l) {
                if vm.isLoadingDetail || (vm.selectedDetail == nil && vm.detailError == nil) {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, WWSpacing.xl)
                } else if let error = vm.detailError {
                    WWEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't load article",
                        message: error,
                        actionTitle: "Retry"
                    ) {
                        Task { await vm.loadDetail(id: necId, services: services) }
                    }
                    .padding(.top, WWSpacing.xl)
                } else if let detail = vm.selectedDetail {
                    // Header
                    VStack(alignment: .leading, spacing: WWSpacing.s) {
                        Text("NEC \(detail.code)")
                            .font(WWFont.caption(.semibold))
                            .foregroundColor(.wwBlue)
                        Text(detail.title)
                            .wwHeading()
                        Text(detail.summary)
                            .wwBodyLarge(color: .wwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }

                    WWDivider()

                    // Expanded explanation
                    if let expanded = detail.expanded ?? vm.expandedText {
                        VStack(alignment: .leading, spacing: WWSpacing.m) {
                            Text("Full Explanation")
                                .wwSectionTitle()
                            Text(expanded)
                                .wwBody()
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(5)
                        }
                    } else {
                        // AI Explain button
                        VStack(alignment: .leading, spacing: WWSpacing.m) {
                            if vm.isExplaining {
                                HStack(spacing: WWSpacing.s) {
                                    ProgressView()
                                    Text("Generating explanation…")
                                        .wwBody(color: .wwTextSecondary)
                                }
                            } else {
                                WWSecondaryButton(title: "Explain Further") {
                                    Task {
                                        await vm.explain(id: detail.id, services: services, appVM: appVM)
                                    }
                                }
                            }

                            if appVM.subscriptionState.hasPaidAccess == false {
                                Text("\(appVM.subscriptionState.necExplanationsRemaining) NEC explanation sample\(appVM.subscriptionState.necExplanationsRemaining == 1 ? "" : "s") left in preview")
                                    .wwCaption()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            if let explainError = vm.explainError {
                                Text(explainError)
                                    .font(WWFont.caption(.medium))
                                    .foregroundColor(.wwError)
                            }
                        }
                    }

                    WWDivider()

                    // Ask tutor
                    WWGhostButton(title: "Ask Tutor About This Article", color: .wwBlue) {
                        showTutor = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .wwScreenPadding()
            .padding(.vertical, WWSpacing.m)
        }
        .background(Color.wwBackground)
        .navigationTitle("NEC \(code)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTutor) {
            TutorSheet(context: vm.selectedDetail.map { TutorContextBuilder.necDetail($0, user: appVM.currentUser) })
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(context: .necLimit)
                .environment(services)
                .environment(appVM)
        }
        .task { await vm.loadDetail(id: necId, services: services) }
    }
}

#Preview {
    NavigationStack {
        NECView()
            .environment(ServiceContainer())
            .environment(AppViewModel())
    }
}
