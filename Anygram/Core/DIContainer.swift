import Foundation
import SwiftUI

/// Central dependency injection container for swapping service implementations.
@MainActor
public final class DIContainer: ObservableObject {
    public static let shared = DIContainer()

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

    public let chatRepository: ChatRepository
    public let userRepository: UserRepository
    public let callsRepository: CallsRepository
    public let searchRepository: SearchRepository
    public let settingsRepository: SettingsRepository
    public let profileRepository: ProfileRepository
    public let proxyRepository: ProxyRepository

    public init(useMockServices: Bool = true) {
        let imageCache = MemoryImageCache()
        self.imageCache = imageCache

        let proxyService = DefaultProxyService()
        self.proxyService = proxyService
        self.networkConfigurationProvider = NetworkConfigurationProvider(proxyService: proxyService)

        if useMockServices {
            let chatService = MockChatService()
            let userService = MockUserService()
            self.chatService = chatService
            self.userService = userService
            self.callsService = MockCallsService()
            self.searchService = MockSearchService(chatService: chatService, userService: userService)
            self.settingsService = MockSettingsService()
            self.mediaService = MockMediaService(cache: imageCache)
            self.profileService = MockProfileService(userService: userService)
        } else {
            let chatService = MockChatService()
            let userService = MockUserService()
            self.chatService = chatService
            self.userService = userService
            self.callsService = MockCallsService()
            self.searchService = MockSearchService(chatService: chatService, userService: userService)
            self.settingsService = MockSettingsService()
            self.mediaService = MockMediaService(cache: imageCache)
            self.profileService = MockProfileService(userService: userService)
        }

        self.chatRepository = ChatRepository(chatService: chatService)
        self.userRepository = UserRepository(userService: userService)
        self.callsRepository = CallsRepository(callsService: callsService)
        self.searchRepository = SearchRepository(searchService: searchService)
        self.settingsRepository = SettingsRepository(settingsService: settingsService)
        self.profileRepository = ProfileRepository(profileService: profileService, mediaService: mediaService)
        self.proxyRepository = ProxyRepository(proxyService: proxyService)
    }

    public func bootstrap() async {
        await proxyRepository.initializeOnFirstLaunch()
    }
}
