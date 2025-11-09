"""
Benchmark: PostgreSQL Connection Establishment

Measures the time to:
1. Create TCP socket
2. Connect to PostgreSQL
3. Complete authentication
4. Receive ReadyForQuery

Target: <0.5ms (4x faster than psycopg2's ~2ms)
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer, print_comparison
from src.protocol.connection import PostgresConnection


# Configuration
alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "benchdb"
alias USER = "benchuser"
alias PASSWORD = "benchpass"
alias ITERATIONS = 1000


fn connect_once() raises:
    """Connect to PostgreSQL and immediately disconnect."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    conn.close()


fn main() raises:
    print("\n" + "=" * 70)
    print("BENCHMARK: PostgreSQL Connection Establishment")
    print("=" * 70)
    print("Configuration:")
    print("  Host:       ", HOST)
    print("  Port:       ", String(PORT))
    print("  Database:   ", DATABASE)
    print("  User:       ", USER)
    print("  Iterations: ", String(ITERATIONS))
    print("=" * 70)

    # Run benchmark
    var result = benchmark[connect_once]("Connection Establishment", ITERATIONS)
    result.print_report()

    # Compare with Python (manual entry for now)
    # TODO: Load this from Python benchmark results
    print("\n" + "=" * 70)
    print("COMPARISON WITH PYTHON DRIVERS")
    print("=" * 70)
    print("Note: Run baseline/bench_connection.py first to get accurate comparison")
    print("")
    print("Expected psycopg2 time:  ~2.0 ms")
    print("Expected asyncpg time:   ~1.5 ms")
    print("")
    print("Target (4x faster):      <0.5 ms")
    print("=" * 70)

    # Calculate speedup vs target
    var mojo_ms = result.mean_ns / 1_000_000.0
    var target_ms = 0.5
    var psycopg2_ms = 2.0

    print("\nActual Performance:")
    print("  Mojo:           ", String(mojo_ms), "ms")
    print("  vs psycopg2:    ", String(psycopg2_ms / mojo_ms), "x faster")
    print("  vs Target:      ", end="")

    if mojo_ms <= target_ms:
        print("✅ TARGET MET!")
    else:
        var slowdown = mojo_ms / target_ms
        print("⚠️  ", String(slowdown), "x slower than target")

    print("\n" + "=" * 70)
    print("Recommendations:")
    if mojo_ms > target_ms:
        print("  - Ensure PostgreSQL is running on localhost")
        print("  - Check network latency (ping localhost)")
        print("  - Profile socket connection overhead")
        print("  - Consider connection pooling for production")
    else:
        print("  - Excellent! Connection time is below target")
        print("  - Consider implementing connection pooling next")
    print("=" * 70)
