import Foundation

/// How a `ChargeReading` is worded, in one place.
///
/// Compiled into both targets: the Power tab, the widget, the live activity and the
/// floating meter all describe the same reading, and they have already drifted once.
/// Copy only — no views. The catalogs of both targets carry these strings.
extension ChargeReading.Source {
    var caption: MWLocalizedString {
        switch self {
        case .charger: return "at phone port"
        case .magSafe: return "at charging coil"
        case .intoBattery: return "into battery"
        case .fromBattery: return "drawn from battery"
        }
    }
}

extension ChargeReading {
    /// An unknown hold is not a title of its own. What is known in that case —
    /// plugged in, not charging — is what the app's own status line says, and a
    /// widget saying “unknown” beside it would be the two disagreeing about one
    /// reading.
    var statusTitle: MWLocalizedString {
        if isOnHold { return "Charging on hold" }
        if isFull { return "Full" }
        if isCharging { return "Charging" }
        if externalConnected { return "Plugged in, not charging" }
        return "On battery"
    }

    var symbolName: String {
        if externalConnected { return isWireless ? "wave.3.right" : "bolt.fill" }
        switch percent ?? 100 {
        case ..<13: return "battery.0"
        case ..<50: return "battery.25"
        default: return "battery.100"
        }
    }

    var percentText: String { percent.map { "\($0)%" } ?? "—" }
}
