-- Scenario 1: Baseline; read plan for Seq Scan cost, rows removed, and buffers.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM market_ticks
WHERE symbol = 'RELIANCE'
AND time > NOW() - INTERVAL '7 days';

-- Scenario 2: Indexed path; compare Index/Bitmap scan and chunk exclusion effects.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM market_ticks
WHERE symbol = 'RELIANCE'
AND time > NOW() - INTERVAL '7 days';

-- Scenario 3: Continuous aggregate read; expect materialized view + ChunkAppend.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM hourly_ohlcv
WHERE symbol = 'TCS'
AND bucket > NOW() - INTERVAL '30 days';

-- Scenario 4: WindowAgg profile; inspect sort cost and memory implications.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT symbol, time_bucket('1 day', time),
  AVG(price),
  AVG(AVG(price)) OVER (PARTITION BY symbol ORDER BY time_bucket('1 day', time)
  ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
FROM market_ticks
GROUP BY symbol, time_bucket('1 day', time)
ORDER BY symbol;
