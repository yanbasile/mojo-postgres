#!/usr/bin/env python3
"""
Python Baseline: Temporal Type Decoding Performance

Measures psycopg2 temporal decoding performance for comparison with mojo-postgres.

Target use case: TimescaleDB time series for cryptocurrency trading

Prerequisites:
    pip install psycopg2-binary
"""

import psycopg2
import time
from datetime import datetime, date, time as time_type


# ============================================================================
# Benchmark Helper
# ============================================================================

class BenchmarkTimer:
    """Simple timer for benchmarking."""

    def __init__(self):
        self.start_time = 0

    def start(self):
        """Start timing."""
        self.start_time = time.perf_counter()

    def elapsed_ms(self) -> float:
        """Get elapsed time in milliseconds."""
        return (time.perf_counter() - self.start_time) * 1000.0


def print_benchmark_result(name: str, iterations: int, total_ms: float):
    """Print formatted benchmark result."""
    avg_us = (total_ms * 1000.0) / iterations
    ops_per_sec = iterations / (total_ms / 1000.0)

    print(f"  {name}")
    print(f"    Total time:   {total_ms:.2f} ms")
    print(f"    Iterations:   {iterations}")
    print(f"    Average:      {avg_us:.3f} μs/op")
    print(f"    Throughput:   {int(ops_per_sec)} ops/sec")


# ============================================================================
# Connection Setup
# ============================================================================

def get_connection():
    """Get PostgreSQL connection."""
    return psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )


# ============================================================================
# Benchmark 1: QueryResult Access Performance
# ============================================================================

