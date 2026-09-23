import Foundation

enum Device {
    /// Stable across launches, so a rejoining player keeps their seat identity and their purse.
    static var id: String {
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    private static let key = "deviceID"
}
