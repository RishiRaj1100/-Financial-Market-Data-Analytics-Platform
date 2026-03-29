#!/bin/bash
set -e
set -u
# Runs all analysis queries and saves output.
# Usage: ./scripts/run_analysis.sh
# Output goes to results/ directory with timestamp.

mkdir -p results
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTFILE="results/analysis_${TIMESTAMP}.txt"

echo "=====================================" >> "$OUTFILE"
echo " MARKET ANALYTICS REPORT - $TIMESTAMP" >> "$OUTFILE"
echo "=====================================" >> "$OUTFILE"

echo "[1/5] Rolling 7-day average prices..." >> "$OUTFILE"
docker exec market-timescaledb psql -U analyst -d market_analytics \
  -f /queries/window_functions.sql >> "$OUTFILE" 2>&1

echo "[2/5] Running EXPLAIN ANALYZE on key queries..." >> "$OUTFILE"
docker exec market-timescaledb psql -U analyst -d market_analytics \
  -f /queries/explain_analysis.sql >> "$OUTFILE" 2>&1

echo "[3/5] Compression stats..." >> "$OUTFILE"
docker exec market-timescaledb psql -U analyst -d market_analytics \
  -c "SELECT * FROM chunk_compression_stats('market_ticks');" >> "$OUTFILE" 2>&1

echo "[4/5] Hypertable info..." >> "$OUTFILE"
docker exec market-timescaledb psql -U analyst -d market_analytics \
  -c "SELECT * FROM timescaledb_information.hypertables;" >> "$OUTFILE" 2>&1

echo "[5/5] Continuous aggregate info..." >> "$OUTFILE"
docker exec market-timescaledb psql -U analyst -d market_analytics \
  -c "SELECT * FROM timescaledb_information.continuous_aggregates;" >> "$OUTFILE" 2>&1

echo "Analysis complete. Report saved to: $OUTFILE"
cat "$OUTFILE"
