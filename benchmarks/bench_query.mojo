"""
Benchmark: PostgreSQL Simple Query Execution

Measures:
1. Single row query time (SELECT 1)
2. Multi-row query time (SELECT with N rows)
3. Query with various data types
4. Row parsing overhead
5. NULL value handling

Target: <0.1ms per simple query (10x faster than psycopg2's ~1ms)
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection


# Configuration
alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "benchdb"
alias USER = "benchuser"
alias PASSWORD = "benchpass"
alias ITERATIONS = 1000


fn query_select_1(conn: PostgresConnection) raises:
    """Benchmark simple SELECT 1 query."""
    var result = conn.query("SELECT 1")
    _ = result.row_count()  # Force evaluation


fn query_select_multiple_cols(conn: PostgresConnection) raises:
    """Benchmark query with multiple columns."""
    var result = conn.query("SELECT 1, 2, 3, 4, 5")
    _ = result.column_count()


fn query_10_rows(conn: PostgresConnection) raises:
    """Benchmark query returning 10 rows."""
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1), (2), (3), (4), (5),
            (6), (7), (8), (9), (10)
        ) AS t(num)
    """)
    _ = result.row_count()


fn query_100_rows(conn: PostgresConnection) raises:
    """Benchmark query returning 100 rows."""
    var result = conn.query("SELECT generate_series(1, 100) AS num")
    _ = result.row_count()


fn query_with_types(conn: PostgresConnection) raises:
    """Benchmark query with various types."""
    var result = conn.query("""
        SELECT
            42::INT4,
            3.14159::FLOAT8,
            TRUE::BOOL,
            'Hello, World!'::TEXT,
            '2024-01-15'::DATE
    """)
    _ = result.column_count()


fn query_with_nulls(conn: PostgresConnection) raises:
    """Benchmark query with NULL values."""
    var result = conn.query("SELECT 1, NULL, 2, NULL, 3")
    for i in range(result.column_count()):
        _ = result.is_null(0, i)


