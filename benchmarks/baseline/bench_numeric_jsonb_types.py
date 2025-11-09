"""
Python baseline benchmarks for NUMERIC and JSONB type decoders.

Uses psycopg2 (PostgreSQL adapter) and json module for comparison
with Mojo implementation.

Install:
  pip install psycopg2-binary

Run:
  python benchmarks/baseline/bench_numeric_jsonb_types.py

Compare with Mojo:
  mojo benchmarks/bench_numeric_jsonb_types.mojo
"""

import psycopg2
import json
import time
from decimal import Decimal


def benchmark_raw_numeric_decoder():
    """Benchmark raw NUMERIC (Decimal) parsing."""
    print("\n[1] Raw NUMERIC Decoder (Python Decimal)")
    print("  Decoding 100,000 NUMERIC values...")

    iterations = 100000

    start = time.time()
    for i in range(iterations):
        _ = Decimal("123.45")
        _ = Decimal("-999.999")
        _ = Decimal("50123.45678901")
    total_ms = (time.time() - start) * 1000

    ops_per_sec = (iterations * 3) / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")
    print(f"  Avg per decode: {total_ms / (iterations * 3):.6f} ms")


def benchmark_numeric_to_float():
    """Benchmark NUMERIC to float conversion."""
    print("\n[2] NUMERIC to Float Conversion")
    print("  Converting 100,000 NUMERIC to float...")

    iterations = 100000

    start = time.time()
    for i in range(iterations):
        num = Decimal("123.45")
        _ = float(num)
    total_ms = (time.time() - start) * 1000

    ops_per_sec = iterations / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")


def benchmark_numeric_comparison():
    """Benchmark NUMERIC comparison operations."""
    print("\n[3] NUMERIC Comparison Operations")
    print("  Comparing 100,000 NUMERIC pairs...")

    a = Decimal("123.45")
    b = Decimal("123.46")

    iterations = 100000

    start = time.time()
    for i in range(iterations):
        _ = a == b
        _ = a < b
    total_ms = (time.time() - start) * 1000

    ops_per_sec = (iterations * 2) / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")


