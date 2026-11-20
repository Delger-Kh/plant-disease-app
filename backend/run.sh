#!/usr/bin/env bash
# Backend-ийг бүх сүлжээнээс (утаснаас) хандах боломжтойгоор асаана.
set -e
cd "$(dirname "$0")"
if [ ! -d .venv ]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi
IP=$( (ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}') || true)
echo "API:          http://localhost:8000/docs"
[ -n "$IP" ] && echo "Утаснаас:     http://$IP:8000   (аппын Серверийн хаяг хэсэгт оруулна)"
exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
