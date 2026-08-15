import Foundation
import ClipBo

public struct LaunchAtLoginManagerTests {
    public static func runAll() throws {
        print("  ▶ Running LaunchAtLoginManagerTests...")
        try testManagerStatusQuery()
        print("  ✔ LaunchAtLoginManagerTests passed")
    }

    static func testManagerStatusQuery() throws {
        let manager = LaunchAtLoginManager.shared
        let status = manager.statusDescription
        try assertFalse(status.isEmpty, "Status description must not be empty")
    }
}
