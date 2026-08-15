import Foundation

/// Formats dates into human-readable relative timestamps.
public enum RelativeTimestamp {
    public static func format(date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        
        if elapsed < 30 {
            return "Just now"
        }
        
        let minutes = Int(elapsed / 60)
        if minutes < 1 {
            return "Just now"
        }
        if minutes == 1 {
            return "1 min ago"
        }
        if minutes < 60 {
            return "\(minutes) min ago"
        }
        
        let hours = Int(elapsed / 3600)
        if hours == 1 {
            return "1 hour ago"
        }
        if hours < 24 {
            return "\(hours) hours ago"
        }
        
        let days = Int(elapsed / 86400)
        if days == 1 {
            return "Yesterday"
        }
        if days < 7 {
            return "\(days) days ago"
        }
        
        let weeks = Int(days / 7)
        if weeks == 1 {
            return "1 week ago"
        }
        if weeks < 4 {
            return "\(weeks) weeks ago"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
