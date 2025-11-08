"""
Benchmark: Bulk Database Operations

Measures performance for high-volume operations:
1. Sequential INSERTs (1000 rows)
2. Large result set retrieval (1000+ rows)
3. Repeated small queries (simulating OLTP workload)
4. Large row scanning (full table scan simulation)

This is critical for the cryptocurrency trading use case where
we need to handle thousands of price updates per second.

Target: 10,000 inserts/sec, 50,000 rows/sec read throughput
"""

from benchmarks.harness import Timer
from src.protocol.connection import PostgresConnection


# Configuration
alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "benchdb"
alias USER = "benchuser"
alias PASSWORD = "benchpass"


fn setup_test_table(conn: PostgresConnection) raises:
    """Create test table for benchmarking."""
    # Drop if exists
    try:
        var result = conn.query("DROP TABLE IF EXISTS bench_test")
        _ = result.command_tag
    except:
        pass

    # Create table
    var result = conn.query("""
        CREATE TABLE bench_test (
            id SERIAL PRIMARY KEY,
            ticker TEXT NOT NULL,
            price FLOAT8 NOT NULL,
            volume INT8 NOT NULL,
            timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)
    _ = result.command_tag

    print("  ✓ Test table created")


fn cleanup_test_table(conn: PostgresConnection) raises:
    """Drop test table."""
    try:
        var result = conn.query("DROP TABLE IF EXISTS bench_test")
        _ = result.command_tag
    except:
        pass


fn benchmark_sequential_inserts() raises:
    """Benchmark sequential INSERT statements."""
    print("\n" + "=" * 70)
    print("1. Sequential INSERTs (1000 rows)")
    print("=" * 70)

    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    setup_test_table(conn)

    var num_inserts = 1000
    var timer = Timer()

    # Execute INSERT statements
    for i in range(num_inserts):
        var query = """
            INSERT INTO bench_test (ticker, price, volume)
            VALUES ('BTC', """ + String(50000.0 + Float64(i) * 10.0) + """, """ + String(1000 + i) + """)
        """
        var result = conn.query(query)
        _ = result.rows_affected

    var elapsed_ns = timer.elapsed_ns()
    var elapsed_ms = Float64(elapsed_ns) / 1_000_000.0
    var elapsed_sec = Float64(elapsed_ns) / 1_000_000_000.0

    print("Total time:        ", String(elapsed_ms), "ms")
    print("Avg per INSERT:    ", String(elapsed_ms / Float64(num_inserts)), "ms")
    print("Throughput:        ", String(Int(Float64(num_inserts) / elapsed_sec)), "inserts/sec")

    # Target: 10,000 inserts/sec
    var target_inserts_per_sec = 10000.0
    var actual_inserts_per_sec = Float64(num_inserts) / elapsed_sec

    if actual_inserts_per_sec >= target_inserts_per_sec:
        print("Status:            ✅ TARGET MET")
    else:
        var percent_of_target = (actual_inserts_per_sec / target_inserts_per_sec) * 100.0
        print("Status:            ⚠️  ", String(Int(percent_of_target)), "% of target (", String(Int(target_inserts_per_sec)), " inserts/sec)")

    cleanup_test_table(conn)
    conn.close()


fn benchmark_large_result_set() raises:
    """Benchmark retrieving large result sets."""
    print("\n" + "=" * 70)
    print("2. Large Result Set Retrieval (10,000 rows)")
    print("=" * 70)

    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var num_rows = 10000
    var timer = Timer()

    # Generate and retrieve 10,000 rows
    var result = conn.query("SELECT generate_series(1, " + String(num_rows) + ") AS num")

    var elapsed_ns = timer.elapsed_ns()
    var elapsed_ms = Float64(elapsed_ns) / 1_000_000.0
    var elapsed_sec = Float64(elapsed_ns) / 1_000_000_000.0

    print("Rows retrieved:    ", String(result.row_count()))
    print("Total time:        ", String(elapsed_ms), "ms")
    print("Avg per row:       ", String(elapsed_ms / Float64(num_rows)), "ms")
    print("Throughput:        ", String(Int(Float64(num_rows) / elapsed_sec)), "rows/sec")

    # Target: 50,000 rows/sec
    var target_rows_per_sec = 50000.0
    var actual_rows_per_sec = Float64(num_rows) / elapsed_sec

    if actual_rows_per_sec >= target_rows_per_sec:
        print("Status:            ✅ TARGET MET")
    else:
        var percent_of_target = (actual_rows_per_sec / target_rows_per_sec) * 100.0
        print("Status:            ⚠️  ", String(Int(percent_of_target)), "% of target (", String(Int(target_rows_per_sec)), " rows/sec)")

    conn.close()


fn benchmark_oltp_workload() raises:
    """Benchmark OLTP-style workload (many small queries)."""
    print("\n" + "=" * 70)
    print("3. OLTP Workload (1000 small queries)")
    print("=" * 70)

    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    setup_test_table(conn)

    # Insert some data first
    for i in range(100):
        var query = "INSERT INTO bench_test (ticker, price, volume) VALUES ('BTC', 50000.0, 1000)"
        var result = conn.query(query)
        _ = result.rows_affected

    # Now run mixed workload
    var num_queries = 1000
    var timer = Timer()

    for i in range(num_queries):
        if i % 3 == 0:
            # SELECT query
            var result = conn.query("SELECT * FROM bench_test LIMIT 10")
            _ = result.row_count()
        elif i % 3 == 1:
            # INSERT query
            var result = conn.query("INSERT INTO bench_test (ticker, price, volume) VALUES ('ETH', 3000.0, 500)")
            _ = result.rows_affected
        else:
            # COUNT query
            var result = conn.query("SELECT COUNT(*) FROM bench_test")
            _ = result.row_count()

    var elapsed_ns = timer.elapsed_ns()
    var elapsed_ms = Float64(elapsed_ns) / 1_000_000.0
    var elapsed_sec = Float64(elapsed_ns) / 1_000_000_000.0

    print("Queries executed:  ", String(num_queries))
    print("Total time:        ", String(elapsed_ms), "ms")
    print("Avg per query:     ", String(elapsed_ms / Float64(num_queries)), "ms")
    print("Throughput:        ", String(Int(Float64(num_queries) / elapsed_sec)), "queries/sec")

    cleanup_test_table(conn)
    conn.close()


fn benchmark_full_table_scan() raises:
    """Benchmark full table scan performance."""
    print("\n" + "=" * 70)
    print("4. Full Table Scan (5000 rows)")
    print("=" * 70)

    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    setup_test_table(conn)

    # Insert 5000 rows
    print("Inserting 5000 rows...")
    for i in range(5000):
        var query = "INSERT INTO bench_test (ticker, price, volume) VALUES ('BTC', " + String(50000.0 + Float64(i)) + ", " + String(1000 + i) + ")"
        var result = conn.query(query)
        _ = result.rows_affected

    # Full table scan
    print("Scanning...")
    var timer = Timer()
    var result = conn.query("SELECT * FROM bench_test")
    var elapsed_ns = timer.elapsed_ns()
    var elapsed_ms = Float64(elapsed_ns) / 1_000_000.0
    var elapsed_sec = Float64(elapsed_ns) / 1_000_000_000.0

    print("Rows scanned:      ", String(result.row_count()))
    print("Columns:           ", String(result.column_count()))
    print("Total time:        ", String(elapsed_ms), "ms")
    print("Throughput:        ", String(Int(Float64(result.row_count()) / elapsed_sec)), "rows/sec")

    cleanup_test_table(conn)
    conn.close()


fn main() raises:
    print("\n" + "=" * 70)
    print("BENCHMARK: Bulk Database Operations")
    print("=" * 70)
    print("Configuration:")
    print("  Host:       ", HOST)
    print("  Port:       ", String(PORT))
    print("  Database:   ", DATABASE)
    print("  User:       ", USER)
    print("=" * 70)
    print("\nThis benchmark tests high-volume operations for cryptocurrency")
    print("trading use case (thousands of price updates per second)")
    print("=" * 70)

    # Run benchmarks
    benchmark_sequential_inserts()
    benchmark_large_result_set()
    benchmark_oltp_workload()
    benchmark_full_table_scan()

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print("These benchmarks test the driver's ability to handle:")
    print("  ✓ High-frequency INSERT operations (trading data)")
    print("  ✓ Large result set retrieval (historical data)")
    print("  ✓ Mixed OLTP workload (real-time queries)")
    print("  ✓ Full table scans (analytics)")
    print("")
    print("Performance targets:")
    print("  - INSERT: 10,000/sec (trading data ingestion)")
    print("  - SELECT: 50,000 rows/sec (historical queries)")
    print("  - OLTP: 1,000 queries/sec (real-time trading)")
    print("")
    print("Note: These are baseline Simple Query Protocol numbers.")
    print("Extended Query Protocol (prepared statements, COPY) will be")
    print("significantly faster and is planned for Phase 2.")
    print("=" * 70)
