import Combine
import Foundation

final class TablesViewModel: ObservableObject {
    @Published private(set) var summaries: [TableSummary] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let tableRepository: TableRepository
    private let orderRepository: OrderRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        tableRepository: TableRepository = AppDependencies.shared.tableRepository,
        orderRepository: OrderRepository = AppDependencies.shared.orderRepository
    ) {
        self.tableRepository = tableRepository
        self.orderRepository = orderRepository
        observe()
    }

    private func observe() {
        tableRepository
            .observeSummaries()
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case let .failure(error) = completion {
                    self.errorMessage = "Не удалось прочитать зал: \(error.localizedDescription)"
                }
                self.isLoading = false
            }, receiveValue: { [weak self] summaries in
                guard let self = self else { return }
                self.summaries = summaries
                self.isLoading = false
            })
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Открывает существующий счёт на столе или создаёт новый.
    func openOrder(for table: DiningTable) -> UUID? {
        do {
            return try orderRepository.openOrder(for: table)
        } catch {
            errorMessage = "Не удалось открыть счёт: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Derived

    var freeCount: Int {
        summaries.filter { $0.status == .free }.count
    }

    var occupiedCount: Int {
        summaries.filter { $0.status != .free }.count
    }

    var totalAmount: Double {
        summaries.reduce(0) { $0 + $1.total }
    }

    var zones: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for summary in summaries where !seen.contains(summary.table.zone) {
            seen.insert(summary.table.zone)
            result.append(summary.table.zone)
        }
        return result
    }
}
