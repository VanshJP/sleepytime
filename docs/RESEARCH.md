# Goodnight — Research Synthesis (Verified)

Four parallel literature sweeps + an independent adversarial verification pass. Every load-bearing claim below survived verification or was corrected. Confidence: ✅ verified against primary source, ◐ partially confirmed / corrected, ⚠️ conflicting evidence.

## 1. Why temperature controls sleep

| # | Claim | Numbers | Source | Verdict |
|---|---|---|---|---|
| 1.1 | The distal–proximal skin gradient (DPG) is the **best single predictor of sleep onset**, beating core temp, heart rate, and melatonin. After lights-out: distal skin warms → core falls. | DPG strongest in the 1.5 h pre-lights-off; cascade melatonin↑ → distal vasodilation → CBT↓ | Kräuchi et al. 2000, *Am J Physiol* 278:R741–748 | ✅ |
| 1.2 | Warming the periphery *cools the core* (heat shunt through hands/feet). Warm bath 40–42.5 °C, ≥10 min, 1–2 h before bed → shorter SOL. | SOL ≈ −36% relative (~10 min) per citing review + UT release; abstract itself gives no effect size | Haghayegh et al. 2019, *Sleep Med Rev* 46:124–135 | ✅ (numbers via secondary attribution — flagged) |
| 1.3 | Proximal skin warming of just +0.4 °C (thermosuit, elderly/insomniacs) nearly doubled SWS % (8→14% healthy elderly; 4→9% insomniacs) and cut early-morning wake probability 0.58→0.04. Suit thermoneutral zone ≈31–35 °C. | +0.4 °C skin, core unchanged | Raymann, Swaab & Van Someren 2008, *Brain* 131:500–513 | ✅ |
| 1.4 | Conductive cooling mattress RCT: N3 +7.5 ± 21.6 min per night (p=0.0038), sleeping HR −2.36 bpm (p<0.0001), REM unchanged. Effect scales with core-to-back heat flux. Benefit accrues over hours → sustained plateau, not pulses. | N=72, 3-center blinded crossover | Herberger et al. 2024, *Sci Rep* 14:4669 | ✅ |
| 1.5 | Maximum rate of core-temp decline occurs ~60 min before sleep onset; closer MROD → less wakefulness in the first hour of sleep (rₛ=0.70). | n=10 elderly; journal is *Chronobiology International* 11(2):126–131, correlate is first-hour wakefulness | Campbell & Broughton 1994 | ◐ corrected by verifier |
| 1.6 | Free-running sleep onset averages ~1.3 h before the circadian core-temperature minimum (Tmin); sleep ends on the rising limb well after Tmin. Tmin ≈ 04:46 (women) / 06:11 (men); phase angle to wake ≈3.5 h / ~2 h. | Zulley, Wever & Aschoff 1981, *Pflüg Arch* 391:314–318; Park et al. 2013 *Sleep* | ✅ |

## 2. Heat vs cold across the night

| # | Claim | Numbers | Source | Verdict |
|---|---|---|---|---|
| 2.1 | Comfortable bed microclimate ≈ **32–34 °C, 40–60 % RH** under the duvet. | — | Okamoto-Mizuno & Mizuno 2012, *J Physiol Anthropol* 31:14 | ✅ |
| 2.2 | **First-half heat is worse than second-half heat** (suppresses the nocturnal core drop, steals early SWS, raises wake in both segments). Humid heat also suppresses REM. | 26→32 °C chamber studies, 1999–2005 series | Okamoto-Mizuno series; review 2012 | ✅ |
| 2.3 | With normal bedding, room temps **13–23 °C produce few objective stage differences**; cold shifts HRV even when stages hold. Cold mainly threatens late-night (REM-rich) segment. | 13–23 °C, 3–17 °C comparisons | Okamoto-Mizuno 2012; Tsuzuki 2018 | ✅ |
| 2.4 | REM is a **poikilothermic state** (shivering/sweating control lost). REM fraction vs ambient temperature forms an inverted-U peaking at thermoneutrality → REM is fragile to both too cold and too hot. | Cerri et al. 2017, *Front Physiol* 8:624 (Parmeggiani lineage) | ✅ |
| 2.5 | Cool "early phase" bed temps in free-living Pod use: men deep sleep **+14.3 min (+22 %)** (p=0.003); women cooler first half REM **+9 min (+25 %)**; warm late-phase men light sleep +19 %. Water range ≈13–43 °C. Women's recommended setpoints run ~1–2 °C warmer than men's. | N=54, 16 nights; company-affiliated | Moyen et al. 2024, *Bioengineering* 11(4):352 | ◐ stage effects confirmed; ~~"+3 awakenings from warm late phase"~~ **not supported** (paper: p=0.123, no awakening difference) — removed from algorithm |
| 2.6 | A second device study found **no significant objective effects** in healthy good sleepers. Expect modest (~10–15 min) stage shifts, largest in below-average sleepers. | 14 nights, MDPI 2025 | ⚠️ conflict with 2.5, resolved as effect-size honesty |
| 2.7 | The famous "65 °F / 18.3 °C bedroom" has **no identifiable primary trial**; defensible statement is the 13–23 °C band with bedding + avoid >26 °C. | Sleep Foundation convention vs Okamoto-Mizuno data | ⚠️ folklore — we do not hard-code it |

