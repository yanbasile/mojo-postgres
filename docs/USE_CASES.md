# Real-World Use Cases for mojo-postgres

This document presents 12 real-world use cases across multiple industries where mojo-postgres excels, with a focus on high-frequency time-series data and performance-critical applications.

## Table of Contents

1. [Cryptocurrency Trading & Analytics](#1-cryptocurrency-trading--analytics) 🔷
2. [High-Frequency Market Data](#2-high-frequency-market-data) 🔷
3. [DeFi Protocol Monitoring](#3-defi-protocol-monitoring) 🔷
4. [IoT Sensor Network](#4-iot-sensor-network)
5. [Application Performance Monitoring (APM)](#5-application-performance-monitoring-apm)
6. [Real-Time Gaming Analytics](#6-real-time-gaming-analytics)
7. [E-Commerce Clickstream Analysis](#7-e-commerce-clickstream-analysis)
8. [Smart City Traffic Management](#8-smart-city-traffic-management)
9. [Deep Learning Experiment Tracking](#9-deep-learning-experiment-tracking)
10. [DevOps Metrics & Logs](#10-devops-metrics--logs)
11. [LLM Training & Fine-Tuning](#11-llm-training--fine-tuning)
12. [LLM Inference & RAG Systems](#12-llm-inference--rag-systems)

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

## 9. Deep Learning Experiment Tracking

### Domain
ML Platform tracking experiments, hyperparameters, and metrics for distributed deep learning training across 1,000+ GPUs.

### Problem Statement
Track millions of training experiments for computer vision, NLP, and multimodal models. Store hyperparameters, training metrics (loss, accuracy, perplexity), validation results, and model checkpoints metadata. Enable fast experiment comparison and automatic hyperparameter optimization.

### Data Volume
- **Concurrent Experiments**: 10,000
- **Metrics/sec**: 500,000 (100 metrics per experiment every 200ms)
- **Daily Volume**: ~43B metrics/day
- **Experiment Duration**: Minutes to weeks
- **Data Retention**: Indefinite (research archive)

### Schema
```sql
CREATE TABLE experiments (
    experiment_id       TEXT PRIMARY KEY,
    user_id             TEXT NOT NULL,
    project_name        TEXT NOT NULL,
    model_architecture  TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    status              TEXT NOT NULL,  -- 'running', 'completed', 'failed'
    hyperparameters     JSONB NOT NULL,
    git_commit          TEXT,
    dataset_version     TEXT
);

CREATE TABLE training_metrics (
    time                TIMESTAMPTZ NOT NULL,
    experiment_id       TEXT NOT NULL,
    epoch               INT,
    step                BIGINT NOT NULL,
    metric_name         TEXT NOT NULL,  -- 'loss', 'accuracy', 'perplexity', 'throughput'
    metric_value        NUMERIC(18,8),
    phase               TEXT,           -- 'train', 'val', 'test'
    gpu_id              INT
);

SELECT create_hypertable('training_metrics', 'time',
    chunk_time_interval => INTERVAL '6 hours');

CREATE INDEX ON training_metrics (experiment_id, time DESC);
CREATE INDEX ON training_metrics (metric_name, time DESC);

-- Enable compression after 7 days
ALTER TABLE training_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'experiment_id,metric_name',
    timescaledb.compress_orderby = 'time DESC'
);

-- Continuous aggregate for experiment summaries
CREATE MATERIALIZED VIEW experiment_summary
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('5 minutes', time) AS bucket,
    experiment_id,
    metric_name,
    AVG(metric_value) AS avg_value,
    MIN(metric_value) AS min_value,
    MAX(metric_value) AS max_value,
    STDDEV(metric_value) AS stddev_value
FROM training_metrics
GROUP BY bucket, experiment_id, metric_name;

CREATE TABLE model_checkpoints (
    time                TIMESTAMPTZ NOT NULL,
    experiment_id       TEXT NOT NULL,
    checkpoint_id       TEXT PRIMARY KEY,
    epoch               INT,
    step                BIGINT,
    metrics             JSONB,          -- Best metrics at checkpoint
    model_size_bytes    BIGINT,
    storage_path        TEXT,
    is_best             BOOLEAN
);

SELECT create_hypertable('model_checkpoints', 'time',
    chunk_time_interval => INTERVAL '1 day');
```

### Critical Queries

1. **Real-time training monitoring** (sub-100ms)
   ```sql
   SELECT
       time,
       metric_name,
       metric_value,
       step
   FROM training_metrics
   WHERE experiment_id = 'exp_123'
     AND time > NOW() - INTERVAL '5 minutes'
   ORDER BY time DESC;
   ```

2. **Best experiment search** (sub-1s across 100K experiments)
   ```sql
   WITH best_val_loss AS (
       SELECT
           experiment_id,
           MIN(metric_value) AS best_loss
       FROM training_metrics
       WHERE metric_name = 'val_loss'
         AND phase = 'val'
         AND time > NOW() - INTERVAL '7 days'
       GROUP BY experiment_id
   )
   SELECT
       e.experiment_id,
       e.model_architecture,
       e.hyperparameters,
       b.best_loss
   FROM experiments e
   JOIN best_val_loss b ON e.experiment_id = b.experiment_id
   WHERE e.project_name = 'vision_transformer'
   ORDER BY b.best_loss ASC
   LIMIT 10;
   ```

3. **Hyperparameter correlation analysis** (sub-5s)
   ```sql
   SELECT
       e.hyperparameters->>'learning_rate' AS lr,
       e.hyperparameters->>'batch_size' AS bs,
       AVG(m.metric_value) AS avg_final_accuracy
   FROM experiments e
   JOIN training_metrics m ON e.experiment_id = m.experiment_id
   WHERE m.metric_name = 'accuracy'
     AND m.phase = 'val'
     AND m.epoch = (
         SELECT MAX(epoch)
         FROM training_metrics
         WHERE experiment_id = e.experiment_id
     )
   GROUP BY lr, bs
   ORDER BY avg_final_accuracy DESC;
   ```

4. **GPU utilization tracking** (real-time)
   ```sql
   SELECT
       gpu_id,
       COUNT(DISTINCT experiment_id) AS active_experiments,
       AVG(metric_value) FILTER (WHERE metric_name = 'gpu_memory_used') AS avg_memory,
       AVG(metric_value) FILTER (WHERE metric_name = 'throughput') AS avg_throughput
   FROM training_metrics
   WHERE time > NOW() - INTERVAL '1 minute'
   GROUP BY gpu_id;
   ```

### Performance Requirements
- **Ingestion**: 500K metrics/sec during peak training
- **Dashboard queries**: <100ms for active experiments
- **Experiment search**: <1s across 100K+ experiments
- **Hyperparameter analysis**: <5s for correlation studies
- **Compression**: 10-20x for old experiment data

### Why mojo-postgres?
- ✅ High-throughput metric ingestion (500K/sec)
- ✅ Fast JSONB queries for hyperparameter search
- ✅ Continuous aggregates for dashboard performance
- ✅ Efficient compression for long-term experiment archive
- ✅ Sub-100ms queries for real-time training monitoring
- ✅ ACID transactions for checkpoint consistency

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

## 11. LLM Training & Fine-Tuning

### Domain
Large Language Model training platform tracking pre-training and fine-tuning runs for models from 1B to 100B+ parameters across distributed GPU clusters.

### Problem Statement
Track LLM training runs with billions of parameters across thousands of GPUs. Monitor training metrics (loss, perplexity, throughput), checkpoint metadata, data pipeline statistics, and resource utilization. Enable fast comparison of training configurations and automatic detection of training instabilities.

### Data Volume
- **Concurrent Training Runs**: 500 (pre-training + fine-tuning)
- **Metrics/sec**: 1,000,000 (distributed across GPUs)
- **Daily Volume**: ~86B metrics/day
- **Training Duration**: Weeks to months for pre-training
- **Data Retention**: Permanent (research + compliance)

### Schema
```sql
CREATE TABLE llm_training_runs (
    run_id              TEXT PRIMARY KEY,
    model_name          TEXT NOT NULL,
    model_size          TEXT NOT NULL,       -- '7B', '13B', '70B', etc.
    training_type       TEXT NOT NULL,       -- 'pretraining', 'fine-tuning', 'rlhf'
    started_at          TIMESTAMPTZ NOT NULL,
    status              TEXT NOT NULL,       -- 'running', 'paused', 'completed', 'failed'
    config              JSONB NOT NULL,      -- All hyperparameters
    num_gpus            INT,
    total_tokens        BIGINT,
    dataset_name        TEXT,
    base_model          TEXT                 -- For fine-tuning
);

CREATE TABLE llm_training_metrics (
    time                TIMESTAMPTZ NOT NULL,
    run_id              TEXT NOT NULL,
    global_step         BIGINT NOT NULL,
    tokens_processed    BIGINT,

    -- Loss metrics
    loss                NUMERIC(18,8),
    grad_norm           NUMERIC(18,8),

    -- LLM-specific metrics
    perplexity          NUMERIC(18,8),
    token_accuracy      NUMERIC(8,6),

    -- Performance metrics
    throughput_tps      NUMERIC(18,2),      -- Tokens per second
    mfu_percent         NUMERIC(8,4),       -- Model FLOPs Utilization

    -- Resource metrics
    gpu_id              INT,
    gpu_memory_used_gb  NUMERIC(10,2),
    gpu_utilization     NUMERIC(5,2),

    -- Optimizer state
    learning_rate       NUMERIC(12,10),

    phase               TEXT                 -- 'train', 'eval'
);

SELECT create_hypertable('llm_training_metrics', 'time',
    chunk_time_interval => INTERVAL '12 hours');

CREATE INDEX ON llm_training_metrics (run_id, time DESC);
CREATE INDEX ON llm_training_metrics (run_id, global_step DESC);

-- Enable compression after 3 days
ALTER TABLE llm_training_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'run_id,gpu_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Continuous aggregate for training progress
CREATE MATERIALIZED VIEW llm_training_progress
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('10 minutes', time) AS bucket,
    run_id,
    AVG(loss) AS avg_loss,
    MIN(loss) AS min_loss,
    AVG(perplexity) AS avg_perplexity,
    AVG(throughput_tps) AS avg_throughput,
    AVG(mfu_percent) AS avg_mfu,
    MAX(tokens_processed) AS total_tokens
FROM llm_training_metrics
WHERE phase = 'train'
GROUP BY bucket, run_id;

CREATE TABLE llm_checkpoints (
    time                TIMESTAMPTZ NOT NULL,
    run_id              TEXT NOT NULL,
    checkpoint_id       TEXT PRIMARY KEY,
    global_step         BIGINT,
    tokens_processed    BIGINT,

    -- Checkpoint metrics
    train_loss          NUMERIC(18,8),
    eval_loss           NUMERIC(18,8),
    eval_perplexity     NUMERIC(18,8),

    -- Storage
    checkpoint_size_gb  NUMERIC(12,2),
    storage_path        TEXT,

    -- Evaluation benchmarks
    benchmark_scores    JSONB,              -- MMLU, HellaSwag, etc.

    is_best             BOOLEAN,
    is_published        BOOLEAN
);

SELECT create_hypertable('llm_checkpoints', 'time',
    chunk_time_interval => INTERVAL '7 days');

CREATE TABLE training_instabilities (
    time                TIMESTAMPTZ NOT NULL,
    run_id              TEXT NOT NULL,
    global_step         BIGINT,
    instability_type    TEXT NOT NULL,      -- 'nan_loss', 'grad_explosion', 'throughput_drop'
    severity            TEXT NOT NULL,      -- 'warning', 'critical'
    details             JSONB,
    auto_recovered      BOOLEAN
);

SELECT create_hypertable('training_instabilities', 'time',
    chunk_time_interval => INTERVAL '1 month');
```

### Critical Queries

1. **Real-time training dashboard** (sub-100ms)
   ```sql
   SELECT
       time,
       loss,
       perplexity,
       throughput_tps,
       mfu_percent,
       tokens_processed
   FROM llm_training_metrics
   WHERE run_id = 'llama3-70b-pretrain'
     AND time > NOW() - INTERVAL '10 minutes'
     AND phase = 'train'
   ORDER BY time DESC
   LIMIT 1000;
   ```

2. **Training stability analysis** (sub-1s)
   ```sql
   WITH recent_metrics AS (
       SELECT
           time_bucket('1 minute', time) AS bucket,
           AVG(loss) AS avg_loss,
           STDDEV(loss) AS stddev_loss,
           AVG(grad_norm) AS avg_grad_norm,
           MAX(grad_norm) AS max_grad_norm
       FROM llm_training_metrics
       WHERE run_id = 'llama3-70b-pretrain'
         AND time > NOW() - INTERVAL '1 hour'
       GROUP BY bucket
   )
   SELECT
       bucket,
       avg_loss,
       stddev_loss,
       CASE
           WHEN avg_loss != avg_loss THEN 'NAN_DETECTED'
           WHEN stddev_loss > avg_loss * 0.5 THEN 'HIGH_VARIANCE'
           WHEN max_grad_norm > 1.0 THEN 'GRAD_EXPLOSION'
           ELSE 'STABLE'
       END AS stability_status
   FROM recent_metrics
   ORDER BY bucket DESC;
   ```

3. **Throughput optimization** (sub-500ms)
   ```sql
   SELECT
       r.config->>'batch_size' AS batch_size,
       r.config->>'gradient_accumulation_steps' AS grad_accum,
       r.config->>'sequence_length' AS seq_len,
       AVG(m.throughput_tps) AS avg_throughput,
       AVG(m.mfu_percent) AS avg_mfu
   FROM llm_training_runs r
   JOIN llm_training_metrics m ON r.run_id = m.run_id
   WHERE r.model_size = '70B'
     AND m.time > NOW() - INTERVAL '1 day'
     AND m.phase = 'train'
   GROUP BY batch_size, grad_accum, seq_len
   ORDER BY avg_throughput DESC
   LIMIT 20;
   ```

4. **Checkpoint comparison** (sub-1s)
   ```sql
   SELECT
       checkpoint_id,
       global_step,
       tokens_processed,
       eval_loss,
       eval_perplexity,
       benchmark_scores->>'mmlu' AS mmlu_score,
       benchmark_scores->>'hellaswag' AS hellaswag_score,
       checkpoint_size_gb
   FROM llm_checkpoints
   WHERE run_id = 'llama3-70b-pretrain'
     AND eval_loss IS NOT NULL
   ORDER BY eval_loss ASC
   LIMIT 10;
   ```

### Performance Requirements
- **Ingestion**: 1M metrics/sec across distributed training
- **Dashboard updates**: <100ms for real-time monitoring
- **Stability detection**: <1s for instability alerts
- **Checkpoint queries**: <1s for best model selection
- **Compression**: 15-20x for old training runs

### Why mojo-postgres?
- ✅ 1M metrics/sec ingestion for distributed training
- ✅ Sub-100ms queries for real-time loss monitoring
- ✅ Fast JSONB queries for hyperparameter optimization
- ✅ Continuous aggregates for training progress dashboards
- ✅ Efficient storage of multi-month training runs
- ✅ ACID compliance for checkpoint metadata integrity

---

## 12. LLM Inference & RAG Systems

### Domain
Production LLM inference platform serving 1M+ requests/day with Retrieval-Augmented Generation (RAG), prompt caching, and token usage tracking.

### Problem Statement
Track all LLM inference requests including prompts, completions, retrieved context, token usage, latency, and costs. Enable prompt optimization, RAG performance analysis, user behavior tracking, and cost attribution. Support A/B testing of different prompts and model configurations.

### Data Volume
- **Requests/sec**: 1,000-10,000 (peak during business hours)
- **Daily Volume**: ~50M requests/day
- **Average tokens/request**: 2,000 (prompt + completion)
- **RAG retrievals**: 3-10 documents per request
- **Data Retention**: 90 days hot, 1 year compressed

### Schema
```sql
CREATE TABLE llm_requests (
    time                TIMESTAMPTZ NOT NULL,
    request_id          TEXT PRIMARY KEY,
    user_id             TEXT NOT NULL,
    session_id          TEXT,

    -- Model info
    model_name          TEXT NOT NULL,      -- 'gpt-4', 'claude-3', 'llama-70b', etc.
    model_version       TEXT,

    -- Request details
    prompt_template     TEXT,               -- Template name/ID
    prompt_tokens       INT,
    completion_tokens   INT,
    total_tokens        INT,

    -- RAG details
    rag_enabled         BOOLEAN,
    num_retrieved_docs  INT,
    retrieval_latency_ms INT,

    -- Performance
    total_latency_ms    INT,
    ttft_ms             INT,               -- Time to first token
    tokens_per_second   NUMERIC(10,2),

    -- Response
    finish_reason       TEXT,              -- 'stop', 'length', 'content_filter'
    status_code         INT,

    -- Cost & attribution
    cost_usd            NUMERIC(10,6),
    department          TEXT,
    application         TEXT,

    -- Quality
    user_rating         INT,               -- 1-5 if provided
    regenerated         BOOLEAN
);

SELECT create_hypertable('llm_requests', 'time',
    chunk_time_interval => INTERVAL '1 day');

CREATE INDEX ON llm_requests (user_id, time DESC);
CREATE INDEX ON llm_requests (model_name, time DESC);
CREATE INDEX ON llm_requests (application, time DESC);

-- Enable compression after 7 days
ALTER TABLE llm_requests SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'model_name,application',
    timescaledb.compress_orderby = 'time DESC'
);

CREATE TABLE rag_retrievals (
    time                TIMESTAMPTZ NOT NULL,
    request_id          TEXT NOT NULL,
    document_id         TEXT NOT NULL,
    rank                INT,                -- 1 for top result
    relevance_score     NUMERIC(6,4),
    chunk_text          TEXT,               -- Retrieved text chunk
    metadata            JSONB,
    used_in_context     BOOLEAN             -- Was it actually used?
);

SELECT create_hypertable('rag_retrievals', 'time',
    chunk_time_interval => INTERVAL '1 day');

-- Continuous aggregate for usage analytics
CREATE MATERIALIZED VIEW llm_usage_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    model_name,
    application,
    COUNT(*) AS num_requests,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost,
    AVG(total_latency_ms) AS avg_latency,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY total_latency_ms) AS p95_latency,
    AVG(tokens_per_second) AS avg_throughput
FROM llm_requests
GROUP BY bucket, model_name, application;

CREATE TABLE prompt_experiments (
    experiment_id       TEXT PRIMARY KEY,
    prompt_template_a   TEXT NOT NULL,
    prompt_template_b   TEXT NOT NULL,
    model_name          TEXT NOT NULL,
    started_at          TIMESTAMPTZ NOT NULL,
    ended_at            TIMESTAMPTZ,
    status              TEXT,

    -- Results
    variant_a_requests  INT,
    variant_b_requests  INT,
    variant_a_avg_rating NUMERIC(3,2),
    variant_b_avg_rating NUMERIC(3,2),
    winner              TEXT                -- 'A', 'B', or 'no_difference'
);

CREATE TABLE token_cache_hits (
    time                TIMESTAMPTZ NOT NULL,
    model_name          TEXT NOT NULL,
    cache_key_hash      TEXT NOT NULL,
    hit                 BOOLEAN,
    tokens_saved        INT,
    latency_saved_ms    INT
);

SELECT create_hypertable('token_cache_hits', 'time',
    chunk_time_interval => INTERVAL '6 hours');
```

### Critical Queries

1. **Real-time usage dashboard** (sub-100ms)
   ```sql
   SELECT
       COUNT(*) AS requests,
       SUM(total_tokens) AS tokens,
       SUM(cost_usd) AS cost,
       AVG(total_latency_ms) AS avg_latency
   FROM llm_requests
   WHERE time > NOW() - INTERVAL '5 minutes'
   GROUP BY time_bucket('1 minute', time)
   ORDER BY time_bucket DESC;
   ```

2. **Cost attribution** (sub-1s)
   ```sql
   SELECT
       department,
       application,
       model_name,
       COUNT(*) AS num_requests,
       SUM(total_tokens) AS total_tokens,
       SUM(cost_usd) AS total_cost,
       AVG(user_rating) AS avg_rating
   FROM llm_requests
   WHERE time > NOW() - INTERVAL '24 hours'
   GROUP BY department, application, model_name
   ORDER BY total_cost DESC;
   ```

3. **RAG performance analysis** (sub-2s)
   ```sql
   WITH rag_metrics AS (
       SELECT
           r.request_id,
           r.total_latency_ms,
           r.retrieval_latency_ms,
           r.user_rating,
           COUNT(rv.document_id) AS num_docs_retrieved,
           AVG(rv.relevance_score) AS avg_relevance
       FROM llm_requests r
       JOIN rag_retrievals rv ON r.request_id = rv.request_id
       WHERE r.time > NOW() - INTERVAL '7 days'
         AND r.rag_enabled = true
       GROUP BY r.request_id, r.total_latency_ms,
                r.retrieval_latency_ms, r.user_rating
   )
   SELECT
       num_docs_retrieved,
       COUNT(*) AS num_requests,
       AVG(retrieval_latency_ms) AS avg_retrieval_latency,
       AVG(total_latency_ms) AS avg_total_latency,
       AVG(user_rating) AS avg_rating
   FROM rag_metrics
   GROUP BY num_docs_retrieved
   ORDER BY num_docs_retrieved;
   ```

4. **Prompt A/B testing results** (sub-500ms)
   ```sql
   SELECT
       r.prompt_template,
       COUNT(*) AS num_requests,
       AVG(r.user_rating) AS avg_rating,
       AVG(r.total_latency_ms) AS avg_latency,
       AVG(r.completion_tokens) AS avg_completion_length,
       COUNT(*) FILTER (WHERE r.regenerated = true)::FLOAT / COUNT(*)
           AS regeneration_rate
   FROM llm_requests r
   JOIN prompt_experiments e
       ON r.prompt_template = e.prompt_template_a
           OR r.prompt_template = e.prompt_template_b
   WHERE e.experiment_id = 'exp_001'
     AND r.time BETWEEN e.started_at AND COALESCE(e.ended_at, NOW())
   GROUP BY r.prompt_template;
   ```

5. **Cache effectiveness** (sub-500ms)
   ```sql
   SELECT
       time_bucket('1 hour', time) AS hour,
       model_name,
       COUNT(*) AS total_requests,
       COUNT(*) FILTER (WHERE hit = true) AS cache_hits,
       (COUNT(*) FILTER (WHERE hit = true)::FLOAT / COUNT(*))
           AS cache_hit_rate,
       SUM(tokens_saved) AS total_tokens_saved,
       SUM(latency_saved_ms) AS total_latency_saved_ms
   FROM token_cache_hits
   WHERE time > NOW() - INTERVAL '24 hours'
   GROUP BY hour, model_name
   ORDER BY hour DESC;
   ```

### Performance Requirements
- **Ingestion**: 10K requests/sec peak
- **Dashboard queries**: <100ms for real-time metrics
- **Cost reports**: <1s for daily/weekly attribution
- **RAG analysis**: <2s for performance correlation
- **A/B test results**: <500ms for experiment evaluation
- **Compression**: 10-15x for old request logs

### Why mojo-postgres?
- ✅ 10K requests/sec ingestion during peak traffic
- ✅ Sub-100ms queries for real-time dashboards
- ✅ Fast JSONB queries for metadata and RAG analysis
- ✅ Continuous aggregates for usage analytics
- ✅ Efficient text storage with compression
- ✅ Complex JOIN performance for A/B testing
- ✅ Cost-effective long-term retention

---

## Summary Comparison

| Use Case | Events/Sec | Daily Volume | Key Feature | Performance Requirement |
|----------|-----------|--------------|-------------|------------------------|
| **1. Crypto Trading** 🔷 | 15K | 500M | Sub-ms trading | <5ms ingestion |
| **2. Market Data** 🔷 | 200K | 5B | VWAP/OHLCV | <50ms queries |
| **3. DeFi Monitoring** 🔷 | 50K | 2B | Arbitrage detection | <100ms detection |
| **4. IoT Sensors** | 100K | 8.6B | Compression | 20x compression |
| **5. APM** | 1.5M | 100B | Percentiles | <500ms dashboards |
| **6. Gaming** | 200K | 17B | Leaderboards | <1s updates |
| **7. E-Commerce** | 1M | 86B | Funnels | <2s analytics |
| **8. Traffic** | 50K | 4.3B | Prediction | <5s incident |
| **9. DL Experiments** | 500K | 43B | Hyperparameter search | <100ms dashboards |
| **10. DevOps** | 2.5M | 250B | Log search | <5s search |
| **11. LLM Training** | 1M | 86B | Stability detection | <100ms monitoring |
| **12. LLM Inference** | 10K | 50M requests | RAG + Cost tracking | <100ms dashboards |

All use cases benefit from mojo-postgres's:
- ✅ High-throughput ingestion (COPY protocol)
- ✅ Fast time-range queries (chunk pruning)
- ✅ Efficient storage (compression)
- ✅ Real-time aggregations (continuous aggregates)
- ✅ Zero-copy performance (no Python overhead)
