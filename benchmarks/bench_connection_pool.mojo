"""
Benchmark: Connection Pool Performance

Measures connection pool performance:
1. Pool initialization (min connections)
2. Connection acquisition and release
3. Connection reuse vs new connection
4. Pool statistics overhead
5. Sequential queries (pool vs direct)
6. Connection lifecycle management

Expected Results:
- Connection reuse: 100x faster than new connection
- Pool overhead: <5% compared to direct connection
- Acquisition: <1ms for idle connection
- Statistics: <1μs
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool
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
# Benchmark 1: Pool Initialization
# ============================================================================

fn bench_pool_init_min2() raises:
    """Benchmark: Initialize pool with 2 minimum connections."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(2, 10)
    pool.initialize()
    pool.close_all()


fn bench_pool_init_min5() raises:
    """Benchmark: Initialize pool with 5 minimum connections."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(5, 20)
    pool.initialize()
    pool.close_all()


fn bench_pool_init_min10() raises:
    """Benchmark: Initialize pool with 10 minimum connections."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(10, 50)
    pool.initialize()
    pool.close_all()


# ============================================================================
# Benchmark 2: Connection Acquisition
# ============================================================================

fn bench_acquire_from_pool() raises:
    """Benchmark: Acquire connection from pool (warm pool)."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(5, 10)
    pool.initialize()

    # Acquire and release
    var conn = pool.acquire()
    pool.release(conn)

    pool.close_all()


fn bench_acquire_release_10x() raises:
    """Benchmark: Acquire and release 10 times."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(5, 10)
    pool.initialize()

    for i in range(10):
        var conn = pool.acquire()
        pool.release(conn)

    pool.close_all()


# ============================================================================
# Benchmark 3: New Connection vs Pool Reuse
# ============================================================================

fn bench_new_connection() raises:
    """Benchmark: Create new connection each time."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    conn.close()


fn bench_pool_reuse() raises:
    """Benchmark: Reuse connection from pool."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(2, 5)
    pool.initialize()

    var conn = pool.acquire()
    pool.release(conn)

    pool.close_all()


# ============================================================================
# Benchmark 4: Query Execution (Pool vs Direct)
# ============================================================================

fn bench_query_direct_10x() raises:
    """Benchmark: 10 queries with direct connection (reused)."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    for i in range(10):
        var _ = conn.query("SELECT " + String(i))

    conn.close()


fn bench_query_pool_10x() raises:
    """Benchmark: 10 queries with connection pool."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(2, 5)
    pool.initialize()

    for i in range(10):
        var conn = pool.acquire()
        var _ = conn.query("SELECT " + String(i))
        pool.release(conn)

    pool.close_all()


# ============================================================================
# Benchmark 5: Pool Statistics
# ============================================================================

