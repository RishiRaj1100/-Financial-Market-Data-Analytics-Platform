CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Raw tick storage with fixed-precision prices for financial correctness.
CREATE TABLE market_ticks (
  time        TIMESTAMPTZ NOT NULL,
  symbol      VARCHAR(20) NOT NULL,
  price       DECIMAL(15,4) NOT NULL,
  volume      BIGINT NOT NULL,
  trade_type  VARCHAR(10) NOT NULL CHECK (trade_type IN ('BUY', 'SELL', 'NEUTRAL')),
  exchange    VARCHAR(10) NOT NULL DEFAULT 'NSE'
);

-- Converts table to hypertable; 1-day chunks suit high-frequency tick scans.
SELECT create_hypertable('market_ticks', 'time',
  chunk_time_interval => INTERVAL '1 day');

-- Composite index for symbol + recent time filters.
CREATE INDEX idx_market_ticks_symbol ON market_ticks (symbol, time DESC);

-- Secondary index for exchange-scoped scans.
CREATE INDEX idx_market_ticks_exchange ON market_ticks (exchange, time DESC);

-- Hourly OHLCV continuous aggregate (Open, High, Low, Close, Volume).
CREATE MATERIALIZED VIEW hourly_ohlcv
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', time)     AS bucket,
  symbol,
  exchange,
  FIRST(price, time)              AS open,
  MAX(price)                      AS high,
  MIN(price)                      AS low,
  LAST(price, time)               AS close,
  SUM(volume)                     AS total_volume,
  COUNT(*)                        AS tick_count,
  AVG(price)                      AS avg_price
FROM market_ticks
GROUP BY bucket, symbol, exchange
WITH NO DATA;

-- Refreshes recent windows every 30 minutes.
SELECT add_continuous_aggregate_policy('hourly_ohlcv',
  start_offset => INTERVAL '3 hours',
  end_offset   => INTERVAL '1 hour',
  schedule_interval => INTERVAL '30 minutes');

-- Daily OHLCV built from hourly aggregate (hierarchical continuous aggregate).
CREATE MATERIALIZED VIEW daily_ohlcv
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 day', bucket)    AS day,
  symbol,
  exchange,
  FIRST(open, bucket)             AS open,
  MAX(high)                       AS high,
  MIN(low)                        AS low,
  LAST(close, bucket)             AS close,
  SUM(total_volume)               AS total_volume,
  SUM(tick_count)                 AS total_ticks,
  AVG(avg_price)                  AS avg_price
FROM hourly_ohlcv
GROUP BY day, symbol, exchange
WITH NO DATA;

-- Refreshes daily rollups hourly.
SELECT add_continuous_aggregate_policy('daily_ohlcv',
  start_offset => INTERVAL '3 days',
  end_offset   => INTERVAL '1 day',
  schedule_interval => INTERVAL '1 hour');

-- Enables columnstore compression with query-aligned segment/order keys.
ALTER TABLE market_ticks SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol, exchange',
  timescaledb.compress_orderby   = 'time DESC'
);

-- Compresses chunks older than 7 days.
SELECT add_compression_policy('market_ticks',
  INTERVAL '7 days');

-- Automatically drops chunks older than 2 years.
SELECT add_retention_policy('market_ticks',
  INTERVAL '2 years');

-- Portfolio snapshots for position and P&L tracking.
CREATE TABLE portfolio_summary (
  snapshot_time  TIMESTAMPTZ NOT NULL,
  symbol         VARCHAR(20) NOT NULL,
  position_qty   INT NOT NULL DEFAULT 0,
  avg_buy_price  DECIMAL(15,4),
  current_price  DECIMAL(15,4),
  unrealized_pnl DECIMAL(15,4),
  realized_pnl   DECIMAL(15,4) DEFAULT 0,
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Weekly chunking for snapshot analytics.
SELECT create_hypertable('portfolio_summary', 'snapshot_time',
  chunk_time_interval => INTERVAL '1 week');
