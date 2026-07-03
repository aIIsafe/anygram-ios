import SwiftUI

struct CallsListView: View {
    @StateObject private var viewModel: CallsViewModel

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: CallsViewModel(repository: container.callsRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Filter", selection: $viewModel.selectedSegment) {
                        Text("All").tag(0)
                        Text("Missed").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(AppSpacing.md)
                    .onChange(of: viewModel.selectedSegment) { _, _ in
                        Task { await viewModel.load() }
                    }

                    if viewModel.isLoading && viewModel.calls.isEmpty {
                        LoadingView()
                    } else if viewModel.calls.isEmpty {
                        ContentUnavailableView("No Calls", systemImage: "phone", description: Text("Your call history will appear here"))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.calls) { call in
                                    CallRowView(call: call)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteCall(call) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .contextMenu {
                                            Button { Task { await viewModel.deleteCall(call) } } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {} label: {
                                                Label("Call Back", systemImage: "phone")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

                Button {} label: {
                    Image(systemName: "phone.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.accent)
                        .clipShape(Circle())
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 8, y: 4)
                }
                .padding(AppSpacing.lg)
                .accessibilityLabel("New call")
            }
            .navigationTitle("Calls")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load() }
        }
    }
}