def benchmark_numeric_query_accessor():
    """Benchmark psycopg2 NUMERIC query and access."""
    print("\n[4] Psycopg2 NUMERIC Query")
    print("  Fetching and decoding 10,000 NUMERIC values from query...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    iterations = 10000

    start = time.time()
    for i in range(iterations):
        cursor.execute("SELECT 123.45::NUMERIC AS value")
        row = cursor.fetchone()
        _ = row[0]  # Access NUMERIC value (auto-converted to Decimal)
    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    ops_per_sec = iterations / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")
    print(f"  Avg per query+decode: {total_ms / iterations:.3f} ms")


def benchmark_numeric_bulk_query():
    """Benchmark bulk NUMERIC query with multiple rows."""
    print("\n[5] Bulk NUMERIC Query (1000 rows)")
    print("  Fetching 1000 NUMERIC values in single query, repeat 100 times...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    iterations = 100
    rows_per_query = 1000

    start = time.time()
    for i in range(iterations):
        cursor.execute("""
            SELECT (random() * 1000000)::NUMERIC(20, 8) AS price
            FROM generate_series(1, 1000)
        """)

        # Fetch and decode all rows
        for row in cursor.fetchall():
            _ = row[0]

    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    total_rows = iterations * rows_per_query
    rows_per_sec = total_rows / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Rows/sec: {int(rows_per_sec)}")
    print(f"  Avg per 1000 rows: {total_ms / iterations:.2f} ms")


def benchmark_raw_jsonb_decoder():
    """Benchmark raw JSONB (json) parsing."""
    print("\n[6] Raw JSONB Decoder (Python json)")
    print("  Decoding 50,000 JSONB objects...")

    iterations = 50000

    start = time.time()
    for i in range(iterations):
        _ = json.loads('{"name": "Alice", "age": 30}')
        _ = json.loads('{"balance": 123.45, "active": true}')
    total_ms = (time.time() - start) * 1000

    ops_per_sec = (iterations * 2) / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")


def benchmark_jsonb_field_access():
    """Benchmark JSONB field access operations."""
    print("\n[7] JSONB Field Access")
    print("  Accessing 100,000 JSONB fields...")

    data = json.loads('{"name": "Alice", "age": 30, "balance": 123.45, "active": true}')

    iterations = 100000

    start = time.time()
    for i in range(iterations):
        _ = data["name"]
        _ = data["age"]
        _ = data["balance"]
        _ = data["active"]
    total_ms = (time.time() - start) * 1000

    ops_per_sec = (iterations * 4) / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")


def benchmark_jsonb_query_accessor():
    """Benchmark psycopg2 JSONB query and access."""
    print("\n[8] Psycopg2 JSONB Query")
    print("  Fetching and decoding 5,000 JSONB values from query...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    iterations = 5000

    start = time.time()
    for i in range(iterations):
        cursor.execute("""SELECT '{"name": "Alice", "age": 30}'::JSONB AS value""")
        row = cursor.fetchone()
        data = row[0]  # Already a dict in psycopg2
        _ = data["name"]
    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    ops_per_sec = iterations / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Operations/sec: {int(ops_per_sec)}")
    print(f"  Avg per query+decode: {total_ms / iterations:.3f} ms")


def benchmark_jsonb_bulk_query():
    """Benchmark bulk JSONB query with multiple rows."""
    print("\n[9] Bulk JSONB Query (500 rows)")
    print("  Fetching 500 JSONB objects in single query, repeat 50 times...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    iterations = 50
    rows_per_query = 500

    start = time.time()
    for i in range(iterations):
        cursor.execute("""
            SELECT jsonb_build_object(
                'id', gs.id,
                'name', 'User_' || gs.id::TEXT,
                'balance', (random() * 1000)::NUMERIC(10, 2),
                'active', (random() > 0.5)
            ) AS metadata
            FROM generate_series(1, 500) AS gs(id)
        """)

        # Fetch and decode all rows
        for row in cursor.fetchall():
            data = row[0]
            _ = data["id"]

    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    total_rows = iterations * rows_per_query
    rows_per_sec = total_rows / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Rows/sec: {int(rows_per_sec)}")
    print(f"  Avg per 500 rows: {total_ms / iterations:.2f} ms")


def benchmark_financial_calculations():
    """Benchmark NUMERIC for financial calculations."""
    print("\n[10] Financial Calculations (Account Balances)")
    print("  Computing balances for 10,000 accounts...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    # Create temporary table
    cursor.execute("""
        CREATE TEMPORARY TABLE IF NOT EXISTS bench_accounts_py (
            id SERIAL PRIMARY KEY,
            balance NUMERIC(20, 8),
            reserved NUMERIC(20, 8)
        )
    """)

    # Insert test data
    cursor.execute("""
        INSERT INTO bench_accounts_py (balance, reserved)
        SELECT
            (random() * 1000)::NUMERIC(20, 8),
            (random() * 100)::NUMERIC(20, 8)
        FROM generate_series(1, 10000)
    """)
    conn.commit()

    iterations = 100

    start = time.time()
    for i in range(iterations):
        cursor.execute("""
            SELECT id, balance, reserved,
                   (balance - reserved) AS available
            FROM bench_accounts_py
            LIMIT 1000
        """)

        # Process results
        for row in cursor.fetchall():
            balance = row[1]
            reserved = row[2]
            available = row[3]

    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    total_calcs = iterations * 1000 * 3  # 3 numeric values per row
    calcs_per_sec = total_calcs / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  NUMERIC values/sec: {int(calcs_per_sec)}")


def benchmark_metadata_queries():
    """Benchmark JSONB for metadata queries."""
    print("\n[11] Metadata Queries (Trade Metadata)")
    print("  Querying 5,000 trades with JSONB metadata...")

    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test"
    )
    cursor = conn.cursor()

    # Create temporary table
    cursor.execute("""
        CREATE TEMPORARY TABLE IF NOT EXISTS bench_trades_py (
            id SERIAL PRIMARY KEY,
            symbol TEXT,
            metadata JSONB
        )
    """)

    # Insert test data
    cursor.execute("""
        INSERT INTO bench_trades_py (symbol, metadata)
        SELECT
            CASE WHEN random() > 0.5 THEN 'BTC/USD' ELSE 'ETH/USD' END,
            jsonb_build_object(
                'exchange', CASE WHEN random() > 0.5 THEN 'Coinbase' ELSE 'Binance' END,
                'fee', (random() * 0.01)::NUMERIC(10, 8),
                'maker', random() > 0.5
            )
        FROM generate_series(1, 5000)
    """)
    conn.commit()

    iterations = 50

    start = time.time()
    for i in range(iterations):
        cursor.execute("""
            SELECT id, symbol, metadata
            FROM bench_trades_py
            LIMIT 1000
        """)

        # Process results
        for row in cursor.fetchall():
            metadata = row[2]
            _ = metadata["exchange"]
            _ = metadata["fee"]
            _ = metadata["maker"]

    total_ms = (time.time() - start) * 1000

    cursor.close()
    conn.close()

    total_queries = iterations * 1000
    queries_per_sec = total_queries / (total_ms / 1000.0)

    print(f"  Time: {total_ms:.2f} ms")
    print(f"  Trades/sec: {int(queries_per_sec)}")


if __name__ == "__main__":
    print("=" * 70)
    print("Python Baseline: NUMERIC and JSONB Type Decoders")
    print("=" * 70)
    print("")
    print("Using psycopg2 + Decimal + json")
    print("")

    print("NUMERIC Benchmarks:")
    benchmark_raw_numeric_decoder()
    benchmark_numeric_to_float()
    benchmark_numeric_comparison()
    benchmark_numeric_query_accessor()
    benchmark_numeric_bulk_query()

    print("\n" + "-" * 70)
    print("JSONB Benchmarks:")
    benchmark_raw_jsonb_decoder()
    benchmark_jsonb_field_access()
    benchmark_jsonb_query_accessor()
    benchmark_jsonb_bulk_query()

    print("\n" + "-" * 70)
    print("Real-World Use Cases:")
    benchmark_financial_calculations()
    benchmark_metadata_queries()

    print("\n" + "=" * 70)
    print("✅ All Python baseline benchmarks complete!")
    print("=" * 70)
    print("")
    print("Compare with Mojo implementation:")
    print("  mojo benchmarks/bench_numeric_jsonb_types.mojo")
    print("")
