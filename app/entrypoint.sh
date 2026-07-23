#!/bin/bash
set -e

# Nothing to provision here anymore: the syncstorage schema is applied by the
# server at startup, the tokenserver schema via SYNC_TOKENSERVER__RUN_MIGRATIONS,
# and the sync-1.5 node is bootstrapped from SYNC_TOKENSERVER__INIT_NODE_URL.
# All configuration is passed in as SYNC_* environment variables by compose.

export RUST_LOG="${RUST_LOG:-info}"

exec /usr/local/cargo/bin/syncserver
