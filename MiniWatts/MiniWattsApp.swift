import SwiftUI

@main
struct MiniWattsApp: App {
    @StateObject private var monitor: PowerMonitor
    /// One per process, and alive for as long as the app is: the layer Picture in
    /// Picture draws from cannot come and go with a settings sheet.
    @StateObject private var floatingMeter = FloatingMeterController()

    init() {
        let monitor = PowerMonitor()
        _monitor = StateObject(wrappedValue: monitor)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(monitor)
                .environmentObject(floatingMeter)
                .onOpenURL { url in
                    if url.scheme == "miniwatts" && url.host == "end-live-activity" {
                        ChargeActivityController.endAll()
                    }
                }
        }
    }
}
