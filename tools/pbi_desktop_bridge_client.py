"""
Minimal client for the Power BI Desktop Bridge (Preview) - a named-pipe
JSON-RPC 2.0 server built directly into Power BI Desktop, distinct from
the Modeling MCP server (see pbi_mcp_client.py, which only reaches the
Analysis Services / semantic model layer via a separate exe). The Desktop
Bridge is Microsoft's own mechanism for external tools to reach a running
Desktop session - per the docs, intended for report-definition read/write
and screenshot capture, which is the report-layer gap pbi_mcp_client.py
cannot cover.

Protocol: Content-Length-delimited JSON-RPC 2.0 frames over a Windows
named pipe \\.\pipe\pbi-desktop-bridge-<processId>. Must be enabled in
Power BI Desktop: File > Options and settings > Options > Preview
Features > "Enable external tool access to Power BI Desktop through
secure local APIs".

Usage:
    python tools/pbi_desktop_bridge_client.py <method_name> ['<json_args>']

Example:
    python tools/pbi_desktop_bridge_client.py bridge.manifest
"""

import json
import subprocess
import sys


def _find_desktop_pid():
    result = subprocess.run(
        [
            "powershell", "-NoProfile", "-Command",
            "(Get-Process -Name PBIDesktop -ErrorAction SilentlyContinue "
            "| Select-Object -First 1).Id",
        ],
        capture_output=True, text=True,
    )
    pid = result.stdout.strip()
    if not pid:
        raise RuntimeError("Power BI Desktop (PBIDesktop.exe) is not running.")
    return pid


def _pipe_path(pid):
    return r"\\.\pipe\pbi-desktop-bridge-" + pid


def _write_frame(pipe, payload):
    body = json.dumps(payload).encode("utf-8")
    header = ("Content-Length: %d\r\n\r\n" % len(body)).encode("ascii")
    pipe.write(header + body)
    pipe.flush()


def _read_frame(pipe):
    header = b""
    while not header.endswith(b"\r\n\r\n"):
        b = pipe.read(1)
        if not b:
            raise RuntimeError("Connection closed before headers were read.")
        header += b
    content_length = None
    for line in header.decode("ascii").split("\r\n"):
        if line.lower().startswith("content-length:"):
            content_length = int(line.split(":", 1)[1].strip())
    if content_length is None:
        raise RuntimeError("Response is missing the Content-Length header.")
    body = b""
    while len(body) < content_length:
        chunk = pipe.read(content_length - len(body))
        if not chunk:
            raise RuntimeError("Connection closed before the response body was fully read.")
        body += chunk
    return json.loads(body.decode("utf-8"))


_next_id = 0


def call_method(method, args=None, pipe_path=None):
    global _next_id
    if pipe_path is None:
        pid = _find_desktop_pid()
        pipe_path = _pipe_path(pid)
    _next_id += 1
    request = {
        "jsonrpc": "2.0",
        "id": _next_id,
        "method": method,
        "params": {"args": args or {}},
    }
    with open(pipe_path, "r+b", buffering=0) as pipe:
        _write_frame(pipe, request)
        return _read_frame(pipe)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    method_name = sys.argv[1]
    method_args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    response = call_method(method_name, method_args)
    print(json.dumps(response, indent=2))
