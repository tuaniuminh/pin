import Foundation

/// The handful of numbers a glance needs — a widget, a live activity — derived
/// once from a full `PowerSnapshot`.
///
/// Compiled into both the app and the widget extension. Everything here is plain
/// data so it can cross the process boundary: ActivityKit encodes it as a live
/// activity's content state, and the app writes it into the App Group container
/// for the widget to fall back on.
nonisolated struct ChargeReading: Codable, Hashable, Sendable {
    /// Where `watts` was measured, which decides the caption under it.
    enum Source: String, Codable, Hashable, Sendable {
        /// USB-C input: voltage × current at the port.
        case charger
        /// Wireless input. Only possible on a phone that exposes a coil current.
        case magSafe
        /// Plugged in but the input side cannot be measured — wireless on every
        /// model checked so far — so the figure is what reaches the cell.
        case intoBattery
        /// On battery, measured at the battery rail.
        case fromBattery
    }

    var date: Date
    var percent: Int?
    var externalConnected: Bool
    var isCharging: Bool
    var isOnHold: Bool
    var isFull: Bool
    var isWireless: Bool
    var isFastCharging: Bool
    var watts: Double?
    var source: Source?
    var batteryTemperature: Double?

    enum CodingKeys: String, CodingKey {
        case date, percent, externalConnected, isCharging, isOnHold, isFull, isWireless, isFastCharging, watts, source, batteryTemperature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        percent = try container.decodeIfPresent(Int.self, forKey: .percent)
        externalConnected = try container.decode(Bool.self, forKey: .externalConnected)
        isCharging = try container.decode(Bool.self, forKey: .isCharging)
        isOnHold = try container.decodeIfPresent(Bool.self, forKey: .isOnHold) ?? false
        isFull = try container.decodeIfPresent(Bool.self, forKey: .isFull) ?? false
        isWireless = try container.decodeIfPresent(Bool.self, forKey: .isWireless) ?? false
        isFastCharging = try container.decodeIfPresent(Bool.self, forKey: .isFastCharging) ?? false
        watts = try container.decodeIfPresent(Double.self, forKey: .watts)
        source = try container.decodeIfPresent(Source.self, forKey: .source)
        batteryTemperature = try container.decodeIfPresent(Double.self, forKey: .batteryTemperature)
    }

    init(date: Date,
         percent: Int?,
         externalConnected: Bool,
         isCharging: Bool,
         isOnHold: Bool = false,
         isFull: Bool = false,
         isWireless: Bool = false,
         isFastCharging: Bool = false,
         watts: Double?,
         source: Source?,
         batteryTemperature: Double? = nil) {
        self.date = date
        self.percent = percent
        self.externalConnected = externalConnected
        self.isCharging = isCharging
        self.isOnHold = isOnHold
        self.isFull = isFull
        self.isWireless = isWireless
        self.isFastCharging = isFastCharging
        self.watts = watts
        self.source = source
        self.batteryTemperature = batteryTemperature
    }

    /// Mirrors `PowerMonitor.headline`, minus its last fallback: the %-rate
    /// estimate needs several snapshots over minutes, and a widget refresh only
    /// ever has the one.
    init(_ snapshot: PowerSnapshot) {
        date = snapshot.date
        percent = snapshot.percent
        externalConnected = snapshot.externalConnected
        isCharging = snapshot.isCharging
        isOnHold = snapshot.isChargingOnHold
        isFull = snapshot.fullyCharged && snapshot.externalConnected
        isWireless = snapshot.isWirelessInput || snapshot.adapterIsWireless
        isFastCharging = snapshot.isFastCharging
        batteryTemperature = snapshot.batteryTemperature

        if snapshot.externalConnected {
            if let input = snapshot.inputWatts {
                watts = input
                source = snapshot.isWirelessInput ? .magSafe : .charger
            } else if let battery = snapshot.batteryWatts {
                watts = max(battery, 0)
                source = .intoBattery
            } else {
                watts = nil
                source = nil
            }
        } else if let battery = snapshot.batteryWatts, battery != 0 {
            watts = abs(battery)
            source = .fromBattery
        } else {
            watts = nil
            source = nil
        }
    }

    /// True when this reading carries anything beyond what the system's own battery
    /// indicator already shows — i.e. the PMU sensors actually answered.
    var hasPower: Bool { watts != nil }
}
