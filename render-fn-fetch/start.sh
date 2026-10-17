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
  kill -TERM "$p" 2>/dev/null || true; sleep 2; kill -KILL "$p" 2>/dev/null || true
  wineserver -k 2>/dev/null || true; wait "$p" 2>/dev/null || true; return 0
}
echo '{"state":"wineboot"}' >/data/status.json
run_limited 18 wineboot -u
echo '{"state":"downloading_terminal"}' >/data/status.json
wget -q "$MT5_TARBALL_URL" -O /tmp/mt5-portable.tgz
if [ "$(sha256sum /tmp/mt5-portable.tgz | awk '{print $1}')" != "7c803594a78fe6ae543736b7b3e70ca8ec5ff53de2ae446dc86f07cec9b424fe" ]; then
  echo '{"state":"error","error":"portable bundle checksum mismatch"}' >/data/status.json; wait; exit 0
fi
mkdir -p "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5"
tar -xzf /tmp/mt5-portable.tgz -C /tmp
cp -a /tmp/mt5-portable/. "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5/"
if [ ! -f "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
  echo '{"state":"error","error":"terminal copy failed"}' >/data/status.json; wait; exit 0
fi
echo '{"state":"installing_python"}' >/data/status.json
rm -rf /opt/winpy/*; unzip -q /opt/bootstrap/py.zip -d /opt/winpy
sed -i 's/^#import site/import site/' /opt/winpy/python311._pth
printf '\nLib\\site-packages\n' >> /opt/winpy/python311._pth
run_limited 60 wine /opt/winpy/python.exe Z:\\opt\\bootstrap\\get-pip.py
run_limited 90 wine /opt/winpy/python.exe -m pip install --no-cache-dir MetaTrader5
echo '{"state":"fetch_start"}' >/data/status.json
xvfb-run -a wine /opt/winpy/python.exe Z:\\app\\fetch.py || true
wait