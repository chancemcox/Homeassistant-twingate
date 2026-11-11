#!/usr/bin/env python3
"""Minimal health/status HTTP server for the Twingate Connector add-on."""

from __future__ import annotations

import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError, HTTPError
from urllib.request import urlopen

STATUS_FILE = Path(os.environ.get("TWINGATE_STATUS_FILE", "/data/twingate-status.json"))
PORT = int(os.environ.get("TWINGATE_HEALTH_PORT", "0"))
NETWORK = os.environ.get("TWINGATE_NETWORK", "").strip()


def read_status() -> dict:
    default = {
        "ok": False,
        "connector_running": False,
        "controller_reachable": False,
        "restarts": 0,
        "started_at": None,
        "last_restart_at": None,
        "last_check_at": None,
        "message": "starting",
        "network": NETWORK or None,
    }
    try:
        data = json.loads(STATUS_FILE.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            default.update(data)
    except (OSError, json.JSONDecodeError):
        pass
    return default


def controller_probe() -> bool:
    if not NETWORK:
        return False
    url = f"https://{NETWORK}.twingate.com/api/v1/public_keys"
    try:
        with urlopen(url, timeout=8) as response:  # noqa: S310 - fixed Twingate controller URL
            return 200 <= response.status < 300
    except (URLError, HTTPError, TimeoutError, ValueError):
        return False


def html_page(status: dict) -> bytes:
    ok = bool(status.get("ok"))
    color = "#0f7b3a" if ok else "#a32020"
    label = "Connected" if ok else "Degraded"
    rows = [
        ("Network", status.get("network") or "—"),
        ("Connector process", "running" if status.get("connector_running") else "stopped"),
        ("Controller reachable", "yes" if status.get("controller_reachable") else "no"),
        ("Restarts", status.get("restarts", 0)),
        ("Started", status.get("started_at") or "—"),
        ("Last restart", status.get("last_restart_at") or "—"),
        ("Last check", status.get("last_check_at") or "—"),
        ("Message", status.get("message") or "—"),
    ]
    body_rows = "".join(
        f"<tr><th>{key}</th><td>{value}</td></tr>" for key, value in rows
    )
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="15" />
  <title>Twingate Connector</title>
  <style>
    :root {{
      --bg: #0b1220;
      --panel: #121a2b;
      --text: #e8eefc;
      --muted: #9aa8c7;
      --accent: {color};
    }}
    body {{
      margin: 0;
      font-family: "Segoe UI", system-ui, sans-serif;
      background:
        radial-gradient(1200px 600px at 10% -10%, #1b2a4a 0%, transparent 55%),
        radial-gradient(900px 500px at 100% 0%, #13261c 0%, transparent 45%),
        var(--bg);
      color: var(--text);
      min-height: 100vh;
    }}
    main {{
      max-width: 720px;
      margin: 0 auto;
      padding: 2.5rem 1.25rem 3rem;
    }}
    h1 {{
      margin: 0 0 0.35rem;
      font-size: 1.75rem;
      letter-spacing: -0.02em;
    }}
    .sub {{
      color: var(--muted);
      margin-bottom: 1.5rem;
    }}
    .badge {{
      display: inline-block;
      background: color-mix(in srgb, var(--accent) 22%, transparent);
      color: #fff;
      border: 1px solid color-mix(in srgb, var(--accent) 55%, #fff);
      border-radius: 999px;
      padding: 0.35rem 0.85rem;
      font-weight: 600;
      margin-bottom: 1.25rem;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      background: color-mix(in srgb, var(--panel) 88%, transparent);
      border: 1px solid #24314d;
      border-radius: 12px;
      overflow: hidden;
    }}
    th, td {{
      text-align: left;
      padding: 0.85rem 1rem;
      border-bottom: 1px solid #24314d;
      vertical-align: top;
    }}
    th {{
      width: 40%;
      color: var(--muted);
      font-weight: 500;
    }}
    tr:last-child th, tr:last-child td {{
      border-bottom: 0;
    }}
  </style>
</head>
<body>
  <main>
    <div class="badge">{label}</div>
    <h1>Twingate Connector</h1>
    <p class="sub">Home Assistant add-on status · auto-refreshes every 15s</p>
    <table>{body_rows}</table>
  </main>
</body>
</html>
"""
    return html.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        return

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        status = read_status()

        if path in ("/health", "/healthz"):
            # Supervisor watchdog: any HTTP status < 300 counts as healthy.
            # Require the connector process itself; controller blips should not
            # force a full add-on restart.
            code = 200 if status.get("connector_running") else 503
            payload = {
                "status": "ok" if code == 200 else "error",
                "connector_running": bool(status.get("connector_running")),
                "controller_reachable": bool(status.get("controller_reachable")),
                "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
            self._send(code, json.dumps(payload).encode("utf-8"), "application/json")
            return

        if path in ("/status", "/api/status"):
            self._send(200, json.dumps(status, indent=2).encode("utf-8"), "application/json")
            return

        if path in ("/", "/index.html"):
            self._send(200, html_page(status), "text/html; charset=utf-8")
            return

        self._send(404, b'{"error":"not found"}', "application/json")


def main() -> None:
    if PORT <= 0:
        raise SystemExit(
            "TWINGATE_HEALTH_PORT must be set to the Supervisor-assigned ingress port"
        )

    # Warm controller reachability once so the first page render is useful.
    status = read_status()
    status["controller_reachable"] = controller_probe()
    status["last_check_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATUS_FILE.write_text(json.dumps(status), encoding="utf-8")
    except OSError:
        pass

    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
