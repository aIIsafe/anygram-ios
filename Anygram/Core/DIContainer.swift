import Combine
import Foundation
import SwiftUI

/// Central dependency injection container for swapping service implementations.
@MainActor
public final class DIContainer: ObservableObject {
    public static let shared = DIContainer()

    public let authService: AuthServiceProtocol
    public let networkService: TelegramNetworkService
    public let chatService: ChatServiceProtocol
    public let userService: UserServiceProtocol
    public let callsService: CallsServiceProtocol
    public let searchService: SearchServiceProtocol
    public let settingsService: SettingsServiceProtocol
    public let mediaService: MediaServiceProtocol
    public let profileService: ProfileServiceProtocol
    public let proxyService: ProxyServiceProtocol
    public let imageCache: ImageCacheProtocol
    public let networkConfigurationProvider: NetworkConfigurationProvider

    public let authRepository: AuthRepository
    public let chatRepository: ChatRepository
    public let userRepository: UserRepository
    public let callsRepository: CallsRepository
    public let searchRepository: SearchRepository
    public let settingsRepository: SettingsRepository
    public let profileRepository: ProfileRepository
    public let proxyRepository: ProxyRepository

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var currentUser: User?

    private var cancellables = Set<AnyCancellable>()

    public init(useMockServices: Bool = true) {
        let imageCache = MemoryImageCache()
        self.imageCache = imageCache

        let proxyService = DefaultProxyService()
        self.proxyService = proxyService
        self.networkConfigurationProvider = NetworkConfigurationProvider(proxyService: proxyService)

        let authService = TDLibAuthService()
        self.authService = authService
        self.networkService = TelegramNetworkService(proxyService: proxyService, authService: authService)
        self.authRepository = AuthRepository(authService: authService, networkService: networkService)

        let chatService = TelegramChatService(networkConfiguration: networkConfigurationProvider)
        self.chatService = chatService

        #if USE_SCAFFOLD_AUTH
        self.userService = MockUserService()
        #elseif targetEnvironment(simulator)
        self.userService = MockUserService()
        #elseif canImport(TDLibKit)
        self.userService = TDLibUserService()
        #else
        self.userService = MockUserService()
        #endif

        self.callsService = TelegramCallsService()
        self.searchService = TelegramSearchService(
            chatService: chatService,
            userService: self.userService
        )
        self.settingsService = MockSettingsService()
        self.mediaService = MockMediaService(cache: imageCache)
        self.profileService = MockProfileService(userService: self.userService)

        self.chatRepository = ChatRepository(chatService: chatService)
        self.userRepository = UserRepository(userService: userService)
        self.callsRepository = CallsRepository(callsService: callsService)
        self.searchRepository = SearchRepository(searchService: searchService)
        self.settingsRepository = SettingsRepository(settingsService: settingsService)
        self.profileRepository = ProfileRepository(profileService: profileService, mediaService: mediaService)
        self.proxyRepository = ProxyRepository(proxyService: proxyService)

        isAuthenticated = authService.isAuthenticated
        authService.authorizationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let authenticated: Bool
                if case .ready = state {
                    authenticated = true
                } else {
                    authenticated = false
                }
                self.isAuthenticated = authenticated
                if authenticated {
                    Task { await self.onAuthenticated() }
                } else {
                    self.currentUser = nil
                }
            }
            .store(in: &cancellables)

        if authService.isAuthenticated {
            Task { await onAuthenticated() }
        }
    }

    private func onAuthenticated() async {
        await loadCurrentUser()
        try? await chatRepository.fetchChats(includeArchived: true)
        try? await userRepository.fetchContacts()
        await searchRepository.reindex()
    }

    public func bootstrap() async {
        AppDebugLogger.shared.log("DIContainer.bootstrap (proxy init)", category: .UI)
        await proxyRepository.initializeOnFirstLaunch()
    }

    public func loadCurrentUser() async {
        currentUser = try? await authRepository.fetchCurrentUser()
    }

    public func logout() async {
        try? await authRepository.logout()
        currentUser = nil
    }
}
