import SwiftUI
import SleepCore

struct ThermalCurveView: View {
    let schedule: ThermalSchedule

    private var domainStart: Date { schedule.phases.first?.start ?? schedule.lightsOut }
    private var domainEnd: Date { schedule.wake }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Canvas { ctx, size in
                draw(in: &ctx, size: size, now: context.date)
            }
        }
        .frame(height: 240)
        .accessibilityLabel("Nightly temperature curve from \(domainStart.formatted(date: .omitted, time: .shortened)) to \(domainEnd.formatted(date: .omitted, time: .shortened)))")
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let offsets = schedule.phases.flatMap { [$0.startOffsetC, $0.endOffsetC] }
        guard let minOffset = offsets.min(), let maxOffset = offsets.max() else { return }
        let paddingC = max(0.8, (maxOffset - minOffset) * 0.15)
        let low = minOffset - paddingC
        let high = maxOffset + paddingC

        let totalSeconds = domainEnd.timeIntervalSince(domainStart)
        func x(_ date: Date) -> CGFloat {
            CGFloat(date.timeIntervalSince(domainStart) / totalSeconds) * size.width
        }
        func yTemp(_ offset: Double) -> CGFloat {
            let t = (offset - low) / (high - low)
            return size.height * (1 - CGFloat(t) * 0.86) - size.height * 0.07
        }

        for phase in schedule.phases {
            let rect = CGRect(x: x(phase.start), y: 0, width: x(phase.end) - x(phase.start), height: size.height)
            let bandColor: Color = bandColor(for: phase.id)
            ctx.fill(Path(rect), with: .color(bandColor.opacity(0.05)))
            if phase.id != "winddown" && phase.id != "holdtowake" {
                var line = Path()
                line.move(to: CGPoint(x: rect.minX, y: 0))
                line.addLine(to: CGPoint(x: rect.minX, y: size.height))
                ctx.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            let midX = rect.midX
            if rect.width >= 74 {
                ctx.draw(
                    Text(phase.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55)),
                    at: CGPoint(x: midX, y: size.height - 14),
                    anchor: .center
                )
            }
        }

        let step = totalSeconds / 420
        var points: [CGPoint] = []
        var cursor = domainStart
        while cursor <= domainEnd {
            points.append(CGPoint(x: x(cursor), y: yTemp(schedule.offset(at: cursor))))
            cursor = cursor.addingTimeInterval(step)
        }
        guard let first = points.first else { return }

        var area = Path()
        area.move(to: CGPoint(x: first.x, y: size.height))
        for point in points { area.addLine(to: point) }
        area.addLine(to: CGPoint(x: points.last!.x, y: size.height))
        area.closeSubpath()
        ctx.fill(area, with: .linearGradient(
            Gradient(colors: [NightTheme.frost.opacity(0.30), NightTheme.ice.opacity(0.04)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        let neutralY = yTemp(0)
        if neutralY > 0 && neutralY < size.height {
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: neutralY))
            baseline.addLine(to: CGPoint(x: size.width, y: neutralY))
            ctx.stroke(baseline, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            ctx.draw(
                Text("neutral")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.4)),
                at: CGPoint(x: size.width - 6, y: neutralY - 8),
                anchor: .trailing
            )
        }

        var curve = Path()
        curve.move(to: first)
        for point in points.dropFirst() { curve.addLine(to: point) }
        ctx.stroke(curve, with: .color(NightTheme.frost.opacity(0.16)), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        ctx.stroke(curve, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        ctx.blendMode = .plusLighter
        ctx.stroke(curve, with: .linearGradient(thermalGradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        ctx.blendMode = .normal

        if now >= domainStart && now <= domainEnd {
            let nowX = x(now)
            let nowY = yTemp(schedule.offset(at: now))
            var hairline = Path()
            hairline.move(to: CGPoint(x: nowX, y: 4))
            hairline.addLine(to: CGPoint(x: nowX, y: size.height))
            ctx.stroke(hairline, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            let glow = CGRect(x: nowX - 13, y: nowY - 13, width: 26, height: 26)
            ctx.fill(Circle().path(in: glow), with: .color(NightTheme.mint.opacity(0.22)))
            let dot = CGRect(x: nowX - 5.5, y: nowY - 5.5, width: 11, height: 11)
            ctx.fill(Circle().path(in: dot), with: .color(.white))
            ctx.stroke(Circle().path(in: dot), with: .color(NightTheme.mint), lineWidth: 2.5)
        }
    }

    private var thermalGradient: Gradient {
        Gradient(stops: [
            .init(color: NightTheme.amber, location: 0),
            .init(color: NightTheme.frost, location: 0.35),
            .init(color: NightTheme.ice, location: 0.65),
            .init(color: NightTheme.mint, location: 1)
        ])
    }

    private func bandColor(for id: String) -> Color {
        switch id {
        case "winddown": return NightTheme.amber
        case "descent": return NightTheme.lavender
        case "plateau": return NightTheme.ice
        case "remhold": return NightTheme.mint
        case "wakeramp": return NightTheme.amber
        default: return .white
        }
    }
}
