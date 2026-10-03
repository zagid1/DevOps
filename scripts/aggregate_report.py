#!/usr/bin/env python3
"""Единый отчёт: аттестация локальных хуков (git-трейлеры) + статусы стадий Jenkins."""
import json, subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"; REPORTS.mkdir(exist_ok=True)

def git(*a): return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True).stdout

local = []
for line in git("log", "--no-merges", "-10",
                "--format=%h %s ¦ %(trailers:key=X-Local-Checks,valueonly,separator=, )").strip().splitlines():
    sha, _, rest = line.partition(" "); msg, _, tr = rest.partition(" ¦ "); tr = tr.strip()
    local.append({"commit": sha, "message": msg,
                  "local_checks": tr or "NO TRAILER (hooks bypassed or not installed)"})

server = {f.name[6:]: ("pass" if f.read_text().strip() == "0" else "fail")
          for f in sorted(REPORTS.glob("stage_*"))}

report = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "local_gates": local,
    "server_gates": server,
    "hook_bypassed_commits": [c["commit"] for c in local if "NO TRAILER" in c["local_checks"]],
    "overall": "pass" if server and all(v == "pass" for v in server.values()) else "fail",
    "policy": "hooks = fast feedback (bypassable); CI = enforcement (source of truth)",
}
(REPORTS / "ci-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps(report, indent=2, ensure_ascii=False))
if report["overall"] == "pass":
    (REPORTS / "verdict-ok").write_text("ok\n")