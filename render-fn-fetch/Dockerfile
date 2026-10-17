FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive WINEDEBUG=-all WINEPREFIX=/opt/mt5prefix WINEDLLOVERRIDES=mscoree,mshtml=
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget curl gnupg unzip xvfb python3 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update && apt-get install -y --install-recommends winehq-staging && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app /data /opt/winpy && \
    wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe && \
    (xvfb-run -a wineboot -u || true) && \
    (timeout 150 xvfb-run -a wine /tmp/mt5setup.exe /auto || true) && \
    test -f "/opt/mt5prefix/drive_c/Program Files/MetaTrader 5/terminal64.exe" && \
    wget -q https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip -O /tmp/py.zip && \
    unzip -q /tmp/py.zip -d /opt/winpy && \
    sed -i 's/^#import site/import site/' /opt/winpy/python311._pth && \
    printf '\nLib\\site-packages\n' >> /opt/winpy/python311._pth && \
    wget -q https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py && \
    xvfb-run -a wine /opt/winpy/python.exe Z:\\tmp\\get-pip.py && \
    xvfb-run -a wine /opt/winpy/python.exe -m pip install --no-cache-dir MetaTrader5
COPY render-fn-fetch/fetch.py /app/fetch.py
COPY render-fn-fetch/start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
