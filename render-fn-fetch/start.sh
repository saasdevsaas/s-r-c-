#!/bin/bash
set -u
mkdir -p /data
echo '{"state":"starting"}' >/data/status.json
: >/data/fetch.log
python3 -m http.server "${PORT:-10000}" --directory /data --bind 0.0.0.0 >/tmp/http.log 2>&1 &
for n in 1 2 3; do
  echo "attempt $n" >>/data/fetch.log
  xvfb-run -a wine /opt/winpy/python.exe Z:\\app\\fetch.py && break
  echo "attempt $n failed" >>/data/fetch.log
  sleep 10
done
wait