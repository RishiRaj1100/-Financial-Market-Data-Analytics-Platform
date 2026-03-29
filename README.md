# 📈 Financial Market Data Analytics Platform

### TimescaleDB | PostgreSQL | Docker | NSE Market Data

Project name: financial-market-analytics  
GitHub username: RishiRaj1100  
DockerHub username: rishiraj01

## 1) What This Project Demonstrates

This project is not only a schema demo. It proves production-grade time-series design decisions used by real financial and industrial analytics teams running Tiger Data (Timescale) workloads.

- High-ingest market storage with hypertables: Demonstrates write-optimized partitioning for continuous tick ingestion. Real-world use case: brokerage feeds, IoT telemetry, payments event streams.
- Pre-aggregated multi-resolution analytics: Demonstrates hourly and daily continuous aggregates for low-latency dashboards. Real-world use case: KPI rollups, reporting APIs, observability trend views.
- Hierarchical aggregation strategy: Demonstrates daily rollups from hourly rollups rather than from raw events. Real-world use case: reducing compute cost for long-range analytics windows.
- Columnstore compression lifecycle: Demonstrates automatic historical compression policy for older chunks. Real-world use case: keeping years of data online with controlled storage costs.
- Automatic retention enforcement: Demonstrates chunk-level expiry with policy jobs instead of ad-hoc deletes. Real-world use case: regulatory retention windows, predictable database growth.
- SQL analytics with window functions: Demonstrates rolling metrics, rank, momentum, cumulative measures, and volatility. Real-world use case: risk and market behavior monitoring.
- Performance investigation discipline: Demonstrates EXPLAIN ANALYZE reading from baseline scans to indexed/chunk-pruned plans. Real-world use case: query tuning and SLA hardening.

## 2) Architecture Diagram (ASCII)

