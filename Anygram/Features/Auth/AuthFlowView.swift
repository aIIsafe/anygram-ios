import SwiftUI

struct AuthFlowView: View {
    @StateObject private var viewModel: AuthViewModel

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authRepository: container.authRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                Group {
                    switch viewModel.step {
                    case .phone, .loading:
                        PhoneInputView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .code:
                        CodeInputView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case .twoFactor:
                        TwoFactorView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(AppAnimation.standard, value: viewModel.step)
            }
            .telegramBackground()
            .navigationDestination(isPresented: $viewModel.showDebugLogs) {
                DebugLogsView()
            }
        }
    }
}
