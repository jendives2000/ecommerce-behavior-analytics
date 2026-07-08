# Power BI Report — Build Notes & Architecture Decisions

This file documents the architecture decisions behind `dashboards/ecommerce_analytics.pbix` — the reasoning belongs here rather than in the main README to keep the README scannable, following the same pattern already used for [`price_ceiling_research.md`](../price_ceiling_research.md).

---

## Data Source: Import Mode vs. Live Connection

The report uses **Import mode** — a static snapshot of each module's verified query results, baked directly into the `.pbix` file — rather than a live/DirectQuery connection to BigQuery. Live connection is usually the more sophisticated-looking choice, so here's the explicit case for why it doesn't pay off for this specific project.

**1. Freshness — the entire reason live connections exist — has zero value here.** DirectQuery/live is the right call when the underlying data keeps changing and stakeholders need current numbers. This dataset is permanently frozen (Oct 2019 – Apr 2020); no new rows will ever land in `rees46.events` again. There is no fresher number a live connection could ever surface. Choosing live mode here would mean paying all its costs for a benefit that structurally cannot exist.

**2. Portability.** A live/DirectQuery `.pbix` needs an authenticated BigQuery connection every time it's opened. A recruiter or interviewer opening the file on their own machine either hits a failure or an authentication prompt they can't satisfy. Import mode bakes a snapshot directly into the file — it opens and renders fully offline, on anyone's machine, indefinitely. Same underlying constraint already documented for the Excel workbook in the main README.

**3. Performance and DAX capability.** Import mode runs against Power BI's in-memory VertiPaq columnar engine — near-instant slicer/cross-filter interactions. DirectQuery translates every interaction into a live SQL query sent to BigQuery in real time, and Power BI restricts a meaningful chunk of DAX under DirectQuery (certain iterators, calculated columns, some time-intelligence patterns) specifically to prevent pathological query generation. Given the DAX planned here (retention curves, rolling z-score-driven alert flags, revenue-share measures), Import gives the full DAX surface with nothing to work around.

**4. The concrete trap specific to this dataset.** DirectQuery pointed at the raw `rees46.events` table means every visual interaction fires a query against 411M rows — slow, and it burns through BigQuery quota fast. Making DirectQuery viable at all would require first materializing pre-aggregated summary tables in BigQuery (exactly what the 7 SQL files already compute), then DirectQuerying *those* small tables instead. But once the data is already reduced to a few dozen–few hundred rows per module, there's no real benefit left to keeping a live dependency — you'd be keeping the fragility without the freshness.

**Conclusion:** live connection is the right default in general, but every condition that makes it worth its cost — changing data, an audience needing current numbers, willingness to maintain a live dependency — is absent here. Import mode isn't the lazy option in this case; it has the stronger argument on every axis.

---

## Page Architecture

5 SQL modules map to dedicated pages; 2 modules (Cohort Retention, Anomaly Detection) get full-depth treatment via drillthrough pages instead of top-level tabs, so nothing loses depth despite a compact visible nav. A 6th visible page — the Data Dictionary — was added for transparency (see below).

**Visible top-level pages (6):**

| Page | Source module(s) | Notes |
|------|-------------------|-------|
| Overview | Cross-module KPIs | Headline metrics + flagged anomaly KPI cards (drill through to Anomaly Detail); hover tooltip page on "Overall Conversion" card surfaces the Funnel Floor Bias caveat |
| Funnel | Module 1 (Funnel Analysis) | Bookmark-toggled panel reveals Module 2 (Session Analytics) depth-bucket chart and converting-vs-non-converting comparison as an alternate view of the same page |
| Customer Segments | Module 3 (RFM Segmentation) | Segment Pareto chart, KPI cards; drills through to Cohort Detail |
| Category & Brand | Module 5 (Category & Brand Performance) | |
| COVID Impact | Module 7 (COVID Quasi-Experiment) | |
| Data Dictionary | — | Every DAX measure, calculated column, and KPI with its definition — see below |

**Hidden supporting pages:**

| Page | Type | Source module | Reached from |
|------|------|----------------|---------------|
| Cohort Detail | Drillthrough | Module 4 (Cohort Retention) | Customer Segments page |
| Anomaly Detail | Drillthrough | Module 6 (Anomaly Detection) | Overview's flagged KPI cards |
| Overall Conversion tooltip | Tooltip page | Data Quality Finding #4 | Hover on Overview's "Overall Conversion" KPI card |

---

## Data Dictionary — Dynamic, Model-Bound Structure

The Data Dictionary is **not** a manually maintained table — a hand-typed list is exactly the kind of thing that silently drifts out of sync the moment a measure's definition changes (the same staleness risk already discussed for the Excel workbook's `write_table()` design). Instead, it's built directly from the semantic model's own metadata, so it updates itself as the model changes.

**Mechanism:** three calculated tables built with Power BI's `INFO.VIEW.*` DAX functions, which query the model's own schema — the Tabular-model equivalent of a database's `INFORMATION_SCHEMA`:
- `INFO.VIEW.MEASURES()` — every measure: name, table, DAX expression, format string, display folder, description
- `INFO.VIEW.COLUMNS()` — every column, including calculated columns: name, table, data type, description
- `INFO.VIEW.TABLES()` — every table in the model: name, description

**How the plain-language definitions stay dynamic:** each measure/column's business definition lives in its **Description** property (set once, in Power BI Desktop, via right-click → Properties → Description) — not retyped separately into a dictionary table. `INFO.VIEW.MEASURES()`/`INFO.VIEW.COLUMNS()` surface this Description field directly. Edit a measure's DAX or its Description later, and the dictionary reflects it the next time the model recalculates (on save in Desktop, or scheduled refresh in Service) — there is no second copy of the definition to remember to update.

**One honest limitation:** "which report page uses this measure" is not part of the model's metadata — it lives in the report layout, a separate part of the `.pbix` file that `INFO.VIEW.*` cannot see. That single column needs manual upkeep; everything else (name, type, DAX formula, description) is fully model-bound and self-updating.

**Version note:** `INFO.VIEW.*` functions require a reasonably recent Power BI Desktop build (rolled out 2023+) — confirm the installed Desktop version supports them before relying on this design; if not, the fallback is DAX Studio's DMV query pane against the same model metadata, exported into a table that would then need manual refreshing.

**Columns shown on the Data Dictionary page:**

| Column | Source | Dynamic? |
|--------|--------|----------|
| Name | `INFO.VIEW.MEASURES/COLUMNS/TABLES[Name]` | Yes |
| Type | Derived from which `INFO.VIEW.*` source the row came from | Yes |
| DAX / Source | `INFO.VIEW.MEASURES[Expression]` (imported fields have none) | Yes |
| Business Definition | `INFO.VIEW.MEASURES/COLUMNS/TABLES[Description]` — set via the object's Description property | Yes |
| Used On | Which report page(s) reference it | No — manual |

Same transparency intent as the equivalent Data Dictionary page in Project 1 (TechFlow), but implemented so the dictionary is guaranteed to reflect the model's actual current state rather than a snapshot that can go stale.
