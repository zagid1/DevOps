#!/bin/bash
python3 server.py >/dev/null 2>&1 & SRV=$!
trap 'kill $SRV >/dev/null 2>&1' EXIT
ok=0; for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8000/health >/dev/null && { ok=1; break; }; sleep 1; done
[ "$ok" = 1 ] || { echo "server not started"; exit 1; }
curl -sf http://127.0.0.1:8000/health | grep -q healthy || exit 1
curl -sf http://127.0.0.1:8000/v1/models | grep -q GigaAM || exit 1
echo "✅ integration passed"