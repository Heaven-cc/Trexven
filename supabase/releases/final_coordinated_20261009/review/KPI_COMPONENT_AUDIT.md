# Current KPI implementation and verification — Batch 8/9

Reusable `MetricContent`/Owner card variants now provide compact/standard/hero
content-driven layouts. Secondary Home metrics use compact content; the primary
summary retains its hierarchy. Narrow/high-text-scale layouts wrap rather than
forcing the unapproved illustrative height ranges below. POS action touch targets
remain distinct from KPIs.

Executed Owner widget tests include dashboard widths 320/412 at scales 1/2 and
Record Sale viewports 320×568, 390×844, 800×1000 and 780×360 at scales 1/2,
including shared payment confirmation. They passed with the full 85-test suite.
This is widget evidence; Android screenshot/performance review is still blocked
by device access. Historical source measurements/proposals below are retained
for comparison and are not the current fixed-size contract.

---

# KPI component audit

Source measurements, not device screenshots:

| Component | Current geometry | Consumers / finding |
| --- | --- | --- |
| `lib/widgets/stat_card.dart` — StatCard | padding 16; value 26; icon 18; radius 18; Spacer needs bounded height | Generic card exists; caller search needed before migration |
| Owner Dashboard `_miniKPICard` | minHeight 132; padding 15; icon container 38; icon 20; value 21; radius 20; row gaps 12 | Home renders four private cards, bypassing generic StatCard |
| `lib/core/app_sizing.dart` | page inset 16; card padding 16; button/quantity targets 56 | No KPI variant tokens |
| POS Dashboard `_ActionCard` | fixed height 150; padding 16 | Action cards, not KPI cards; must not shrink with KPI tokens |
| Owner finance/personnel | Screen-local summary layouts | Domain meaning/loading differ; inspect each before consolidation |

Proposal: one `TrexvenKpiCard` with compact, standard and hero variants,
content-driven growth and explicit variants at callers. Companion ranges remain
proposals: compact 92–112 dp, standard 112–136, hero 136–164, compact padding
10–12, value 20–24 sp. Do not force these as fixed heights or shrink touch targets.
At narrow widths/high text scale allow one-column fallback and wrapping.

Owner Home already separates its primary summary from secondary metrics. Preserve
that hierarchy, expansion interactions and loading/error states. A shared package
across the two repositories requires agreeing on package location/build packaging.

No KPI resizing or theme changes made in the access batch. Required before visual
implementation: rendered comparison at 320/390/600 dp, scales 1.0/1.3/1.6, both
supported themes, long NGN amounts/names, and target Android screenshot review.
