import Foundation
import ClipBo

public struct RelativeTimestampTests {
    public static func runAll() throws {
        print("  ▶ Running RelativeTimestampTests...")
        try testRelativeFormatting()
        print("  ✔ RelativeTimestampTests passed")
    }

    static func testRelativeFormatting() throws {
        let now = Date()

        // 10 seconds ago -> Just now
        let justNow = now.addingTimeInterval(-10)
        try assertEqual(RelativeTimestamp.format(date: justNow, relativeTo: now), "Just now")

        // 1 minute ago
        let oneMin = now.addingTimeInterval(-65)
        try assertEqual(RelativeTimestamp.format(date: oneMin, relativeTo: now), "1 min ago")

        // 15 minutes ago
        let fifteenMins = now.addingTimeInterval(-15 * 60)
        try assertEqual(RelativeTimestamp.format(date: fifteenMins, relativeTo: now), "15 min ago")

        // 1 hour ago
        let oneHour = now.addingTimeInterval(-3600)
        try assertEqual(RelativeTimestamp.format(date: oneHour, relativeTo: now), "1 hour ago")

        // 3 hours ago
        let threeHours = now.addingTimeInterval(-3 * 3600)
        try assertEqual(RelativeTimestamp.format(date: threeHours, relativeTo: now), "3 hours ago")

        // Yesterday
        let yesterday = now.addingTimeInterval(-86400)
        try assertEqual(RelativeTimestamp.format(date: yesterday, relativeTo: now), "Yesterday")

        // 4 days ago
        let fourDays = now.addingTimeInterval(-4 * 86400)
        try assertEqual(RelativeTimestamp.format(date: fourDays, relativeTo: now), "4 days ago")
    }
}
