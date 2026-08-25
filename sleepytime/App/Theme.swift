import SwiftUI
import SleepCore

enum NightTheme {
    static let backgroundTop = Color(red: 0.06, green: 0.09, blue: 0.24)
    static let backgroundBottom = Color(red: 0.14, green: 0.19, blue: 0.42)
    static let ice = Color(red: 0.45, green: 0.78, blue: 1.0)
    static let frost = Color(red: 0.62, green: 0.90, blue: 0.94)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.36)
    static let ember = Color(red: 1.0, green: 0.52, blue: 0.42)
    static let mint = Color(red: 0.55, green: 0.95, blue: 0.75)
    static let lavender = Color(red: 0.72, green: 0.66, blue: 1.0)

    static func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .deep: return Color(red: 0.30, green: 0.44, blue: 0.95)
        case .rem: return lavender
        case .core: return Color(red: 0.28, green: 0.62, blue: 0.85)
        case .unspecified: return Color(red: 0.45, green: 0.58, blue: 0.72)
        case .awake: return ember.opacity(0.9)
        }
    }

    static var coolGradient: LinearGradient {
        LinearGradient(colors: [ice, frost, mint], startPoint: .leading, endPoint: .trailing)
    }

    static var pageBackground: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    static func phaseColor(_ phaseID: String) -> Color {
        switch phaseID {
        case "winddown": return amber
        case "descent": return lavender
        case "plateau": return ice
        case "remhold": return mint
        case "wakeramp", "holdtowake": return amber
        default: return frost
        }
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.075))
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                    .opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

struct StarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            staticStars
        } else {
            animatedStars
        }
    }

    private var staticStars: some View {
        Canvas { ctx, size in
            for index in 0..<90 {
                let seedX = Double((index * 137) % 100) / 100
                let seedY = Double((index * 61) % 100) / 100
                let x = size.width * seedX
                let y = size.height * seedY * 0.85
                let radius = 1.0 + Double(index % 3) * 0.7
                ctx.fill(
                    Circle().path(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(0.3))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var animatedStars: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for index in 0..<90 {
                    let seedX = Double((index * 137) % 100) / 100
                    let seedY = Double((index * 61) % 100) / 100
                    let twinkle = 0.5 + 0.45 * sin(t * (0.6 + Double(index % 5) * 0.17) + Double(index))
                    let x = size.width * seedX
                    let y = size.height * seedY * 0.85
                    let radius = 1.0 + Double(index % 3) * 0.7
                    ctx.fill(
                        Circle().path(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(max(0.05, twinkle * 0.5)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct AuroraGlow: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [NightTheme.lavender.opacity(0.28), .clear],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [NightTheme.ice.opacity(0.20), .clear],
                center: UnitPoint(x: 0.1, y: 0.35),
                startRadius: 10,
                endRadius: 380
            )
            RadialGradient(
                colors: [NightTheme.mint.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 10,
                endRadius: 360
            )
        }
        .allowsHitTesting(false)
    }
}


struct NightScreenBackground: View {
    var body: some View {
        ZStack {
            NightTheme.pageBackground
            AuroraGlow()
            StarField()
        }
        .ignoresSafeArea()
    }
}

extension View {
    func nightScreen() -> some View {
        background(NightScreenBackground())
    }
}
