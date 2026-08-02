# 5min BTC Polymarket Skill

Open-source OpenClaw skill for **BTC 5-minute Up/Down** markets on Polymarket.

Repository: https://github.com/Novals83/5min-btc-polymarket

## Strategy (Momentum into Close)
This skill is aligned with a short-horizon momentum strategy:

1. Trade BTC 5m event markets near expiry.
2. Main entry window: around **2 minutes left**.
3. Confirm that BTC has already moved by about **$70-$100** in the active interval.
4. Check market skew (crowd positioning). If flow supports the move direction, enter **with** momentum.
5. Typical sizing: around **50% of trading allocation** (user-defined risk tolerance).
6. Optional micro-hedge when skew is extreme (for example, 95/5): place a small opposite position ($1-$2 equivalent) to reduce tail risk.

This is a momentum-following approach, not a reversal strategy.

## Repository Structure
- `SKILL.md` — skill definition and operating rules
- `config/` — profiles and risk parameters
- `scripts/` — runners/wrappers/hot commands
- `examples/` — practical command examples

## Deploy / Run
### Prerequisites
- OpenClaw environment
- Polymarket execution stack available at:
  - `<your-workspace>/pm-hl-conservative-plus-repo`
- Python virtual env for runner scripts
- Valid API credentials configured outside this repository

### Quick Start
```bash
git clone https://github.com/Novals83/5min-btc-polymarket.git
cd 5min-btc-polymarket
```

Read:
- `SKILL.md`
- `config/btc_5m_profiles.yaml`

Run a conservative real test (example):
```bash
.venv/bin/python scripts/test_btc_5m_session_exit_sl.py --profile conservative --execute
```

Run aggressive profile:
```bash
.venv/bin/python scripts/test_btc_5m_session_exit_sl.py --profile aggressive --execute
```

Unified skill control (recommended):
```bash
scripts/btc5m_ctl.sh start --profile conservative
scripts/btc5m_ctl.sh status
scripts/btc5m_ctl.sh report --limit 20
scripts/btc5m_ctl.sh stop
```

Runtime isolation:
- skill runtime dir: `./runtime`
- auth/env source (default): `<your-workspace>/pm-hl-conservative-plus-repo/.env`
- overrides: `BTC5M_REPO`, `BTC5M_ENV_FILE`, `BTC5M_RUNNER`
- completion auto-report cron (topic 184): `btc5m-completion-autoreport-topic184`

Optional Docker isolation:
```bash
scripts/btc5m_docker.sh up
scripts/btc5m_docker.sh status
scripts/btc5m_docker.sh down
```

### Deploy on Railway (always-on)
This repo's `Dockerfile` builds a self-contained image: it clones the execution
engine (`alexkavalec/polymarket-hl-strategy`) at build time, gives it its own
venv, and runs `scripts/btc5m_railway_loop.sh` as the container's main
process. That script runs one entry/monitor/close cycle at a time (the
strategy runner exits after at most one trade) and immediately starts the
next, so the service trades continuously instead of running once and idling.

1. Create a Railway project from this GitHub repo — Railway auto-detects the
   `Dockerfile`.
2. Set environment variables (Railway → service → Variables), nothing here
   is baked into the image:
   - `PM_PRIVATE_KEY`, `PM_FUNDER` (or `PM_ADDRESS`)
   - `PM_SIGNATURE_TYPE` — **set this explicitly.** The strategy runner
     defaults to `2` if unset, but the execution engine defaults to `1`;
     leaving it unset lets the two processes silently disagree. Use the
     signature type that matches your wallet (`2` for a Polymarket proxy
     wallet, `1` for a plain EOA).
   - `PM_API_KEY` / `PM_API_SECRET` / `PM_API_PASSPHRASE` — optional; the
     execution engine self-derives these from `PM_PRIVATE_KEY` if left
     unset. Only needed for the strategy runner's stuck-order
     cancel-and-repost fallback, which no-ops harmlessly without them.
   - `BTC5M_ACCOUNT_EQUITY_USD` — **set this to your real balance.**
     Position sizing is a percentage of this value; leaving it at the
     default (`100`) will size trades for a $100 account regardless of
     what's actually funded.
   - Optional tuning: `BTC5M_PROFILE` (`conservative`|`aggressive`,
     default `conservative`), `BTC5M_ENTRY_TIMEOUT_MIN` (default `8`),
     `BTC5M_POLL_SEC` (default `2`), `BTC5M_CLOSE_RETRY_MAX` (default `30`),
     `BTC5M_CLOSE_RETRY_DELAY_SEC` (default `2`),
     `BTC5M_CYCLE_COOLDOWN_SEC` (default `5`)
