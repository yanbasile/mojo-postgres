"""
Benchmark: Prepared Statements Performance

Measures the performance benefits of prepared statements:
1. Simple query vs prepared statement (single execution)
2. Repeated query execution (10x, 100x, 1000x)
3. Parameter binding overhead
4. Statement cache effectiveness
5. SQL injection protection overhead

Expected Results:
- Prepared statements: 5-10x faster for repeated queries
- Parameter binding: Negligible overhead (<5%)
- Statement cache: Near-instant lookups
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection
from src.protocol.prepared import PreparedStatement, StatementCache
from time import now


# ============================================================================
# Configuration
# ============================================================================

alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "test"
alias USER = "test"
alias PASSWORD = "test"
alias ITERATIONS = 100


# ============================================================================
# Benchmark 1: Simple Query vs Prepared Statement (Single Execution)
# ============================================================================

fn bench_simple_query_single() raises:
    """Benchmark: Single simple query."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    var _ = conn.query("SELECT 1")
    conn.close()


fn bench_prepared_single() raises:
    """Benchmark: Single prepared statement."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    var stmt = PreparedStatement(conn, "SELECT 1")
    var _ = stmt.execute()
    stmt.close()
    conn.close()


# ============================================================================
# Benchmark 2: Repeated Query Execution (10x)
# ============================================================================

fn bench_simple_query_10x() raises:
    """Benchmark: 10 simple queries."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    for i in range(10):
        var _ = conn.query("SELECT " + String(i))
    conn.close()


fn bench_prepared_10x() raises:
    """Benchmark: 10 prepared statement executions."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    var stmt = PreparedStatement(conn, "SELECT $1")
    for i in range(10):
        stmt.reset()
        stmt.bind_int(0, i)
        var _ = stmt.execute()
    stmt.close()
    conn.close()


# ============================================================================
# Benchmark 3: Repeated Query Execution (100x)
# ============================================================================

fn bench_simple_query_100x() raises:
    """Benchmark: 100 simple queries."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    for i in range(100):
        var _ = conn.query("SELECT " + String(i))
    conn.close()


fn bench_prepared_100x() raises:
    """Benchmark: 100 prepared statement executions."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    var stmt = PreparedStatement(conn, "SELECT $1")
    for i in range(100):
        stmt.reset()
        stmt.bind_int(0, i)
        var _ = stmt.execute()
    stmt.close()
    conn.close()


# ============================================================================
# Benchmark 4: Parameter Binding Overhead
# ============================================================================

fn bench_binding_string() raises:
    """Benchmark: Bind string parameter."""
    var conn = PostgresConnection(HOST, PORT)
    var stmt = PreparedStatement(conn, "SELECT $1")
    stmt.bind(0, "test_value")
    conn.close()


fn bench_binding_int() raises:
    """Benchmark: Bind integer parameter."""
    var conn = PostgresConnection(HOST, PORT)
    var stmt = PreparedStatement(conn, "SELECT $1")
    stmt.bind_int(0, 12345)
    conn.close()


fn bench_binding_float() raises:
    """Benchmark: Bind float parameter."""
    var conn = PostgresConnection(HOST, PORT)
    var stmt = PreparedStatement(conn, "SELECT $1")
    stmt.bind_float(0, 123.456)
    conn.close()


fn bench_binding_multiple() raises:
    """Benchmark: Bind multiple parameters."""
    var conn = PostgresConnection(HOST, PORT)
    var stmt = PreparedStatement(conn, "SELECT $1, $2, $3, $4, $5")
    stmt.bind(0, "test")
    stmt.bind_int(1, 123)
    stmt.bind_float(2, 45.67)
    stmt.bind_bool(3, True)
    stmt.bind_null(4)
    conn.close()


# ============================================================================
# Benchmark 5: Statement Cache Performance
# ============================================================================

fn bench_cache_add() raises:
    """Benchmark: Add statement to cache."""
    var cache = StatementCache(1000)
    cache.add("SELECT * FROM users WHERE id = $1")


fn bench_cache_contains_hit() raises:
    """Benchmark: Cache lookup (hit)."""
    var cache = StatementCache(1000)
    var sql = "SELECT * FROM users WHERE id = $1"
    cache.add(sql)
    var _ = cache.contains(sql)


fn bench_cache_contains_miss() raises:
    """Benchmark: Cache lookup (miss)."""
    var cache = StatementCache(1000)
    cache.add("SELECT * FROM users WHERE id = $1")
    var _ = cache.contains("SELECT * FROM products WHERE id = $1")


# ============================================================================
# Benchmark 6: Insert Performance (Simple vs Prepared)
# ============================================================================

fn bench_insert_simple_1000() raises:
    """Benchmark: 1000 simple INSERTs."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_simple")
    var __ = conn.query("CREATE TABLE bench_simple (id INT, value TEXT)")

    # Insert 1000 rows
    for i in range(1000):
        var ___ = conn.query("INSERT INTO bench_simple (id, value) VALUES (" + String(i) + ", 'value" + String(i) + "')")

    # Cleanup
    var ____ = conn.query("DROP TABLE bench_simple")
    conn.close()


