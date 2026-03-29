#!/bin/bash
set -e
set -u
# Manually refresh all continuous aggregates.
# Use when fresh analytics are needed immediately instead of waiting for policies.
echo "Refreshing continuous aggregates..."
docker exec market-timescaledb psql -U analyst -d market_analytics -c "
CALL refresh_continuous_aggregate('hourly_ohlcv', NOW() - INTERVAL '3 days', NOW());
CALL refresh_continuous_aggregate('daily_ohlcv', NOW() - INTERVAL '7 days', NOW());
"
echo "Aggregates refreshed."
