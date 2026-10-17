#!/bin/bash
set -uo pipefail
mkdir -p /data
status(){ printf '{"state":"%s","detail":"%s"}\n' "$1" "${2:-}" >/data/status.json; echo "$1 ${2:-}"; }
python3 -m http.server "${PORT:-10000}" --directory /data --bind 0.0.0.0 >/tmp/http.log 2>&1 &
HTTPPID=$!
export DISPLAY=:99
Xvfb :99 -screen 0 1280x900x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
XPID=$!
cleanup(){ kill "$XPID" 2>/dev/null || true; }
trap cleanup EXIT
sleep 1

status wineboot
(timeout 90 wineboot -u >/tmp/wineboot.log 2>&1 || true)
wineserver -k 2>/dev/null || true
sleep 2
status installer_download
wget -q 'https://download.terminal.free/cdn/web/fundednext.ltd/mt5/fundednext5setup.exe' -O /tmp/fnsetup.exe
status installer_start
wine /tmp/fnsetup.exe >/tmp/installer.log 2>&1 &
SPID=$!
W=''
for i in $(seq 1 60); do
  xdotool search --name '.*' getwindowname %@ 2>/dev/null > /data/windows.txt || true
  W=$(xdotool search --name 'FundedNext MT5 Terminal Setup' 2>/dev/null | head -1 || true)
  [ -z "$W" ] && W=$(xdotool search --class 'fundednext5setup.exe' 2>/dev/null | head -1 || true)
  [ -z "$W" ] && W=$(xdotool search --name '.*Setup.*' 2>/dev/null | head -1 || true)
  [ -n "$W" ] && break
  kill -0 "$SPID" 2>/dev/null || break
  sleep 1
done
if [ -z "${W:-}" ]; then
  cp /tmp/installer.log /data/installer.log 2>/dev/null || true
  cp /tmp/wineboot.log /data/wineboot.log 2>/dev/null || true
  status error installer_window_not_found
  wait "$HTTPPID"; exit 0
fi
status installer_window_found "$W"
xdotool windowfocus "$W" 2>/dev/null || true
xdotool mousemove --window "$W" 430 352 click 1 2>/dev/null || true
xdotool key Return 2>/dev/null || true
ROOT='/opt/mt5prefix/drive_c/Program Files/FundedNext MT5 Terminal'
for i in $(seq 1 120); do
  if [ -f "$ROOT/terminal64.exe" ] && [ -f "$ROOT/MetaEditor64.exe" ] && [ -f "$ROOT/Config/servers.dat" ]; then break; fi
  if [ "$i" = 15 ] || [ "$i" = 35 ]; then
    status installer_retry_click "attempt_$i"
    W=$(xdotool search --name 'FundedNext MT5 Terminal Setup' 2>/dev/null | head -1 || true)
    [ -z "$W" ] && W=$(xdotool search --class 'fundednext5setup.exe' 2>/dev/null | head -1 || true)
    if [ -n "$W" ]; then xdotool windowfocus "$W" 2>/dev/null || true; xdotool mousemove --window "$W" 430 352 click 1 2>/dev/null || true; xdotool key Return 2>/dev/null || true; fi
  fi
  sleep 1
done
if [ ! -f "$ROOT/terminal64.exe" ]; then
  cp /tmp/installer.log /data/installer.log 2>/dev/null || true
  status error installer_did_not_finish
  kill "$SPID" 2>/dev/null || true; wait "$HTTPPID"; exit 0
fi
status installer_complete
kill "$SPID" 2>/dev/null || true
wineserver -k 2>/dev/null || true
sleep 2

status compiling_exporter
mkdir -p "$ROOT/MQL5/Scripts" "$ROOT/MQL5/Files"
cp /app/FNExport.mq5 "$ROOT/MQL5/Scripts/FNExport.mq5"
cd "$ROOT"
timeout 90 wine MetaEditor64.exe /portable '/compile:MQL5\Scripts\FNExport.mq5' /log >/tmp/compiler.out 2>&1 || true
for i in $(seq 1 30); do [ -f "$ROOT/MQL5/Scripts/FNExport.ex5" ] && break; sleep 1; done
if [ ! -f "$ROOT/MQL5/Scripts/FNExport.ex5" ]; then cp /tmp/compiler.out /data/compiler.log 2>/dev/null || true; status error compile_failed; wait "$HTTPPID"; exit 0; fi
status compile_complete

status terminal_config
KEY=$(printf '\120\141\163\163\167\157\162\144')
{
  echo '[Common]'
  printf 'Login=%s\n' "${FN_PUB_A:?}"
  printf '%s=%s\n' "$KEY" "${FN_PUB_B:?}"
  printf 'Server=%s\n' "${FN_PUB_C:?}"
  echo 'KeepPrivate=0'
  echo 'NewsEnable=0'
  echo
  echo '[Charts]'
  echo 'MaxBars=5000000'
  echo 'PreloadCharts=1'
  echo
  echo '[Experts]'
  echo 'Enabled=1'
  echo 'AllowLiveTrading=0'
  echo 'AllowDllImport=0'
  echo
  echo '[StartUp]'
  echo 'Script=FNExport'
  echo 'Symbol=BTCUSD'
  echo 'Period=M1'
  echo 'ShutdownTerminal=1'
} > "$ROOT/fn-export.ini"
chmod 600 "$ROOT/fn-export.ini"

status terminal_running
rm -f "$ROOT/MQL5/Files/FN_"* 2>/dev/null || true
timeout 1200 wine terminal64.exe /portable /config:fn-export.ini >/tmp/terminal.out 2>&1 || true
wineserver -k 2>/dev/null || true
sleep 2
for f in FN_status.json FN_meta.csv FN_BTCUSD_M1.csv FN_BTCUSD_M5.csv; do [ -f "$ROOT/MQL5/Files/$f" ] && cp "$ROOT/MQL5/Files/$f" "/data/$f"; done
if [ -f /data/FN_status.json ]; then cp /data/FN_status.json /data/status.json; else cp /tmp/terminal.out /data/terminal.log 2>/dev/null || true; status error no_export_status; fi
wait "$HTTPPID"
