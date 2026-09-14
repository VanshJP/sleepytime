import SwiftUI
import SleepCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var showCitations = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    dataSection
                    deviceSection
                    temperatureSection
                    preferenceSection
                    dualZoneSection
                    remindersSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .nightScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.bottom, 110, for: .scrollContent)
            .sheet(isPresented: $showCitations) {
                CitationsView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyView()
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Data source", systemImage: "heart.text.square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Toggle(isOn: Binding(
                get: { model.demoMode },
                set: { enabled in
                    Task { await model.switchToDemo(enabled) }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo mode").font(.subheadline).foregroundStyle(.white)
                    Text("Synthetic nights on this device only").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.mint)

            if !model.demoMode {
                Button {
                    Task { await model.reconnectHealth() }
                } label: {
                    Label("Re-sync Apple Health", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NightTheme.frost)
                }
                .buttonStyle(.glass)
            }

            Text("Goodnight processes sleep stages entirely on-device and never transmits health data.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))

            if let error = model.errorText {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightTheme.ember)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your device", systemImage: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                deviceRow(.eightSleep, "Eight Sleep Pod", "Water-cooled smart mattress")
                deviceRow(.waterPad, "ChiliPad / water pad", "Any pumped water pad")
                deviceRow(.airConditioner, "Smart AC / thermostat", "Room-level control")
                deviceRow(.generic, "Generic", "Plain offsets for any automation")
            }

            if model.settings.device == .airConditioner {
                Text("AC schedules stay within ±2 °C of your usual room setting and skip the pre-bed warmth phase, since air can't warm a bed like a pad can.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            } else if model.settings.device == .generic {
                Text("Generic mode outputs plain offsets from neutral you can map to any automation.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func deviceRow(_ kind: DeviceKind, _ title: String, _ subtitle: String) -> some View {
        let selected = model.settings.device == kind
        return Button {
            model.settings.device = kind
            model.applySettingChange()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? .white : .white.opacity(0.7))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(selected ? NightTheme.mint : .white.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.10) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? NightTheme.mint.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Temperature", systemImage: "thermometer.medium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Picker("Units", selection: Binding(
                get: { model.useFahrenheit },
                set: { enabled in
                    model.useFahrenheit = enabled
                    model.applySettingChange()
                }
            )) {
                Text("Celsius °C").tag(false)
                Text("Fahrenheit °F").tag(true)
            }
            .pickerStyle(.segmented)

            if model.settings.device == .eightSleep || model.settings.device == .waterPad {
                HStack {
                    Text("Neutral bed temp")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(neutralDisplay)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(NightTheme.frost)
                }
                Slider(
                    value: Binding(
                        get: { model.settings.neutralC },
                        set: { value in
                            model.settings.neutralC = (value * 2).rounded() / 2
                            model.applySettingChange()
                        }
                    ),
                    in: 15...32,
                    step: 0.5
                )
                .tint(NightTheme.frost)

                Text("The temperature that feels neutral when you're simply lying there. Most people settle between 25–28 °C on a water pad. Adjust once; the schedule is built relative to it.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            } else if model.settings.device == .airConditioner {
                roomSetpointRow
            }

            biasRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var roomSetpointRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usual room temp at night")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(model.useFahrenheit ? DeviceMapper.temperatureString(celsius: model.settings.roomSetpointC, useFahrenheit: true) : String(format: "%.0f°C", model.settings.roomSetpointC))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(NightTheme.frost)
            }
            Slider(value: Binding(
                get: { model.settings.roomSetpointC },
                set: { value in
                    model.settings.roomSetpointC = value.rounded()
                    model.applySettingChange()
                }
            ), in: 16...26, step: 1)
            .tint(NightTheme.frost)
        }
    }

    private var biasRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Personal bias")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(biasLabel)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(biasColor)
            }
            Slider(value: Binding(
                get: { model.settings.thermalBias },
                set: { value in
                    model.settings.thermalBias = (value * 4).rounded() / 4
                    model.applySettingChange()
                }
            ), in: -1...1, step: 0.25)
            .tint(NightTheme.amber)
            Text("Runs hot or cold compared to the research defaults? Nudge everything warmer or cooler without changing the shape of the night.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var neutralDisplay: String {
        let c = model.settings.neutralC
        return model.useFahrenheit ? DeviceMapper.temperatureString(celsius: c, useFahrenheit: true) : String(format: "%.1f°C", c)
    }

    private var biasLabel: String {
        switch model.settings.thermalBias {
        case ..<(-0.5): return "Much cooler"
        case ..<(-0.05): return "Cooler"
        case -0.05...0.05: return "Research default"
        case ...0.5: return "Warmer"
        default: return "Much warmer"
        }
    }

    private var biasColor: Color {
        model.settings.thermalBias < -0.05 ? NightTheme.ice : (model.settings.thermalBias > 0.05 ? NightTheme.amber : NightTheme.mint)
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Preferences", systemImage: "switch.2")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Toggle(isOn: Binding(
                get: { model.settings.wakeWarmthEnabled },
                set: { enabled in
                    model.settings.wakeWarmthEnabled = enabled
                    model.applySettingChange()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gentle wake ramp").font(.subheadline).foregroundStyle(.white)
                    Text("Slight warming over the final 30 minutes, mirroring dawn-light physiology. No direct thermal trial exists yet.").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.amber)

            Toggle(isOn: Binding(
                get: { model.settings.hotSleeperMode },
                set: { enabled in
                    model.settings.hotSleeperMode = enabled
                    model.applySettingChange()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hot sleeper").font(.subheadline).foregroundStyle(.white)
                    Text("Disables pre-wake warming and eases cooling depth").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.ember)

            Toggle(isOn: Binding(
                get: { model.settings.gradualTransitions },
                set: { enabled in
                    model.settings.gradualTransitions = enabled
                    model.applySettingChange()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gradual setpoints").font(.subheadline).foregroundStyle(.white)
                    Text("Export ~2.5°F steps for manual pad controllers instead of big jumps").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.ice)

            Picker("Biological sex prior", selection: Binding(
                get: { model.sexSelection },
                set: { sel in
                    model.sexSelection = sel
                    model.applySettingChange()
                }
            )) {
                Text("Woman").tag(AppModel.SexSelection.woman)
                Text("Man").tag(AppModel.SexSelection.man)
            }
            .pickerStyle(.segmented)

            Text("Women's recommended starting setpoints run ~1–2 °C warmer in device studies.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var dualZoneSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Dual zone", systemImage: "rectangle.split.2x1")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Toggle(isOn: Binding(
                get: { model.dualZoneEnabled },
                set: { enabled in
                    model.dualZoneEnabled = enabled
                    model.applySettingChange()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Two sleepers, two schedules").font(.subheadline).foregroundStyle(.white)
                    Text("Side B uses the same sleep timing with its own temperature profile").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.mint)

            if model.dualZoneEnabled {
                HStack {
                    Text("Side B neutral temp")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(partnerNeutralDisplay)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(NightTheme.frost)
                }
                Slider(value: Binding(
                    get: { model.partnerSettings.neutralC },
                    set: { value in
                        model.partnerSettings.neutralC = (value * 2).rounded() / 2
                        model.applySettingChange()
                    }
                ), in: 15...32, step: 0.5)
                .tint(NightTheme.frost)

                Picker("Side B sex prior", selection: Binding(
                    get: { model.partnerSettings.isBiologicalSexFemale },
                    set: { value in
                        model.partnerSettings.isBiologicalSexFemale = value
                        model.applySettingChange()
                    }
                )) {
                    Text("Woman").tag(Optional(true))
                    Text("Man").tag(Optional(false))
                }
                .pickerStyle(.segmented)

                Toggle(isOn: Binding(
                    get: { model.partnerSettings.hotSleeperMode },
                    set: { enabled in
                        model.partnerSettings.hotSleeperMode = enabled
                        model.applySettingChange()
                    }
                )) {
                    Text("Side B hot sleeper").font(.subheadline).foregroundStyle(.white)
                }
                .tint(NightTheme.ember)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var partnerNeutralDisplay: String {
        model.useFahrenheit
            ? DeviceMapper.temperatureString(celsius: model.partnerSettings.neutralC, useFahrenheit: true)
            : String(format: "%.1f°C", model.partnerSettings.neutralC)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reminders", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Toggle(isOn: Binding(
                get: { model.windDownRemindersEnabled },
                set: { enabled in
                    if enabled {
                        model.requestReminderAuthorizationAndSchedule()
                    } else {
                        model.windDownRemindersEnabled = false
                        model.applySettingChange()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wind-down reminder").font(.subheadline).foregroundStyle(.white)
                    Text("15 minutes before the warm phase, for the coming week").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(NightTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About", systemImage: "book.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Button {
                showCitations = true
            } label: {
                Label("Research & citations", systemImage: "text.book.closed")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NightTheme.frost)
            }
            .buttonStyle(.glass)
            Button {
                showPrivacy = true
            } label: {
                Label("Privacy", systemImage: "lock.shield")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NightTheme.frost)
            }
            .buttonStyle(.glass)
            Text("Not medical advice. Temperature effects in trials are real but modest (~10–15 min stage shifts). If you suspect a sleep disorder, talk to a clinician.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
            Text("No accounts. No servers. No tracking. Sleep stages never leave this device.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
