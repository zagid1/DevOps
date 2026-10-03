#!/bin/bash
# Интеграционный тест: поднимает реальный сервер и бьёт по HTTP.
#
# VOICEAPI_SKIP_MODEL_LOAD=1 — ключевой момент: тест проверяет
# HTTP-поверхность, а не транскрипцию. Без флага фоновая загрузка GigaAM
# тянула бы многогигабайтные веса на каждой стадии Jenkins.
# Свой порт — чтобы не конфликтовать с нагрузочным тестом следующей стадии.
set -uo pipefail

cd "$(dirname "$0")/.."
. scripts/_common.sh

require_python fastapi "нужен сервер"

PORT="${INTEGRATION_PORT:-8101}"
BASE="http://127.0.0.1:${PORT}"
export PORT VOICEAPI_SKIP_MODEL_LOAD=1

"$PY" server.py >/tmp/integration_server.log 2>&1 &
SRV=$!
trap 'kill "$SRV" >/dev/null 2>&1; wait "$SRV" 2>/dev/null' EXIT

if ! wait_for_health "$BASE" "$SRV"; then
    echo "server did not become ready on port ${PORT}"
    tail -20 /tmp/integration_server.log
    exit 1
fi

curl -sf "$BASE/health" | grep -q '"status":"healthy"' || { echo "bad /health"; exit 1; }
curl -sf "$BASE/v1/models" | grep -q 'GigaAM' || { echo "bad /v1/models"; exit 1; }

# Неизвестная модель обязана отвергаться запросом 400, а не падать.
# Файл нужен реальный: curl не умеет читать /dev/null как вложение.
# Имя относительное — нативный curl для Windows не понимает MSYS-пути
# (/tmp/...) и падает с "Read error", т.е. с кодом 000 вместо ответа.
UPLOAD=".tmp-integration-upload.wav"
trap 'kill "$SRV" >/dev/null 2>&1; wait "$SRV" 2>/dev/null; rm -f "$UPLOAD"' EXIT
printf 'RIFFdummy' > "$UPLOAD"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -F "model=not-a-model" -F "file=@${UPLOAD};filename=a.wav" \
    "$BASE/v1/audio/transcriptions")
[ "$code" = "400" ] || { echo "expected 400 for unknown model, got $code"; exit 1; }

echo "✅ integration passed (port ${PORT})"