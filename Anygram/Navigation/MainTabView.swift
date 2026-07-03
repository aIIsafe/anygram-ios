import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case contacts
    case calls
    case chats
    case settings
    case search

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .contacts: return L10n.tabContacts
        case .calls: return L10n.tabCalls
        case .chats: return L10n.tabChats
        case .settings: return L10n.tabSettings
        case .search: return L10n.tabSearch
        }
    }

    var icon: String {
        switch self {
        case .contacts: return "person.2.fill"
        case .calls: return "phone.fill"
        case .chats: return "message.fill"
        case .settings: return "gearshape.fill"
        case .search: return "magnifyingglass"
        }
    }

    var badge: Int? {
        switch self {
        case .chats: return 12
        case .calls: return 2
        default: return nil
        }
    }
}

/// Telegram-style tab bar with liquid glass bottom panel.
struct MainTabView: View {
    @State private var selectedTab: AppTab = .chats
    @Namespace private var tabAnimation
    let container: DIContainer

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .contacts:
                    ContactsListView(container: container)
                        .transition(.opacity)
                case .calls:
                    CallsListView(container: container)
                        .transition(.opacity)
                case .chats:
                    ChatsListView(container: container)
                        .transition(.opacity)
                case .settings:
                    SettingsRootView(container: container)
                        .transition(.opacity)
                case .search:
                    GlobalSearchView(container: container)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            tabBar
        }
        .telegramBackground()
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(AppAnimation.tab) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                                .foregroundStyle(selectedTab == tab ? AppColors.accent : AppColors.textSecondary)
                                .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                                .animation(AppAnimation.spring, value: selectedTab)

                            if let badge = tab.badge {
                                Text("\(badge)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AppColors.destructive)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }

                        Text(tab.title)
                            .font(AppTypography.tabLabel)
                            .foregroundStyle(selectedTab == tab ? AppColors.accent : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .fill(AppColors.accent.opacity(0.12))
                                .matchedGeometryEffect(id: "tabHighlight", in: tabAnimation)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .glassTabBar()
    }
}
