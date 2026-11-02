import Foundation
import UIKit

/// Stable installation identifier used to bind refresh sessions. It is not a
/// user identifier and is never displayed.
enum DeviceIdentity {
    private static let fallbackKey = "fitai_installation_id"

    static let current: String = {
        if let vendor = UIDevice.current.identifierForVendor?.uuidString {
            return vendor
        }
        if let stored = UserDefaults.standard.string(forKey: fallbackKey) {
            return stored
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: fallbackKey)
        return value
    }()
}
