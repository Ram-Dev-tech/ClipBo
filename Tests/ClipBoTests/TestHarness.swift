import Foundation

/// Lightweight test assertion framework for standalone CLI environments.
public struct TestFailure: Error, CustomStringConvertible {
    public let message: String
    public let file: String
    public let line: Int

    public var description: String {
        "\(file):\(line): Test failed: \(message)"
    }
}

public func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) throws {
    if actual != expected {
        let msg = message.isEmpty ? "Expected '\(expected)', but got '\(actual)'" : "\(message) (Expected '\(expected)', got '\(actual)')"
        throw TestFailure(message: msg, file: file, line: line)
    }
}

public func assertTrue(_ condition: Bool, _ message: String = "Expected condition to be true", file: String = #file, line: Int = #line) throws {
    if !condition {
        throw TestFailure(message: message, file: file, line: line)
    }
}

public func assertFalse(_ condition: Bool, _ message: String = "Expected condition to be false", file: String = #file, line: Int = #line) throws {
    if condition {
        throw TestFailure(message: message, file: file, line: line)
    }
}

public func assertNil(_ value: Any?, _ message: String = "Expected value to be nil", file: String = #file, line: Int = #line) throws {
    if value != nil {
        throw TestFailure(message: message, file: file, line: line)
    }
}

public func assertNotNil(_ value: Any?, _ message: String = "Expected value not to be nil", file: String = #file, line: Int = #line) throws {
    if value == nil {
        throw TestFailure(message: message, file: file, line: line)
    }
}

public func assertThrows<T>(_ expression: () throws -> T, _ message: String = "Expected expression to throw an error", file: String = #file, line: Int = #line) throws {
    do {
        _ = try expression()
        throw TestFailure(message: message, file: file, line: line)
    } catch is TestFailure {
        throw TestFailure(message: message, file: file, line: line)
    } catch {
        // Expected throw
    }
}

public func assertThrowsAsync<T>(_ expression: () async throws -> T, _ message: String = "Expected async expression to throw an error", file: String = #file, line: Int = #line) async throws {
    do {
        _ = try await expression()
        throw TestFailure(message: message, file: file, line: line)
    } catch is TestFailure {
        throw TestFailure(message: message, file: file, line: line)
    } catch {
        // Expected throw
    }
}
