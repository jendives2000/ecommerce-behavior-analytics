"""
Creates the three supporting measures for the HTML Content KPI card test
(COVID Session Conversion Lift), live in the running Power BI Desktop
session via the Power BI Modeling MCP server (see tools/pbi_mcp_client.py).

Run with Power BI Desktop open on ecommerce_behavior_analytics.pbip and
a live local instance available (checked via connection_operations
ListLocalInstances beforehand).

Usage:
    python tools/pbi_create_html_card_measures.py
"""

from pbi_mcp_client import run_sequence, _extract_text

CONNECTION_STRING = "Data Source=localhost:50981;Application Name=MCP-PBIModeling"

MEASURE_DEFINITIONS = [
    {
        "Name": "COVID Lift Color",
        "TableName": "_Measures",
        "Expression": 'IF ( [COVID Session Conversion Lift] >= 0, "#2ECC71", "#E74C3C" )',
        "DisplayFolder": "HTML Cards",
        "Description": (
            "Hex color code (green or red) reflecting whether the COVID Session "
            "Conversion Lift measure is positive or negative. Feeds the badge "
            "background on the 'COVID Lift KPI Card' HTML Content visual - not "
            "meant to be used directly in a chart."
        ),
    },
    {
        "Name": "COVID Lift Direction Text",
        "TableName": "_Measures",
        "Expression": (
            "IF (\n"
            "    [COVID Session Conversion Lift] >= 0,\n"
            '    "Conversion rate improved after COVID-19 onset",\n'
            '    "Conversion rate declined after COVID-19 onset"\n'
            ")"
        ),
        "DisplayFolder": "HTML Cards",
        "Description": (
            "Plain-language read of whether conversion improved or declined "
            "after COVID-19 onset, driven by the sign of COVID Session "
            "Conversion Lift. Feeds the 'COVID Lift KPI Card' HTML Content "
            "visual - not meant to be used directly in a chart."
        ),
    },
    {
        "Name": "COVID Lift KPI Card",
        "TableName": "_Measures",
        "Expression": (
            "VAR LiftValue = FORMAT ( [COVID Session Conversion Lift], \"+0.0%;-0.0%;0.0%\" )\n"
            "VAR BadgeColor = [COVID Lift Color]\n"
            "VAR DirectionText = [COVID Lift Direction Text]\n"
            "RETURN\n"
            "    \"<div style='font-family:Segoe UI,sans-serif;text-align:center;padding:12px;'>\" &\n"
            "        \"<div style='font-size:12px;color:#666666;text-transform:uppercase;letter-spacing:0.5px;'>COVID Impact on Conversion</div>\" &\n"
            "        \"<div style='font-size:32px;font-weight:700;color:#1A1A2E;margin-top:4px;'>\" & LiftValue & \"</div>\" &\n"
            "        \"<div style='display:inline-block;margin-top:8px;padding:4px 12px;border-radius:12px;font-size:12px;font-weight:600;color:white;background-color:\" & BadgeColor & \";'>\" & DirectionText & \"</div>\" &\n"
            "    \"</div>\""
        ),
        "DisplayFolder": "HTML Cards",
        "Description": (
            "Self-contained HTML/CSS string combining the COVID Session "
            "Conversion Lift value, a color-coded badge, and a plain-language "
            "interpretation - built for the HTML Content custom visual, which "
            "renders whatever HTML a bound measure returns. Demonstrates a "
            "compound KPI card a native Power BI card visual can't produce in "
            "a single tile. Bind this measure to the visual's data role."
        ),
    },
]


if __name__ == "__main__":
    calls = [
        ("connection_operations", {"operation": "Connect", "ConnectionString": CONNECTION_STRING}),
        ("measure_operations", {"Operation": "Create", "Definitions": MEASURE_DEFINITIONS}),
    ]

    results = run_sequence(calls)

    print("Connect:", _extract_text(results[0]))
    print()
    print("Create measures:", _extract_text(results[1]))
