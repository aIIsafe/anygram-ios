import SwiftUI

struct GlobalSearchView: View {
    @StateObject private var viewModel: SearchViewModel

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(repository: container.searchRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    SearchBarView(text: $viewModel.query, placeholder: L10n.searchPlaceholder)
                        .padding(.vertical, AppSpacing.sm)
                        .onChange(of: viewModel.query) { _, _ in
                            viewModel.search()
                        }

                    if viewModel.isSearching {
                        LoadingView()
                    } else if viewModel.query.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColors.textTertiary)
                            Text(L10n.searchEmptyHint)
                                .font(AppTypography.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.xl)
                        }
                        .frame(maxHeight: .infinity)
                    } else if viewModel.results.isEmpty {
                        ContentUnavailableView.search(text: viewModel.query)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                                ForEach(viewModel.groupedResults, id: \.0) { type, items in
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(type.title)
                                            .font(AppTypography.captionBold)
                                            .foregroundStyle(AppColors.accent)
                                            .padding(.horizontal, AppSpacing.md)

                                        ForEach(items) { result in
                                            searchResultRow(result)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, AppSpacing.sm)
                        }
                    }
                }
            }
            .navigationTitle(L10n.searchTitle)
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
        }
    }

    @ViewBuilder
    private func searchResultRow(_ result: SearchResult) -> some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(name: result.title, colorHex: result.avatarColorHex, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(result.subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if let date = result.date {
                Text(date.chatListFormatted)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }
}