3. Leave `BTC5M_EXECUTE` unset (or `false`) on the first deploy — the loop
   runs in dry-run mode by default. Watch the Railway logs for a few cycles
   to confirm market resolution, threshold detection, and engine hand-off
   look right.
4. Only once that looks correct, set `BTC5M_EXECUTE=true` and redeploy to go
   live.

This deployment enforces a daily-loss cap, a max-trades-per-day limit, and a
max-consecutive-losses circuit breaker (see `config/btc_5m_profiles.yaml` and
`--account-equity-usd`/`--daily-max-loss-pct`/`--max-trades-per-day`/
`--max-consecutive-losses`). That state lives in `./runtime` and persists
across the loop's one-trade-per-process restarts, but **not** across a
redeploy — a fresh deploy mid-day resets the counters. Hedge logic from the
strategy doc is still not implemented anywhere; treat it as aspirational
only.

## Execution Checklist (Before Live Trade)
Use this quick pre-flight checklist before any real order:

1. **Market validity**
   - Confirm the BTC 5m market is active and not about to close unexpectedly.
2. **Time-to-close window**
   - Prefer entries around ~120 seconds left (with reasonable tolerance).
3. **Impulse confirmation**
   - Confirm the observed BTC move is meaningful (strategy reference: ~$70-$100).
4. **Skew confirmation**
   - Verify market skew supports the intended direction (do not fade strong momentum by default).
5. **Liquidity/spread checks**
   - Ensure spread and top-of-book notional pass your minimum thresholds.
6. **Sizing guardrails**
   - Validate stake, max notional, and daily loss limits before execution.
7. **Stop / exit controls**
   - Confirm stop-loss and `exit_before_sec` are configured.
8. **Execution mode**
   - Start in dry-run when changing parameters; switch to `--execute` only after validation.

## Risk Controls
Enforced by `test_btc_5m_session_exit_sl.py` (profile defaults; override with CLI flags or the matching `--*` args):

- **Per-trade risk cap**: 2% (conservative) / 3% (aggressive) of `--account-equity-usd`, capped at `max_notional_usd`
- **Stop-loss**: 15% (conservative) / 20% (aggressive) drop in the position's live price before market resolution
- **Daily max loss**: 5% (conservative) / 7% (aggressive) of account equity; blocks new entries for the rest of the UTC day once hit
- **Max trades/day**: 12 (conservative) / 20 (aggressive)
- **Max consecutive losses**: 4 (conservative) / 3 (aggressive); blocks new entries for the rest of the UTC day
- **Max notional/trade**: strict upper bound regardless of equity sizing
- **Quote staleness guard**: skip if market data is stale
- **Spread guard**: skip when spread exceeds threshold
- **Liquidity guard**: skip when top ask/bid notional is too thin
- **Extreme skew hedge**: optional small opposite hedge in 95/5-type scenarios
- **Operational kill switch**: immediate stop on repeated API/DNS/execution failures

## Risk Notice
This repository is educational/operational infrastructure, not financial advice.
Use your own risk limits, daily loss caps, and capital controls.

## Contributing
- Fork the repository
- Create a feature branch
- Commit changes
- Open a PR to `main`

PRs are welcome.
