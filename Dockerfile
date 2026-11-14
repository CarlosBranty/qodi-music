# syntax=docker/dockerfile:1

# ---- Flutter web client ----
FROM debian:trixie-slim AS web
ARG FLUTTER_VERSION=3.50.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
RUN flutter config --no-analytics --enable-web >/dev/null && flutter precache --web
WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock* ./
RUN flutter pub get
COPY app/ ./
RUN flutter build web --release

# ---- Rust server ----
FROM rust:1-trixie AS server
WORKDIR /src/server
COPY server/ ./
RUN cargo build --release --locked && strip target/release/qodi-server

# ---- Runtime ----
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 1000 --home /data qodi \
 && mkdir -p /data /music && chown qodi /data
COPY --from=server /src/server/target/release/qodi-server /usr/local/bin/qodi-server
COPY --from=web /src/app/build/web /app/web
USER qodi
ENV QODI_BIND=0.0.0.0:4040 QODI_MUSIC_DIR=/music QODI_DATA_DIR=/data QODI_WEB_DIR=/app/web RUST_LOG=info
EXPOSE 4040
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD ["sh", "-c", "exec 3<>/dev/tcp/127.0.0.1/4040 && printf 'GET /api/v1/health HTTP/1.0\\r\\n\\r\\n' >&3 && grep -q '\"ok\"' <&3"]
ENTRYPOINT ["tini", "--"]
CMD ["qodi-server"]
