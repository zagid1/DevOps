#!/bin/bash
python3 server.py >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV >/dev/null 2>&1' EXIT
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8000/health >/dev/null && break; sleep 1; done
N=100; START=$(date +%s%N)
for _ in $(seq 1 $N); do curl -sf http://127.0.0.1:8000/health >/dev/null || exit 1; done
AVG_MS=$(( ($(date +%s%N)-START)/N/1000000 ))
echo "requests=$N avg=${AVG_MS}ms"
[ "$AVG_MS" -lt 500 ] || { echo "❌ load threshold exceeded"; exit 1; }
echo "✅ load test passed"