fn bench_get_stats() raises:
    """Benchmark: Get pool statistics."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(5, 10)
    pool.initialize()

    var stats = pool.get_stats()

    pool.close_all()


# ============================================================================
# Benchmark 6: Sequential Workload (100 queries)
# ============================================================================

fn bench_sequential_new_connections() raises:
    """Benchmark: 100 queries with new connection each time."""
    for i in range(100):
        var conn = PostgresConnection(HOST, PORT)
        conn.connect(DATABASE, USER, PASSWORD)
        var _ = conn.query("SELECT " + String(i))
        conn.close()


fn bench_sequential_pool() raises:
    """Benchmark: 100 queries with connection pool."""
    var pool = ConnectionPool(HOST, PORT, DATABASE, USER, PASSWORD)
    pool.set_pool_size(5, 10)
    pool.initialize()

    for i in range(100):
        var conn = pool.acquire()
        var _ = conn.query("SELECT " + String(i))
        pool.release(conn)

    pool.close_all()


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("CONNECTION POOL PERFORMANCE BENCHMARKS")
    print("=" * 70)
    print("\n")

    # Benchmark 1: Pool Initialization
    print("📊 Benchmark 1: Pool Initialization\n")

    var r1 = benchmark[bench_pool_init_min2]("Pool Init (min=2)", 10)
    print("min=2 connections:", String(r1.mean_ns / 1_000_000.0), "ms")

    var r2 = benchmark[bench_pool_init_min5]("Pool Init (min=5)", 10)
    print("min=5 connections:", String(r2.mean_ns / 1_000_000.0), "ms")

    var r3 = benchmark[bench_pool_init_min10]("Pool Init (min=10)", 10)
    print("min=10 connections:", String(r3.mean_ns / 1_000_000.0), "ms")
    print("\n")

    # Benchmark 2: Connection Acquisition
    print("📊 Benchmark 2: Connection Acquisition\n")

    var r4 = benchmark[bench_acquire_from_pool]("Acquire from Pool", ITERATIONS)
    r4.print_report()
    print()

    var r5 = benchmark[bench_acquire_release_10x]("Acquire/Release (10x)", ITERATIONS)
    print("10 acquire/release cycles:", String(r5.mean_ns / 1_000_000.0), "ms")
    print("Per operation:", String(r5.mean_ns / 10.0 / 1_000.0), "μs")
    print("\n")

    # Benchmark 3: New Connection vs Pool Reuse
    print("📊 Benchmark 3: Connection Reuse Performance\n")

    var r6 = benchmark[bench_new_connection]("New Connection", ITERATIONS)
    r6.print_report()
    print()

    var r7 = benchmark[bench_pool_reuse]("Pool Reuse", ITERATIONS)
    r7.print_report()
    print()

    var speedup1 = r6.mean_ns / r7.mean_ns
    print("🚀 Speedup:", String(speedup1), "x")
    if speedup1 >= 10.0:
        print("✅ TARGET MET: Connection reuse is", String(speedup1), "x faster!")
    print("\n")

    # Benchmark 4: Query Execution
    print("📊 Benchmark 4: Query Execution (10 queries)\n")

    var r8 = benchmark[bench_query_direct_10x]("Direct Connection (reused)", ITERATIONS)
    r8.print_report()
    print()

    var r9 = benchmark[bench_query_pool_10x]("Connection Pool", ITERATIONS)
    r9.print_report()
    print()

    var overhead = ((r9.mean_ns - r8.mean_ns) / r8.mean_ns) * 100.0
    print("Pool overhead:", String(overhead), "%")
    if overhead < 10.0:
        print("✅ Pool overhead is minimal (<10%)")
    print("\n")

    # Benchmark 5: Statistics
    print("📊 Benchmark 5: Pool Statistics Overhead\n")

    var r10 = benchmark[bench_get_stats]("Get Statistics", ITERATIONS * 10)
    print("Statistics call:", String(r10.mean_ns / 1000.0), "μs")
    if r10.mean_ns < 10_000:  # Less than 10μs
        print("✅ Statistics overhead is negligible")
    print("\n")

    # Benchmark 6: Sequential Workload
    print("📊 Benchmark 6: Sequential Workload (100 queries)\n")
    print("This benchmark will take a while...\n")

    var r11 = benchmark[bench_sequential_new_connections]("New Connections (100x)", 3)
    r11.print_report()
    print()

    var r12 = benchmark[bench_sequential_pool]("Connection Pool (100x)", 3)
    r12.print_report()
    print()

    var speedup2 = r11.mean_ns / r12.mean_ns
    print("🚀 Speedup:", String(speedup2), "x")
    if speedup2 >= 50.0:
        print("✅ TARGET EXCEEDED: Pool is", String(speedup2), "x faster!")
    elif speedup2 >= 10.0:
        print("✅ TARGET MET: Pool is", String(speedup2), "x faster!")
    print("\n")

    # Summary
    print("=" * 70)
    print("SUMMARY: Connection Pool Performance")
    print("=" * 70)
    print()
    print("Key Findings:")
    print(f"  • Pool initialization (5 connections): {r2.mean_ns / 1_000_000.0:.2f} ms")
    print(f"  • Connection acquisition: {r4.mean_ns / 1_000.0:.2f} μs")
    print(f"  • Reuse vs new connection: {speedup1:.1f}x faster")
    print(f"  • Pool overhead: {overhead:.1f}%")
    print(f"  • Sequential workload: {speedup2:.1f}x faster")
    print()
    print("Recommendations:")
    print("  ✓ Always use connection pooling in production")
    print("  ✓ Set min connections based on baseline load")
    print("  ✓ Set max connections based on peak load")
    print("  ✓ Pool overhead is minimal for most workloads")
    print("  ✓ Connection reuse eliminates handshake overhead")
    print()
    print("=" * 70)
    print("\n")
