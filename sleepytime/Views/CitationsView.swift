import SwiftUI

struct CitationsView: View {
    private struct Citation: Identifiable {
        let id = UUID()
        let claim: String
        let study: String
        let detail: String
    }

    private let citations: [Citation] = [
        Citation(
            claim: "Warm periphery before bed accelerates sleep onset",
            study: "Kräuchi K. et al. (2000), Am J Physiol 278:R741–748 · Haghayegh S. et al. (2019), Sleep Med Rev 46:124–135",
            detail: "The distal–proximal skin gradient is the best single predictor of sleep onset. Warm baths (40–42.5 °C, ≥10 min, 1–2 h before bed) shorten latency by ~36% by shunting core heat outward."
        ),
        Citation(
            claim: "A sustained cool plateau deepens slow-wave sleep",
            study: "Herberger M. et al. (2024), Sci Rep 14:4669 (N=72 RCT crossover)",
            detail: "Enhanced conductive heat loss during sleep increased N3 by ~7.5 min and lowered heart rate 2.4 bpm without reducing REM."
        ),
        Citation(
            claim: "Cooler early-night settings help stage outcomes in free living",
            study: "Moyen J.N. et al. (2024), Bioengineering 11(4):352 (N=54, 16 nights)",
            detail: "Men at cooler early-phase temps gained +22% deep sleep; women gained +25% REM. Women's recommended setpoints run ~1–2 °C warmer than men's."
        ),
        Citation(
            claim: "First-half heat is the most damaging window",
            study: "Okamoto-Mizuno K., Mizuno K. (2012), J Physiol Anthropol 31:14 (+1999–2005 series)",
            detail: "Heat exposure in the first half suppresses the core-temperature drop that drives slow-wave sleep; with bedding, cool rooms (13–23 °C) barely disturb stages."
        ),
        Citation(
            claim: "REM cannot thermoregulate, so stability beats manipulation late",
            study: "Cerri F. et al. (2017), Front Physiol 8:624",
            detail: "REM is a poikilothermic state; REM fraction forms an inverted-U against ambient temperature, peaking at thermoneutrality. Both cold and heat fragment it."
        ),
        Citation(
            claim: "Slight skin warming shortens sleep latency and deepens sleep",
            study: "Raymann R.J.E.M. et al. (2008), Brain 131:500–513",
            detail: "+0.4 °C proximal skin warming nearly doubled SWS % in older adults and cut early-morning wake probability from 0.58 to 0.04."
        ),
        Citation(
            claim: "Your personal deep-sleep centroid times the cool plateau",
            study: "Carskadon & Dement (2011), Normal Human Sleep · Ohayon M.M. et al. (2004), SLEEP 27(7):1255–73",
            detail: "N3 concentrates in cycles 1–2 (13–23% of TST); REM lengthens across the night (20–25%, latency ≈90 min). The schedule reads YOUR centroids instead of assuming them."
        ),
        Citation(
            claim: "Consistency gates how aggressively to personalize",
            study: "Phillips A.J.K. et al. (2017), Sci Rep 7:3216 · Windred D.P. et al. (2024), SLEEP zsad253",
            detail: "The Sleep Regularity Index predicts cardiometabolic risk and mortality more strongly than duration. Low regularity shifts architecture nightly, so Goodnight falls back to the canonical template."
        ),
        Citation(
            claim: "Wearables need multi-night aggregation",
            study: "Robbins R. et al. (2024), Sensors 24:6532 (Apple Watch vs PSG)",
            detail: "Deep-sleep minute estimates agree poorly on any single night (ICC 0.13) while total sleep time agrees well. Goodnight acts only on rolling multi-night aggregates."
        ),
        Citation(
            claim: "Gentle warmth before waking (extrapolated)",
            study: "Kräuchi K. et al. (2004), J Sleep Res 13:121–127 · van de Werken M. et al. (2010), J Sleep Res 19:425–435",
            detail: "No direct thermal-alarm trial exists. Dawn light in the final 30 minutes reduces sleep inertia via distal vasoconstriction and lighter sleep; the wake ramp mirrors this conservatively and can be turned off."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Every phase of the schedule maps to peer-reviewed thermoregulation research. Effects are real but modest; this app aims for evidence-shaped defaults you can tune.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                    ForEach(citations) { citation in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(citation.claim)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(citation.detail)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.68))
                            Text(citation.study)
                                .font(.caption2)
                                .foregroundStyle(NightTheme.frost.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 18)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Research")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
