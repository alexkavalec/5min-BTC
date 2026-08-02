FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ARG ENGINE_REPO_URL=https://github.com/alexkavalec/polymarket-hl-strategy.git
# Pinned to an exact commit rather than a branch. Docker keys this layer's
# cache on the command text, so with a floating "main" the clone is reused
# from cache and engine updates silently never reach the image -- the
# runtime then fails on whatever the old checkout was missing. Bump this
# when the engine changes; it doubles as a record of what is deployed.
ARG ENGINE_REF=a51f3635657a6e73ffe8802761a7c0fab824349b
ENV BTC5M_REPO=/engine

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Execution engine lives in a separate repo; clone it and give it its own
# venv, since the strategy runner below invokes it as "$BTC5M_REPO/.venv/bin/python".
# The final import check fails the build here rather than in the trading
# loop if the pinned engine's requirements don't provide the clients that
# both this repo's runner and the engine import.
RUN git clone "$ENGINE_REPO_URL" /engine \
    && git -C /engine checkout --detach "$ENGINE_REF" \
    && python -m venv /engine/.venv \
    && /engine/.venv/bin/pip install --no-cache-dir --upgrade pip \
    && /engine/.venv/bin/pip install --no-cache-dir -r /engine/requirements.txt \
    && /engine/.venv/bin/python -c "import py_clob_client_v2, py_clob_client"

WORKDIR /app
COPY . /app
RUN chmod +x scripts/*.sh

CMD ["scripts/btc5m_railway_loop.sh"]
