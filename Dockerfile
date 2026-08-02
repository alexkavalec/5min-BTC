FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ARG ENGINE_REPO_URL=https://github.com/alexkavalec/polymarket-hl-strategy.git
ENV BTC5M_REPO=/engine

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Execution engine lives in a separate repo; clone it and give it its own
# venv, since the strategy runner below invokes it as "$BTC5M_REPO/.venv/bin/python".
RUN git clone --depth 1 "$ENGINE_REPO_URL" /engine \
    && python -m venv /engine/.venv \
    && /engine/.venv/bin/pip install --no-cache-dir --upgrade pip \
    && /engine/.venv/bin/pip install --no-cache-dir -r /engine/requirements.txt

WORKDIR /app
COPY . /app
RUN chmod +x scripts/*.sh

CMD ["scripts/btc5m_railway_loop.sh"]
