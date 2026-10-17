#!/bin/bash
set -u
mkdir -p /data /opt/winpy
python3 -m http.server "${PORT:-10000}" --directory /data --bind 0.0.0.0 >/tmp/http.log 2>&1 &
run_limited() {
  secs="$1"; shift
  xvfb-run -a "$@" & p=$!
  for ((i=0;i<secs;i++)); do
    kill -0 "$p" 2>/dev/null || { wait "$p" 2>/dev/null || true; return 0; }
    sleep 1
  done
  kill -TERM "$p" 2>/dev/null || true
  sleep 2
  kill -KILL "$p" 2>/dev/null || true
  wineserver -k 2>/dev/null || true
  wait "$p" 2>/dev/null || true
  return 0
}
echo '{"state":"wineboot"}' >/data/status.json
run_limited 18 wineboot -u
echo '{"state":"installing_mt5"}' >/data/status.json
run_limited 90 wine /opt/bootstrap/mt5setup.exe /auto
if [ ! -f "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
  echo '{"state":"error","error":"terminal64.exe not installed"}' >/data/status.json
  wait
  exit 0
fi
echo '{"state":"installing_python"}' >/data/status.json
rm -rf /opt/winpy/*
unzip -q /opt/bootstrap/py.zip -d /opt/winpy
sed -i 's/^#import site/import site/' /opt/winpy/python311._pth
printf '\nLib\\site-packages\n' >> /opt/winpy/python311._pth
run_limited 60 wine /opt/winpy/python.exe Z:\\opt\\bootstrap\\get-pip.py
run_limited 90 wine /opt/winpy/python.exe -m pip install --no-cache-dir MetaTrader5
echo '{"state":"fetch_start"}' >/data/status.json
xvfb-run -a wine /opt/winpy/python.exe Z:\\app\\fetch.py || true
wait