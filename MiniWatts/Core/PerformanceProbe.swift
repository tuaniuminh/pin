import Foundation
import QuartzCore
import Combine

/// Diagnostic probe ("con bọ đo lường hiệu năng") that monitors:
/// 1. Hardware & sensor read latency (IOKit / HID)
/// 2. Math & algorithm calculation latency (energy integration, curve fitting)
/// 3. Main thread state dispatch time
/// 4. Scrolling frame hitches & drop detection via CADisplayLink
@MainActor
final class PerformanceProbe: ObservableObject {
    static let shared = PerformanceProbe()

    struct TickMetric: Identifiable {
        let id = UUID()
        let timestamp: Date
        let sensorReadMs: Double
        let calculationMs: Double
        let mainThreadMs: Double
        let hadScrollHitch: Bool
    }

    struct HitchSummary {
        var totalFrames: Int = 0
        var totalHitches: Int = 0
        var worstHitchMs: Double = 0
        var hitchesDuringTick: Int = 0
        var averageFps: Double = 60.0
    }

    @Published private(set) var lastSensorReadMs: Double = 0
    @Published private(set) var lastCalculationMs: Double = 0
    @Published private(set) var lastMainThreadMs: Double = 0
    @Published private(set) var averageTickMs: Double = 0
    @Published private(set) var peakTickMs: Double = 0

    @Published private(set) var hitchSummary = HitchSummary()
    @Published private(set) var recentTicks: [TickMetric] = []

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var isTrackingTickInProgress = false
    private var currentTickHadHitch = false
    private var tickStartTime: CFTimeInterval = 0
    private var frameDurations: [Double] = []

    // Internal raw counters to avoid mutating @Published on every display frame
    private var rawTotalFrames: Int = 0
    private var rawTotalHitches: Int = 0
    private var rawWorstHitchMs: Double = 0
    private var rawHitchesDuringTick: Int = 0
    private var rawAverageFps: Double = 60.0

    init() {
        startDisplayLink()
    }

    private func startDisplayLink() {
        let target = DisplayLinkTarget { [weak self] in
            MainActor.assumeIsolated {
                self?.onFrame()
            }
        }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.step))
        link.add(to: .main, forMode: .common)
        link.add(to: .main, forMode: .tracking)
        self.displayLink = link
    }

    private func onFrame() {
        guard let displayLink else { return }
        let current = displayLink.timestamp
        if lastFrameTimestamp > 0 {
            let delta = (current - lastFrameTimestamp) * 1000.0 // in ms
            rawTotalFrames += 1

            let targetInterval = (displayLink.targetTimestamp - displayLink.timestamp) * 1000.0
            let threshold = targetInterval > 0 ? targetInterval * 1.5 : 25.0

            if delta > threshold {
                rawTotalHitches += 1
                if delta > rawWorstHitchMs {
                    rawWorstHitchMs = delta
                }
                if isTrackingTickInProgress {
                    rawHitchesDuringTick += 1
                    currentTickHadHitch = true
                }
            }

            frameDurations.append(delta)
            if frameDurations.count > 120 {
                frameDurations.removeFirst()
            }
            if !frameDurations.isEmpty {
                let avgDuration = frameDurations.reduce(0, +) / Double(frameDurations.count)
                if avgDuration > 0 {
                    rawAverageFps = min(1000.0 / avgDuration, 120.0)
                }
            }
        }
        lastFrameTimestamp = current
    }

    func recordTickStart() {
        isTrackingTickInProgress = true
        currentTickHadHitch = false
        tickStartTime = CACurrentMediaTime()
    }

    func recordTickCancel() {
        isTrackingTickInProgress = false
        currentTickHadHitch = false
    }

    func recordTickEnd(sensorReadMs: Double, calculationMs: Double) {
        let totalMs = (CACurrentMediaTime() - tickStartTime) * 1000.0
        let mainThreadMs = max(totalMs - sensorReadMs - calculationMs, 0)

        lastSensorReadMs = sensorReadMs
        lastCalculationMs = calculationMs
        lastMainThreadMs = mainThreadMs

        // Publish frame metrics once per tick instead of every 8-16ms
        hitchSummary = HitchSummary(
            totalFrames: rawTotalFrames,
            totalHitches: rawTotalHitches,
            worstHitchMs: rawWorstHitchMs,
            hitchesDuringTick: rawHitchesDuringTick,
            averageFps: rawAverageFps
        )

        let metric = TickMetric(
            timestamp: Date(),
            sensorReadMs: sensorReadMs,
            calculationMs: calculationMs,
            mainThreadMs: mainThreadMs,
            hadScrollHitch: currentTickHadHitch
        )

        recentTicks.append(metric)
        if recentTicks.count > 60 {
            recentTicks.removeFirst()
        }

        let allTotals = recentTicks.map { $0.sensorReadMs + $0.calculationMs + $0.mainThreadMs }
        if !allTotals.isEmpty {
            averageTickMs = allTotals.reduce(0, +) / Double(allTotals.count)
            peakTickMs = allTotals.max() ?? 0
        }

        isTrackingTickInProgress = false
    }

    func formattedSummary() -> String {
        let summary = HitchSummary(
            totalFrames: rawTotalFrames,
            totalHitches: rawTotalHitches,
            worstHitchMs: rawWorstHitchMs,
            hitchesDuringTick: rawHitchesDuringTick,
            averageFps: rawAverageFps
        )
        let correlationPct = summary.totalHitches > 0
            ? String(format: "%.0f%%", Double(summary.hitchesDuringTick) / Double(summary.totalHitches) * 100)
            : "0%"

        return """
        # Performance & Scrolling Diagnostics
        - Average FPS: \(String(format: "%.1f", summary.averageFps)) FPS
        - Total Frames Tracked: \(summary.totalFrames)
        - Frame Hitches (>threshold drop): \(summary.totalHitches)
        - Worst Frame Hitch: \(String(format: "%.1f", summary.worstHitchMs)) ms
        - Hitches Coinciding with 1s Sensor Ticks: \(summary.hitchesDuringTick) (\(correlationPct))
        - Sensor Read Time (IOKit/HID): \(String(format: "%.2f", lastSensorReadMs)) ms
        - Calculation Time (Math/Integrals): \(String(format: "%.2f", lastCalculationMs)) ms
        - Main Thread State Mutation: \(String(format: "%.2f", lastMainThreadMs)) ms
        - Total Tick Latency: \(String(format: "%.2f", lastSensorReadMs + lastCalculationMs + lastMainThreadMs)) ms (Peak: \(String(format: "%.2f", peakTickMs)) ms)
        """
    }
}

private final class DisplayLinkTarget: NSObject {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
    }
    @objc func step() {
        action()
    }
}
