FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive WINEDEBUG=-all WINEPREFIX=/opt/mt5prefix WINEDLLOVERRIDES=mscoree,mshtml=
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget curl gnupg xvfb xdotool python3 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update && apt-get install -y --install-recommends winehq-staging && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app /data
COPY render-fn-fetch/FNExport.mq5 /app/FNExport.mq5
COPY render-fn-fetch/start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
