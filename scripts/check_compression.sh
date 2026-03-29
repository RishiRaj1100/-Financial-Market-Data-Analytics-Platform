#!/bin/bash
set -e
set -u
# Check compression stats and savings on market_ticks.
# Demonstrates practical validation of columnstore effectiveness.
echo "Compression Statistics for market_ticks:"
docker exec market-timescaledb psql -U analyst -d market_analytics -c "
SELECT
  chunk_schema,
  chunk_name,
  compression_status,
  pg_size_pretty(before_compression_total_bytes) AS before,
  pg_size_pretty(after_compression_total_bytes)  AS after,
  ROUND(
    (1 - after_compression_total_bytes::numeric /
         NULLIF(before_compression_total_bytes,0)) * 100, 1
  ) AS compression_pct
FROM chunk_compression_stats('market_ticks')
ORDER BY chunk_name;
"
