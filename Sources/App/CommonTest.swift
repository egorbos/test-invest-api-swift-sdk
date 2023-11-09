import Foundation
import InvestApiSwiftSdk

extension FileHandle: TextOutputStream {
  public func write(_ string: String) {
    let data = Data(string.utf8)
    self.write(data)
  }
}

public struct CommonTest {
    private let client: CommonApiClient
    private let fromDate: Date // Текущее время
    private let toDate: Date // Текущее время + 24 часа
    private let testInstrumentUid: String // Uid инструмента для тестов
    
    public init(token: String) throws {
        self.client = try InvestApiClient.common(token, appName: "codes.egorbos.test-invest-api-swift-sdk")
        self.fromDate = Date()
        self.toDate = self.fromDate.addingTimeInterval(60 * 60 * 24)
        self.testInstrumentUid = "e2d0dbac-d354-4c36-a5ed-e5aae42ffc76" // TRUR
    }
    
    private func askUserToContinue(message: String) -> Bool {
        print("\n\(message) (y/n): ", terminator: "")
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              input.count == 1,
              ["y", "n"].contains(input)
        else {
            return askUserToContinue(message: message)
        }
        return input == "y"
    }
    
    private func chooseAccount(accounts: [Account]) -> Account {
        print("\nДля продолжения выберите аккаунт для тестирования.")
        for (index, account) in accounts.enumerated() {
            print("\(index) - \(account.name)")
        }
        
        print("\nВведите номер: ", terminator: "")
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              input.count == 1,
              let choosenIndex = Int(input, radix: 10),
              accounts.endIndex > choosenIndex
        else {
            return chooseAccount(accounts: accounts)
        }
        
        return accounts[choosenIndex]
    }
    
    private func printTestResult(_ result: Bool, terminator: String = "\n") -> Void {
        switch result {
        case true: print("\u{2705}", terminator: terminator)
        case false: print("\u{274C}", terminator: terminator)
        }
    }
    
