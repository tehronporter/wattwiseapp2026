import SwiftUI

// MARK: - NEC Search View (tab entry point)

struct NECView: View {
    @State private var vm = NECViewModel()
    @Environment(ServiceContainer.self) private var services
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.wwTextMuted)
                TextField("Search NEC code or topic…", text: $vm.searchQuery)
                    .font(WWFont.body())
                    .onSubmit { vm.search(services: services) }
                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                        vm.search(services: services)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.wwTextMuted)
                    }
                }
            }
            .padding(.horizontal, WWSpacing.m)
            .padding(.vertical, 12)
            .background(Color.wwSurface)
            .clipShape(RoundedRectangle(cornerRadius: WWSpacing.Radius.pill, style: .continuous))
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
            } else if vm.results.isEmpty && !vm.searchQuery.isEmpty {
                WWEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "No results",
                    message: "Try a different search term or NEC article number."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if vm.searchQuery.isEmpty {
                            Text("Common References")
                                .wwLabel()
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .wwScreenPadding()
                                .padding(.top, WWSpacing.m)
                        }

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
        .background(Color.wwBackground)
        .navigationTitle("NEC Lookup")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.search(services: services) }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(reason: "AI-powered NEC explanations are a Pro feature.")
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
                if vm.isLoadingDetail {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, WWSpacing.xl)
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
                                WWSecondaryButton(title: "Explain with AI") {
                                    Task {
                                        await vm.explain(id: detail.id, services: services, subscription: appVM.subscriptionState)
                                    }
                                }

                                if !appVM.subscriptionState.isPro {
                                    Text("AI explanations use 1 daily credit")
                                        .wwCaption()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
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
            TutorSheet(context: TutorContext(type: .necDetail, id: necId))
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(reason: "AI-powered NEC explanations are a Pro feature.")
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
