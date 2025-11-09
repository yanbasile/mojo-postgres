"""
Benchmarks for PostgreSQL NUMERIC and JSONB type decoders.

Measures:
- NUMERIC decoding performance (vs Python Decimal)
- JSONB decoding performance (vs Python json)
- QueryResult typed accessors
- Real-world use cases (financial calculations, metadata)

Run:
  mojo benchmarks/bench_numeric_jsonb_types.mojo

Compare with Python baseline:
  python benchmarks/baseline/bench_numeric_jsonb_types.py
"""

from src.protocol.connection import PostgresConnection
from time import now


struct Timer:
    """Simple timer for benchmarking."""
    var start_time: Int

    fn __init__(inout self):
        self.start_time = 0

    fn start(inout self):
        self.start_time = now()

    fn elapsed_ms(self) -> Float64:
        var end_time = now()
        return Float64(end_time - self.start_time) / 1_000_000.0


# ============================================================================
# NUMERIC Decoder Benchmarks
# ============================================================================

fn benchmark_raw_numeric_decoder() raises:
    """Benchmark raw NUMERIC decoder."""
    print("\n[1] Raw NUMERIC Decoder")
    print("  Decoding 100,000 NUMERIC values...")

    from src.types.numeric_jsonb import decode_numeric

    var timer = Timer()
    var iterations = 100000

    timer.start()
    for i in range(iterations):
        var _ = decode_numeric("123.45")
        var __ = decode_numeric("-999.999")
        var ___ = decode_numeric("50123.45678901")
    var total_ms = timer.elapsed_ms()

    var ops_per_sec = (iterations * 3) / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))
    print("  Avg per decode: " + String(total_ms / (iterations * 3)) + " ms")


fn benchmark_numeric_to_float64() raises:
    """Benchmark NUMERIC to Float64 conversion."""
    print("\n[2] NUMERIC to Float64 Conversion")
    print("  Converting 100,000 NUMERIC to Float64...")

    from src.types.numeric_jsonb import decode_numeric

    var iterations = 100000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var num = decode_numeric("123.45")
        var _ = num.to_float64()
    var total_ms = timer.elapsed_ms()

    var ops_per_sec = iterations / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))


fn benchmark_numeric_comparison() raises:
    """Benchmark NUMERIC comparison operations."""
    print("\n[3] NUMERIC Comparison Operations")
    print("  Comparing 100,000 NUMERIC pairs...")

    from src.types.numeric_jsonb import decode_numeric

    var a = decode_numeric("123.45")
    var b = decode_numeric("123.46")

    var iterations = 100000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var _ = a.equals(b)
        var __ = a.less_than(b)
    var total_ms = timer.elapsed_ms()

    var ops_per_sec = (iterations * 2) / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))


fn benchmark_numeric_query_accessor() raises:
    """Benchmark QueryResult.get_numeric() accessor."""
    print("\n[4] QueryResult.get_numeric() Accessor")
    print("  Fetching and decoding 10,000 NUMERIC values from query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var iterations = 10000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("SELECT 123.45::NUMERIC AS value")
        var _ = result.get_numeric(0, 0)
    var total_ms = timer.elapsed_ms()

    conn.close()

    var ops_per_sec = iterations / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))
    print("  Avg per query+decode: " + String(total_ms / iterations) + " ms")


fn benchmark_numeric_bulk_query() raises:
    """Benchmark bulk NUMERIC query with multiple rows."""
    print("\n[5] Bulk NUMERIC Query (1000 rows)")
    print("  Fetching 1000 NUMERIC values in single query, repeat 100 times...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var iterations = 100
    var rows_per_query = 1000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("""
            SELECT (random() * 1000000)::NUMERIC(20, 8) AS price
            FROM generate_series(1, 1000)
        """)

        # Decode all rows
        for row_idx in range(result.row_count()):
            var _ = result.get_numeric(row_idx, 0)

    var total_ms = timer.elapsed_ms()

    conn.close()

    var total_rows = iterations * rows_per_query
    var rows_per_sec = total_rows / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Rows/sec: " + String(int(rows_per_sec)))
    print("  Avg per 1000 rows: " + String(total_ms / iterations) + " ms")


# ============================================================================
# JSONB Decoder Benchmarks
# ============================================================================

fn benchmark_raw_jsonb_decoder() raises:
    """Benchmark raw JSONB decoder."""
    print("\n[6] Raw JSONB Decoder")
    print("  Decoding 50,000 JSONB objects...")

    from src.types.numeric_jsonb import decode_jsonb

    var iterations = 50000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var _ = decode_jsonb('{"name": "Alice", "age": 30}')
        var __ = decode_jsonb('{"balance": 123.45, "active": true}')
    var total_ms = timer.elapsed_ms()

    var ops_per_sec = (iterations * 2) / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))


fn benchmark_jsonb_field_access() raises:
    """Benchmark JSONB field access operations."""
    print("\n[7] JSONB Field Access")
    print("  Accessing 100,000 JSONB fields...")

    from src.types.numeric_jsonb import decode_jsonb

    var json = decode_jsonb('{"name": "Alice", "age": 30, "balance": 123.45, "active": true}')

    var iterations = 100000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var _ = json.get_string("name")
        var __ = json.get_int("age")
        var ___ = json.get_float("balance")
        var ____ = json.get_bool("active")
    var total_ms = timer.elapsed_ms()

    var ops_per_sec = (iterations * 4) / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))


