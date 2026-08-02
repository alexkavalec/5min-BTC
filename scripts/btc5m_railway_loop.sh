#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$SCRIPT_DIR/test_btc_5m_session_exit_sl.py"

: "${BTC5M_REPO:?BTC5M_REPO must point at the execution-engine checkout (e.g. /engine)}"
VENV_PY="$BTC5M_REPO/.venv/bin/python"

PROFILE="${BTC5M_PROFILE:-conservative}"
ENTRY_TIMEOUT_MIN="${BTC5M_ENTRY_TIMEOUT_MIN:-8}"
POLL_SEC="${BTC5M_POLL_SEC:-2}"
CLOSE_RETRY_MAX="${BTC5M_CLOSE_RETRY_MAX:-30}"
CLOSE_RETRY_DELAY_SEC="${BTC5M_CLOSE_RETRY_DELAY_SEC:-2}"
CYCLE_COOLDOWN_SEC="${BTC5M_CYCLE_COOLDOWN_SEC:-5}"
EXECUTE="${BTC5M_EXECUTE:-false}"

EXECUTE_FLAG=()
if [[ "$EXECUTE" == "true" || "$EXECUTE" == "1" ]]; then
  EXECUTE_FLAG=(--execute)
  echo "[$(date -u +%FT%TZ)] LIVE MODE: BTC5M_EXECUTE is enabled, real orders will be placed." >&2
else
  echo "[$(date -u +%FT%TZ)] DRY RUN MODE: set BTC5M_EXECUTE=true to place real orders." >&2
fi

echo "[$(date -u +%FT%TZ)] btc5m railway loop starting: profile=$PROFILE repo=$BTC5M_REPO execute=$EXECUTE"

# Runs one entry/monitor/close cycle per iteration (the runner exits after
# at most one trade), then immediately starts the next cycle. A failed
# cycle is logged and retried rather than killing the whole service.
while true; do
  echo "[$(date -u +%FT%TZ)] cycle start"
  "$VENV_PY" "$RUNNER" \
    --repo "$BTC5M_REPO" \
    --profile "$PROFILE" \
    --entry-timeout-min "$ENTRY_TIMEOUT_MIN" \
    --poll-sec "$POLL_SEC" \
    --close-retry-max "$CLOSE_RETRY_MAX" \
    --close-retry-delay-sec "$CLOSE_RETRY_DELAY_SEC" \
    "${EXECUTE_FLAG[@]}"
  status=$?
  echo "[$(date -u +%FT%TZ)] cycle finished exit_code=$status, sleeping ${CYCLE_COOLDOWN_SEC}s"
  sleep "$CYCLE_COOLDOWN_SEC"
done
