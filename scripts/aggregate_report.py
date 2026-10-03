#!/usr/bin/env python3
"""Единый отчёт: аттестация локальных хуков (git-трейлеры) + статусы стадий Jenkins.

Режимы:
  (по умолчанию)  полный — Jenkins. Учитывает reports/stage_*, пишет
                   reports/verdict-ok и НЕ влияет на код возврата: итог
                   объявляет отдельная стадия Final Verdict.
  --local-only     только раздел local_gates. Для GitHub Actions, где
                   серверных стадий нет, и для локального запуска.
"""
import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
REPORTS.mkdir(exist_ok=True)

# Стадии, которые обязан отработать Jenkinsfile. Стадия, не оставившая
# свой stage_* файл, считается проваленной, а не просто отсутствует:
# иначе упавший посреди пайплайна build выглядел бы зелёным, потому что
# all() по оставшимся ключам возвращает True.
EXPECTED_STAGES = ["fast_checks", "unit", "integration", "security", "load"]


def git(*a):
    # Без явной кодировки subprocess берёт кодировку локали (cp1251/cp866 на
    # Windows), git отдаёт UTF-8 — русские коммиты превращались в мусор, и
    # разделитель " ¦ " переставал совпадать. Из-за этого КАЖДЫЙ коммит
    # помечался как NO TRAILER и попадал в hook_bypassed_commits.
    return subprocess.run(
        ["git", *a],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    ).stdout


parser = argparse.ArgumentParser(description="Единый отчёт по хукам и стадиям CI")
parser.add_argument(
    "--local-only",
    action="store_true",
    help="не учитывать серверные стадии Jenkins (для GitHub Actions и локального запуска)",
)
args = parser.parse_args()

# Разделитель — табуляция, а не не-ASCII символ: при декодировании вывода
# git в кодировке локали не-ASCII разделитель рассыпался и partition()
# переставал совпадать.
#
# separator=%x2C, а не separator=", ": запятая внутри значения конфликтует
# с запятой как разделителем аргументов атома, и git не раскрывал
# %(trailers:...) вовсе — подставлял его буквально. %x2C — hex-экранирование
# той же запятой. Плюс значение не должно содержать перевод строки, иначе
# splitlines() разорвал бы строку отчёта пополам.
FMT = "--format=%h%x09%s%x09%(trailers:key=X-Local-Checks,valueonly,separator=%x2C)"
log_out = git("log", "--no-merges", "-10", FMT).strip()

local = []
for line in log_out.splitlines():
    parts = line.split("\t", 2)
    if len(parts) < 3:
        continue
    sha, msg, tr = parts[0], parts[1], parts[2].strip()
    local.append({
        "commit": sha,
        "message": msg,
        "local_checks": tr or "NO TRAILER (hooks bypassed or not installed)",
    })

if args.local_only:
    server = {}
    overall = "pass"
    scope = "local-gates-only"
else:
    observed = {
        f.name[6:]: ("pass" if f.read_text(encoding="utf-8").strip() == "0" else "fail")
        for f in sorted(REPORTS.glob("stage_*"))
    }
    server = {name: observed.get(name, "missing") for name in EXPECTED_STAGES}
    server.update({n: v for n, v in observed.items() if n not in EXPECTED_STAGES})
    overall = "pass" if all(v == "pass" for v in server.values()) else "fail"
    scope = "full"

bypassed = [c["commit"] for c in local if "NO TRAILER" in c["local_checks"]]

report = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "scope": scope,
    "local_gates": local,
    "server_gates": server,
    "hook_bypassed_commits": bypassed,
    "overall": overall,
    "policy": "hooks = fast feedback (bypassable); CI = enforcement (source of truth)",
}
(REPORTS / "ci-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(report, indent=2, ensure_ascii=False))  # noqa: T201

if not args.local_only:
    # verdict-ok всегда пересоздаётся, иначе успешный прогон оставляет метку
    # "ok" на диске и следующий упавший build наследует зелёный статус.
    verdict = REPORTS / "verdict-ok"
    if overall == "pass":
        verdict.write_text("ok\n", encoding="utf-8")
    elif verdict.exists():
        verdict.unlink()

sys.exit(0 if overall == "pass" else 1)
