-- Rolling 7-day average by symbol using a moving window frame.
SELECT
  time_bucket('1 day', time) AS day,
  symbol,
  AVG(price) AS daily_avg,
  AVG(AVG(price)) OVER (
    PARTITION BY symbol
    ORDER BY time_bucket('1 day', time)
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7day_avg
FROM market_ticks
GROUP BY day, symbol
ORDER BY symbol, day;

-- Daily volume ranking; RANK() and DENSE_RANK() highlight tie behavior.
SELECT
  time_bucket('1 day', time) AS day,
  symbol,
  SUM(volume) AS total_volume,
  RANK() OVER (
    PARTITION BY time_bucket('1 day', time)
    ORDER BY SUM(volume) DESC
  ) AS volume_rank,
  DENSE_RANK() OVER (
    PARTITION BY time_bucket('1 day', time)
    ORDER BY SUM(volume) DESC
  ) AS dense_volume_rank
FROM market_ticks
GROUP BY day, symbol
ORDER BY day, volume_rank;

-- Day-over-day momentum with LAG() on daily close.
SELECT
  day,
  symbol,
  close_price,
  LAG(close_price) OVER (
    PARTITION BY symbol
    ORDER BY day
  ) AS prev_close,
  ROUND(
    (close_price - LAG(close_price) OVER (
      PARTITION BY symbol ORDER BY day
    )) / NULLIF(LAG(close_price) OVER (
      PARTITION BY symbol ORDER BY day
    ), 0) * 100, 2
  ) AS pct_change
FROM (
  SELECT day, symbol, close AS close_price
  FROM daily_ohlcv
) d
ORDER BY symbol, day;

-- Intraday cumulative volume using running SUM window.
SELECT
  time_bucket('1 day', time) AS day,
  time_bucket('1 hour', time) AS hour,
  symbol,
  SUM(volume) AS hourly_volume,
  SUM(SUM(volume)) OVER (
    PARTITION BY symbol, time_bucket('1 day', time)
    ORDER BY time_bucket('1 hour', time)
    ROWS UNBOUNDED PRECEDING
  ) AS cumulative_daily_volume
FROM market_ticks
GROUP BY day, hour, symbol
ORDER BY symbol, hour;

-- Daily volatility snapshot with STDDEV, range, and sample size.
SELECT
  time_bucket('1 day', time) AS day,
  symbol,
  ROUND(AVG(price)::numeric, 4)     AS avg_price,
  ROUND(STDDEV(price)::numeric, 4)  AS price_stddev,
  ROUND(MAX(price) - MIN(price), 4) AS price_range,
  COUNT(*) AS tick_count
FROM market_ticks
GROUP BY day, symbol
HAVING STDDEV(price) > 0
ORDER BY price_stddev DESC;
