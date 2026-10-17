#!/bin/bash
set -u
mkdir -p /data
echo '{"state":"starting"}' >/data/status.json
python3 -m http.server "${PORT:-10000}" --directory /data --bind 0.0.0.0 >/tmp/http.log 2>&1 &
for n in 1 2 3; do
  echo "attempt $n" >>/data/fetch.log
  xvfb-run -a wine /opt/winpy/pythonw.exe Z:\\app\\fetch.py >>/data/fetch.log 2>&1 && break
  sleep 10
done
wait