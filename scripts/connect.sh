#!/bin/bash
set -e
set -u
# Quick connect to TimescaleDB via psql CLI.
# Usage: ./scripts/connect.sh
# Demonstrates direct CLI access for debugging and ad-hoc analytics.
docker exec -it market-timescaledb \
  psql -U analyst -d market_analytics

echo "Connected to TimescaleDB market_analytics database"