def benchmark_query_result_timestamptz():
    """Benchmark TIMESTAMPTZ access from query results."""
    print("\n1. Query Result TIMESTAMPTZ Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 TIMESTAMPTZ values
    cursor.execute("""
        SELECT (TIMESTAMP '2024-01-01 00:00:00' + (n || ' seconds')::INTERVAL) AT TIME ZONE 'UTC' AS ts
        FROM generate_series(1, 100) AS n
    """)
    rows = cursor.fetchall()

    iterations = 5000
    timer = BenchmarkTimer()

    # Benchmark TIMESTAMPTZ access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # datetime object
    total_ms = timer.elapsed_ms()

    print_benchmark_result("TIMESTAMPTZ access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


def benchmark_query_result_date():
    """Benchmark DATE access from query results."""
    print("\n2. Query Result DATE Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 DATE values
    cursor.execute("""
        SELECT (DATE '2024-01-01' + n) AS date
        FROM generate_series(1, 100) AS n
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark DATE access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # date object
    total_ms = timer.elapsed_ms()

    print_benchmark_result("DATE access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


# ============================================================================
# Benchmark 2: TimescaleDB Simulations
# ============================================================================

def benchmark_timescaledb_sensor_data():
    """Benchmark TimescaleDB-style sensor data decoding."""
    print("\n3. TimescaleDB Sensor Data (Realistic Workload)")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create temporary table
    cursor.execute("""
        CREATE TEMPORARY TABLE sensor_data (
            time TIMESTAMPTZ NOT NULL,
            sensor_id INT NOT NULL,
            temperature FLOAT8 NOT NULL,
            humidity FLOAT8 NOT NULL
        )
    """)

    # Insert 1000 sensor readings
    cursor.execute("""
        INSERT INTO sensor_data (time, sensor_id, temperature, humidity)
        SELECT
            TIMESTAMP '2024-01-01 00:00:00' + (n || ' seconds')::INTERVAL,
            (n % 10) + 1,
            20.0 + (random() * 10.0),
            50.0 + (random() * 20.0)
        FROM generate_series(1, 1000) AS n
    """)
    conn.commit()

    # Benchmark: Query and decode sensor data
    iterations = 100
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT time, sensor_id, temperature, humidity
            FROM sensor_data
            ORDER BY time
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            time = row[0]  # datetime
            sensor_id = row[1]  # int
            temperature = row[2]  # float
            humidity = row[3]  # float
            # Process sensor reading

    total_ms = timer.elapsed_ms()

    print(f"  Query + decode 1000 sensor readings")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Average:        {total_ms / iterations:.2f} ms/query")
    print(f"    Readings decoded: {iterations * 1000}")
    print(f"    Decode rate:    {int((iterations * 1000) / (total_ms / 1000.0))} readings/sec")

    cursor.close()
    conn.close()


def benchmark_crypto_ohlcv_data():
    """Benchmark cryptocurrency OHLCV data with timestamps."""
    print("\n4. Cryptocurrency OHLCV Data (1-minute candles)")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create OHLCV table
    cursor.execute("""
        CREATE TEMPORARY TABLE ohlcv_1min (
            time TIMESTAMPTZ NOT NULL,
            symbol VARCHAR(20) NOT NULL,
            open FLOAT8 NOT NULL,
            high FLOAT8 NOT NULL,
            low FLOAT8 NOT NULL,
            close FLOAT8 NOT NULL,
            volume INT8 NOT NULL
        )
    """)

    # Insert 500 candles
    cursor.execute("""
        INSERT INTO ohlcv_1min (time, symbol, open, high, low, close, volume)
        SELECT
            TIMESTAMP '2024-01-01 00:00:00' + (n || ' minutes')::INTERVAL,
            'BTC/USD',
            50000.0 + (random() * 100.0),
            50000.0 + (random() * 150.0),
            50000.0 - (random() * 100.0),
            50000.0 + (random() * 100.0),
            (1000000 + random() * 1000000)::INT8
        FROM generate_series(1, 500) AS n
    """)
    conn.commit()

    # Benchmark: Query and decode OHLCV data
    iterations = 200
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT time, symbol, open, high, low, close, volume
            FROM ohlcv_1min
            ORDER BY time
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            time = row[0]  # datetime
            symbol = row[1]  # str
            open = row[2]  # float
            high = row[3]  # float
            low = row[4]  # float
            close = row[5]  # float
            volume = row[6]  # int
            # Process OHLCV candle

    total_ms = timer.elapsed_ms()
    total_candles = iterations * 500

    print(f"  Query + decode 500 OHLCV candles")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Candles decoded: {total_candles}")
    print(f"    Decode rate:    {int(total_candles / (total_ms / 1000.0))} candles/sec")

    cursor.close()
    conn.close()


def benchmark_date_range_queries():
    """Benchmark DATE queries with range filtering."""
    print("\n5. DATE Range Query Performance")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create table with dates
    cursor.execute("""
        CREATE TEMPORARY TABLE events (
            id SERIAL PRIMARY KEY,
            event_date DATE NOT NULL,
            event_name TEXT NOT NULL
        )
    """)

    # Insert 365 days of events
    cursor.execute("""
        INSERT INTO events (event_date, event_name)
        SELECT
            (DATE '2024-01-01' + n),
            'Event ' || n
        FROM generate_series(0, 364) AS n
    """)
    conn.commit()

    # Benchmark: Query date ranges
    iterations = 1000
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT event_date, event_name
            FROM events
            WHERE event_date BETWEEN '2024-06-01' AND '2024-06-30'
            ORDER BY event_date
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            event_date = row[0]  # date
            event_name = row[1]  # str
            # Process event

    total_ms = timer.elapsed_ms()

    print(f"  Query + decode 30-day range")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Average:        {total_ms / iterations:.2f} ms/query")

    cursor.close()
    conn.close()


# ============================================================================
# Main Benchmark Runner
# ============================================================================

def main():
    print("\n" + "=" * 70)
    print("Python Baseline: Temporal Type Performance (psycopg2)")
    print("=" * 70)
    print("")
    print("PostgreSQL: localhost:5432, database: test")
    print("")

    # Query result access benchmarks
    benchmark_query_result_timestamptz()
    benchmark_query_result_date()

    # TimescaleDB simulation benchmarks
    benchmark_timescaledb_sensor_data()
    benchmark_crypto_ohlcv_data()
    benchmark_date_range_queries()

    print("\n" + "=" * 70)
    print("Benchmark Summary (Python/psycopg2)")
    print("=" * 70)
    print("")
    print("Note: psycopg2 returns native Python types directly")
    print("      - TIMESTAMPTZ → Python datetime")
    print("      - DATE → Python date")
    print("      - TIME → Python time")
    print("")
    print("Compare these results with mojo-postgres benchmarks:")
    print("  mojo benchmarks/bench_temporal_types.mojo")
    print("")
    print("Expected: Mojo should be 1.5-3x faster for timestamp parsing")
    print("=" * 70)


if __name__ == "__main__":
    main()
