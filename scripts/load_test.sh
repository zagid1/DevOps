#!/bin/bash
# Нагрузочный тест: N последовательных запросов к /health, проверка
# среднего времени ответа.
#
# Время меряется через curl -w '%{time_total}', а не через date +%s%N:
# %N поддерживает только GNU date, на macOS/BSD выведет литерал "N"
# и арифметика сломается.
set -uo pipefail

cd "$(dirname "$0")/.."
. scripts/_common.sh

require_python fastapi "нужен сервер"

PORT="${LOAD_PORT:-8102}"
BASE="http://127.0.0.1:${PORT}"
N="${LOAD_REQUESTS:-100}"
THRESHOLD_MS="${LOAD_THRESHOLD_MS:-500}"
export PORT VOICEAPI_SKIP_MODEL_LOAD=1

"$PY" server.py >/tmp/load_server.log 2>&1 &
SRV=$!
trap 'kill "$SRV" >/dev/null 2>&1; wait "$SRV" 2>/dev/null' EXIT

if ! wait_for_health "$BASE" "$SRV"; then
    echo "server did not become ready on port ${PORT}"
    tail -20 /tmp/load_server.log
    exit 1
fi

total=0
failed=0
for _ in $(seq 1 "$N"); do
    t=$(curl -sf -o /dev/null -w '%{time_total}' "$BASE/health") || { failed=$((failed + 1)); continue; }
    total=$(awk -v a="$total" -v b="$t" 'BEGIN { printf "%.6f", a + b }')
done

if [ "$failed" -ne 0 ]; then
    echo "❌ $failed of $N requests failed"
    exit 1
fi

AVG_MS=$(awk -v t="$total" -v n="$N" 'BEGIN { printf "%.1f", (t / n) * 1000 }')
echo "requests=$N avg=${AVG_MS}ms threshold=${THRESHOLD_MS}ms"

if awk -v a="$AVG_MS" -v b="$THRESHOLD_MS" 'BEGIN { exit !(a < b) }'; then
    echo "✅ load test passed"
else
    echo "❌ load threshold exceeded: ${AVG_MS}ms >= ${THRESHOLD_MS}ms"
    exit 1
fi