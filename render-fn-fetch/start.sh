#!/bin/bash
set -u
mkdir -p /data /opt/winpy
python3 -m http.server "${PORT:-10000}" --directory /data --bind 0.0.0.0 >/tmp/http.log 2>&1 &
echo '{"state":"wineboot"}' >/data/status.json
timeout 45 xvfb-run -a wineboot -u || true
echo '{"state":"installing_mt5"}' >/data/status.json
timeout 150 xvfb-run -a wine /opt/bootstrap/mt5setup.exe /auto || true
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
xvfb-run -a wine /opt/winpy/python.exe Z:\\opt\\bootstrap\\get-pip.py
xvfb-run -a wine /opt/winpy/python.exe -m pip install --no-cache-dir MetaTrader5
echo '{"state":"fetch_start"}' >/data/status.json
xvfb-run -a wine /opt/winpy/python.exe Z:\\app\\fetch.py || true
wait