import App
import Darwin
import Foundation

private var token = ProcessInfo.processInfo.environment["API_TOKEN"] ?? ""

private func inputToken() -> String {
    print("\nПожалуйста введите токен доступа к API: ", terminator: "")
    guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
        return inputToken()
    }
    return input
}

if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    token = inputToken()
}

private func testResultSymbol(_ result: Bool) -> String {
    switch result {
    case true: return String("\u{2705}")
    case false: return String("\u{274C}")
    }
}

private func startEventBasedTests(_ closure: () throws -> Void) {
    do {
        let start = CFAbsoluteTimeGetCurrent()
        try closure()
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("\nВсе тесты завершены успешно (\(Double(round(1000 * diff) / 1000)) сек.)...\(testResultSymbol(true))")
    } catch {
        print(testResultSymbol(false))
        print("\nОшибка: \(error)")
        exit(EXIT_FAILURE)
    }
}

private func startAsyncBasedTests(_ closure: () async throws -> Void) async {
    do {
        let start = CFAbsoluteTimeGetCurrent()
        try await closure()
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("\nВсе тесты завершены успешно (\(Double(round(1000 * diff) / 1000)) сек.)...\(testResultSymbol(true))")
    } catch {
        print(testResultSymbol(false))
        print("\nОшибка: \(error)")
        exit(EXIT_FAILURE)
    }
}

print("\n⭕ Тестируем канал песочницы.")
let sandboxTest = try SandboxTest(token: token)

print("\n⭕   Запускаю event-style тесты...")
startEventBasedTests {
    try sandboxTest.start()
}

print("\n⭕   Запускаю async-style тесты...")
await startAsyncBasedTests {
    try await sandboxTest.startAsync()
}

print("\n⭕ Тестируем основной канал.")
let commonTest = try CommonTest(token: token)

print("\n⭕   Запускаю event-style тесты...")
startEventBasedTests {
    try commonTest.start()
}

print("\n⭕   Запускаю async-style тесты...")
await startAsyncBasedTests {
    try await commonTest.startAsync()
}