## 3. Sleep architecture timing (what we personalize against)

| # | Claim | Numbers | Source | Verdict |
|---|---|---|---|---|
| 3.1 | N3 ≈ 13–23 % of TST, REM ≈ 20–25 %, REM latency ≈ 80–100 min, 4–6 cycles of ~90 min. | Carskadon & Dement 2011 ch. 2; Ohayon et al. 2004 *SLEEP* 27(5):1255–73 for norms table | ✅ |
| 3.2 | SWS concentrates in cycles 1–2 (first third); SWA declines exponentially across the night. REM episodes lengthen across the night, longest in final third. REM propensity peaks near Tmin on the rising limb. | Carskadon & Dement; Dijk & Czeisler 1995 *J Neurosci* 15:3526 | ✅ (front-loading is textbook-level, exact ">70 %" figure not sourced — we measure the user's own centroid instead) |
| 3.3 | Apple Watch deep-sleep detection: sensitivity ~50 %, deep-minute agreement ICC ≈ 0.13 vs PSG (single night), while TST ICC = 0.85 and latency ICC > 0.94. | Robbins et al. 2024, *Sensors* 24:6532 (n=35) | ◐ verifier notes ICC is cross-participant single-night — implication stands: **never act on one night's deep minutes; aggregate 7+ nights** |
| 3.4 | Adults need ≥7 h (consensus 7–9 h); SE ≥85 % good / <80 % poor; SOL ≤30 min normal. | Watson et al. 2015 *JCSM*; Aurora et al. 2019 *Lancet Respir Med* | ✅ |

## 4. Consistency (the second input pillar)

| # | Claim | Numbers | Source | Verdict |
|---|---|---|---|---|
| 4.1 | Sleep Regularity Index = probability of being in the same sleep/wake state at two time points 24 h apart, averaged over all epoch pairs (0–100). | Phillips et al. 2017, *Sci Rep* 7:3216 | ✅ formula confirmed |
| 4.2 | Typical adult medians range ~60–81 depending on pipeline (epoch length + scoring algorithm); same cohort can shift quintiles between calculators. | Windred 2024 *SLEEP* zsad253 (median 81) vs Cribb 2023 *eLife* (median 60); Czeisler 2025 *SLEEP* zsaf299 pipeline comparison | ⚠️ → we fix ONE pipeline (5-min bins, HealthKit asleep states) and use SRI only **within-person** (trend + threshold gating), never absolute claims |
| 4.3 | Low SRI predicts all-cause mortality (HR up to 1.53 at 5th percentile), worse GPA (r=0.37), later DLMO (~2.5 h), reduced REM/SWS time vs regular sleepers. Circadian misalignment degrades continuity and redistributes REM. | Windred 2024; Phillips 2017; PLoS One 2013 10.1371/journal.pone.0072877 | ✅ direction robust |

## 5. The pre-wake question (adjudicated)

No peer-reviewed head-to-head exists for thermal waking cues. Evidence assembled:

- Dawn light in the final 30 min reduces subjective sleepiness/inertia; mechanism = lighter sleep + accelerated **distal vasoconstriction** post-wake, *not* core warming (van de Werken 2010 *J Sleep Res* 19:425–435; Giménez 2010 *Chronobiol Int* 27:1219–1241). No minutes-saved number is sourceable.
- Sleep-inertia dissipation tracks distal vasoconstriction + rising core temp (Kräuchi et al. 2004, *J Sleep Res* 13:121–127).
- Cooling in the final hour is contraindicated: REM-dominant segment + cold hits late sleep hardest (2.3, 2.4); proximal cooling pushes core temp the wrong way (Herberger 2024).
- Gentle proximal warmth does not increase awakenings (Raymann 2008; Moyen 2024 warm-late-phase null on awakenings).

**Decision:** gentle warming ramp (+~1 °C above neutral over the final 30–45 min), never active cooling after the REM hold begins, opt-out toggle in settings, honest in-product framing ("extrapolated from dawn-light physiology; no direct thermal-alarm trial exists"). Hot-sleeper mode defaults it off.

## 6. What this means (design constraints distilled)

1. Warm periphery before lights-out (bath analog) → faster onset. Stop heating ≥30 min before bed so the core lands on its natural declining limb.
2. Cool plateau from shortly after onset through the personal SWS window — sustained, not pulsed; coldest point of night; first-half heat must be avoided at all costs.
3. Thermoneutral-ish hold during the REM-dominant back half — stability, not manipulation (REM can't thermoregulate).
4. Mild warm ramp at the end, opt-out.
5. Personalize **timing** off the user's own stage centroids; personalize **magnitude** only from multi-night aggregates (wearable deep-sleep noise); gate aggressiveness on schedule consistency.
6. Express everything relative to a personal neutral; map to device ranges locally.

## Full bibliography

- Kräuchi K. et al. (2000) *Am J Physiol Regul Integr Comp Physiol* 278(3):R741–R748. PMID 10712296
- Kräuchi K. et al. (1999) *Nature* 401:36–37. · Kräuchi K. et al. (2004) *J Sleep Res* 13:121–127
- Haghayegh S. et al. (2019) *Sleep Med Rev* 46:124–135. PMID 31102877
- Raymann R.J.E.M., Swaab D.F., Van Someren E.J.W. (2008) *Brain* 131:500–513. PMID 18192289 · Raymann & Van Someren (2008) *Sleep* 31(9):1301–1309
- Herberger M. et al. (2024) *Sci Rep* 14:4669. doi:10.1038/s41598-024-53839-x
- Okamoto-Mizuno K., Mizuno K. (2012) *J Physiol Anthropol* 31:14 (+ 1999 *Sleep* 22:767; 2003/2004/2005 *Int J Biometeorol*, *Physiol Behav*, *Ergonomics* series)
- Moyen J.N. et al. (2024) *Bioengineering* 11(4):352. doi:10.3390/bioengineering11040352
- Harding E.C., Franks N.P., Wisden W. (2019) *Front Neurosci* 13:336 · Cerri F. et al. (2017) *Front Physiol* 8:624
- Phillips A.J.K. et al. (2017) *Sci Rep* 7:3216 · Windred D.P. et al. (2024) *SLEEP* 47(1):zsad253 · Cribb L. et al. (2023) *eLife* 12:e88359
- Carskadon M.A., Dement W.C. (2011) "Normal Human Sleep," *Principles & Practice of Sleep Medicine*, 5e · Ohayon M.M. et al. (2004) *SLEEP* 27(7):1255–73
- Robbins R. et al. (2024) *Sensors* 24(20):6532 · Miller D.J. et al. (2024) systematic review PMC10948771
- Zulley J., Wever R., Aschoff J. (1981) *Pflüg Arch* 391:314–318 · Campbell S.S., Broughton R.J. (1994) *Chronobiol Int* 11(2):126–131
- van de Werken M. et al. (2010) *J Sleep Res* 19:425–435 · Giménez M.C. et al. (2010) *Chronobiol Int* 27:1219–1241
- Dijk D.-J., Czeisler C.A. (1995) *J Neurosci* 15(5):3526–3538 · Watson N.F. et al. (2015) *J Clin Sleep Med* 11(6):591–592
- Aurora R.N. et al. (2019) *Lancet Respir Med* 7(5) · Togo F. et al. (2007) *Sleep* 30(6):797–802
