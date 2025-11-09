#!/usr/bin/env python3
"""
Python Baseline: Text and Boolean Type Decoding Performance

Measures psycopg2 text and boolean decoding performance for comparison with mojo-postgres.

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

def benchmark_query_result_bool():
    """Benchmark BOOLEAN access from query results."""
    print("\n1. Query Result BOOLEAN Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 BOOLEAN values
    cursor.execute("""
        SELECT (n % 2 = 0)::BOOLEAN AS value
        FROM generate_series(1, 100) AS n
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark BOOLEAN access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # BOOLEAN value (Python bool)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("BOOLEAN access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


def benchmark_query_result_text():
    """Benchmark TEXT access from query results."""
    print("\n2. Query Result TEXT Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 TEXT values
    cursor.execute("""
        SELECT 'symbol_' || n::TEXT AS value
        FROM generate_series(1, 100) AS n
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark TEXT access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # TEXT value (Python str)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("TEXT access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


def benchmark_query_result_varchar():
    """Benchmark VARCHAR access from query results."""
    print("\n3. Query Result VARCHAR Access")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Query with 100 VARCHAR values
    cursor.execute("""
        SELECT 'user_' || n::VARCHAR(50) AS value
        FROM generate_series(1, 100) AS n
    """)
    rows = cursor.fetchall()

    iterations = 10000
    timer = BenchmarkTimer()

    # Benchmark VARCHAR access
    timer.start()
    for _ in range(iterations):
        for row in rows:
            value = row[0]  # VARCHAR value (Python str)
    total_ms = timer.elapsed_ms()

    print_benchmark_result("VARCHAR access", iterations * len(rows), total_ms)

    cursor.close()
    conn.close()


# ============================================================================
# Benchmark 2: Bulk Operations
# ============================================================================

def benchmark_bulk_crypto_symbols():
    """Benchmark bulk decoding of cryptocurrency symbols (realistic workload)."""
    print("\n4. Bulk Crypto Symbol Decoding (Realistic Workload)")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create temporary table with 100 trading pairs
    cursor.execute("""
        CREATE TEMPORARY TABLE benchmark_symbols (
            id SERIAL PRIMARY KEY,
            symbol VARCHAR(20) NOT NULL,
            is_active BOOLEAN NOT NULL
        )
    """)

    cursor.execute("""
        INSERT INTO benchmark_symbols (symbol, is_active)
        SELECT
            'SYMBOL' || n::TEXT,
            (n % 2 = 0)::BOOLEAN
        FROM generate_series(1, 100) AS n
    """)
    conn.commit()

    # Benchmark: Query and decode all symbols
    iterations = 1000
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT symbol, is_active
            FROM benchmark_symbols
            ORDER BY id
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            symbol = row[0]  # VARCHAR
            active = row[1]  # BOOLEAN
            # In real use case, would process these values

    total_ms = timer.elapsed_ms()

    print(f"  Query + decode 100 symbols")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Average:        {total_ms / iterations:.2f} ms/query")
    print(f"    Symbols decoded: {iterations * 100}")
    print(f"    Decode rate:    {int((iterations * 100) / (total_ms / 1000.0))} symbols/sec")

    cursor.close()
    conn.close()


def benchmark_bulk_user_data():
    """Benchmark bulk decoding of user data with mixed text/boolean fields."""
    print("\n5. Bulk User Data Decoding")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Create temporary table
    cursor.execute("""
        CREATE TEMPORARY TABLE benchmark_users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(50) NOT NULL,
            email VARCHAR(255) NOT NULL,
            is_active BOOLEAN NOT NULL,
            is_verified BOOLEAN NOT NULL
        )
    """)

    cursor.execute("""
        INSERT INTO benchmark_users (username, email, is_active, is_verified)
        SELECT
            'user_' || n::TEXT,
            'user' || n || '@example.com',
            (n % 2 = 0)::BOOLEAN,
            (n % 3 = 0)::BOOLEAN
        FROM generate_series(1, 500) AS n
    """)
    conn.commit()

    # Benchmark: Query and decode all users
    iterations = 100
    timer = BenchmarkTimer()

    timer.start()
    for _ in range(iterations):
        cursor.execute("""
            SELECT username, email, is_active, is_verified
            FROM benchmark_users
            ORDER BY id
        """)
        rows = cursor.fetchall()

        # Decode all rows
        for row in rows:
            username = row[0]    # VARCHAR
            email = row[1]       # VARCHAR
            is_active = row[2]   # BOOLEAN
            is_verified = row[3] # BOOLEAN
            # Process user data

    total_ms = timer.elapsed_ms()
    total_records = iterations * 500

    print(f"  Query + decode 500 user records")
    print(f"    Iterations:     {iterations}")
    print(f"    Total time:     {total_ms:.2f} ms")
    print(f"    Records decoded: {total_records}")
    print(f"    Decode rate:    {int(total_records / (total_ms / 1000.0))} records/sec")

    cursor.close()
    conn.close()


# ============================================================================
# Benchmark 3: Text Length Variations
# ============================================================================

def benchmark_text_length_variations():
    """Benchmark TEXT decoding with different string lengths."""
    print("\n6. TEXT Length Variation Performance")
    print("   " + "-" * 60)

    conn = get_connection()
    cursor = conn.cursor()

    # Short strings (10 chars)
    cursor.execute("SELECT repeat('x', 10)::TEXT AS value FROM generate_series(1, 100)")
    rows_short = cursor.fetchall()

    iterations = 5000
    timer1 = BenchmarkTimer()
    timer1.start()
    for _ in range(iterations):
        for row in rows_short:
            value = row[0]
    short_ms = timer1.elapsed_ms()

    # Medium strings (100 chars)
    cursor.execute("SELECT repeat('x', 100)::TEXT AS value FROM generate_series(1, 100)")
    rows_medium = cursor.fetchall()

    timer2 = BenchmarkTimer()
    timer2.start()
    for _ in range(iterations):
        for row in rows_medium:
            value = row[0]
    medium_ms = timer2.elapsed_ms()

    # Long strings (1000 chars)
    cursor.execute("SELECT repeat('x', 1000)::TEXT AS value FROM generate_series(1, 100)")
    rows_long = cursor.fetchall()

    timer3 = BenchmarkTimer()
    timer3.start()
    for _ in range(iterations):
        for row in rows_long:
            value = row[0]
    long_ms = timer3.elapsed_ms()

    print("  Short strings (10 chars):")
    print_benchmark_result("TEXT access", iterations * 100, short_ms)

    print("\n  Medium strings (100 chars):")
    print_benchmark_result("TEXT access", iterations * 100, medium_ms)

    print("\n  Long strings (1000 chars):")
    print_benchmark_result("TEXT access", iterations * 100, long_ms)

    cursor.close()
    conn.close()


# ============================================================================
# Main Benchmark Runner
# ============================================================================

def main():
    print("\n" + "=" * 70)
    print("Python Baseline: Text and Boolean Type Performance (psycopg2)")
    print("=" * 70)
    print("")
    print("PostgreSQL: localhost:5432, database: test")
    print("")

    # Query result access benchmarks
    benchmark_query_result_bool()
    benchmark_query_result_text()
    benchmark_query_result_varchar()

    # Bulk operation benchmarks
    benchmark_bulk_crypto_symbols()
    benchmark_bulk_user_data()

    # Length variation benchmarks
    benchmark_text_length_variations()

    print("\n" + "=" * 70)
    print("Benchmark Summary (Python/psycopg2)")
    print("=" * 70)
    print("")
    print("Note: psycopg2 returns native Python types directly")
    print("      - BOOLEAN → Python bool")
    print("      - TEXT/VARCHAR → Python str")
    print("")
    print("Compare these results with mojo-postgres benchmarks:")
    print("  mojo benchmarks/bench_text_types.mojo")
    print("")
    print("Expected: Similar performance (text is passthrough)")
    print("=" * 70)


if __name__ == "__main__":
    main()