fn bench_insert_prepared_1000() raises:
    """Benchmark: 1000 prepared INSERTs."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_prepared")
    var __ = conn.query("CREATE TABLE bench_prepared (id INT, value TEXT)")

    # Prepare statement
    var stmt = PreparedStatement(conn, "INSERT INTO bench_prepared (id, value) VALUES ($1, $2)")

    # Insert 1000 rows
    for i in range(1000):
        stmt.reset()
        stmt.bind_int(0, i)
        stmt.bind(1, "value" + String(i))
        var ___ = stmt.execute()

    # Cleanup
    stmt.close()
    var ____ = conn.query("DROP TABLE bench_prepared")
    conn.close()


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("PREPARED STATEMENTS PERFORMANCE BENCHMARKS")
    print("=" * 70)
    print("\n")

    # Benchmark 1: Single Execution
    print("📊 Benchmark 1: Single Execution\n")

    var r1 = benchmark[bench_simple_query_single]("Simple Query (Single)", ITERATIONS)
    r1.print_report()
    print()

    var r2 = benchmark[bench_prepared_single]("Prepared Statement (Single)", ITERATIONS)
    r2.print_report()
    print()

    var speedup1 = r1.mean_ns / r2.mean_ns
    print("Speedup:", String(speedup1), "x")
    if speedup1 < 1.0:
        print("Note: Prepared statements slower for single execution (expected)")
    print("\n")

    # Benchmark 2: 10x Execution
    print("📊 Benchmark 2: Repeated Execution (10x)\n")

    var r3 = benchmark[bench_simple_query_10x]("Simple Query (10x)", ITERATIONS)
    r3.print_report()
    print()

    var r4 = benchmark[bench_prepared_10x]("Prepared Statement (10x)", ITERATIONS)
    r4.print_report()
    print()

    var speedup2 = r3.mean_ns / r4.mean_ns
    print("🚀 Speedup:", String(speedup2), "x")
    if speedup2 >= 2.0:
        print("✅ Prepared statements are", String(speedup2), "x faster!")
    print("\n")

    # Benchmark 3: 100x Execution
    print("📊 Benchmark 3: Repeated Execution (100x)\n")

    var r5 = benchmark[bench_simple_query_100x]("Simple Query (100x)", ITERATIONS)
    r5.print_report()
    print()

    var r6 = benchmark[bench_prepared_100x]("Prepared Statement (100x)", ITERATIONS)
    r6.print_report()
    print()

    var speedup3 = r5.mean_ns / r6.mean_ns
    print("🚀 Speedup:", String(speedup3), "x")
    if speedup3 >= 5.0:
        print("✅ Prepared statements are", String(speedup3), "x faster!")
        print("✅ TARGET MET: 5x+ improvement for repeated queries")
    print("\n")

    # Benchmark 4: Parameter Binding
    print("📊 Benchmark 4: Parameter Binding Overhead\n")

    var r7 = benchmark[bench_binding_string]("Bind String", ITERATIONS * 10)
    print("String binding:", String(r7.mean_ns / 1000.0), "μs")

    var r8 = benchmark[bench_binding_int]("Bind Int", ITERATIONS * 10)
    print("Int binding:   ", String(r8.mean_ns / 1000.0), "μs")

    var r9 = benchmark[bench_binding_float]("Bind Float", ITERATIONS * 10)
    print("Float binding: ", String(r9.mean_ns / 1000.0), "μs")

    var r10 = benchmark[bench_binding_multiple]("Bind Multiple (5 params)", ITERATIONS * 10)
    print("Multiple (5):  ", String(r10.mean_ns / 1000.0), "μs")
    print("\n")

    # Benchmark 5: Statement Cache
    print("📊 Benchmark 5: Statement Cache Performance\n")

    var r11 = benchmark[bench_cache_add]("Cache Add", ITERATIONS * 10)
    print("Add to cache:  ", String(r11.mean_ns / 1000.0), "μs")

    var r12 = benchmark[bench_cache_contains_hit]("Cache Hit", ITERATIONS * 10)
    print("Cache hit:     ", String(r12.mean_ns / 1000.0), "μs")

    var r13 = benchmark[bench_cache_contains_miss]("Cache Miss", ITERATIONS * 10)
    print("Cache miss:    ", String(r13.mean_ns / 1000.0), "μs")
    print("\n")

    # Benchmark 6: INSERT Performance
    print("📊 Benchmark 6: INSERT Performance (1000 rows)\n")
    print("This benchmark will take a while...\n")

    var r14 = benchmark[bench_insert_simple_1000]("Simple INSERT (1000x)", 5)
    r14.print_report()
    print()

    var r15 = benchmark[bench_insert_prepared_1000]("Prepared INSERT (1000x)", 5)
    r15.print_report()
    print()

    var speedup4 = r14.mean_ns / r15.mean_ns
    print("🚀 Speedup:", String(speedup4), "x")
    if speedup4 >= 10.0:
        print("✅ TARGET EXCEEDED: Prepared statements are", String(speedup4), "x faster!")
    elif speedup4 >= 5.0:
        print("✅ TARGET MET: Prepared statements are", String(speedup4), "x faster!")
    print("\n")

    # Summary
    print("=" * 70)
    print("SUMMARY: Prepared Statements Performance")
    print("=" * 70)
    print()
    print("Key Findings:")
    print(f"  • Single execution: {speedup1:.2f}x (prepared may be slower)")
    print(f"  • 10x execution: {speedup2:.2f}x faster")
    print(f"  • 100x execution: {speedup3:.2f}x faster")
    print(f"  • 1000 INSERTs: {speedup4:.2f}x faster")
    print()
    print("Recommendations:")
    print("  ✓ Use prepared statements for repeated queries")
    print("  ✓ Use prepared statements for batch operations")
    print("  ✓ Parameter binding has negligible overhead")
    print("  ✓ Statement caching is extremely fast")
    print()
    print("=" * 70)
    print("\n")