Raw NSE Tick Data (15-min intervals, 10 symbols, 90 days)
|
v
┌─────────────────────────────────────────────┐
| TimescaleDB Hypertable |
| market_ticks (partitioned by day) |
| Compression: 90%+ after 7 days |
| Retention: auto-drop after 2 years |
└──────────────┬──────────────────────────────┘
|
┌───────┴───────┐
v v
┌─────────────┐ ┌──────────────────────────┐
| Hourly | | Window Function Queries |
| OHLCV | | - Rolling 7-day avg |
| (Level 1 | | - Volume ranking |
| Aggregate)| | - Price momentum LAG() |
└──────┬──────┘ | - Cumulative volume |
| | - Volatility STDDEV |
v └──────────────────────────┘
┌─────────────┐
| Daily |
| OHLCV |
| (Level 2 |
| Aggregate |
| on Level 1|
└─────────────┘

## 3) Tech Stack

| Layer                 | Technology              | Why It Is Used                                |
| --------------------- | ----------------------- | --------------------------------------------- |
| Database Engine       | PostgreSQL 16           | Reliable relational core and SQL ecosystem    |
| Time-Series Extension | TimescaleDB             | Hypertables, continuous aggregates, policies  |
| Storage Optimization  | TimescaleDB Compression | Major reduction in historical footprint       |
| Orchestration         | Docker Compose          | One-command reproducible local environment    |
| Admin UI              | pgAdmin 4               | Visual SQL and schema inspection              |
| Query Language        | SQL                     | Native analytical and operational querying    |
| Scripting             | Bash                    | Repeatable operations and automated reporting |

## 4) TimescaleDB Concepts Implemented

### Hypertables

A hypertable is a logical table split into many internal chunks by time. This allows TimescaleDB to route writes efficiently and skip irrelevant chunks for bounded time queries. It matters because large append-heavy datasets stay queryable without manual partition management.

### Hierarchical Continuous Aggregates

A hierarchical aggregate builds one continuous aggregate on top of another, such as daily from hourly. This avoids recomputing long windows from raw ticks. It matters because refresh jobs become cheaper and more predictable as data volume grows.

### Columnstore Compression

Compression rewrites older chunks into a column-oriented representation optimized for analytical scans. It matters because historical data can remain online at much lower storage cost while still being queryable.

### Data Retention Policies

Retention policies drop expired chunks automatically based on age. It matters because database size stays bounded without periodic delete jobs, lock pressure, or heavy vacuum churn.

### time_bucket() vs date_trunc()

time_bucket() is designed for time-series grouping in TimescaleDB and integrates with chunk pruning and policy workflows. date_trunc() is generic PostgreSQL date truncation. time_bucket() matters for performance-oriented series aggregation.

### FIRST() and LAST() hyperfunctions

FIRST(value, time) and LAST(value, time) return the earliest/latest value in each bucket by timestamp order. They matter for OHLC computations where open and close must be time-accurate, not arbitrary min/max substitutions.

## 5) Window Functions Reference Table

| Function                         | Query Used In     | Business Purpose         |
| -------------------------------- | ----------------- | ------------------------ |
| AVG() OVER (ROWS BETWEEN)        | Rolling 7-day avg | Smooth price trend       |
| RANK() OVER                      | Volume ranking    | Market activity analysis |
| LAG()                            | Price momentum    | Day-over-day change %    |
| SUM() OVER (UNBOUNDED PRECEDING) | Cumulative volume | Intraday volume tracking |
| STDDEV()                         | Volatility        | Risk assessment          |

## 6) EXPLAIN ANALYZE Learnings

- Scenario 1 (baseline): Seq Scan touched much more data than needed; many rows were removed by filter, showing poor selectivity handling without an efficient access path.
- Scenario 2 (indexed): Planner can use Index Scan or Bitmap Heap Scan. Combined with chunk exclusion on time bounds, far fewer chunks and pages are scanned.
- Scenario 3 (continuous aggregate): Query operates on materialized aggregate data, not raw ticks, reducing runtime aggregation work and lowering latency.
- Scenario 4 (window query): WindowAgg depends on sorted partitions; sort behavior and work memory influence runtime and spill risk.
- Key progression: Seq Scan -> Index Scan/Bitmap -> Chunk Exclusion + pre-aggregated reads.
- Typical impact in this pattern: often around 10x to 20x faster for selective recent-window queries; a practical benchmark target is roughly 17x faster after indexing and chunk pruning.

## 7) Setup and Run

Step 1: Clone repo  
Step 2: cp .env.example .env  
Step 3: docker-compose up -d  
Step 4: Wait 30 seconds for seed data to load  
Step 5: ./scripts/connect.sh to open psql CLI  
Step 6: ./scripts/run_analysis.sh to generate full report  
Step 7: Open http://localhost:8080 for pgAdmin UI

## 8) Key Queries Quick Reference (copy-paste ready)

1. Latest 20 RELIANCE ticks

```sql
SELECT time, symbol, price, volume, trade_type, exchange
FROM market_ticks
WHERE symbol = 'RELIANCE'
ORDER BY time DESC
LIMIT 20;
```

2. Hourly OHLCV for TCS in last 7 days

```sql
SELECT *
FROM hourly_ohlcv
WHERE symbol = 'TCS'
  AND bucket > NOW() - INTERVAL '7 days'
ORDER BY bucket DESC;
```

3. Daily OHLCV for all symbols in last 30 days

```sql
SELECT *
FROM daily_ohlcv
WHERE day > NOW() - INTERVAL '30 days'
ORDER BY day DESC, symbol;
```

4. Top 5 symbols by volume today

```sql
SELECT symbol, SUM(volume) AS total_volume
FROM market_ticks
WHERE time >= date_trunc('day', NOW())
GROUP BY symbol
ORDER BY total_volume DESC
LIMIT 5;
```

5. Portfolio unrealized P&L snapshot

```sql
SELECT snapshot_time, symbol, position_qty, avg_buy_price, current_price, unrealized_pnl, realized_pnl
FROM portfolio_summary
ORDER BY snapshot_time DESC, symbol;
```

## 9) What I Learned

- Hypertables remove manual partition-management burden while preserving normal SQL semantics.
- Choosing chunk interval is a performance lever; one day works well for dense tick streams.
- Continuous aggregates are operationally stronger than ad-hoc grouped queries for dashboards.
- Hierarchical aggregates significantly reduce recomputation cost on long-range reporting.
- Compression and retention policies are core lifecycle controls, not optional tuning extras.
- Query-plan literacy with EXPLAIN ANALYZE is necessary to validate indexing and chunk exclusion benefits.
