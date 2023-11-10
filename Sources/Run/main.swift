import App
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

func timeString(time: TimeInterval) -> String {
    let minutes = Int(time) / 60 % 60
    let seconds = Int(time) % 60
    return String(format: "%02i мин. %02i сек.", minutes, seconds)
}

private func startEventBasedTests(_ closure: () throws -> Void) {
    startTests {
        try closure()
    }
}

private func startAsyncBasedTests(_ closure: @escaping () async throws -> Void) async {
    startTests {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            try await closure()
            semaphore.signal()
        }
        semaphore.wait()
    }
}

private func startTests(_ closure: () throws -> Void) {
    do {
        let start = Date()
        try closure()
        let diff = Date().timeIntervalSince(start)
        print("\nВсе тесты завершены успешно (\(timeString(time: diff)))...\(testResultSymbol(true))")
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
