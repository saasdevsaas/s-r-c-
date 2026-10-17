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
run_limited 100 wineboot -u
if [ ! -f "/opt/mt5prefix/drive_c/windows/system32/kernel32.dll" ]; then
  echo '{"state":"error","error":"wine prefix incomplete"}' >/data/status.json; wait; exit 0
fi
echo '{"state":"downloading_terminal"}' >/data/status.json
wget -q "$MT5_TARBALL_URL" -O /tmp/mt5-portable.tgz
if [ "$(sha256sum /tmp/mt5-portable.tgz | awk '{print $1}')" != "7c803594a78fe6ae543736b7b3e70ca8ec5ff53de2ae446dc86f07cec9b424fe" ]; then
  echo '{"state":"error","error":"portable bundle checksum mismatch"}' >/data/status.json; wait; exit 0
fi
mkdir -p "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5"
tar -xzf /tmp/mt5-portable.tgz -C /tmp
cp -a /tmp/mt5-portable/. "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5/"
echo '{"state":"installing_python"}' >/data/status.json
rm -rf /opt/winpy/*; unzip -q /opt/bootstrap/py.zip -d /opt/winpy
sed -i 's/^#import site/import site/' /opt/winpy/python311._pth
printf '\nLib\\site-packages\n' >> /opt/winpy/python311._pth
mkdir -p /opt/winpy/Lib/site-packages /tmp/wheels
wget -q https://files.pythonhosted.org/packages/c5/31/7fc6239c12bce7e931463251cca4426c465e1876ba3cc785402ef4dd8f4e/numpy-2.4.6-cp311-cp311-win_amd64.whl -O /tmp/wheels/numpy.whl
wget -q https://files.pythonhosted.org/packages/c5/46/2d85a3ea15a93123e6b4c49ff600e59c0bb9d0c3fc84462091595b76d8ff/metatrader5-5.0.6231-cp311-cp311-win_amd64.whl -O /tmp/wheels/mt5.whl
echo '1e254a00cdf42b1e4d5b3d68d33af63268d41340d8885df2ab6470f2e1500147  /tmp/wheels/numpy.whl' | sha256sum -c -
echo '1e0fb5e43437f426be3e5aef614f6798a918377db4cdb380593a66d1908f918d  /tmp/wheels/mt5.whl' | sha256sum -c -
unzip -q /tmp/wheels/numpy.whl -d /opt/winpy/Lib/site-packages
unzip -q /tmp/wheels/mt5.whl -d /opt/winpy/Lib/site-packages
echo '{"state":"fetch_start"}' >/data/status.json
xvfb-run -a wine /opt/winpy/python.exe Z:\\app\\fetch.py || true
wait