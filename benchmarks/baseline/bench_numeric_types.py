#!/usr/bin/env python3
"""
Python Baseline: Numeric Type Decoding Performance

Measures psycopg2 numeric decoding performance for comparison with mojo-postgres.

Target use case: High-frequency cryptocurrency trading system

Prerequisites:
    pip install psycopg2-binary
"""

import psycopg2
import time
from typing import List, Tuple


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

def benchmark_query_result_int4():
    """Benchmark INT4 access from query results."""
    print("\n1. Query Result INT4 Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 INT4 values
    cursor.execute("SELECT generate_series(1, 100)::INT4 AS value")
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark INT4 access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # INT4 value (Python int)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("INT4 access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


def benchmark_query_result_int8():
    """Benchmark INT8 access from query results."""
    print("\n2. Query Result INT8 Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 INT8 timestamp values
    cursor.execute("""
        SELECT (1704067200000000::INT8 + generate_series(1, 100) * 1000000) AS timestamp_us
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark INT8 access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # INT8 value (Python int)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("INT8 access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


def benchmark_query_result_float8():
    """Benchmark FLOAT8 access from query results."""
    print("\n3. Query Result FLOAT8 Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 FLOAT8 price values
    cursor.execute("""
        SELECT (50000.0 + generate_series(1, 100) * 0.5)::FLOAT8 AS price
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark FLOAT8 access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # FLOAT8 value (Python float)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("FLOAT8 access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


# ============================================================================
# Benchmark 2: String Conversion (for comparison)
# ============================================================================

def benchmark_string_to_int_conversion():
    """Benchmark Python string to int conversion (for reference)."""
    print("\n4. Python String to Int Conversion (Reference)")
    print("   " + "-" * 60)

    iterations = 100000
    timer = BenchmarkTimer()

    # Benchmark string to int
    timer.start()
    for _ in range(iterations):
        _ = int("42")
        _ = int("-100")
        _ = int("2147483647")
    total_ms = timer.elapsed_ms()

    print_benchmark_result("int()", iterations * 3, total_ms)


def benchmark_string_to_float_conversion():
    """Benchmark Python string to float conversion (for reference)."""
    print("\n5. Python String to Float Conversion (Reference)")
    print("   " + "-" * 60)

    iterations = 100000
    timer = BenchmarkTimer()

    # Benchmark string to float
    timer.start()
    for _ in range(iterations):
        _ = float("3.14159")
        _ = float("50123.45")
        _ = float("-42.5")
    total_ms = timer.elapsed_ms()

    print_benchmark_result("float()", iterations * 3, total_ms)


# ============================================================================
# Benchmark 3: Bulk Operations
# ============================================================================

def benchmark_bulk_crypto_trades():
    """Benchmark bulk decoding of cryptocurrency trades (realistic workload)."""
    print("\n6. Bulk Crypto Trade Decoding (Realistic Workload)")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create temporary table with 1000 trades
    cursor.execute("""
        CREATE TEMPORARY TABLE benchmark_trades (
            id SERIAL PRIMARY KEY,
            timestamp_us INT8 NOT NULL,
            price FLOAT8 NOT NULL,
            volume INT8 NOT NULL
        )
    """)

    cursor.execute("""
        INSERT INTO benchmark_trades (timestamp_us, price, volume)
        SELECT
            1704067200000000::INT8 + (n * 1000),
            50000.0 + (random() * 1000.0),
            (100000 + random() * 900000)::INT8
        FROM generate_series(1, 1000) AS n
    """)
    conn.commit()

    # Benchmark: Query and decode all trades
    iterations = 100
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT timestamp_us, price, volume
            FROM benchmark_trades
            ORDER BY timestamp_us
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            timestamp = row[0]  # INT8
            price = row[1]      # FLOAT8
            volume = row[2]     # INT8
            # In real use case, would process these values

    total_ms = timer.elapsed_ms()

    print(f"  Query + decode 1000 trades")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Average:        {total_ms / iterations:.2f} ms/query")
    print(f"    Trades decoded: {iterations * 1000}")
    print(f"    Decode rate:    {int((iterations * 1000) / (total_ms / 1000.0))} trades/sec")

    cursor.close()
    conn.close()


def benchmark_bulk_timeseries_data():
    """Benchmark bulk decoding of TimescaleDB-style time series data."""
    print("\n7. Bulk TimescaleDB Time Series Decoding")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query 5000 time series points (5 seconds at 1kHz)
    cursor.execute("""
        SELECT
            (1704067200000000::INT8 + n * 1000) AS timestamp_us,
            (50000.0 + sin(n::FLOAT8 / 100.0) * 100.0) AS value
        FROM generate_series(1, 5000) AS n
    """)
    rows = cursor.fetchall()

    iterations = 50
    timer = BenchmarkTimer()

    # Benchmark decoding
    timer.start()
    for _ in range(iterations):
        for row in rows:
            timestamp = row[0]  # INT8
            value = row[1]      # FLOAT8
            # Process data point

    total_ms = timer.elapsed_ms()
    total_points = iterations * len(rows)

    print(f"  Decode 5000 time series points")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Points decoded: {total_points}")
    print(f"    Decode rate:    {int(total_points / (total_ms / 1000.0))} points/sec")
    print(f"    Per-point:      {(total_ms * 1000.0) / total_points:.3f} μs/point")

    cursor.close()
    conn.close()


# ============================================================================
# Benchmark 4: Mixed Types
# ============================================================================

def benchmark_mixed_numeric_types():
    """Benchmark mixed numeric type access."""
    print("\n8. Mixed Numeric Types Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with mixed numeric types
    cursor.execute("""
        SELECT
            generate_series(1, 100)::INT4 AS id,
            50000.0::FLOAT8 AS price
    """)
    rows = cursor.fetchall()

    iterations = 5000
    timer = BenchmarkTimer()

    # Benchmark access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            id_val = row[0]     # INT4
            price = row[1]      # FLOAT8
    total_ms = timer.elapsed_ms()

    print_benchmark_result("Mixed access", iterations * len(rows) * 2, total_ms)

    cursor.close()
    conn.close()


# ============================================================================
# Main Benchmark Runner
# ============================================================================

def main():
    print("\n" + "=" * 70)
    print("Python Baseline: Numeric Type Decoding Performance (psycopg2)")
    print("=" * 70)
    print("")
    print("PostgreSQL: localhost:5432, database: test")
    print("")

    # Query result access benchmarks
    benchmark_query_result_int4()
    benchmark_query_result_int8()
    benchmark_query_result_float8()

    # String conversion benchmarks (reference)
    benchmark_string_to_int_conversion()
    benchmark_string_to_float_conversion()

    # Bulk operation benchmarks
    benchmark_bulk_crypto_trades()
    benchmark_bulk_timeseries_data()

    # Mixed types
    benchmark_mixed_numeric_types()

    print("\n" + "=" * 70)
    print("Benchmark Summary (Python/psycopg2)")
    print("=" * 70)
    print("")
    print("Note: psycopg2 returns native Python types directly")
    print("      - INT4/INT8 → Python int")
    print("      - FLOAT8 → Python float")
    print("")
    print("Compare these results with mojo-postgres benchmarks:")
    print("  mojo benchmarks/bench_numeric_types.mojo")
    print("")
    print("Expected: Mojo should be 2-5x faster for type conversion")
    print("=" * 70)


if __name__ == "__main__":
    main()
