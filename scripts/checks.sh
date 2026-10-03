#!/bin/bash
# Быстрые проверки (< 5 сек). Запускаются локально из pre-push и
# воспроизводятся на сервере как стадия "Fast Checks Replay".
set -euo pipefail

cd "$(dirname "$0")/.."
. scripts/_common.sh

require_python ruff "нужен линтер"
echo "[fast] interpreter: $PY"
echo "[fast] syntax"
"$PY" -m compileall -q server.py voicegen.py model_loader.py scripts/aggregate_report.py
echo "[fast] lint"
"$PY" -m ruff check .
echo "[fast] TODO"
bash ci-check.sh
echo "[fast] OK"