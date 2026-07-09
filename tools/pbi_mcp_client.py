"""
Minimal MCP client for the Power BI Modeling MCP server, driven directly
over stdio. Bypasses VS Code/Claude Code's native MCP registration (which
does not pick up this particular extension-bundled server) by speaking
the MCP JSON-RPC protocol to the executable as a plain subprocess.

Usage:
    python tools/pbi_mcp_client.py <tool_name> '<json_arguments>'

Example:
    python tools/pbi_mcp_client.py connection_operations '{"operation": "ConnectFolder", "FolderPath": "dashboards/ecommerce_behavior_analytics.SemanticModel"}'
    python tools/pbi_mcp_client.py dax_query_operations '{"operation": "Execute", "query": "EVALUATE ROW(\"x\", 1+1)"}'

Each invocation starts a fresh process, so any connection established via
connection_operations does not persist between separate calls to this
script. For a sequence of related calls (e.g. connect, then query),
call run_sequence() from a custom script instead of the CLI entry point.
"""

import json
import subprocess
import sys
import threading

EXE_PATH = (
    r"C:\Users\Jean-Yves TRAN\.vscode\extensions"
    r"\analysis-services.powerbi-modeling-mcp-0.4.0-win32-x64"
    r"\server\powerbi-modeling-mcp.exe"
)


def _start_process():
    return subprocess.Popen(
        [EXE_PATH, "--start"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )


def _send(proc, msg):
    proc.stdin.write(json.dumps(msg) + "\n")
    proc.stdin.flush()


def _read_line(proc, timeout=10):
    result = [None]

    def target():
        result[0] = proc.stdout.readline()

    t = threading.Thread(target=target)
    t.daemon = True
    t.start()
    t.join(timeout)
    return result[0]


def _handshake(proc):
    _send(proc, {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "claude-code-manual-client", "version": "1.0.0"},
        },
    })
    _read_line(proc)
    _send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})


def call_tool(tool_name, arguments, proc=None, call_id=2):
    """Call one tool. If proc is None, starts and tears down its own process."""
    owns_process = proc is None
    if owns_process:
        proc = _start_process()
        _handshake(proc)

    _send(proc, {
        "jsonrpc": "2.0", "id": call_id, "method": "tools/call",
        "params": {"name": tool_name, "arguments": {"request": arguments}},
    })
    resp = _read_line(proc)

    if owns_process:
        proc.terminate()

    if resp is None:
        return {"error": "No response (timeout)"}
    return json.loads(resp)


def run_sequence(calls):
    """Run multiple tool calls against ONE persistent connection/process.

    calls: list of (tool_name, arguments_dict) tuples.
    Returns a list of parsed responses, in order.
    """
    proc = _start_process()
    _handshake(proc)
    results = []
    for i, (tool_name, arguments) in enumerate(calls, start=2):
        results.append(call_tool(tool_name, arguments, proc=proc, call_id=i))
    proc.terminate()
    return results


def _extract_text(response):
    """Pull the plain-text/JSON payload out of a tools/call response envelope."""
    if "error" in response:
        return response
    content = response.get("result", {}).get("content", [])
    texts = [c.get("text", "") for c in content if "text" in c]
    return "\n".join(texts) if texts else response


def _extract_csv_result(response):
    """Pull the DAX query result CSV out of a dax_query_operations Execute response, if present."""
    if "error" in response:
        return None
    content = response.get("result", {}).get("content", [])
    for c in content:
        if c.get("type") == "resource" and c.get("resource", {}).get("mimeType") == "text/csv":
            return c["resource"]["text"].strip()
    return None


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    tool_name = sys.argv[1]
    arguments = json.loads(sys.argv[2])
    result = call_tool(tool_name, arguments)
    print(_extract_text(result))
