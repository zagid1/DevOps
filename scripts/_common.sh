#!/bin/bash
# Общий помощник для скриптов проверок.
#
# pick_python MODULE печатает путь к интерпретатору, в котором реально
# импортируется MODULE. Выбирать "первый python в PATH" нельзя: на Windows
# в PATH лежит python из WindowsApps без установленных пакетов, и сервер
# на нём падал на `import fastapi`.
#
# Локальные venv проверяются первыми: git запускает хуки в окружении
# оболочки, а не в активированном venv, поэтому без этого трейлер
# X-Local-Checks всегда получался бы "fail".

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_pick_python() {
    local module="$1" c cand
    for cand in \
        "$REPO_ROOT/venv/bin/python" "$REPO_ROOT/.venv/bin/python" \
        "$REPO_ROOT/venv/Scripts/python.exe" "$REPO_ROOT/.venv/Scripts/python.exe"
    do
        if [ -x "$cand" ] && "$cand" -c "import $module" >/dev/null 2>&1; then
            command -v "$cand" 2>/dev/null || echo "$cand"
            return 0
        fi
    done
    for c in python3 python; do
        if command -v "$c" >/dev/null 2>&1 && "$c" -c "import $module" >/dev/null 2>&1; then
            command -v "$c"
            return 0
        fi
    done
    return 1
}

pick_python() { _pick_python "$1"; }

# require_python MODULE DESCRIPTION -> экспортирует PY или печатает ошибку
require_python() {
    local module="$1" description="$2"
    if ! PY="$(pick_python "$module")"; then
        echo "❌ не найден интерпретатор с пакетом '$module' ($description)" >&2
        echo "   python -m pip install -r requirements.txt -r requirements-dev.txt" >&2
        exit 1
    fi
    export PY
}

# wait_for_health BASE_URL PID — ждёт готовый HTTP-ответ, а не просто процесс.
# Возвращает 1, если процесс умер или не поднялся за отведённое время.
wait_for_health() {
    local base="$1" pid="$2" i
    for i in $(seq 1 "${READY_ATTEMPTS:-60}"); do
        if curl -sf "$base/health" >/dev/null 2>&1; then
            return 0
        fi
        kill -0 "$pid" 2>/dev/null || return 1   # процесс умер — ждать бессмысленно
        sleep 1
    done
    return 1
}