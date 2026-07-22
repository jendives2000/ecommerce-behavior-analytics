# Power BI Report — Build Notes & Architecture Decisions

This file documents the architecture decisions behind `dashboards/ecommerce_analytics.pbix` — the reasoning belongs here rather than in the main README to keep the README scannable, following the same pattern already used for [`price_ceiling_research.md`](../price_ceiling_research.md).

---

## Data Source: Import Mode vs. Live Connection

The report uses **Import mode** — a static snapshot of each module's verified query results, baked directly into the `.pbix` file — rather than a live/DirectQuery connection to BigQuery. Fact and dimensions tables were queried in BigQuery, then consolidated in one single excel file: [powerbi_source_data.xlsx](powerbi_source_data.xlsx). This same file was imported using the import mode.  
Live connection is usually the more sophisticated-looking choice, so here's the explicit case for why it doesn't pay off for this specific project.

**1. Freshness — the entire reason live connections exist — has zero value here.** DirectQuery/live is the right call when the underlying data keeps changing and stakeholders need current numbers. This dataset is permanently frozen (Oct 2019 – Apr 2020); no new rows will ever land in `rees46.events` again. There is no fresher number a live connection could ever surface. Choosing live mode here would mean paying all its costs for a benefit that structurally cannot exist.

**2. Portability.** A live/DirectQuery `.pbix` needs an authenticated BigQuery connection every time it's opened. A recruiter or interviewer opening the file on their own machine either hits a failure or an authentication prompt they can't satisfy. Import mode bakes a snapshot directly into the file — it opens and renders fully offline, on anyone's machine, indefinitely. Same underlying constraint documented for the Excel workbook below.

**3. Performance and DAX capability.** Import mode runs against Power BI's in-memory VertiPaq columnar engine — near-instant slicer/cross-filter interactions. DirectQuery translates every interaction into a live SQL query sent to BigQuery in real time, and Power BI restricts a meaningful chunk of DAX under DirectQuery (certain iterators, calculated columns, some time-intelligence patterns) specifically to prevent pathological query generation. Given the DAX planned here (retention curves, rolling z-score-driven alert flags, revenue-share measures), Import gives the full DAX surface with nothing to work around.

**4. The concrete trap specific to this dataset.** DirectQuery pointed at the raw `rees46.events` table means every visual interaction fires a query against 411M rows — slow, and it burns through BigQuery quota fast. Making DirectQuery viable at all would require first materializing pre-aggregated summary tables in BigQuery (exactly what the 7 SQL files already compute), then DirectQuerying *those* small tables instead. But once the data is already reduced to a few dozen–few hundred rows per module, there's no real benefit left to keeping a live dependency — you'd be keeping the fragility without the freshness.

**Conclusion:** live connection is the right default in general, but every condition that makes it worth its cost — changing data, an audience needing current numbers, willingness to maintain a live dependency — is absent here. Import mode isn't the lazy option in this case; it has the stronger argument on every axis.

---

## Excel Workbook: Static Snapshot vs. Live Connection