fn benchmark_jsonb_query_accessor() raises:
    """Benchmark QueryResult.get_jsonb() accessor."""
    print("\n[8] QueryResult.get_jsonb() Accessor")
    print("  Fetching and decoding 5,000 JSONB values from query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var iterations = 5000
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("""SELECT '{"name": "Alice", "age": 30}'::JSONB AS value""")
        var json = result.get_jsonb(0, 0)
        var _ = json.get_string("name")
    var total_ms = timer.elapsed_ms()

    conn.close()

    var ops_per_sec = iterations / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Operations/sec: " + String(int(ops_per_sec)))
    print("  Avg per query+decode: " + String(total_ms / iterations) + " ms")


fn benchmark_jsonb_bulk_query() raises:
    """Benchmark bulk JSONB query with multiple rows."""
    print("\n[9] Bulk JSONB Query (500 rows)")
    print("  Fetching 500 JSONB objects in single query, repeat 50 times...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var iterations = 50
    var rows_per_query = 500
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("""
            SELECT jsonb_build_object(
                'id', gs.id,
                'name', 'User_' || gs.id::TEXT,
                'balance', (random() * 1000)::NUMERIC(10, 2),
                'active', (random() > 0.5)
            ) AS metadata
            FROM generate_series(1, 500) AS gs(id)
        """)

        # Decode all rows
        for row_idx in range(result.row_count()):
            var json = result.get_jsonb(row_idx, 0)
            var _ = json.get_int("id")

    var total_ms = timer.elapsed_ms()

    conn.close()

    var total_rows = iterations * rows_per_query
    var rows_per_sec = total_rows / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Rows/sec: " + String(int(rows_per_sec)))
    print("  Avg per 500 rows: " + String(total_ms / iterations) + " ms")


# ============================================================================
# Real-World Use Case Benchmarks
# ============================================================================

fn benchmark_financial_calculations() raises:
    """Benchmark NUMERIC for financial calculations."""
    print("\n[10] Financial Calculations (Account Balances)")
    print("  Computing balances for 10,000 accounts...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE IF NOT EXISTS bench_accounts (
            id SERIAL PRIMARY KEY,
            balance NUMERIC(20, 8),
            reserved NUMERIC(20, 8)
        )
    """)

    # Insert test data
    var __ = conn.query("""
        INSERT INTO bench_accounts (balance, reserved)
        SELECT
            (random() * 1000)::NUMERIC(20, 8),
            (random() * 100)::NUMERIC(20, 8)
        FROM generate_series(1, 10000)
    """)

    var iterations = 100
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("""
            SELECT id, balance, reserved,
                   (balance - reserved) AS available
            FROM bench_accounts
            LIMIT 1000
        """)

        # Process results
        for row_idx in range(result.row_count()):
            var balance = result.get_numeric(row_idx, 1)
            var reserved = result.get_numeric(row_idx, 2)
            var available = result.get_numeric(row_idx, 3)

    var total_ms = timer.elapsed_ms()

    conn.close()

    var total_calcs = iterations * 1000 * 3  # 3 numeric values per row
    var calcs_per_sec = total_calcs / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  NUMERIC values/sec: " + String(int(calcs_per_sec)))


fn benchmark_metadata_queries() raises:
    """Benchmark JSONB for metadata queries."""
    print("\n[11] Metadata Queries (Trade Metadata)")
    print("  Querying 5,000 trades with JSONB metadata...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE IF NOT EXISTS bench_trades (
            id SERIAL PRIMARY KEY,
            symbol TEXT,
            metadata JSONB
        )
    """)

    # Insert test data
    var __ = conn.query("""
        INSERT INTO bench_trades (symbol, metadata)
        SELECT
            CASE WHEN random() > 0.5 THEN 'BTC/USD' ELSE 'ETH/USD' END,
            jsonb_build_object(
                'exchange', CASE WHEN random() > 0.5 THEN 'Coinbase' ELSE 'Binance' END,
                'fee', (random() * 0.01)::NUMERIC(10, 8),
                'maker', random() > 0.5
            )
        FROM generate_series(1, 5000)
    """)

    var iterations = 50
    var timer = Timer()

    timer.start()
    for i in range(iterations):
        var result = conn.query("""
            SELECT id, symbol, metadata
            FROM bench_trades
            LIMIT 1000
        """)

        # Process results
        for row_idx in range(result.row_count()):
            var metadata = result.get_jsonb(row_idx, 2)
            var _ = metadata.get_string("exchange")
            var __ = metadata.get_float("fee")
            var ___ = metadata.get_bool("maker")

    var total_ms = timer.elapsed_ms()

    conn.close()

    var total_queries = iterations * 1000
    var queries_per_sec = total_queries / (total_ms / 1000.0)

    print("  Time: " + String(total_ms) + " ms")
    print("  Trades/sec: " + String(int(queries_per_sec)))


# ============================================================================
# Main Benchmark Runner
# ============================================================================

fn main() raises:
    print("=" * 70)
    print("Benchmarks: NUMERIC and JSONB Type Decoders")
    print("=" * 70)
    print("")
    print("Mojo implementation vs Python baseline (psycopg2 + json)")
    print("")

    print("NUMERIC Benchmarks:")
    benchmark_raw_numeric_decoder()
    benchmark_numeric_to_float64()
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
    print("✅ All benchmarks complete!")
    print("=" * 70)
    print("")
    print("Compare with Python baseline:")
    print("  python benchmarks/baseline/bench_numeric_jsonb_types.py")
    print("")
