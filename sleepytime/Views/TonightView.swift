import SwiftUI
import SleepCore

struct TonightView: View {
    @Environment(AppModel.self) private var model
    @State private var showExport = false
    @State private var selectedSide: AppModel.BedSide = .primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeSchedule: ThermalSchedule? {
        model.schedule(for: selectedSide)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if model.isRefreshing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.mini).tint(NightTheme.frost)
                            Text("Updating from Apple Health…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    if model.dualZoneEnabled {
                        sidePicker
                    }
                    if model.shouldShowMorningDebrief, let audit = model.lastNightAudit {
                        morningDebrief(audit)
                    }
                    if let schedule = activeSchedule {
                        heroHeader(schedule)
                        heroScheduleCard(schedule)
                        curveCard(schedule)
                        phasesCard(schedule)
                        actionRow(schedule)
                        notesCard(schedule)
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .nightScreen()
            .contentMargins(.bottom, 110, for: .scrollContent)
            .navigationTitle("Tonight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        if model.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing)
                }
            }
            .sheet(isPresented: $showExport) {
                AutomationExportSheet()
            }
        }
    }

    private var sidePicker: some View {
        Picker("Side", selection: $selectedSide) {
            Text("Side A").tag(AppModel.BedSide.primary)
            Text("Side B").tag(AppModel.BedSide.partner)
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    private func heroHeader(_ schedule: ThermalSchedule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("TONIGHT · \(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                consistencyBadge(schedule.metrics.consistencyClass)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "moon.fill")
                    .font(.title3)
                    .foregroundStyle(NightTheme.lavender)
                Text(schedule.lightsOut.formatted(date: .omitted, time: .shortened))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
                Text(schedule.wake.formatted(date: .omitted, time: .shortened))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func morningDebrief(_ audit: NightThermalAudit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(NightTheme.amber)
                Text("Morning debrief")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let landed = audit.coolingLandedOnDeep {
                    Text(landed ? "Aligned" : "Retargeting")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(landed ? NightTheme.mint : NightTheme.amber)
                }
            }
            Text(audit.summary)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
            if let deep = audit.deepMeanOffsetC, let rem = audit.remMeanOffsetC {
                Text(String(format: "Deep avg %+.1f°C · REM avg %+.1f°C (commanded offsets)", deep, rem))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }

    private func consistencyBadge(_ klass: ConsistencyClass) -> some View {
        let (label, color): (String, Color) = switch klass {
        case .high: ("Regular rhythm", NightTheme.mint)
        case .moderate: ("Fairly regular", NightTheme.frost)
        case .low: ("Irregular", NightTheme.amber)
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(scheduleSRI.map { "\(label) · SRI \($0)" } ?? label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.13)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35)))
    }

    private var scheduleSRI: Int? {
        guard let sri = model.schedule?.metrics.sri else { return nil }
        return Int(sri.rounded())
    }

    @ViewBuilder
    private func heroScheduleCard(_ schedule: ThermalSchedule) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if let phase = schedule.phases.first(where: { now >= $0.start && now < $0.end }) {
                ActivePhaseCard(schedule: schedule, phase: phase, now: now, model: model)
            } else {
                UpcomingCard(schedule: schedule, now: now)
            }
        }
    }

    private func curveCard(_ schedule: ThermalSchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Thermal plan", systemImage: "chart.xyaxis.line")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize()
                Spacer()
                Text(deviceLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ThermalCurveView(schedule: schedule)
            HStack(spacing: 14) {
                legendDot(NightTheme.amber, "warm")
                legendDot(NightTheme.ice, "cool")
                legendDot(NightTheme.mint, "hold")
                Spacer()
                Text("coldest point targets your deep-sleep window")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            confidenceFooter(schedule)
        }
        .glassCard()
    }

    @ViewBuilder
    private func confidenceFooter(_ schedule: ThermalSchedule) -> some View {
        let confidence = schedule.metrics.confidence
        let label = ScheduleConfidence.label(for: confidence)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(confidenceColor(confidence))
                Spacer()
                Text("\(Int((confidence * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            ProgressView(value: confidence)
                .tint(confidenceColor(confidence))
            let sriText = schedule.metrics.sri.map { String(format: "SRI %.0f", $0) }
            let parts = [
                schedule.metrics.nightsAnalyzed > 0 ? "\(schedule.metrics.nightsAnalyzed) nights" : "canonical template",
                schedule.metrics.goodNightsUsed > 0 ? "\(schedule.metrics.goodNightsUsed) high-efficiency" : nil,
                sriText,
                model.learningSummary
            ].compactMap { $0 }
            Text(parts.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private func confidenceColor(_ score: Double) -> Color {
        switch score {
        case 0.75...: return NightTheme.mint
        case 0.45..<0.75: return NightTheme.frost
        default: return NightTheme.amber
        }
    }

    private var deviceLabel: String {
        let neutral = model.useFahrenheit
            ? DeviceMapper.temperatureString(celsius: model.settings.neutralC, useFahrenheit: true)
            : String(format: "%.0f°C", model.settings.neutralC)
        switch model.settings.device {
        case .eightSleep: return "Eight Sleep · neutral \(neutral)"
        case .waterPad: return "Water pad · neutral \(neutral)"
        case .airConditioner: return "AC / thermostat"
        case .generic: return "Generic offsets"
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
    }

    private func phasesCard(_ schedule: ThermalSchedule) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(schedule.phases.enumerated()), id: \.element.id) { index, phase in
                PhaseRow(
                    phase: phase,
                    settings: model.effectiveSettings(),
                    useFahrenheit: model.useFahrenheit,
                    isLast: index == schedule.phases.count - 1
                )
            }
        }
        .glassCard()
    }

    private func actionRow(_ schedule: ThermalSchedule) -> some View {
        HStack(spacing: 10) {
            Button {
                model.copyAutomation(for: selectedSide)
                showExport = true
            } label: {
                Label("Copy plan", systemImage: "doc.on.doc.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)

            ShareLink(item: shareText(schedule)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Share tonight's plan")
        }
    }

    private func shareText(_ schedule: ThermalSchedule) -> String {
        AutomationExporter.exportText(
            schedule: schedule,
            settings: model.effectiveSettings(),
            calendar: model.calendar,
            useFahrenheit: model.useFahrenheit
        )
    }

    @ViewBuilder
    private func notesCard(_ schedule: ThermalSchedule) -> some View {
        if !schedule.notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Why this shape", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NightTheme.frost)
                ForEach(Array(schedule.notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(NightTheme.frost.opacity(0.7)).frame(width: 5, height: 5).padding(.top, 6)
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.largeTitle)
                .foregroundStyle(NightTheme.lavender)
            Text(model.demoMode ? "Demo nights loaded" : "No sleep data yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Once a few nights of Apple Health sleep data exist, your personal temperature schedule appears here.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            if !model.demoMode {
                Button("Try demo nights") {
                    Task { await model.switchToDemo(true) }
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.top, 30)
    }
}

struct ActivePhaseCard: View {
    let schedule: ThermalSchedule
    let phase: ThermalPhase
    let now: Date
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { NightTheme.phaseColor(phase.id) }

    private var progress: Double {
        let total = phase.end.timeIntervalSince(phase.start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(phase.start) / total))
    }

    private var countdown: String {
        let remaining = max(0, phase.end.timeIntervalSince(now))
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        if hours > 0 { return "\(hours)h \(minutes % 60)m left" }
        return "\(minutes)m \(Int(remaining) % 60)s left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 8, height: 8)
                    .shadow(color: tint, radius: 4)
                Text("RIGHT NOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .tracking(1.5)
                Text(phase.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(countdown)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.09)))
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DeviceMapper.displayString(
                        offsetC: phase.offset(at: now),
                        settings: model.effectiveSettings(),
                        useFahrenheit: model.useFahrenheit
                    ))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Text("target setpoint")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: phase.id == "plateau" ? "snowflake" : (phase.id == "winddown" || phase.id == "wakeramp" ? "flame.fill" : "leaf.fill"))
                    .font(.system(size: 34))
                    .foregroundStyle(tint)
                    .symbolEffect(.breathe, isActive: !reduceMotion)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(tint)
                HStack {
                    Text(phase.start.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text(phase.end.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .opacity(0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.18), radius: 18, y: 6)
    }
}

struct UpcomingCard: View {
    let schedule: ThermalSchedule
    let now: Date

    private var text: String {
        if let upcoming = schedule.phases.first(where: { $0.start > now }) {
            let start = upcoming.start.formatted(date: .omitted, time: .shortened)
            let until = upcoming.start.formatted(.relative(presentation: .named))
            return "Tonight's schedule begins with \(upcoming.name.lowercased()) at \(start), \(until)."
        }
        return "Schedule complete for tonight. It refreshes after your next sleep."
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.and.horizon.fill")
                .font(.title3)
                .foregroundStyle(NightTheme.amber)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}

struct PhaseRow: View {
    let phase: ThermalPhase
    let settings: ThermalSettings
    let useFahrenheit: Bool
    let isLast: Bool
    @State private var expanded = false

    private var bandTint: Color { NightTheme.phaseColor(phase.id) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
        } label: {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(bandTint)
                        .frame(width: 4, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(timeRange)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text(tempSummary)
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(bandTint)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(phase.rationale)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Evidence: \(phase.evidence)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
            }
        }
    }

    private var timeRange: String {
        "\(phase.start.formatted(date: .omitted, time: .shortened)) – \(phase.end.formatted(date: .omitted, time: .shortened))"
    }

    private var tempSummary: String {
        let startVal = DeviceMapper.displayString(offsetC: phase.startOffsetC, settings: settings, useFahrenheit: useFahrenheit)
        let endVal = DeviceMapper.displayString(offsetC: phase.endOffsetC, settings: settings, useFahrenheit: useFahrenheit)
        return startVal == endVal ? startVal : "\(startVal) → \(endVal)"
    }
}