Every figure in [`dashboards/ecommerce_analytics.xlsx`](ecommerce_analytics.xlsx) is hardcoded from verified query results rather than pulled live. In a real corporate environment, this workbook would typically be wired to BigQuery through a live connection (the BigQuery ODBC/JDBC driver, or Power Query's native BigQuery connector), so it refreshes automatically as new data lands.

That live-refresh model was deliberately skipped here, for the same reasoning as the Import mode decision above: a portfolio artifact needs to keep working and stay inspectable indefinitely, long after any live BigQuery connection stops being available. A self-contained static file beats something current but fragile for this particular purpose.

---

## Power BI Service Dashboard: Why It Wasn't Built

The original analytics plan (see `workflows/02_analytics_plan.md`) called for a second artifact beyond the Report: a Power BI Service Dashboard with pinned KPI tiles and Data Alerts (conversion rate floor, cart abandonment ceiling, revenue anomaly, and similar thresholds) that would notify the relevant team the moment a number crosses a line.

That layer was deliberately left unbuilt. Power BI Data Alerts only fire to recipients who hold a Power BI license inside the organization's own Fabric or Power BI tenancy, and everyone in the alert loop needs one. This project is a portfolio artifact disconnected from any real organization, so there's no licensed tenancy and no actual stakeholder to notify; standing up the alerting layer would just mean configuring infrastructure with nobody on the other end. The right time to build it is once there's a real deployment with genuine KPI-monitoring needs and licensed recipients to notify.

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

---

## Tooling Evolution: From a Hand-Built Bridge Script to Microsoft's Official Authoring Skill

**Every page in this report — all 6 visible pages plus the 3 hidden drillthrough/tooltip pages — was built before this project adopted any AI-specific Power BI authoring skill.** The entire build ran on a general-purpose coding agent (Claude Code), direct TMDL/PBIR file edits, and a single custom Python script (`tools/pbi_desktop_bridge_client.py`) that speaks JSON-RPC directly to Power BI Desktop's native named-pipe Desktop Bridge — a Microsoft preview feature, documented in [`dashboards/documentation/desktop_bridge.md`](documentation/desktop_bridge.md) — for live status checks, report reloads, and screenshot-based visual review.

That ordering was deliberate, not incidental. It demonstrates that this report-build workflow never depended on a purpose-built AI skill existing: a documented protocol, a coding agent, and careful file-level engineering were enough to build a full multi-page report with drillthrough pages, a tooltip page, custom Deneb visuals, dynamic HTML insight cards, and a self-documenting Data Dictionary — using nothing Power BI–specific beyond what Microsoft already ships in Desktop itself.

**Only after the report was complete** did this project install Microsoft's official [`powerbi-authoring`](https://github.com/microsoft/skills-for-fabric/tree/main/plugins/powerbi-authoring) plugin — specifically the [`powerbi-report-authoring`](https://github.com/microsoft/skills-for-fabric/blob/main/plugins/powerbi-authoring/skills/powerbi-report-authoring/SKILL.md) skill within it — for two reasons:

1. **Audit the already-built report.** The skill ships an offline PBIR validator (`powerbi-report-author validate`) and a metadata-lookup CLI (`catalog describe`, `formatting describe-object`) that check things the hand-built workflow had no systematic way to check: deprecated visual types, malformed role bindings, missing selectors, invalid formatting enum values. Running it against an already-complete report is a genuine quality check against a real baseline, not a rebuild.
2. **Raise the ceiling for future work.** The skill adds a capability the hand-built workflow deliberately avoided: creating brand-new visual containers directly rather than only editing containers placed by hand in Desktop, backed by that same offline validator as a safety net.

**Why the order matters:** this project treats *evaluating and adopting* AI tooling as a skill worth demonstrating in its own right — not "used an AI report builder to make a dashboard," but "shipped the work first on fundamentals, then deliberately layered in official tooling to save time and go deeper, evaluating it against a real, already-working baseline rather than taking it on faith." That evaluation habit — knowing when a tool earns its place in the workflow versus when it's just novel — is part of what this project is meant to show a reviewer, alongside the analytics work itself.

**Practical note on why the Python script stays in the repo.** `tools/pbi_desktop_bridge_client.py` is checked into version control — it works on any machine that clones this repo and has the Desktop Bridge preview feature enabled in Power BI Desktop, no extra install required. The skill's CLIs (`powerbi-report-author`, `powerbi-desktop`) are global npm packages installed at the user's machine level, outside the repo — they won't exist for anyone who clones this project without separately installing the skill. The script remains the more portable, dependency-free option and stays in the repo for that reason, even though live Desktop interaction going forward uses the skill's CLI instead.

**Installing the skill** (Claude Code):

```bash
/plugin marketplace add microsoft/skills-for-fabric
/plugin install powerbi-authoring@fabric-collection
```

Source: [`skills-for-fabric`](https://github.com/microsoft/skills-for-fabric/tree/main) (parent marketplace, install instructions for the focused bundle) · [`powerbi-report-authoring/SKILL.md`](https://github.com/microsoft/skills-for-fabric/blob/main/plugins/powerbi-authoring/skills/powerbi-report-authoring/SKILL.md) (the specific skill used here).
