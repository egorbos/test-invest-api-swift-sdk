import Foundation
import InvestApiSwiftSdk

public struct SandboxTest {
    private let client: SandboxApiClient
    private let fromDate: Date // Текущее время
    private let toDate: Date // Текущее время + 24 часа
    private let testInstrumentUid: String // Uid инструмента для тестов
    
    public init(token: String) throws {
        self.client = try InvestApiClient.sandbox(token, appName: "codes.egorbos.test-invest-api-swift-sdk")
        self.fromDate = Date()
        self.toDate = self.fromDate.addingTimeInterval(60 * 60 * 24)
        self.testInstrumentUid = "e6123145-9665-43e0-8413-cd61b8aa9b13" // SBER
    }
    
    private func printTestResult(_ result: Bool, terminator: String = "\n") -> Void {
        switch result {
        case true: print("\u{2705}", terminator: terminator)
        case false: print("\u{274C}", terminator: terminator)
        }
    }
    
    public func start() throws -> Void {
        // MARK: SandboxService
        
        print("\n⚪ SandboxService")
        
        print("🔘 Тестируем открытие счёта песочницы...", terminator: "")
        let accountId = try client.sendRequest(.openSandboxAccount).wait()
        printTestResult(!accountId.isEmpty)
        print(" - Открыт счёт: \(accountId)")
        
        print("🔘 Тестируем получение счетов песочницы...", terminator: "")
        let sandboxAccounts = try client.sendRequest(.getSandboxAccounts).wait()
        printTestResult(!sandboxAccounts.isEmpty)
        
        print("🔘 Тестируем пополнение счёта песочницы...", terminator: "")
        let balance = try client.sendRequest(.sandboxPayIn(accountId: accountId, amount: .russianRuble(units: 10000))).wait()
        printTestResult(balance.units == 10000)
        
        print("🔘 Тестируем выставление рыночной заявки в песочнице...", terminator: "")
        let marketOrder = try client.sendRequest(
            .postSandboxOrder(
                accountId: accountId, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .buy, price: .zero(), quantity: 1
            )
        ).wait()
        printTestResult(!marketOrder.orderId.isEmpty && marketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(marketOrder.orderId)")
        
        print("🔘 Тестируем получение позиций в песочнице...", terminator: "")
        let positions = try client.sendRequest(.getSandboxPositions(accountId: accountId)).wait()
        printTestResult(positions.money[0].units > 0 && positions.securities.count == 1)
        print(" - Позиции: RUB - \(positions.money[0]), SHARES - \(positions.securities.count)")
        
        print("🔘 Тестируем получение портфеля в песочнице...", terminator: "")
        let portfolio = try client.sendRequest(
            .getSandboxPortfolio(accountId: accountId, currency: .russianRuble)
        ).wait()
        printTestResult(portfolio.accountId == accountId && portfolio.positions.count == 2)
        print(" - Позиции в портфеле: \(portfolio.positions.count)")
        
        print("🔘 Тестируем получение доступных для вывода средств в песочнице...", terminator: "")
        let withdrawLimits = try client.sendRequest(
            .getSandboxWithdrawLimits(accountId: accountId)
        ).wait()
        printTestResult(!withdrawLimits.money.isEmpty && withdrawLimits.money[0] == positions.money[0])
        print(" - Доступные для вывода средства: \(withdrawLimits.money[0])")
        
        print("🔘 Тестируем получение операций в песочнице...", terminator: "")
        let operations = try client.sendRequest(
            .getSandboxOperations(accountId: accountId, from: fromDate, to: toDate, state: .executed, figi: marketOrder.figi)
        ).wait()
        printTestResult(!operations.isEmpty && operations.contains(where: { $0.instrumentType == .share}))
        print(" - Операции: \(operations.count)")
        
        print("🔘 Тестируем получение операций в песочнице с пагинацией...", terminator: "")
        let operationsByCursor = try client.sendRequest(
            .getSandboxOperationsByCursor(
                accountId: accountId, instrumentId: marketOrder.uid, from: fromDate, to: toDate,
                cursor: "", limit: 10, types: [.buy], state: .executed, withCommissions: true,
                withTrades: true, withOvernights: true
            )
        ).wait()
        printTestResult(!operationsByCursor.items.isEmpty && operationsByCursor.items.contains(where: { $0.figi == marketOrder.figi }))
        print(" - Операции: \(operationsByCursor.items.count)")
        
        print("🔘 Тестируем выставление лимитной заявки в песочнице...", terminator: "")
        let limitOrder = try client.sendRequest(
            .postSandboxOrder(
                accountId: accountId, instrumentId: testInstrumentUid, orderRequestId: UUID().uuidString,
                type: .limit, direction: .buy, price: Quotation(units: marketOrder.executedOrderPrice.units - 100, nano: 0), quantity: 1
            )
        ).wait()
        printTestResult(!limitOrder.orderId.isEmpty && limitOrder.status == .new)
        print(" - Заявка выставлена. ID: \(limitOrder.orderId)")
        
        print("🔘 Тестируем изменение лимитной заявки в песочнице...", terminator: "")
        let changedLimitOrder = try client.sendRequest(
            .replaceSandboxOrder(
                accountId: accountId, orderId: limitOrder.orderId, orderRequestId: UUID().uuidString,
                price: Quotation(units: marketOrder.executedOrderPrice.units - 50, nano: 0), priceType: .currency, quantity: 1
            )
        ).wait()
        printTestResult(!changedLimitOrder.orderId.isEmpty && changedLimitOrder.status == .new)
        print(" - Заявка изменена. ID: \(changedLimitOrder.orderId)")
        
        print("🔘 Тестируем получение активных заявок в песочнице...", terminator: "")
        let activeOrders = try client.sendRequest(.getSandboxOrders(accountId: accountId)).wait()
        printTestResult(!activeOrders.isEmpty && activeOrders[0].orderId == changedLimitOrder.orderId)
        print(" - Активных заявок: \(activeOrders.count)")
        
        print("🔘 Тестируем отмену лимитной заявки в песочнице...", terminator: "")
        let cancelLimitOrderDate = try client.sendRequest(
            .cancelSandboxOrder(accountId: accountId, orderId: changedLimitOrder.orderId)
        ).wait()
        printTestResult(true)
        print(" - Заявка отменена. Время: \(cancelLimitOrderDate)")
        
        print("🔘 Тестируем получение статуса заявки в песочнице...", terminator: "")
        let orderState = try client.sendRequest(
            .getSandboxOrderState(accountId: accountId, orderId: changedLimitOrder.orderId)
        ).wait()
        printTestResult(orderState.status == .cancelled)
        
        
        // MARK: UsersService
        
        print("\n⚪ UsersService")
        
        print("🔘 Тестируем получение счетов пользователя...", terminator: "")
        let userAccounts = try client.sendRequest(.getAccounts).wait()
        printTestResult(!userAccounts.isEmpty)
        
        print("🔘 Тестируем получение текущих лимитов запросов пользователя...", terminator: "")
        _ = try client.sendRequest(.getUserTariff).wait()
        printTestResult(true)
        
        print("🔘 Тестируем получение информации о статусе пользователя...", terminator: "")
        _ = try client.sendRequest(.getInfo).wait()
        printTestResult(true)
        
        
        // MARK: SandboxService
        
        print("\n⚪ SandboxService")
        
        print("🔘 Тестируем закрытие счёта песочницы...", terminator: "")
        try client.sendRequest(.closeSandboxAccount(accountId: accountId)).wait()
        printTestResult(true)
        print(" - Закрыт счёт: \(accountId)")
    }
    
    public func startAsync() async throws -> Void {
        // MARK: SandboxService
        
        print("\n⚪ SandboxService")
        
        print("🔘 Тестируем открытие счёта песочницы...", terminator: "")
        let accountId = try await client.sendRequest(.openSandboxAccount)
        printTestResult(!accountId.isEmpty)
        print(" - Открыт счёт: \(accountId)")
        
        print("🔘 Тестируем получение счетов песочницы...", terminator: "")
        let sandboxAccounts = try await client.sendRequest(.getSandboxAccounts)
        printTestResult(!sandboxAccounts.isEmpty)
        
        print("🔘 Тестируем пополнение счёта песочницы...", terminator: "")
        let balance = try await client.sendRequest(.sandboxPayIn(accountId: accountId, amount: .russianRuble(units: 10000)))
        printTestResult(balance.units == 10000)
        
        print("🔘 Тестируем выставление рыночной заявки в песочнице...", terminator: "")
        let marketOrder = try await client.sendRequest(
            .postSandboxOrder(
                accountId: accountId, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .buy, price: .zero(), quantity: 1
            )
        )
        printTestResult(!marketOrder.orderId.isEmpty && marketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(marketOrder.orderId)")
        
        print("🔘 Тестируем получение позиций в песочнице...", terminator: "")
        let positions = try await client.sendRequest(.getSandboxPositions(accountId: accountId))
        printTestResult(positions.money[0].units > 0 && positions.securities.count == 1)
        print(" - Позиции: RUB - \(positions.money[0]), SHARES - \(positions.securities.count)")
        
        print("🔘 Тестируем получение портфеля в песочнице...", terminator: "")
        let portfolio = try await client.sendRequest(
            .getSandboxPortfolio(accountId: accountId, currency: .russianRuble)
        )
        printTestResult(portfolio.accountId == accountId && portfolio.positions.count == 2)
        print(" - Позиции в портфеле: \(portfolio.positions.count)")
        
        print("🔘 Тестируем получение доступных для вывода средств в песочнице...", terminator: "")
        let withdrawLimits = try await client.sendRequest(
            .getSandboxWithdrawLimits(accountId: accountId)
        )
        printTestResult(!withdrawLimits.money.isEmpty && withdrawLimits.money[0] == positions.money[0])
        print(" - Доступные для вывода средства: \(withdrawLimits.money[0])")
        
        print("🔘 Тестируем получение операций в песочнице...", terminator: "")
        let operations = try await client.sendRequest(
            .getSandboxOperations(accountId: accountId, from: fromDate, to: toDate, state: .executed, figi: marketOrder.figi)
        )
        printTestResult(!operations.isEmpty && operations.contains(where: { $0.instrumentType == .share}))
        print(" - Операции: \(operations.count)")
        
        print("🔘 Тестируем получение операций в песочнице с пагинацией...", terminator: "")
        let operationsByCursor = try await client.sendRequest(
            .getSandboxOperationsByCursor(
                accountId: accountId, instrumentId: marketOrder.uid, from: fromDate, to: toDate,
                cursor: "", limit: 10, types: [.buy], state: .executed, withCommissions: true,
                withTrades: true, withOvernights: true
            )
        )
        printTestResult(!operationsByCursor.items.isEmpty && operationsByCursor.items.contains(where: { $0.figi == marketOrder.figi }))
        print(" - Операции: \(operationsByCursor.items.count)")
        
        print("🔘 Тестируем выставление лимитной заявки в песочнице...", terminator: "")
        let limitOrder = try await client.sendRequest(
            .postSandboxOrder(
                accountId: accountId, instrumentId: testInstrumentUid, orderRequestId: UUID().uuidString,
                type: .limit, direction: .buy, price: Quotation(units: marketOrder.executedOrderPrice.units - 100, nano: 0), quantity: 1
            )
        )
        printTestResult(!limitOrder.orderId.isEmpty && limitOrder.status == .new)
        print(" - Заявка выставлена. ID: \(limitOrder.orderId)")
        
        print("🔘 Тестируем изменение лимитной заявки в песочнице...", terminator: "")
        let changedLimitOrder = try await client.sendRequest(
            .replaceSandboxOrder(
                accountId: accountId, orderId: limitOrder.orderId, orderRequestId: UUID().uuidString,
                price: Quotation(units: marketOrder.executedOrderPrice.units - 50, nano: 0), priceType: .currency, quantity: 1
            )
        )
        printTestResult(!changedLimitOrder.orderId.isEmpty && changedLimitOrder.status == .new)
        print(" - Заявка изменена. ID: \(changedLimitOrder.orderId)")
        
        print("🔘 Тестируем получение активных заявок в песочнице...", terminator: "")
        let activeOrders = try await client.sendRequest(.getSandboxOrders(accountId: accountId))
        printTestResult(!activeOrders.isEmpty && activeOrders[0].orderId == changedLimitOrder.orderId)
        print(" - Активных заявок: \(activeOrders.count)")
        
        print("🔘 Тестируем отмену лимитной заявки в песочнице...", terminator: "")
        let cancelLimitOrderDate = try await client.sendRequest(
            .cancelSandboxOrder(accountId: accountId, orderId: changedLimitOrder.orderId)
        )
        printTestResult(true)
        print(" - Заявка отменена. Время: \(cancelLimitOrderDate)")
        
        print("🔘 Тестируем получение статуса заявки в песочнице...", terminator: "")
        let orderState = try await client.sendRequest(
            .getSandboxOrderState(accountId: accountId, orderId: changedLimitOrder.orderId)
        )
        printTestResult(orderState.status == .cancelled)
        
        
        // MARK: UsersService
        
        print("\n⚪ UsersService")
        
        print("🔘 Тестируем получение счетов пользователя...", terminator: "")
        let userAccounts = try await client.sendRequest(.getAccounts)
        printTestResult(!userAccounts.isEmpty)
        
        print("🔘 Тестируем получение текущих лимитов запросов пользователя...", terminator: "")
        _ = try await client.sendRequest(.getUserTariff)
        printTestResult(true)
        
        print("🔘 Тестируем получение информации о статусе пользователя...", terminator: "")
        _ = try await client.sendRequest(.getInfo)
        printTestResult(true)
        
        
        // MARK: SandboxService
        
        print("\n⚪ SandboxService")
        
        print("🔘 Тестируем закрытие счёта песочницы...", terminator: "")
        try await client.sendRequest(.closeSandboxAccount(accountId: accountId))
        printTestResult(true)
        print(" - Закрыт счёт: \(accountId)")
    }
}
