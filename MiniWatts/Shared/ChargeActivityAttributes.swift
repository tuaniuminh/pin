import Foundation

nonisolated enum LiveActivityMetric: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case chargingPower
    case socTemperature
    case batteryTemperature
    case hottestTemperature

    var id: Self { self }
}
