import Foundation

@MainActor
final class CallsViewModel: ObservableObject {
    @Published var calls: [Call] = []
    @Published var selectedSegment = 0
    @Published var isLoading = false

    private let repository: CallsRepository

    init(repository: CallsRepository) {
        self.repository = repository
    }

    var filter: CallFilter {
        selectedSegment == 0 ? .all : .missed
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        calls = (try? await repository.fetchCalls(filter: filter)) ?? []
    }

    func deleteCall(_ call: Call) async {
        try? await repository.deleteCall(call.id)
        await load()
    }
}