fn main() raises:
    print("\n" + "=" * 70)
    print("BENCHMARK: PostgreSQL Simple Query Execution")
    print("=" * 70)
    print("Configuration:")
    print("  Host:       ", HOST)
    print("  Port:       ", String(PORT))
    print("  Database:   ", DATABASE)
    print("  User:       ", USER)
    print("  Iterations: ", String(ITERATIONS))
    print("=" * 70)

    # Establish connection for benchmarking
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    print("\n" + "=" * 70)
    print("Warm-up...")
    print("=" * 70)

    # Warm-up queries
    for i in range(10):
        var result = conn.query("SELECT 1")
        _ = result.row_count()

    # Benchmark 1: SELECT 1
    print("\n" + "=" * 70)
    print("1. Simple Query (SELECT 1)")
    print("=" * 70)

    var timer1 = Timer()
    var total_time1 = 0

    for i in range(ITERATIONS):
        var start = timer1.elapsed_ns()
        query_select_1(conn)
        var elapsed = timer1.elapsed_ns() - start
        total_time1 += elapsed

    var avg_ms1 = Float64(total_time1) / Float64(ITERATIONS) / 1_000_000.0
    print("Average time:      ", String(avg_ms1), "ms")
    print("Throughput:        ", String(Int(Float64(ITERATIONS) / (Float64(total_time1) / 1_000_000_000.0))), "queries/sec")

    # Benchmark 2: SELECT with 5 columns
    print("\n" + "=" * 70)
    print("2. Multiple Columns (SELECT 1,2,3,4,5)")
    print("=" * 70)

    var timer2 = Timer()
    var total_time2 = 0

    for i in range(ITERATIONS):
        var start = timer2.elapsed_ns()
        query_select_multiple_cols(conn)
        var elapsed = timer2.elapsed_ns() - start
        total_time2 += elapsed

    var avg_ms2 = Float64(total_time2) / Float64(ITERATIONS) / 1_000_000.0
    print("Average time:      ", String(avg_ms2), "ms")
    print("Column overhead:   ", String(avg_ms2 - avg_ms1), "ms per 4 columns")

    # Benchmark 3: 10 rows
    print("\n" + "=" * 70)
    print("3. Small Result Set (10 rows)")
    print("=" * 70)

    var timer3 = Timer()
    var total_time3 = 0
    var small_iterations = 500  # Fewer iterations for multi-row queries

    for i in range(small_iterations):
        var start = timer3.elapsed_ns()
        query_10_rows(conn)
        var elapsed = timer3.elapsed_ns() - start
        total_time3 += elapsed

    var avg_ms3 = Float64(total_time3) / Float64(small_iterations) / 1_000_000.0
    var row_overhead3 = (avg_ms3 - avg_ms1) / 10.0
    print("Average time:      ", String(avg_ms3), "ms")
    print("Row overhead:      ", String(row_overhead3 * 1000.0), "μs per row")
    print("Throughput:        ", String(Int(Float64(small_iterations * 10) / (Float64(total_time3) / 1_000_000_000.0))), "rows/sec")

    # Benchmark 4: 100 rows
    print("\n" + "=" * 70)
    print("4. Medium Result Set (100 rows)")
    print("=" * 70)

    var timer4 = Timer()
    var total_time4 = 0
    var med_iterations = 200

    for i in range(med_iterations):
        var start = timer4.elapsed_ns()
        query_100_rows(conn)
        var elapsed = timer4.elapsed_ns() - start
        total_time4 += elapsed

    var avg_ms4 = Float64(total_time4) / Float64(med_iterations) / 1_000_000.0
    var row_overhead4 = (avg_ms4 - avg_ms1) / 100.0
    print("Average time:      ", String(avg_ms4), "ms")
    print("Row overhead:      ", String(row_overhead4 * 1000.0), "μs per row")
    print("Throughput:        ", String(Int(Float64(med_iterations * 100) / (Float64(total_time4) / 1_000_000_000.0))), "rows/sec")

    # Benchmark 5: Various types
    print("\n" + "=" * 70)
    print("5. Various Data Types")
    print("=" * 70)

    var timer5 = Timer()
    var total_time5 = 0

    for i in range(ITERATIONS):
        var start = timer5.elapsed_ns()
        query_with_types(conn)
        var elapsed = timer5.elapsed_ns() - start
        total_time5 += elapsed

    var avg_ms5 = Float64(total_time5) / Float64(ITERATIONS) / 1_000_000.0
    print("Average time:      ", String(avg_ms5), "ms")
    print("Type parsing:      ", String(avg_ms5 - avg_ms1), "ms overhead")

    # Benchmark 6: NULL values
    print("\n" + "=" * 70)
    print("6. NULL Value Handling")
    print("=" * 70)

    var timer6 = Timer()
    var total_time6 = 0

    for i in range(ITERATIONS):
        var start = timer6.elapsed_ns()
        query_with_nulls(conn)
        var elapsed = timer6.elapsed_ns() - start
        total_time6 += elapsed

    var avg_ms6 = Float64(total_time6) / Float64(ITERATIONS) / 1_000_000.0
    print("Average time:      ", String(avg_ms6), "ms")
    print("NULL overhead:     ", String(avg_ms6 - avg_ms1), "ms")

    # Close connection
    conn.close()

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print("Simple query (SELECT 1):        ", String(avg_ms1), "ms")
    print("5 columns:                      ", String(avg_ms2), "ms")
    print("10 rows:                        ", String(avg_ms3), "ms")
    print("100 rows:                       ", String(avg_ms4), "ms")
    print("Various types:                  ", String(avg_ms5), "ms")
    print("NULL values:                    ", String(avg_ms6), "ms")
    print("")
    print("Row parsing overhead:           ", String(row_overhead4 * 1000.0), "μs/row")
    print("Column parsing overhead:        ", String((avg_ms2 - avg_ms1) * 250.0), "μs/column")

    # Performance assessment
    print("\n" + "=" * 70)
    print("PERFORMANCE ASSESSMENT")
    print("=" * 70)

    var target_ms = 0.1  # Target: <0.1ms
    var psycopg2_ms = 1.0  # psycopg2 typical: ~1ms

    print("Target:          <", String(target_ms), "ms")
    print("psycopg2:        ~", String(psycopg2_ms), "ms")
    print("mojo-postgres:   ", String(avg_ms1), "ms")

    if avg_ms1 <= target_ms:
        print("Status:          ✅ TARGET MET!")
        var speedup = psycopg2_ms / avg_ms1
        print("Speedup:         ", String(speedup), "x faster than psycopg2")
    else:
        print("Status:          ⚠️  NEEDS OPTIMIZATION")
        var slowdown = avg_ms1 / target_ms
        print("                 ", String(slowdown), "x slower than target")

    print("=" * 70)
    print("\nNote: Run benchmarks/baseline/bench_query.py for accurate comparison")
    print("=" * 70)
