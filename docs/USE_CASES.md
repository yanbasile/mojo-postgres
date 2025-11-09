# Real-World Use Cases for mojo-postgres

This document presents 10 real-world use cases across multiple industries where mojo-postgres excels, with a focus on high-frequency time-series data and performance-critical applications.

## Table of Contents

1. [Cryptocurrency Trading & Analytics](#1-cryptocurrency-trading--analytics) 🔷
2. [High-Frequency Market Data](#2-high-frequency-market-data) 🔷
3. [DeFi Protocol Monitoring](#3-defi-protocol-monitoring) 🔷
4. [IoT Sensor Network](#4-iot-sensor-network)
5. [Application Performance Monitoring (APM)](#5-application-performance-monitoring-apm)
6. [Real-Time Gaming Analytics](#6-real-time-gaming-analytics)
7. [E-Commerce Clickstream Analysis](#7-e-commerce-clickstream-analysis)
8. [Smart City Traffic Management](#8-smart-city-traffic-management)
9. [Healthcare Patient Monitoring](#9-healthcare-patient-monitoring)
10. [DevOps Metrics & Logs](#10-devops-metrics--logs)

---

## 1. Cryptocurrency Trading & Analytics 🔷

### Domain
High-frequency cryptocurrency trading platform with real-time orderbook analysis and automated trading strategies.

### Problem Statement
Process and analyze 100Hz+ orderbook updates from multiple exchanges (Binance, Coinbase, Kraken) for 50+ trading pairs. Execute trades based on millisecond-precision signals while maintaining complete audit trail.

### Data Volume
- **Ingestion Rate**: 5,000-15,000 orderbook updates/second
- **Daily Volume**: ~500M rows/day
- **Data Retention**: 2 years (compressed after 7 days)
- **Hot Data**: Last 24 hours (uncompressed)

### Schema
```sql
CREATE TABLE orderbook_updates (
    time            TIMESTAMPTZ NOT NULL,
    exchange        TEXT NOT NULL,
    symbol          TEXT NOT NULL,
    side            TEXT NOT NULL,  -- 'bid' or 'ask'
    price_level     INT NOT NULL,   -- 0-19 for top 20 levels
    price           NUMERIC(20,8) NOT NULL,
    quantity        NUMERIC(20,8) NOT NULL,
    update_id       BIGINT NOT NULL
);

SELECT create_hypertable('orderbook_updates', 'time',
    chunk_time_interval => INTERVAL '1 hour');

CREATE INDEX ON orderbook_updates (symbol, time DESC);
CREATE INDEX ON orderbook_updates (exchange, symbol, time DESC);

-- Enable compression after 7 days
ALTER TABLE orderbook_updates SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'exchange,symbol',
    timescaledb.compress_orderby = 'time DESC'
);

-- Continuous aggregate for 1-minute orderbook snapshots
CREATE MATERIALIZED VIEW orderbook_1min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', time) AS bucket,
    exchange,
    symbol,
    side,
    price_level,
    (array_agg(price ORDER BY time DESC))[1] AS price,
    (array_agg(quantity ORDER BY time DESC))[1] AS quantity
FROM orderbook_updates
GROUP BY bucket, exchange, symbol, side, price_level;
```

### Critical Queries
1. **Real-time spread calculation** (sub-10ms required)
   ```sql
   SELECT
       (MIN(CASE WHEN side='ask' THEN price END) -
        MAX(CASE WHEN side='bid' THEN price END)) AS spread
   FROM orderbook_updates
   WHERE symbol = 'BTC/USDT'
     AND exchange = 'binance'
     AND time > NOW() - INTERVAL '1 second';
   ```

2. **Historical orderbook reconstruction** (sub-100ms for 1 hour)
   ```sql
   SELECT * FROM orderbook_1min
   WHERE symbol = 'BTC/USDT'
     AND bucket > NOW() - INTERVAL '1 hour'
   ORDER BY bucket DESC, price_level;
   ```

3. **Cross-exchange arbitrage detection** (sub-50ms)
   ```sql
   SELECT
       a.exchange AS buy_exchange,
       b.exchange AS sell_exchange,
       a.symbol,
       b.price - a.price AS profit,
       LEAST(a.quantity, b.quantity) AS max_volume
   FROM orderbook_updates a
   JOIN orderbook_updates b
       ON a.symbol = b.symbol
       AND a.time = b.time
   WHERE a.side = 'ask'
     AND b.side = 'bid'
     AND b.price > a.price
     AND a.time > NOW() - INTERVAL '100 milliseconds';
   ```

### Performance Requirements
- **Ingestion latency**: <5ms (p99)
- **Query latency**: <10ms (p95) for real-time, <100ms for historical
- **Compression ratio**: >5x for old data
- **Uptime**: 99.99%

### Why mojo-postgres?
- ✅ Zero-copy orderbook ingestion at 15K updates/sec
- ✅ SIMD-accelerated price calculations
- ✅ Sub-millisecond prepared statement execution
- ✅ Direct integration with MDDC-AI trading engine
- ✅ No Python GIL for low-latency critical path

---

## 2. High-Frequency Market Data 🔷

### Domain
Financial market data platform aggregating tick-by-tick trades from global exchanges.

### Problem Statement
Collect, normalize, and distribute every trade from NYSE, NASDAQ, LSE, and 20+ other exchanges. Support real-time analytics and historical backtesting for quantitative traders.

### Data Volume
- **Ingestion Rate**: 50,000-200,000 trades/second during market hours
- **Daily Volume**: ~5B trades/day
- **Peak Load**: 500K trades/sec during market open
- **Data Retention**: 10 years

### Schema
```sql
CREATE TABLE trades (
    time            TIMESTAMPTZ NOT NULL,
    exchange        TEXT NOT NULL,
    symbol          TEXT NOT NULL,
    price           NUMERIC(18,6) NOT NULL,
    quantity        NUMERIC(18,6) NOT NULL,
    trade_id        TEXT NOT NULL,
    buyer_maker     BOOLEAN,
    tape            TEXT  -- 'A', 'B', 'C' for US equities
);

SELECT create_hypertable('trades', 'time',
    chunk_time_interval => INTERVAL '15 minutes');

-- OHLCV continuous aggregates at multiple timeframes
CREATE MATERIALIZED VIEW ohlcv_1sec WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 second', time) AS bucket,
    exchange, symbol,
    (array_agg(price ORDER BY time ASC))[1] AS open,
    MAX(price) AS high,
    MIN(price) AS low,
    (array_agg(price ORDER BY time DESC))[1] AS close,
    SUM(quantity) AS volume,
    COUNT(*) AS num_trades
FROM trades
GROUP BY bucket, exchange, symbol;
```

### Critical Queries
1. **VWAP calculation** (Volume-Weighted Average Price)
   ```sql
   SELECT
       symbol,
       SUM(price * quantity) / SUM(quantity) AS vwap
   FROM trades
   WHERE symbol = 'AAPL'
     AND time BETWEEN '2024-01-01 09:30:00' AND '2024-01-01 16:00:00'
   GROUP BY symbol;
   ```

2. **Tick imbalance analysis**
   ```sql
   SELECT
       time_bucket('1 minute', time) AS bucket,
       COUNT(*) FILTER (WHERE buyer_maker) AS buy_ticks,
       COUNT(*) FILTER (WHERE NOT buyer_maker) AS sell_ticks,
       (COUNT(*) FILTER (WHERE buyer_maker)::FLOAT /
        COUNT(*)::FLOAT) AS buy_ratio
   FROM trades
   WHERE symbol = 'SPY'
     AND time > NOW() - INTERVAL '1 hour';
   ```

### Performance Requirements
- **Ingestion**: 500K trades/sec peak
- **Query**: <50ms for 1-day VWAP, <500ms for 1-year backtest
- **Compression**: 10x+ for historical data

### Why mojo-postgres?
- ✅ Handles 500K inserts/sec with COPY protocol
- ✅ Parallel chunk scanning for historical backtests
- ✅ Continuous aggregates for real-time OHLCV
- ✅ Direct SIMD path from network buffer to database

---

## 3. DeFi Protocol Monitoring 🔷

### Domain
Decentralized Finance (DeFi) protocol analytics tracking liquidity, trades, and arbitrage across Ethereum, BSC, and other chains.

### Problem Statement
Monitor 500+ DeFi protocols in real-time, tracking swaps, liquidity adds/removes, and flash loans. Detect arbitrage opportunities and MEV (Miner Extractable Value) within 100ms of transaction confirmation.

### Data Volume
- **Ingestion Rate**: 5,000-50,000 events/second
- **Daily Volume**: ~2B events/day
- **Chains**: 10+ EVM chains
- **Protocols**: 500+ DEXes, lending platforms

### Schema
```sql
CREATE TABLE defi_events (
    time                TIMESTAMPTZ NOT NULL,
    chain               TEXT NOT NULL,
    protocol            TEXT NOT NULL,
    event_type          TEXT NOT NULL,  -- 'swap', 'add_liquidity', 'remove_liquidity', 'flash_loan'
    transaction_hash    TEXT NOT NULL,
    pool_address        TEXT NOT NULL,
    token_in            TEXT,
    token_out           TEXT,
    amount_in           NUMERIC(38,0),  -- Wei/smallest unit
    amount_out          NUMERIC(38,0),
    sender              TEXT,
    block_number        BIGINT
);

SELECT create_hypertable('defi_events', 'time',
    chunk_time_interval => INTERVAL '1 hour');

-- Track liquidity pools
CREATE TABLE pool_state (
    time                TIMESTAMPTZ NOT NULL,
    chain               TEXT NOT NULL,
    protocol            TEXT NOT NULL,
    pool_address        TEXT NOT NULL,
    token0              TEXT NOT NULL,
    token1              TEXT NOT NULL,
    reserve0            NUMERIC(38,0),
    reserve1            NUMERIC(38,0),
    total_supply        NUMERIC(38,0),
    price               NUMERIC(38,18)  -- token1/token0
);

SELECT create_hypertable('pool_state', 'time',
    chunk_time_interval => INTERVAL '30 minutes');
```

### Critical Queries
1. **Cross-protocol arbitrage detection**
   ```sql
   SELECT
       a.protocol AS buy_protocol,
       b.protocol AS sell_protocol,
       a.pool_address AS buy_pool,
       b.pool_address AS sell_pool,
       b.price / a.price - 1 AS profit_pct
   FROM pool_state a
   JOIN pool_state b
       ON a.token0 = b.token0
       AND a.token1 = b.token1
       AND a.chain = b.chain
   WHERE a.time > NOW() - INTERVAL '10 seconds'
     AND b.time > NOW() - INTERVAL '10 seconds'
     AND a.protocol != b.protocol
     AND b.price > a.price * 1.001  -- >0.1% profit
   ORDER BY profit_pct DESC;
   ```

2. **Flash loan analysis**
   ```sql
   SELECT
       transaction_hash,
       array_agg(event_type ORDER BY time) AS event_sequence,
       SUM(amount_in) AS total_borrowed,
       COUNT(*) AS num_swaps
   FROM defi_events
   WHERE time > NOW() - INTERVAL '1 minute'
     AND transaction_hash IN (
         SELECT transaction_hash
         FROM defi_events
         WHERE event_type = 'flash_loan'
     )
   GROUP BY transaction_hash;
   ```

### Performance Requirements
- **Ingestion**: 50K events/sec during high volatility
- **Arbitrage detection**: <100ms end-to-end
- **Historical analysis**: <1s for 7-day patterns

### Why mojo-postgres?
- ✅ Sub-100ms arbitrage detection with chunk pruning
- ✅ High-throughput event ingestion
- ✅ Parallel scanning for MEV analysis
- ✅ Real-time continuous aggregates for pool metrics

---

## 4. IoT Sensor Network

### Domain
Smart city infrastructure with 100,000+ sensors monitoring air quality, traffic, noise, and weather.

### Data Volume
- **Sensors**: 100,000
- **Reading Frequency**: 1 reading/second per sensor
- **Ingestion Rate**: 100,000 readings/sec
- **Daily Volume**: ~8.6B readings/day

### Schema
```sql
CREATE TABLE sensor_readings (
    time            TIMESTAMPTZ NOT NULL,
    sensor_id       INT NOT NULL,
    sensor_type     TEXT NOT NULL,  -- 'air_quality', 'traffic', 'noise', 'weather'
    location_lat    NUMERIC(9,6),
    location_lon    NUMERIC(9,6),
    metric_name     TEXT NOT NULL,
    value           NUMERIC(10,4),
    unit            TEXT
);

SELECT create_hypertable('sensor_readings', 'time',
    chunk_time_interval => INTERVAL '6 hours');

-- Compress after 3 days
ALTER TABLE sensor_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id,sensor_type',
    timescaledb.compress_orderby = 'time DESC'
);
```

### Critical Queries
1. **Anomaly detection** (real-time)
2. **Heatmap generation** (city-wide)
3. **Predictive maintenance** (sensor failure prediction)

### Performance Requirements
- **Ingestion**: 100K readings/sec sustained
- **Query**: <1s for city-wide heatmap
- **Compression**: 20x for old sensor data

### Why mojo-postgres?
- ✅ Efficient compression for repetitive sensor data
- ✅ Fast spatial queries with TimescaleDB
- ✅ Parallel aggregations across sensors

---

## 5. Application Performance Monitoring (APM)

### Domain
Enterprise APM platform monitoring 10,000+ microservices across cloud infrastructure.

### Data Volume
- **Services**: 10,000
- **Traces/sec**: 500,000
- **Metrics/sec**: 1,000,000
- **Daily Volume**: ~100B metrics/day

### Schema
```sql
CREATE TABLE traces (
    time            TIMESTAMPTZ NOT NULL,
    trace_id        TEXT NOT NULL,
    span_id         TEXT NOT NULL,
    parent_span_id  TEXT,
    service_name    TEXT NOT NULL,
    operation_name  TEXT NOT NULL,
    duration_ms     NUMERIC(10,3),
    status_code     INT,
    tags            JSONB
);

SELECT create_hypertable('traces', 'time',
    chunk_time_interval => INTERVAL '1 hour');

CREATE TABLE metrics (
    time            TIMESTAMPTZ NOT NULL,
    metric_name     TEXT NOT NULL,
    service_name    TEXT NOT NULL,
    value           NUMERIC(18,6),
    tags            JSONB
);

SELECT create_hypertable('metrics', 'time',
    chunk_time_interval => INTERVAL '1 hour');
```

### Critical Queries
1. **P95/P99 latency calculation**
2. **Error rate tracking**
3. **Service dependency mapping**

### Performance Requirements
- **Ingestion**: 1.5M metrics+traces/sec
- **Dashboards**: <500ms refresh
- **Alerting**: <10s detection

### Why mojo-postgres?
- ✅ Million-row/sec ingestion with COPY
- ✅ Percentile calculations with continuous aggregates
- ✅ Fast JSONB indexing for tags

---

## 6. Real-Time Gaming Analytics

### Domain
Multiplayer game with 10M+ DAU tracking player actions, economy, and matchmaking.

### Data Volume
- **Events/sec**: 200,000
- **Daily Volume**: ~17B events/day
- **Player actions**: kills, deaths, purchases, logins

### Schema
```sql
CREATE TABLE player_events (
    time            TIMESTAMPTZ NOT NULL,
    player_id       BIGINT NOT NULL,
    session_id      TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    event_data      JSONB,
    server_id       TEXT
);

SELECT create_hypertable('player_events', 'time',
    chunk_time_interval => INTERVAL '2 hours');
```

### Critical Queries
1. **Real-time leaderboards**
2. **Cheat detection**
3. **Player behavior segmentation**

### Performance Requirements
- **Ingestion**: 200K events/sec
- **Leaderboard updates**: <1s
- **Analytics**: <5s for 7-day cohorts

### Why mojo-postgres?
- ✅ Fast JSONB queries for flexible event data
- ✅ Continuous aggregates for leaderboards
- ✅ Real-time anomaly detection

---

## 7. E-Commerce Clickstream Analysis

### Domain
Global e-commerce platform tracking user behavior across website and mobile apps.

### Data Volume
- **MAU**: 500M
- **Events/sec**: 1,000,000
- **Daily Volume**: ~86B events/day

### Schema
```sql
CREATE TABLE clickstream (
    time            TIMESTAMPTZ NOT NULL,
    user_id         TEXT,
    session_id      TEXT NOT NULL,
    event_type      TEXT NOT NULL,  -- 'view', 'click', 'add_to_cart', 'purchase'
    product_id      TEXT,
    category        TEXT,
    price           NUMERIC(10,2),
    device_type     TEXT,
    country         TEXT,
    referrer        TEXT
);

SELECT create_hypertable('clickstream', 'time',
    chunk_time_interval => INTERVAL '1 hour');
```

### Critical Queries
1. **Conversion funnel analysis**
2. **Real-time recommendations**
3. **A/B test analytics**

### Performance Requirements
- **Ingestion**: 1M events/sec peak
- **Dashboards**: <2s query time
- **ML feature extraction**: <10s for 30-day windows

### Why mojo-postgres?
- ✅ Handles 1M events/sec with batching
- ✅ Fast session-based aggregations
- ✅ Efficient compression for old clickstream data

---

## 8. Smart City Traffic Management

### Domain
City-wide traffic monitoring with cameras, radar, and GPS data from vehicles.

### Data Volume
- **Sensors**: 50,000
- **Readings/sec**: 50,000
- **Daily Volume**: ~4.3B readings/day

### Schema
```sql
CREATE TABLE traffic_data (
    time            TIMESTAMPTZ NOT NULL,
    sensor_id       INT NOT NULL,
    location_lat    NUMERIC(9,6),
    location_lon    NUMERIC(9,6),
    vehicle_count   INT,
    avg_speed_kmh   NUMERIC(5,2),
    congestion_level TEXT,  -- 'low', 'medium', 'high'
    incident        BOOLEAN
);

SELECT create_hypertable('traffic_data', 'time',
    chunk_time_interval => INTERVAL '3 hours');
```

### Critical Queries
1. **Traffic prediction**
2. **Incident detection**
3. **Route optimization**

### Performance Requirements
- **Ingestion**: 50K readings/sec
- **Incident detection**: <5s
- **Historical analysis**: <10s for 1-month patterns

### Why mojo-postgres?
- ✅ Real-time aggregations with CAGGs
- ✅ Spatial queries with PostGIS integration
- ✅ Fast time-series predictions

---

## 9. Healthcare Patient Monitoring

### Domain
Hospital ICU monitoring vital signs from 1,000 beds with medical devices.

### Data Volume
- **Devices/bed**: 5 (ECG, BP, SpO2, etc.)
- **Readings/sec**: 50 per device
- **Total**: 250,000 readings/sec

### Schema
```sql
CREATE TABLE vitals (
    time            TIMESTAMPTZ NOT NULL,
    patient_id      INT NOT NULL,
    device_id       TEXT NOT NULL,
    metric_name     TEXT NOT NULL,  -- 'heart_rate', 'blood_pressure', 'spo2', etc.
    value           NUMERIC(10,4),
    unit            TEXT,
    alert_triggered BOOLEAN
);

SELECT create_hypertable('vitals', 'time',
    chunk_time_interval => INTERVAL '1 hour');
```

### Critical Queries
1. **Real-time alerting** (sub-second)
2. **Trend analysis**
3. **Anomaly detection**

### Performance Requirements
- **Ingestion**: 250K readings/sec
- **Alerts**: <500ms detection
- **Dashboards**: <1s refresh

### Why mojo-postgres?
- ✅ Sub-second alert detection with triggers
- ✅ Reliable data storage (ACID compliance)
- ✅ Fast trend queries with continuous aggregates

---

## 10. DevOps Metrics & Logs

### Domain
Cloud infrastructure monitoring for 100,000 containers/VMs with logs and metrics.

### Data Volume
- **Hosts**: 100,000
- **Metrics/sec**: 2,000,000
- **Logs/sec**: 500,000
- **Daily Volume**: ~200B metrics + 50B logs

### Schema
```sql
CREATE TABLE metrics (
    time            TIMESTAMPTZ NOT NULL,
    host_id         TEXT NOT NULL,
    metric_name     TEXT NOT NULL,
    value           NUMERIC(18,6),
    tags            JSONB
);

SELECT create_hypertable('metrics', 'time',
    chunk_time_interval => INTERVAL '30 minutes');

CREATE TABLE logs (
    time            TIMESTAMPTZ NOT NULL,
    host_id         TEXT NOT NULL,
    level           TEXT NOT NULL,  -- 'DEBUG', 'INFO', 'WARN', 'ERROR'
    message         TEXT,
    service         TEXT,
    metadata        JSONB
);

SELECT create_hypertable('logs', 'time',
    chunk_time_interval => INTERVAL '1 hour');
```

### Critical Queries
1. **Error rate monitoring**
2. **Resource utilization**
3. **Log search and correlation**

### Performance Requirements
- **Ingestion**: 2.5M events/sec combined
- **Dashboards**: <1s queries
- **Log search**: <5s for 1-hour window

### Why mojo-postgres?
- ✅ Handles 2.5M inserts/sec
- ✅ Fast text search with GIN indexes
- ✅ Compression reduces log storage by 10x

---

## Summary Comparison

| Use Case | Events/Sec | Daily Volume | Key Feature | Performance Requirement |
|----------|-----------|--------------|-------------|------------------------|
| **Crypto Trading** 🔷 | 15K | 500M | Sub-ms trading | <5ms ingestion |
| **Market Data** 🔷 | 200K | 5B | VWAP/OHLCV | <50ms queries |
| **DeFi Monitoring** 🔷 | 50K | 2B | Arbitrage detection | <100ms detection |
| **IoT Sensors** | 100K | 8.6B | Compression | 20x compression |
| **APM** | 1.5M | 100B | Percentiles | <500ms dashboards |
| **Gaming** | 200K | 17B | Leaderboards | <1s updates |
| **E-Commerce** | 1M | 86B | Funnels | <2s analytics |
| **Traffic** | 50K | 4.3B | Prediction | <5s incident |
| **Healthcare** | 250K | 21B | Alerting | <500ms alerts |
| **DevOps** | 2.5M | 250B | Log search | <5s search |

All use cases benefit from mojo-postgres's:
- ✅ High-throughput ingestion (COPY protocol)
- ✅ Fast time-range queries (chunk pruning)
- ✅ Efficient storage (compression)
- ✅ Real-time aggregations (continuous aggregates)
- ✅ Zero-copy performance (no Python overhead)
