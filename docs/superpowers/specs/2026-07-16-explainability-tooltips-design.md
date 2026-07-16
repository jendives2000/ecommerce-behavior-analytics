# Explainability Tooltips — Design

**Date:** 2026-07-16
**Status:** Approved, ready for implementation planning

## Purpose

Every data-bearing visual in the report (KPI cards, tables, charts) should help the report
user understand what it's showing without leaving the page: what the metric means, how it's
calculated, and — where genuinely relevant — a pointer to one of the 4 documented data
quality findings (Funnel Floor Bias, Category Taxonomy Anomaly, Platform Price Cap, Logging
Gap). Tooltip content must add information not already visible elsewhere on the same page,
not repeat a number already on screen.

Two visual categories get two different, independent mechanisms — chosen through
brainstorming with the user rather than defaulting to one pattern for everything.

## Mechanism 1 — Definitional tooltips (cards, tables)

For a single-value or single-table visual, the tooltip explains what it is.

**DAX layer:** one new measure per tooltip, named `<Thing> Tooltip` (matching the existing
`Funnel Floor Bias Tooltip` measure), composed of:

1. **Definition** — pulled live via
   `LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "<Thing>")`
   so the wording is always identical to the Data Dictionary page and can never drift out of
   sync with it.
2. **Calculation context** — a short VAR-computed line where it adds real value (e.g. a
   sibling-metric comparison), following the same pattern already used by `Overview Insight`,
   `Funnel Insight`, `Category Brand Insight`, etc.
3. **Data-quality tie-in** — one conditional sentence, included only when the measure
   genuinely touches one of the 4 documented findings. Omitted otherwise — never force-fit.

Each measure returns an HTML string in the same visual language already established
(`Segoe UI Light`, white text on dark background, justified body paragraphs) and is bound to
an `htmlContent` visual on a new hidden `Tooltip`-type page.

**PBIR layer:** the new Tooltip page is wired to its source visual via the `visualTooltip`
VCO (`visualContainerObjects.visualTooltip.properties.section`), identical to the existing
`funnel-floor-bias-tooltip` and `price-cap-tooltip` wiring. This shows the same fixed content
regardless of where on the visual the cursor is.

**Naming convention:** `<page>-<topic>-tooltip` for the page folder (e.g.
`overview-total-events-tooltip`), matching the existing two pages.

## Mechanism 2 — Complementary-measure tooltips (charts)

For a multi-point chart, the tooltip surfaces measures that are complementary to what's
plotted — context for the specific data point under the cursor, not a fixed panel.

**No new pages, no new PBIR wiring.** For each chart:

1. Identify 2–4 complementary measures (existing, or new small ones where nothing
   suitable exists yet).
2. Add them to the visual's native **Tooltip** field well.
3. Turn on **Sentence format** in the Format pane.
4. Write the sentence template referencing each with `{MeasureName}` syntax.

This ties the content to the actual hovered data point (category, brand, cohort month,
etc.), which is the correct behavior for a chart — unlike the fixed-panel behavior that's
correct for a single-value card.

## Known existing inconsistency (not in scope to fix now)

`price-cap-tooltip` currently uses a static hardcoded `textbox` rather than a DAX-driven
`htmlContent` visual, unlike `funnel-floor-bias-tooltip`. This spec's Mechanism 1 is the
standard going forward for all *new* definitional tooltips. Rewriting `price-cap-tooltip` to
match is a valid future cleanup but is explicitly deferred — not part of this rollout unless
requested later.

## Rollout plan

- Page by page, starting with Overview.
- Within a page, one visual at a time: build the measure + page + wiring for one visual,
  validate, reload, screenshot, and pause for review before starting the next. Same rhythm
  already used for the icon rollout this session.
- Once a page's tooltips are approved, move to the next page. No further design discussion
  is expected — this spec is the standing pattern for the rest of the report.

## Scope

Tooltips apply to data-bearing visuals only: KPI cards, tables, and charts. Decorative
chrome (shapes, icon images, action buttons, slicers, navigators) is out of scope — nothing
there needs explaining.

## Verification

Each new tooltip goes through the project's established loop before being considered done:
`powerbi-report-author validate` (must not add new errors/warnings beyond the known
baseline) → `powerbi-desktop reload` → screenshot confirmation that the tooltip renders and
reads correctly.
