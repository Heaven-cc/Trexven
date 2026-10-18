# Proposed design token comparison

See `KPI_COMPONENT_AUDIT.md` for measured source geometry and caller differences.

| Token | Current evidence | Companion proposal |
| --- | --- | --- |
| Owner horizontal inset | AppSizing 16 | 12 compact / 16 phone / 24 tablet |
| Owner buttons/quantity targets | 56 | 48–52 button, min 48 touch |
| Owner Home secondary KPI | min 132, padding 15, value 21 | compact content target 92–112, padding 10–12, value 20–24 |
| Owner bottom navigation | 72 | 60–68 plus safe area |
| POS action card | fixed 150 | action target 80–104; separate from KPI sizing |

These are proposals; no numeric design token was changed in this batch. Preserve
current brand/theme until side-by-side rendering establishes a reviewed choice.
Motion/reduced-motion and accessibility behavior require runtime verification.
