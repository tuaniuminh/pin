import SwiftUI

/// Compact inline sparkline, used in the session list.
struct Sparkline: View {
    let values: [Double]
    var tint: Color = .mwAccent

    private static let resolution = 64

    private var thinned: [Double] {
        guard values.count > Self.resolution else { return values }
        let bucket = Double(values.count) / Double(Self.resolution)
        return (0..<Self.resolution).compactMap { index in
            let start = Int(Double(index) * bucket)
            let end = max(start + 1, Int(Double(index + 1) * bucket))
            return values[start..<min(end, values.count)].max()
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let points = thinned
            let peak = max(points.max() ?? 1, 0.001)
            Path { path in
                guard points.count > 1 else { return }
                for (index, value) in points.enumerated() {
                    let x = geometry.size.width * CGFloat(index) / CGFloat(points.count - 1)
                    let y = geometry.size.height * (1 - CGFloat(value / peak))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Rolling three-minute view of adapter power against battery power.
struct LivePowerChart: View {
    let samples: [LiveSample]
    var height: CGFloat = 130

    private var ceiling: Double {
        let peak = (samples.compactMap(\.inputWatts) + samples.compactMap(\.batteryWatts))
            .filter(\.isFinite).max() ?? 0
        return max(peak * 1.25, 5)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxVal = ceiling

                ZStack(alignment: .topLeading) {
                    ForEach(1..<3) { i in
                        let y = h * CGFloat(i) / 3.0
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color.mwGrid, lineWidth: 0.5)
                    }

                    let inputPoints = samples.compactMap(\.inputWatts)
                    if inputPoints.count > 1 {
                        Path { p in
                            for (idx, val) in inputPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(inputPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [Color.mwAccent.opacity(0.4), Color.mwAccent.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))

                        Path { p in
                            for (idx, val) in inputPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(inputPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.mwAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }

                    let battPoints = samples.compactMap(\.batteryWatts)
                    if battPoints.count > 1 {
                        Path { p in
                            for (idx, val) in battPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(battPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.mwBattery, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                    }
                }
            }
            .frame(height: height)

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.mwAccent).frame(width: 6, height: 6)
                    Text("From charger").font(.system(size: 10)).foregroundStyle(Color.mwMuted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.mwBattery).frame(width: 6, height: 6)
                    Text("Into battery").font(.system(size: 10)).foregroundStyle(Color.mwMuted)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Power over the length of a finished session, plotted against elapsed time.
struct SessionPowerChart: View {
    let samples: [ChargeSample]
    var height: CGFloat = 150

    private var ceiling: Double {
        let peak = (samples.compactMap(\.inputWatts) + samples.compactMap(\.batteryWatts))
            .filter(\.isFinite).max() ?? 0
        return max(peak * 1.2, 5)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxVal = ceiling

                ZStack(alignment: .topLeading) {
                    ForEach(1..<3) { i in
                        let y = h * CGFloat(i) / 3.0
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color.mwGrid, lineWidth: 0.5)
                    }

                    let inputPoints = samples.compactMap(\.inputWatts)
                    if inputPoints.count > 1 {
                        Path { p in
                            for (idx, val) in inputPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(inputPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [Color.mwAccent.opacity(0.4), Color.mwAccent.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))

                        Path { p in
                            for (idx, val) in inputPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(inputPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.mwAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }

                    let battPoints = samples.compactMap(\.batteryWatts)
                    if battPoints.count > 1 {
                        Path { p in
                            for (idx, val) in battPoints.enumerated() {
                                let x = w * CGFloat(idx) / CGFloat(battPoints.count - 1)
                                let y = h * (1.0 - CGFloat(min(max(val, 0), maxVal) / maxVal))
                                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.mwBattery, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                    }
                }
            }
            .frame(height: height)

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.mwAccent).frame(width: 6, height: 6)
                    Text("From charger").font(.system(size: 10)).foregroundStyle(Color.mwMuted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.mwBattery).frame(width: 6, height: 6)
                    Text("Into battery").font(.system(size: 10)).foregroundStyle(Color.mwMuted)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

/// SoC and temperature over the length of a finished session.
struct SessionClimateChart: View {
    let samples: [ChargeSample]
    var height: CGFloat = 200

    private var socPoints: [Double] {
        samples.map { Double($0.percent) }
    }

    private var tempPoints: [Double] {
        samples.compactMap(\.batteryTemperature)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("State of Charge").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.mwAccent)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let points = socPoints
                    ZStack {
                        ForEach(1..<3) { i in
                            let y = h * CGFloat(i) / 3.0
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: w, y: y))
                            }
                            .stroke(Color.mwGrid, lineWidth: 0.5)
                        }
                        if points.count > 1 {
                            Path { p in
                                for (idx, val) in points.enumerated() {
                                    let x = w * CGFloat(idx) / CGFloat(points.count - 1)
                                    let y = h * (1.0 - CGFloat(min(max(val, 0), 100) / 100.0))
                                    if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(Color.mwAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                .frame(height: height * 0.45)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Battery Temperature").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.mwLoss)
                if tempPoints.isEmpty {
                    EmptyNote(text: "No cell temperature was recorded for this session.")
                } else {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let points = tempPoints
                        let minTemp = max((points.min() ?? 25) - 2, 0)
                        let maxTemp = max((points.max() ?? 45) + 2, minTemp + 5)
                        let range = maxTemp - minTemp
                        ZStack {
                            ForEach(1..<3) { i in
                                let y = h * CGFloat(i) / 3.0
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: y))
                                    p.addLine(to: CGPoint(x: w, y: y))
                                }
                                .stroke(Color.mwGrid, lineWidth: 0.5)
                            }
                            if points.count > 1 {
                                Path { p in
                                    for (idx, val) in points.enumerated() {
                                        let x = w * CGFloat(idx) / CGFloat(points.count - 1)
                                        let y = h * (1.0 - CGFloat((val - minTemp) / range))
                                        if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                                    }
                                }
                                .stroke(Color.mwLoss, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                    .frame(height: height * 0.45)
                }
            }
        }
    }
}

/// Rolling three-minute view of the hottest sensor in the phone.
struct LiveTemperatureChart: View {
    let samples: [LiveSample]
    var height: CGFloat = 110

    private var points: [Double] {
        samples.compactMap(\.hottestTemperature).filter(\.isFinite)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let vals = points
            let minVal = max((vals.min() ?? 25) - 2, 0)
            let maxVal = max((vals.max() ?? 45) + 2, minVal + 5)
            let range = maxVal - minVal

            ZStack {
                ForEach(1..<3) { i in
                    let y = h * CGFloat(i) / 3.0
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.mwGrid, lineWidth: 0.5)
                }

                if vals.count > 1 {
                    Path { p in
                        for (idx, val) in vals.enumerated() {
                            let x = w * CGFloat(idx) / CGFloat(vals.count - 1)
                            let y = h * (1.0 - CGFloat((val - minVal) / range))
                            if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.mwLoss.opacity(0.35), Color.mwLoss.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))

                    Path { p in
                        for (idx, val) in vals.enumerated() {
                            let x = w * CGFloat(idx) / CGFloat(vals.count - 1)
                            let y = h * (1.0 - CGFloat((val - minVal) / range))
                            if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.mwLoss, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }
}