    public func start() throws {
        // MARK: UsersService
        print("\n⚪ UsersService")
        
        print("🔘 Тестируем получение счетов пользователя...", terminator: "")
        let userAccounts = try client.sendRequest(.getAccounts).wait()
        printTestResult(!userAccounts.isEmpty)
        
        print("🔘 Тестируем получение текущих лимитов запросов пользователя...", terminator: "")
        let userTariff = try client.sendRequest(.getUserTariff).wait()
        printTestResult({
            let methods = userTariff.unaryLimits.flatMap { $0.methods }
            return methods.contains { e in
                e == "tinkoff.public.invest.api.contract.v1.InstrumentsService/BondBy"
            }
        }())
        
        print("🔘 Тестируем получение информации о статусе пользователя...", terminator: "")
        let userInfo = try client.sendRequest(.getInfo).wait()
        printTestResult(userInfo.qualifiedForWorkWith.contains(where: { $0 == "russian_shares" }))
        
        
        // MARK: InstrumentsService
        print("\n⚪ InstrumentsService")
        
        print("🔘 Тестируем получение расписания работы торговых площадок...", terminator: "")
        let tradingSchedules = try client.sendRequest(
            .tradingSchedules(exchange: "moex", from: fromDate, to: toDate)
        ).wait()
        printTestResult(!tradingSchedules.isEmpty && tradingSchedules[0].exchange.uppercased() == "MOEX")
        
        print("🔘 Тестируем получение списка облигаций...", terminator: "")
        let bonds = try client.sendRequest(.bonds(instrumentStatus: .all)).wait()
        printTestResult(!bonds.isEmpty)
        
        guard let bondFromList = bonds.first(where: {
            $0.maturityDate > fromDate && $0.riskLevel == .low && $0.currency == .russianRuble
        }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение облигации по её идентификатору...", terminator: "")
        let bondById = try client.sendRequest(
            .bondBy(idType: .uid, classCode: "", id: bondFromList.uid)
        ).wait()
        printTestResult(bondById.uid == bondFromList.uid)
        
        print("🔘 Тестируем получение графика выплат купонов по облигации...", terminator: "")
        let bondCoupons = try client.sendRequest(
            .getBondCoupons(figi: bondById.figi, from: bondById.placementDate, to: toDate)
        ).wait()
        printTestResult(!bondCoupons.isEmpty && bondCoupons[0].figi == bondById.figi)
        
        print("🔘 Тестируем получение накопленного купонного дохода по облигации...", terminator: "")
        let accruedInterests = try client.sendRequest(
            .getAccruedInterests(figi: bondById.figi, from: bondById.placementDate, to: toDate)
        ).wait()
        printTestResult(!accruedInterests.isEmpty)
        
        print("🔘 Тестируем получение списка валют...", terminator: "")
        let currencies = try client.sendRequest(.currencies(instrumentStatus: .all)).wait()
        printTestResult(!currencies.isEmpty)
        
        guard let currencyFromList = currencies.first(where: { $0.ticker.uppercased() == "CNYRUB_TOM" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение валюты по её идентификатору...", terminator: "")
        let currencyById = try client.sendRequest(
            .currencyBy(idType: .uid, classCode: "", id: currencyFromList.uid)
        ).wait()
        printTestResult(currencyById.uid == currencyFromList.uid)
        
        print("🔘 Тестируем получение списка инвестиционных фондов...", terminator: "")
        let etfs = try client.sendRequest(.etfs(instrumentStatus: .all)).wait()
        printTestResult(!etfs.isEmpty)
        
        guard let etfFromList = etfs.first(where: { $0.ticker.uppercased() == "TRUR" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение инвестиционного фонда по его идентификатору...", terminator: "")
        let etfById = try client.sendRequest(
            .etfBy(idType: .uid, classCode: "", id: etfFromList.uid)
        ).wait()
        printTestResult(etfById.uid == etfFromList.uid)
                
        print("🔘 Тестируем получение списка фьючерсных контрактов...", terminator: "")
        let futures = try client.sendRequest(.futures(instrumentStatus: .all)).wait()
        printTestResult(!futures.isEmpty)
        
        guard let futureFromList = futures.first(where: { $0.ticker.uppercased() == "USDRUBF" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение фьючерсного контракта по его идентификатору...", terminator: "")
        let futureById = try client.sendRequest(
            .futureBy(idType: .uid, classCode: "", id: futureFromList.uid)
        ).wait()
        printTestResult(futureById.uid == futureFromList.uid)
        
        print("🔘 Тестируем получение размера гарантийного обеспечения по фьючерсному контракту...", terminator: "")
        let futureContractMargin = try client.sendRequest(
            .getFutureContractMargin(figi: futureById.figi)
        ).wait()
        printTestResult(futureContractMargin.minPriceIncrement > .zero())
        
        print("🔘 Тестируем получение списка опционных контрактов...", terminator: "")
//        let options = try client.sendRequest(
//            .optionsBy(basicAssetUid: "e6123145-9665-43e0-8413-cd61b8aa9b13" /* SBER */, basicAssetPositionUid: "")
//        ).wait()
        let options = try client.sendRequest(.options(instrumentStatus: .all)).wait()
        printTestResult(!options.isEmpty)
        
        guard let optionFromList = options.first(where: { $0.direction == .call }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение опционного контракта по его идентификатору...", terminator: "")
        let optionById = try client.sendRequest(
            .optionBy(idType: .uid, classCode: "", id: optionFromList.uid)
        ).wait()
        printTestResult(optionById.uid == optionFromList.uid)
        
        print("🔘 Тестируем получение списка акций...", terminator: "")
        let shares = try client.sendRequest(.shares(instrumentStatus: .all)).wait()
        printTestResult(!shares.isEmpty)
        
        guard let shareFromList = shares.first(where: { $0.liquidityFlag && $0.countryOfRisk.lowercased() == "ru" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение акции по её идентификатору...", terminator: "")
        let shareById = try client.sendRequest(
            .shareBy(idType: .uid, classCode: "", id: shareFromList.uid)
        ).wait()
        printTestResult(shareById.uid == shareFromList.uid)
        
        print("🔘 Тестируем получение основной информации об инструменте...", terminator: "")
        let instrumentByTicker = try client.sendRequest(
            .getInstrumentBy(idType: .ticker, classCode: "TQBR", id: "SBER")
        ).wait()
        printTestResult(instrumentByTicker.isin == "RU0009029540")
        
        print("🔘 Тестируем получение событий выплаты дивидендов по инструменту...", terminator: "")
        let dividends = try client.sendRequest(
            .getDividends(figi: instrumentByTicker.figi, from: instrumentByTicker.firstOneDayCandleDate, to: toDate)
        ).wait()
        printTestResult(!dividends.isEmpty)
        
        print("🔘 Тестируем получение актива по его идентификатору...", terminator: "")
        let assetByUid = try client.sendRequest(
            .getAssetBy(uid: "40d89385-a03a-4659-bf4e-d3ecba011782" /* SBER */)
        ).wait()
        printTestResult(assetByUid.type == .security && assetByUid.security!.share!.primaryIndex.lowercased() == "imoex index")
        
        print("🔘 Тестируем получение списка активов...", terminator: "")
        let shareAssets = try client.sendRequest(.getAssets(kind: .share)).wait()
        printTestResult(!shareAssets.isEmpty && shareAssets.contains(where: { $0.uid == assetByUid.uid }))
        
        print("🔘 Тестируем получение избранных инструментов...", terminator: "")
        var favorites = try client.sendRequest(.getFavorites).wait()
        printTestResult(!favorites.contains(where: { $0.figi == "TCS00A105LS2" /* Реиннольц */ }))
        
        print("🔘 Тестируем добавление инструмента в избранное...", terminator: "")
        favorites = try client.sendRequest(.editFavorites(figis: ["TCS00A105LS2"], action: .add)).wait()
        let addInstrumentResult = favorites.contains(where: { $0.figi == "TCS00A105LS2" })
        printTestResult(addInstrumentResult)
        
        print("🔘 Тестируем удаление инструмента из избранного...", terminator: "")
        favorites = try client.sendRequest(.editFavorites(figis: ["TCS00A105LS2"], action: .delete)).wait()
        printTestResult(addInstrumentResult && !favorites.contains(where: { $0.figi == "TCS00A105LS2" }))
        
        print("🔘 Тестируем получение списка стран...", terminator: "")
        let countries = try client.sendRequest(.getCountries).wait()
        printTestResult(countries.contains(where: { $0.alfaTwo.lowercased() == "ru" }))
        
        print("🔘 Тестируем поиск инструмента...", terminator: "")
        let findedInstruments = try client.sendRequest(
            .findInstrument(query: "Сбер Банк", kind: .share, apiTradeAvailableFlag: true)
        ).wait()
        printTestResult(findedInstruments.contains(where: { $0.ticker.lowercased() == "sber" }))
        
        print("🔘 Тестируем получение списка брендов...", terminator: "")
        let brands = try client.sendRequest(.getBrands).wait()
        printTestResult(!brands.isEmpty)
        
        guard let brandFromList = brands.first else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение бренда по его идентификатору...", terminator: "")
        let brandByUid = try client.sendRequest(
            .getBrandBy(uid: brandFromList.uid)
        ).wait()
        printTestResult(brandByUid.uid == brandFromList.uid)
        
        
        // MARK: MarketDataService
        print("\n⚪ MarketDataService")
        
        print("🔘 Тестируем получение исторических свечей по инструменту...", terminator: "")
        let candles = try client.sendRequest(
            .getCandles(figi: shareFromList.figi, from: fromDate.addingTimeInterval(60 * 60 * 24 * -7), to: fromDate, interval: .oneDay)
        ).wait()
        printTestResult(!candles.isEmpty)
        
        print("🔘 Тестируем получение последних цен по инструментам...", terminator: "")
        let lastPrices = try client.sendRequest(.getLastPrices(figis: [shareFromList.figi])).wait()
        printTestResult(!lastPrices.isEmpty && lastPrices[0].uid == shareFromList.uid)
        
        print("🔘 Тестируем получение стакана по инструменту...", terminator: "")
        let orderBook = try client.sendRequest(.getOrderBook(figi: shareFromList.figi, depth: 20)).wait()
        printTestResult(orderBook.figi == shareFromList.figi && orderBook.depth == 20)
        
        print("🔘 Тестируем получение статуса торгов по инструменту...", terminator: "")
        let tradingStatus = try client.sendRequest(.getTradingStatus(figi: shareFromList.figi)).wait()
        printTestResult(tradingStatus.figi == shareFromList.figi)
        
        print("🔘 Тестируем получение обезличенных сделок за последний час...", terminator: "")
        let lastTrades = try client.sendRequest(
            .getLastTrades(figi: shareFromList.figi, from: fromDate.addingTimeInterval(60 * 60 * -1), to: fromDate)
        ).wait()
        printTestResult(!lastTrades.isEmpty)
        
        print("🔘 Тестируем получение цены закрытия торговой сессии по инструменту...", terminator: "")
        let closePrices = try client.sendRequest(.getClosePrices(figis: [shareFromList.figi])).wait()
        printTestResult(!closePrices.isEmpty && closePrices[0].figi == shareFromList.figi)
        
        // MARK: Ask user to continue
        if !askUserToContinue(message: "Продолжить тестирование сервисов (Операций, Торговых поручений, Стоп-ордеров)?") {
            return
        }
        
        let filteredAccounts = userAccounts.filter {
            $0.status == .open && $0.type == .tinkoff && $0.accessLevel == .fullAccess
        }
        if filteredAccounts.isEmpty {
            throw TestError(message: "Отсутствует активный брокерский счёт, необходимый для тестирования.")
        }
        
        let choosenAccount = chooseAccount(accounts: filteredAccounts)
        print("Выбран аккаунт: \(choosenAccount.name)")
        
        // MARK: OperationsService
        print("\n⚪ OperationsService")
        
        print("🔘 Тестируем получение списка операций по счёту...", terminator: "")
        let operations = try client.sendRequest(
            .getOperations(accountId: choosenAccount.id, from: choosenAccount.openedDate, to: fromDate, state: .executed, figi: "")
        ).wait()
        printTestResult(!operations.isEmpty)
        
        print("🔘 Тестируем получение портфеля по счёту...", terminator: "")
        let portfolio = try client.sendRequest(
            .getPortfolio(accountId: choosenAccount.id, currency: .russianRuble)
        ).wait()
        printTestResult(portfolio.accountId == choosenAccount.id)
        
        print("🔘 Тестируем получение списка позиций по счёту...", terminator: "")
        let positions = try client.sendRequest(
            .getPositions(accountId: choosenAccount.id)
        ).wait()
        let hasRussianRubles = positions.money.contains(where: { $0.currency == .russianRuble && $0.units > 20 })
        printTestResult(hasRussianRubles)
        
        print("🔘 Тестируем получение доступного остатка для вывода средств...", terminator: "")
        let withdrawLimits = try client.sendRequest(
            .getWithdrawLimits(accountId: choosenAccount.id)
        ).wait()
        printTestResult(!withdrawLimits.money.isEmpty)
        
        
        let userDefaults = UserDefaults.standard
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(abbreviation: "UTC")!
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        
        let brokerReportFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: dateComponents.month! - 1, day: 1)
        )!
        
        let range = calendar.range(of: .day, in: .month, for: brokerReportFromDate)!
        
        let brokerReportToDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: dateComponents.month! - 1, day: range.count,
                      hour: 23, minute: 59, second: 59)
        )!
        
        print("🔘 Тестируем отправку запроса на формирование брокерского отчёта...", terminator: "")
        let brokerReportTaskIdKey = "\(choosenAccount.id)[\(brokerReportFromDate)-\(brokerReportToDate)]"
        let brokerReportTaskIdExists = userDefaults.dictionaryRepresentation().keys.contains(where: { $0 == brokerReportTaskIdKey } )
        let brokerReportTaskId = brokerReportTaskIdExists ? userDefaults.string(forKey: brokerReportTaskIdKey)! : try client.sendRequest(
            .generateBrokerReport(accountId: choosenAccount.id, from: brokerReportFromDate, to: brokerReportToDate)
        ).wait()
        printTestResult(!brokerReportTaskId.isEmpty)
        
        if (!brokerReportTaskIdExists && !brokerReportTaskId.isEmpty) {
            userDefaults.setValue(brokerReportTaskId, forKey: brokerReportTaskIdKey)
        }
        
        if (!brokerReportTaskId.isEmpty) {
            print(" - ID запроса: \(brokerReportTaskId)")
            
            var standardOutput = FileHandle.standardOutput
            
            print("🔘 Тестируем получение брокерского отчёта", terminator: "", to: &standardOutput)
            for tick in 1...5 {
                sleep(1)
                print("...\(tick)", terminator: "", to: &standardOutput)
            }
            
            let brokerReport = try client.sendRequest(
                .getBrokerReport(taskId: brokerReportTaskId, page: 0)
            ).wait()
            printTestResult(brokerReport.page == 0)
        }
        
        
        let divForeignReportFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year! - 1, month: 1, day: 1)
        )!
        
        let divForeignReportToDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year! - 1, month: 12, day: 31,
                      hour: 23, minute: 59, second: 59)
        )!
        
        print("🔘 Тестируем отправку запроса на формирование отчёта отчёта \"Справка о доходах за пределами РФ\"...", terminator: "")
        let divForeignReportTaskIdKey = "\(choosenAccount.id)[\(divForeignReportFromDate)-\(divForeignReportToDate)]"
        let divForeignReportTaskIdExists = userDefaults.dictionaryRepresentation().keys.contains(where: { $0 == divForeignReportTaskIdKey } )
        let divForeignReportTaskId = divForeignReportTaskIdExists ? userDefaults.string(forKey: divForeignReportTaskIdKey)! : try client.sendRequest(
            .generateDivForeignIssuerReport(accountId: choosenAccount.id, from: divForeignReportFromDate, to: divForeignReportToDate)
        ).wait()
        printTestResult(!divForeignReportTaskId.isEmpty)
        
        if (!divForeignReportTaskIdExists && !divForeignReportTaskId.isEmpty) {
            userDefaults.setValue(divForeignReportTaskId, forKey: divForeignReportTaskIdKey)
        }
        
        if (!divForeignReportTaskId.isEmpty) {
            print(" - ID запроса: \(divForeignReportTaskId)")
            
            var standardOutput = FileHandle.standardOutput
            
            print("🔘 Тестируем получение отчёта \"Справка о доходах за пределами РФ\"", terminator: "", to: &standardOutput)
            for tick in 1...5 {
                sleep(1)
                print("...\(tick)", terminator: "", to: &standardOutput)
            }
            
            let divForeignReport = try client.sendRequest(
                .getDivForeignIssuerReport(taskId: divForeignReportTaskId, page: 0)
            ).wait()
            printTestResult(divForeignReport.page == 0)
        }
        
        
        let operationsByCursorFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: 1, day: 1)
        )!
        
        print("🔘 Тестируем получение списка операций по счёту с пагинацией...", terminator: "")
        let operationsByCursor = try client.sendRequest(
            .getOperationsByCursor(
                accountId: choosenAccount.id, instrumentId: "", from: operationsByCursorFromDate, to: fromDate,
                cursor: "", limit: 1, types: [.buy], state: .executed, withCommissions: true, withTrades: true, withOvernights: true
            )
        ).wait()
        printTestResult(!operationsByCursor.items.isEmpty)
        
        
        // MARK: OrdersService
        print("\n⚪ OrdersService")
        
        print("🔘 Тестируем выставление рыночной заявки (покупка)...", terminator: "")
        let marketOrder = try client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .buy, price: .zero(), quantity: 1
            )
        ).wait()
        printTestResult(!marketOrder.orderId.isEmpty && marketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(marketOrder.orderId)")
        
        print("🔘 Тестируем выставление заявки \"Лучшая цена\" (покупка)...", terminator: "")
        let bestPriceOrder = try client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .bestPrice, direction: .buy, price: .zero(), quantity: 1
            )
        ).wait()
        printTestResult(!bestPriceOrder.orderId.isEmpty && bestPriceOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(bestPriceOrder.orderId)")
        
        print("🔘 Тестируем выставление лимитной заявки...", terminator: "")
        let limitOrderPrice = marketOrder.executedOrderPrice.toQuotation()
            .decreaseBy(percentage: 5, priceStep: 0.01)
        let limitOrder = try client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .limit, direction: .buy, price: limitOrderPrice, quantity: 1
            )
        ).wait()
        printTestResult(!limitOrder.orderId.isEmpty && limitOrder.status == .new)
        print(" - Заявка выставлена. ID: \(limitOrder.orderId)")
        
        print("🔘 Тестируем изменение лимитной заявки...", terminator: "")
        let changedLimitOrderPrice = marketOrder.executedOrderPrice.toQuotation()
            .decreaseBy(percentage: 7, priceStep: 0.01)
        let changedLimitOrder = try client.sendRequest(
            .replaceOrder(
                accountId: choosenAccount.id, orderId: limitOrder.orderId, orderRequestId: UUID().uuidString,
                price: changedLimitOrderPrice, priceType: .currency, quantity: 1
            )
        ).wait()
        printTestResult(!changedLimitOrder.orderId.isEmpty && changedLimitOrder.status == .new)
        print(" - Заявка изменена. ID: \(changedLimitOrder.orderId)")
        
        print("🔘 Тестируем получение активных заявок по счёту...", terminator: "")
        let activeOrders = try client.sendRequest(
            .getOrders(accountId: choosenAccount.id)
        ).wait()
        printTestResult(!activeOrders.isEmpty && activeOrders.contains(where: { $0.orderId == changedLimitOrder.orderId }))
        
        print("🔘 Тестируем отмену лимитной заявки...", terminator: "")
        let cancelLimitOrderDate = try client.sendRequest(
            .cancelOrder(accountId: choosenAccount.id, orderId: changedLimitOrder.orderId)
        ).wait()
        printTestResult(cancelLimitOrderDate > fromDate)
        print(" - Заявка отменена. Время: \(cancelLimitOrderDate)")
        
        print("🔘 Тестируем получение статуса заявки...", terminator: "")
        let orderState = try client.sendRequest(
            .getOrderState(accountId: choosenAccount.id, orderId: changedLimitOrder.orderId)
        ).wait()
        printTestResult(orderState.status == .cancelled)
        
        
        // MARK: StopOrdersService
        print("\n⚪ StopOrdersService")
        
        print("🔘 Тестируем выставление стоп-заявки...", terminator: "")
        let stopOrderId = try client.sendRequest(
            .postStopOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid,
                quantity: 2, price: .zero(), stopPrice: .init(decimalValue: 5.5), direction: .sell,
                stopOrderType: .stopLoss, expirationType: .goodTillCancel, expireDate: nil
            )
        ).wait()
        printTestResult(!stopOrderId.isEmpty)
        print(" - Стоп-заявка выставлена. ID: \(stopOrderId)")
        
        print("🔘 Тестируем получение активных стоп-заявок по счёту...", terminator: "")
        let stopOrders = try client.sendRequest(
            .getStopOrders(accountId: choosenAccount.id)
        ).wait()
        printTestResult(!stopOrders.isEmpty && stopOrders.contains(where: { $0.stopOrderId == stopOrderId }))
        
        print("🔘 Тестируем отмену лимитной заявки...", terminator: "")
        let cancelStopOrderDate = try client.sendRequest(
            .cancelStopOrder(accountId: choosenAccount.id, stopOrderId: stopOrderId)
        ).wait()
        printTestResult(cancelStopOrderDate > fromDate)
        print(" - Стоп-заявка отменена. Время: \(cancelStopOrderDate)")
        
        
        // MARK: OrdersService
        print("\n⚪ OrdersService")
        
        print("🔘 Тестируем выставление рыночной заявки (продажа)...", terminator: "")
        let sellMarketOrder = try client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .sell, price: .zero(), quantity: 2
            )
        ).wait()
        printTestResult(!sellMarketOrder.orderId.isEmpty && sellMarketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(sellMarketOrder.orderId)")
    }
    
    public func startAsync() async throws {
        // MARK: UsersService
        print("\n⚪ UsersService")
        
        print("🔘 Тестируем получение счетов пользователя...", terminator: "")
        let userAccounts = try await client.sendRequest(.getAccounts)
        printTestResult(!userAccounts.isEmpty)
        
        print("🔘 Тестируем получение текущих лимитов запросов пользователя...", terminator: "")
        let userTariff = try await client.sendRequest(.getUserTariff)
        printTestResult({
            let methods = userTariff.unaryLimits.flatMap { $0.methods }
            return methods.contains { e in
                e == "tinkoff.public.invest.api.contract.v1.InstrumentsService/BondBy"
            }
        }())
        
        print("🔘 Тестируем получение информации о статусе пользователя...", terminator: "")
        let userInfo = try await client.sendRequest(.getInfo)
        printTestResult(userInfo.qualifiedForWorkWith.contains(where: { $0 == "russian_shares" }))
        
        
        // MARK: InstrumentsService
        print("\n⚪ InstrumentsService")
        
        print("🔘 Тестируем получение расписания работы торговых площадок...", terminator: "")
        let tradingSchedules = try await client.sendRequest(
            .tradingSchedules(exchange: "moex", from: fromDate, to: toDate)
        )
        printTestResult(!tradingSchedules.isEmpty && tradingSchedules[0].exchange.uppercased() == "MOEX")
        
        print("🔘 Тестируем получение списка облигаций...", terminator: "")
        let bonds = try await client.sendRequest(.bonds(instrumentStatus: .all))
        printTestResult(!bonds.isEmpty)
        
        guard let bondFromList = bonds.first(where: {
            $0.maturityDate > fromDate && $0.riskLevel == .low && $0.currency == .russianRuble
        }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение облигации по её идентификатору...", terminator: "")
        let bondById = try await client.sendRequest(
            .bondBy(idType: .uid, classCode: "", id: bondFromList.uid)
        )
        printTestResult(bondById.uid == bondFromList.uid)
        
        print("🔘 Тестируем получение графика выплат купонов по облигации...", terminator: "")
        let bondCoupons = try await client.sendRequest(
            .getBondCoupons(figi: bondById.figi, from: bondById.placementDate, to: toDate)
        )
        printTestResult(!bondCoupons.isEmpty && bondCoupons[0].figi == bondById.figi)
        
        print("🔘 Тестируем получение накопленного купонного дохода по облигации...", terminator: "")
        let accruedInterests = try await client.sendRequest(
            .getAccruedInterests(figi: bondById.figi, from: bondById.placementDate, to: toDate)
        )
        printTestResult(!accruedInterests.isEmpty)
        
        print("🔘 Тестируем получение списка валют...", terminator: "")
        let currencies = try await client.sendRequest(.currencies(instrumentStatus: .all))
        printTestResult(!currencies.isEmpty)
        
        guard let currencyFromList = currencies.first(where: { $0.ticker.uppercased() == "CNYRUB_TOM" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение валюты по её идентификатору...", terminator: "")
        let currencyById = try await client.sendRequest(
            .currencyBy(idType: .uid, classCode: "", id: currencyFromList.uid)
        )
        printTestResult(currencyById.uid == currencyFromList.uid)
        
        print("🔘 Тестируем получение списка инвестиционных фондов...", terminator: "")
        let etfs = try await client.sendRequest(.etfs(instrumentStatus: .all))
        printTestResult(!etfs.isEmpty)
        
        guard let etfFromList = etfs.first(where: { $0.ticker.uppercased() == "TRUR" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение инвестиционного фонда по его идентификатору...", terminator: "")
        let etfById = try await client.sendRequest(
            .etfBy(idType: .uid, classCode: "", id: etfFromList.uid)
        )
        printTestResult(etfById.uid == etfFromList.uid)
                
        print("🔘 Тестируем получение списка фьючерсных контрактов...", terminator: "")
        let futures = try await client.sendRequest(.futures(instrumentStatus: .all))
        printTestResult(!futures.isEmpty)
        
        guard let futureFromList = futures.first(where: { $0.ticker.uppercased() == "USDRUBF" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение фьючерсного контракта по его идентификатору...", terminator: "")
        let futureById = try await client.sendRequest(
            .futureBy(idType: .uid, classCode: "", id: futureFromList.uid)
        )
        printTestResult(futureById.uid == futureFromList.uid)
        
        print("🔘 Тестируем получение размера гарантийного обеспечения по фьючерсному контракту...", terminator: "")
        let futureContractMargin = try await client.sendRequest(
            .getFutureContractMargin(figi: futureById.figi)
        )
        printTestResult(futureContractMargin.minPriceIncrement > .zero())
        
        print("🔘 Тестируем получение списка опционных контрактов...", terminator: "")
//        let options = try await client.sendRequest(
//            .optionsBy(basicAssetUid: "e6123145-9665-43e0-8413-cd61b8aa9b13" /* SBER */, basicAssetPositionUid: "")
//        )
        let options = try await client.sendRequest(.options(instrumentStatus: .all))
        printTestResult(!options.isEmpty)
        
        guard let optionFromList = options.first(where: { $0.direction == .call }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение опционного контракта по его идентификатору...", terminator: "")
        let optionById = try await client.sendRequest(
            .optionBy(idType: .uid, classCode: "", id: optionFromList.uid)
        )
        printTestResult(optionById.uid == optionFromList.uid)
        
        print("🔘 Тестируем получение списка акций...", terminator: "")
        let shares = try await client.sendRequest(.shares(instrumentStatus: .all))
        printTestResult(!shares.isEmpty)
        
        guard let shareFromList = shares.first(where: { $0.liquidityFlag && $0.countryOfRisk.lowercased() == "ru" }) else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение акции по её идентификатору...", terminator: "")
        let shareById = try await client.sendRequest(
            .shareBy(idType: .uid, classCode: "", id: shareFromList.uid)
        )
        printTestResult(shareById.uid == shareFromList.uid)
        
        print("🔘 Тестируем получение основной информации об инструменте...", terminator: "")
        let instrumentByTicker = try await client.sendRequest(
            .getInstrumentBy(idType: .ticker, classCode: "TQBR", id: "SBER")
        )
        printTestResult(instrumentByTicker.isin == "RU0009029540")
        
        print("🔘 Тестируем получение событий выплаты дивидендов по инструменту...", terminator: "")
        let dividends = try await client.sendRequest(
            .getDividends(figi: instrumentByTicker.figi, from: instrumentByTicker.firstOneDayCandleDate, to: toDate)
        )
        printTestResult(!dividends.isEmpty)
        
        print("🔘 Тестируем получение актива по его идентификатору...", terminator: "")
        let assetByUid = try await client.sendRequest(
            .getAssetBy(uid: "40d89385-a03a-4659-bf4e-d3ecba011782" /* SBER */)
        )
        printTestResult(assetByUid.type == .security && assetByUid.security!.share!.primaryIndex.lowercased() == "imoex index")
        
        print("🔘 Тестируем получение списка активов...", terminator: "")
        let shareAssets = try await client.sendRequest(.getAssets(kind: .share))
        printTestResult(!shareAssets.isEmpty && shareAssets.contains(where: { $0.uid == assetByUid.uid }))
        
        print("🔘 Тестируем получение избранных инструментов...", terminator: "")
        var favorites = try await client.sendRequest(.getFavorites)
        printTestResult(!favorites.contains(where: { $0.figi == "TCS00A105LS2" /* Реиннольц */ }))
        
        print("🔘 Тестируем добавление инструмента в избранное...", terminator: "")
        favorites = try await client.sendRequest(.editFavorites(figis: ["TCS00A105LS2"], action: .add))
        let addInstrumentResult = favorites.contains(where: { $0.figi == "TCS00A105LS2" })
        printTestResult(addInstrumentResult)
        
        print("🔘 Тестируем удаление инструмента из избранного...", terminator: "")
        favorites = try await client.sendRequest(.editFavorites(figis: ["TCS00A105LS2"], action: .delete))
        printTestResult(addInstrumentResult && !favorites.contains(where: { $0.figi == "TCS00A105LS2" }))
        
        print("🔘 Тестируем получение списка стран...", terminator: "")
        let countries = try await client.sendRequest(.getCountries)
        printTestResult(countries.contains(where: { $0.alfaTwo.lowercased() == "ru" }))
        
        print("🔘 Тестируем поиск инструмента...", terminator: "")
        let findedInstruments = try await client.sendRequest(
            .findInstrument(query: "Сбер Банк", kind: .share, apiTradeAvailableFlag: true)
        )
        printTestResult(findedInstruments.contains(where: { $0.ticker.lowercased() == "sber" }))
        
        print("🔘 Тестируем получение списка брендов...", terminator: "")
        let brands = try await client.sendRequest(.getBrands)
        printTestResult(!brands.isEmpty)
        
        guard let brandFromList = brands.first else {
            throw TestError(message: "Function: \(#function), line: \(#line)")
        }
        
        print("🔘 Тестируем получение бренда по его идентификатору...", terminator: "")
        let brandByUid = try await client.sendRequest(
            .getBrandBy(uid: brandFromList.uid)
        )
        printTestResult(brandByUid.uid == brandFromList.uid)
        
        
        // MARK: MarketDataService
        print("\n⚪ MarketDataService")
        
        print("🔘 Тестируем получение исторических свечей по инструменту...", terminator: "")
        let candles = try await client.sendRequest(
            .getCandles(figi: shareFromList.figi, from: fromDate.addingTimeInterval(60 * 60 * 24 * -7), to: fromDate, interval: .oneDay)
        )
        printTestResult(!candles.isEmpty)
        
        print("🔘 Тестируем получение последних цен по инструментам...", terminator: "")
        let lastPrices = try await client.sendRequest(.getLastPrices(figis: [shareFromList.figi]))
        printTestResult(!lastPrices.isEmpty && lastPrices[0].uid == shareFromList.uid)
        
        print("🔘 Тестируем получение стакана по инструменту...", terminator: "")
        let orderBook = try await client.sendRequest(.getOrderBook(figi: shareFromList.figi, depth: 20))
        printTestResult(orderBook.figi == shareFromList.figi && orderBook.depth == 20)
        
        print("🔘 Тестируем получение статуса торгов по инструменту...", terminator: "")
        let tradingStatus = try await client.sendRequest(.getTradingStatus(figi: shareFromList.figi))
        printTestResult(tradingStatus.figi == shareFromList.figi)
        
        print("🔘 Тестируем получение обезличенных сделок за последний час...", terminator: "")
        let lastTrades = try await client.sendRequest(
            .getLastTrades(figi: shareFromList.figi, from: fromDate.addingTimeInterval(60 * 60 * -1), to: fromDate)
        )
        printTestResult(!lastTrades.isEmpty)
        
        print("🔘 Тестируем получение цены закрытия торговой сессии по инструменту...", terminator: "")
        let closePrices = try await client.sendRequest(.getClosePrices(figis: [shareFromList.figi]))
        printTestResult(!closePrices.isEmpty && closePrices[0].figi == shareFromList.figi)
        
        // MARK: Ask user to continue
        if !askUserToContinue(message: "Продолжить тестирование сервисов (Операций, Торговых поручений, Стоп-ордеров)?") {
            return
        }
        
        let filteredAccounts = userAccounts.filter {
            $0.status == .open && $0.type == .tinkoff && $0.accessLevel == .fullAccess
        }
        if filteredAccounts.isEmpty {
            throw TestError(message: "Отсутствует активный брокерский счёт, необходимый для тестирования.")
        }
        
        let choosenAccount = chooseAccount(accounts: filteredAccounts)
        print("Выбран аккаунт: \(choosenAccount.name)")
        
        // MARK: OperationsService
        print("\n⚪ OperationsService")
        
        print("🔘 Тестируем получение списка операций по счёту...", terminator: "")
        let operations = try await client.sendRequest(
            .getOperations(accountId: choosenAccount.id, from: choosenAccount.openedDate, to: fromDate, state: .executed, figi: "")
        )
        printTestResult(!operations.isEmpty)
        
        print("🔘 Тестируем получение портфеля по счёту...", terminator: "")
        let portfolio = try await client.sendRequest(
            .getPortfolio(accountId: choosenAccount.id, currency: .russianRuble)
        )
        printTestResult(portfolio.accountId == choosenAccount.id)
        
        print("🔘 Тестируем получение списка позиций по счёту...", terminator: "")
        let positions = try await client.sendRequest(
            .getPositions(accountId: choosenAccount.id)
        )
        let hasRussianRubles = positions.money.contains(where: { $0.currency == .russianRuble && $0.units > 20 })
        printTestResult(hasRussianRubles)
        
        print("🔘 Тестируем получение доступного остатка для вывода средств...", terminator: "")
        let withdrawLimits = try await client.sendRequest(
            .getWithdrawLimits(accountId: choosenAccount.id)
        )
        printTestResult(!withdrawLimits.money.isEmpty)
        
        
        let userDefaults = UserDefaults.standard
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(abbreviation: "UTC")!
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        
        let brokerReportFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: dateComponents.month! - 1, day: 1)
        )!
        
        let range = calendar.range(of: .day, in: .month, for: brokerReportFromDate)!
        
        let brokerReportToDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: dateComponents.month! - 1, day: range.count,
                      hour: 23, minute: 59, second: 59)
        )!
        
        print("🔘 Тестируем отправку запроса на формирование брокерского отчёта...", terminator: "")
        let brokerReportTaskIdKey = "\(choosenAccount.id)[\(brokerReportFromDate)-\(brokerReportToDate)]"
        let brokerReportTaskIdExists = userDefaults.dictionaryRepresentation().keys.contains(where: { $0 == brokerReportTaskIdKey } )
        let brokerReportTaskId = brokerReportTaskIdExists ? userDefaults.string(forKey: brokerReportTaskIdKey)! : try await client.sendRequest(
            .generateBrokerReport(accountId: choosenAccount.id, from: brokerReportFromDate, to: brokerReportToDate)
        )
        printTestResult(!brokerReportTaskId.isEmpty)
        
        if (!brokerReportTaskIdExists && !brokerReportTaskId.isEmpty) {
            userDefaults.setValue(brokerReportTaskId, forKey: brokerReportTaskIdKey)
        }
        
        if (!brokerReportTaskId.isEmpty) {
            print(" - ID запроса: \(brokerReportTaskId)")
            
            var standardOutput = FileHandle.standardOutput
            
            print("🔘 Тестируем получение брокерского отчёта", terminator: "", to: &standardOutput)
            for tick in 1...5 {
                sleep(1)
                print("...\(tick)", terminator: "", to: &standardOutput)
            }
            
            let brokerReport = try await client.sendRequest(
                .getBrokerReport(taskId: brokerReportTaskId, page: 0)
            )
            printTestResult(brokerReport.page == 0)
        }
        
        
        let divForeignReportFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year! - 1, month: 1, day: 1)
        )!
        
        let divForeignReportToDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year! - 1, month: 12, day: 31,
                      hour: 23, minute: 59, second: 59)
        )!
        
        print("🔘 Тестируем отправку запроса на формирование отчёта отчёта \"Справка о доходах за пределами РФ\"...", terminator: "")
        let divForeignReportTaskIdKey = "\(choosenAccount.id)[\(divForeignReportFromDate)-\(divForeignReportToDate)]"
        let divForeignReportTaskIdExists = userDefaults.dictionaryRepresentation().keys.contains(where: { $0 == divForeignReportTaskIdKey } )
        let divForeignReportTaskId = divForeignReportTaskIdExists ? userDefaults.string(forKey: divForeignReportTaskIdKey)! : try await client.sendRequest(
            .generateDivForeignIssuerReport(accountId: choosenAccount.id, from: divForeignReportFromDate, to: divForeignReportToDate)
        )
        printTestResult(!divForeignReportTaskId.isEmpty)
        
        if (!divForeignReportTaskIdExists && !divForeignReportTaskId.isEmpty) {
            userDefaults.setValue(divForeignReportTaskId, forKey: divForeignReportTaskIdKey)
        }
        
        if (!divForeignReportTaskId.isEmpty) {
            print(" - ID запроса: \(divForeignReportTaskId)")
            
            var standardOutput = FileHandle.standardOutput
            
            print("🔘 Тестируем получение отчёта \"Справка о доходах за пределами РФ\"", terminator: "", to: &standardOutput)
            for tick in 1...5 {
                sleep(1)
                print("...\(tick)", terminator: "", to: &standardOutput)
            }
            
            let divForeignReport = try await client.sendRequest(
                .getDivForeignIssuerReport(taskId: divForeignReportTaskId, page: 0)
            )
            printTestResult(divForeignReport.page == 0)
        }
        
        
        let operationsByCursorFromDate = calendar.date(from:
                .init(calendar: calendar, timeZone: calendar.timeZone,
                      year: dateComponents.year!, month: 1, day: 1)
        )!
        
        print("🔘 Тестируем получение списка операций по счёту с пагинацией...", terminator: "")
        let operationsByCursor = try await client.sendRequest(
            .getOperationsByCursor(
                accountId: choosenAccount.id, instrumentId: "", from: operationsByCursorFromDate, to: fromDate,
                cursor: "", limit: 1, types: [.buy], state: .executed, withCommissions: true, withTrades: true, withOvernights: true
            )
        )
        printTestResult(!operationsByCursor.items.isEmpty)
        
        
        // MARK: OrdersService
        print("\n⚪ OrdersService")
        
        print("🔘 Тестируем выставление рыночной заявки (покупка)...", terminator: "")
        let marketOrder = try await client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .buy, price: .zero(), quantity: 1
            )
        )
        printTestResult(!marketOrder.orderId.isEmpty && marketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(marketOrder.orderId)")
        
        print("🔘 Тестируем выставление заявки \"Лучшая цена\" (покупка)...", terminator: "")
        let bestPriceOrder = try await client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .bestPrice, direction: .buy, price: .zero(), quantity: 1
            )
        )
        printTestResult(!bestPriceOrder.orderId.isEmpty && bestPriceOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(bestPriceOrder.orderId)")
        
        print("🔘 Тестируем выставление лимитной заявки...", terminator: "")
        let limitOrderPrice = marketOrder.executedOrderPrice.toQuotation()
            .decreaseBy(percentage: 5, priceStep: 0.01)
        let limitOrder = try await client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .limit, direction: .buy, price: limitOrderPrice, quantity: 1
            )
        )
        printTestResult(!limitOrder.orderId.isEmpty && limitOrder.status == .new)
        print(" - Заявка выставлена. ID: \(limitOrder.orderId)")
        
        print("🔘 Тестируем изменение лимитной заявки...", terminator: "")
        let changedLimitOrderPrice = marketOrder.executedOrderPrice.toQuotation()
            .decreaseBy(percentage: 7, priceStep: 0.01)
        let changedLimitOrder = try await client.sendRequest(
            .replaceOrder(
                accountId: choosenAccount.id, orderId: limitOrder.orderId, orderRequestId: UUID().uuidString,
                price: changedLimitOrderPrice, priceType: .currency, quantity: 1
            )
        )
        printTestResult(!changedLimitOrder.orderId.isEmpty && changedLimitOrder.status == .new)
        print(" - Заявка изменена. ID: \(changedLimitOrder.orderId)")
        
        print("🔘 Тестируем получение активных заявок по счёту...", terminator: "")
        let activeOrders = try await client.sendRequest(
            .getOrders(accountId: choosenAccount.id)
        )
        printTestResult(!activeOrders.isEmpty && activeOrders.contains(where: { $0.orderId == changedLimitOrder.orderId }))
        
        print("🔘 Тестируем отмену лимитной заявки...", terminator: "")
        let cancelLimitOrderDate = try await client.sendRequest(
            .cancelOrder(accountId: choosenAccount.id, orderId: changedLimitOrder.orderId)
        )
        printTestResult(cancelLimitOrderDate > fromDate)
        print(" - Заявка отменена. Время: \(cancelLimitOrderDate)")
        
        print("🔘 Тестируем получение статуса заявки...", terminator: "")
        let orderState = try await client.sendRequest(
            .getOrderState(accountId: choosenAccount.id, orderId: changedLimitOrder.orderId)
        )
        printTestResult(orderState.status == .cancelled)
        
        
        // MARK: StopOrdersService
        print("\n⚪ StopOrdersService")
        
        print("🔘 Тестируем выставление стоп-заявки...", terminator: "")
        let stopOrderId = try await client.sendRequest(
            .postStopOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid,
                quantity: 2, price: .zero(), stopPrice: .init(decimalValue: 5.5), direction: .sell,
                stopOrderType: .stopLoss, expirationType: .goodTillCancel, expireDate: nil
            )
        )
        printTestResult(!stopOrderId.isEmpty)
        print(" - Стоп-заявка выставлена. ID: \(stopOrderId)")
        
        print("🔘 Тестируем получение активных стоп-заявок по счёту...", terminator: "")
        let stopOrders = try await client.sendRequest(
            .getStopOrders(accountId: choosenAccount.id)
        )
        printTestResult(!stopOrders.isEmpty && stopOrders.contains(where: { $0.stopOrderId == stopOrderId }))
        
        print("🔘 Тестируем отмену лимитной заявки...", terminator: "")
        let cancelStopOrderDate = try await client.sendRequest(
            .cancelStopOrder(accountId: choosenAccount.id, stopOrderId: stopOrderId)
        )
        printTestResult(cancelStopOrderDate > fromDate)
        print(" - Стоп-заявка отменена. Время: \(cancelStopOrderDate)")
        
        
        // MARK: OrdersService
        print("\n⚪ OrdersService")
        
        print("🔘 Тестируем выставление рыночной заявки (продажа)...", terminator: "")
        let sellMarketOrder = try await client.sendRequest(
            .postOrder(
                accountId: choosenAccount.id, instrumentId: testInstrumentUid, orderRequestId: nil,
                type: .market, direction: .sell, price: .zero(), quantity: 2
            )
        )
        printTestResult(!sellMarketOrder.orderId.isEmpty && sellMarketOrder.status == .fill)
        print(" - Заявка исполнена. ID: \(sellMarketOrder.orderId)")
    }
}
