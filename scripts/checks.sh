#!/bin/bash
set -e
PY=$(command -v python3 || command -v python)
echo "[fast] syntax";  "$PY" -m compileall -q server.py voicegen.py model_loader.py
echo "[fast] lint";    ruff check .
echo "[fast] TODO";    bash ci-check.sh
echo "[fast] OK"