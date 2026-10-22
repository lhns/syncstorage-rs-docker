# Pinned toolchain (matches upstream's 1.91.x). Avoids `rust:latest` drift that
# breaks building an older pinned source.
FROM rust:1.91-trixie AS builder

# Pinned syncstorage-rs revision to build. Must be recent enough to include the
# PostgreSQL backend and the built-in migration / node bootstrap.
ARG GIT_COMMIT=b1f1891e958207639080022f78e2c7752da7f154

# Database backend to compile in. syncstorage-rs selects the backend at compile
# time (exactly one of mysql|postgres), so each image ships a single backend.
ARG DATABASE_BACKEND=postgres

WORKDIR /app

# Install the dev package of the client library the selected backend links against.
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    && if [ "$DATABASE_BACKEND" = "postgres" ]; then \
         apt-get install -y --no-install-recommends libpq-dev; \
       else \
         apt-get install -y --no-install-recommends libmariadb-dev-compat; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# Clone syncstorage-rs at the pinned ref and build only the selected backend.
# The pure-Rust token verifier is used (py_verifier feature omitted), so no
# Python runtime is required. Schema migrations are applied by the server at
# startup, so diesel_cli is no longer installed here either.
RUN git clone https://github.com/mozilla-services/syncstorage-rs ./ \
    && git checkout ${GIT_COMMIT} \
    # --no-default-features drops syncserver's defaults (mysql + py_verifier), so
    # we select the backend explicitly on BOTH the storage and tokenserver crates.
    # tokenserver-db/mysql is technically its own default, but we pass it anyway so
    # the chosen backend is obvious and symmetric with the postgres branch.
    && if [ "$DATABASE_BACKEND" = "postgres" ]; then \
         FEATURES="--features=syncstorage-db/postgres --features=tokenserver-db/postgres"; \
       else \
         FEATURES="--features=syncstorage-db/mysql --features=tokenserver-db/mysql"; \
       fi \
    && cargo install --path ./syncserver --no-default-features $FEATURES --locked \
    && cargo clean

# Runtime stage: fresh Debian so ca-certificates is current (the rust image's
# bundle is frozen at its build date) and no toolchain ships.
FROM debian:trixie-slim
ARG DATABASE_BACKEND=postgres

# ca-certificates must stay unpinned so every rebuild gets the current CA bundle.
# curl is for the compose healthcheck.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libssl3 \
    && if [ "$DATABASE_BACKEND" = "postgres" ]; then \
         apt-get install -y --no-install-recommends libpq5; \
       else \
         apt-get install -y --no-install-recommends libmariadb3; \
       fi \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /app /config
WORKDIR /app

COPY --from=builder /usr/local/cargo/bin/syncserver /usr/local/cargo/bin/syncserver

# Copy entrypoint script and set it
COPY --chmod=755 entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
