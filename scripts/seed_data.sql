-- Seeds realistic NSE market ticks for the last 90 days using generate_series().
-- Approach: generate trading days, create 15-minute slots between 09:15 and 15:30
-- in Asia/Kolkata, then cross-join with symbol-specific ranges to synthesize ticks.
-- Market hours are 09:15-15:30 IST, matching standard NSE cash-market session.
INSERT INTO market_ticks (time, symbol, price, volume, trade_type, exchange)
WITH symbol_ranges AS (
  SELECT *
  FROM (
    VALUES
      ('RELIANCE',   2800.0000::numeric, 2950.0000::numeric),
      ('TCS',        3400.0000::numeric, 3600.0000::numeric),
      ('INFY',       1600.0000::numeric, 1750.0000::numeric),
      ('HDFCBANK',   1850.0000::numeric, 2000.0000::numeric),
      ('WIPRO',       420.0000::numeric,  460.0000::numeric),
      ('ICICIBANK',  1050.0000::numeric, 1150.0000::numeric),
      ('SBIN',        600.0000::numeric,  650.0000::numeric),
      ('BAJAJFINSV', 6500.0000::numeric, 7000.0000::numeric),
      ('MARUTI',    10000.0000::numeric,10500.0000::numeric),
      ('TATAMOTORS',  800.0000::numeric,  860.0000::numeric)
  ) AS s(symbol, min_price, max_price)
),
trade_days AS (
  SELECT d::date AS trade_day
  FROM generate_series(
    ((NOW() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '90 days')::date,
    (NOW() AT TIME ZONE 'Asia/Kolkata')::date,
    INTERVAL '1 day'
  ) AS g(d)
  WHERE EXTRACT(ISODOW FROM d) <= 5
),
market_slots AS (
  SELECT
    td.trade_day,
    slot AS local_slot
  FROM trade_days td
  CROSS JOIN LATERAL generate_series(
    td.trade_day::timestamp + TIME '09:15',
    td.trade_day::timestamp + TIME '15:30',
    INTERVAL '15 minutes'
  ) AS gs(slot)
)
SELECT
  (ms.local_slot AT TIME ZONE 'Asia/Kolkata') AS time,
  sr.symbol,
  ROUND((sr.min_price + random() * (sr.max_price - sr.min_price))::numeric, 4)::DECIMAL(15,4) AS price,
  (1000 + FLOOR(random() * 49001))::BIGINT AS volume,
  CASE
    WHEN random() < 0.33 THEN 'BUY'
    WHEN random() < 0.66 THEN 'SELL'
    ELSE 'NEUTRAL'
  END AS trade_type,
  'NSE' AS exchange
FROM market_slots ms
CROSS JOIN symbol_ranges sr
ORDER BY time, sr.symbol;

-- Inserts sample portfolio snapshots for RELIANCE and TCS for P&L tracking.
INSERT INTO portfolio_summary (
  snapshot_time,
  symbol,
  position_qty,
  avg_buy_price,
  current_price,
  unrealized_pnl,
  realized_pnl
)
VALUES
  (NOW() - INTERVAL '4 days', 'RELIANCE', 120, 2865.2500, 2898.6000, 4002.0000, 1500.0000),
  (NOW() - INTERVAL '3 days', 'RELIANCE', 120, 2865.2500, 2910.4500, 5414.0000, 1500.0000),
  (NOW() - INTERVAL '2 days', 'RELIANCE',  80, 2872.1000, 2920.2000, 3848.0000, 4520.0000),
  (NOW() - INTERVAL '1 day',  'TCS',      150, 3478.3000, 3522.9500, 6697.5000, 1800.0000),
  (NOW(),                     'TCS',      150, 3478.3000, 3550.1000,10770.0000, 1800.0000);

-- Refreshes continuous aggregates so seeded data is immediately queryable.
CALL refresh_continuous_aggregate('hourly_ohlcv', NULL, NULL);
CALL refresh_continuous_aggregate('daily_ohlcv', NULL, NULL);
