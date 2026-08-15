import Foundation

print("========================================")
print("    Running ClipBo Test Suite")
print("========================================")

var failureCount = 0
let startTime = Date()

do {
    try ClipModelTests.runAll()
} catch {
    print("  ❌ ClipModelTests failed: \(error)")
    failureCount += 1
}

do {
    try ClipboardReaderTests.runAll()
} catch {
    print("  ❌ ClipboardReaderTests failed: \(error)")
    failureCount += 1
}

do {
    try ClipboardWriterTests.runAll()
} catch {
    print("  ❌ ClipboardWriterTests failed: \(error)")
    failureCount += 1
}

do {
    try await ClipboardMonitorTests.runAll()
} catch {
    print("  ❌ ClipboardMonitorTests failed: \(error)")
    failureCount += 1
}

do {
    try await CoreDataClipRepositoryTests.runAll()
} catch {
    print("  ❌ CoreDataClipRepositoryTests failed: \(error)")
    failureCount += 1
}

do {
    try ImageStorageTests.runAll()
} catch {
    print("  ❌ ImageStorageTests failed: \(error)")
    failureCount += 1
}

do {
    try LaunchAtLoginManagerTests.runAll()
} catch {
    print("  ❌ LaunchAtLoginManagerTests failed: \(error)")
    failureCount += 1
}

do {
    try await CategoryFilterTests.runAll()
} catch {
    print("  ❌ CategoryFilterTests failed: \(error)")
    failureCount += 1
}

do {
    try RelativeTimestampTests.runAll()
} catch {
    print("  ❌ RelativeTimestampTests failed: \(error)")
    failureCount += 1
}

ClassificationTests.runAll()
SearchTests.runAll()
QuickOverlayNavigationTests.runAll()
await MenuBarCategoryNavigationTests.runAll()
ClipDragProviderTests.runAll()
await SelectionCaptureTests.runAll()
await QuickCaptureTests.runAll()
await QuickSelectionCaptureTests.runAll()
await ClipDisplayLimitTests.runAll()
AdvancedClipboardFormatTests.runAll()
await SettingsTests.runAll()

let elapsed = String(format: "%.3f", Date().timeIntervalSince(startTime))
print("========================================")
if failureCount == 0 {
    print("  ✅ All test suites passed successfully! (\(elapsed)s)")
    print("========================================")
    exit(0)
} else {
    print("  ❌ \(failureCount) test suite(s) failed. (\(elapsed)s)")
    print("========================================")
    exit(1)
}
