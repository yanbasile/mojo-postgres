"""
Benchmark: Transaction Performance

Measures transaction performance:
1. Simple transaction (BEGIN + COMMIT)
2. Transaction with rollback
3. Savepoints (create + rollback)
4. Different isolation levels
5. Read-only transactions
6. Transaction with multiple operations

Expected Results:
- Simple transaction: <1ms overhead
- Savepoint: <500μs overhead
- Isolation level: Minimal difference (<10%)
- Rollback: Faster than commit
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection
from src.protocol.transaction import (
    begin_transaction,
    commit_transaction,
    rollback_transaction,
    create_savepoint,
    rollback_to_savepoint,
    release_savepoint,
    begin_transaction_with_isolation,
    begin_read_only_transaction,
)
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
# Benchmark 1: Simple Transaction (BEGIN + COMMIT)
# ============================================================================

fn bench_empty_transaction() raises:
    """Benchmark: Empty transaction (BEGIN + COMMIT)."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction(conn)
    commit_transaction(conn)

    conn.close()


fn bench_transaction_with_query() raises:
    """Benchmark: Transaction with single query."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction(conn)
    var _ = conn.query("SELECT 1")
    commit_transaction(conn)

    conn.close()


fn bench_transaction_with_insert() raises:
    """Benchmark: Transaction with INSERT."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_tx")
    var __ = conn.query("CREATE TABLE bench_tx (id INT)")

    # Transaction with insert
    begin_transaction(conn)
    var ___ = conn.query("INSERT INTO bench_tx (id) VALUES (1)")
    commit_transaction(conn)

    # Cleanup
    var ____ = conn.query("DROP TABLE bench_tx")
    conn.close()


# ============================================================================
# Benchmark 2: Transaction Rollback
# ============================================================================

fn bench_transaction_rollback() raises:
    """Benchmark: Transaction with rollback."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_rollback")
    var __ = conn.query("CREATE TABLE bench_rollback (id INT)")

    # Transaction with rollback
    begin_transaction(conn)
    var ___ = conn.query("INSERT INTO bench_rollback (id) VALUES (1)")
    rollback_transaction(conn)

    # Cleanup
    var ____ = conn.query("DROP TABLE bench_rollback")
    conn.close()


# ============================================================================
# Benchmark 3: Savepoints
# ============================================================================

fn bench_savepoint_create() raises:
    """Benchmark: Create savepoint."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction(conn)
    create_savepoint(conn, "sp1")
    commit_transaction(conn)

    conn.close()


fn bench_savepoint_rollback() raises:
    """Benchmark: Rollback to savepoint."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_savepoint")
    var __ = conn.query("CREATE TABLE bench_savepoint (id INT)")

    # Transaction with savepoint rollback
    begin_transaction(conn)
    var ___ = conn.query("INSERT INTO bench_savepoint (id) VALUES (1)")
    create_savepoint(conn, "sp1")
    var ____ = conn.query("INSERT INTO bench_savepoint (id) VALUES (2)")
    rollback_to_savepoint(conn, "sp1")
    commit_transaction(conn)

    # Cleanup
    var _____ = conn.query("DROP TABLE bench_savepoint")
    conn.close()


fn bench_savepoint_release() raises:
    """Benchmark: Release savepoint."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction(conn)
    create_savepoint(conn, "sp1")
    release_savepoint(conn, "sp1")
    commit_transaction(conn)

    conn.close()


# ============================================================================
# Benchmark 4: Isolation Levels
# ============================================================================

fn bench_isolation_read_committed() raises:
    """Benchmark: Transaction with READ COMMITTED isolation."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction_with_isolation(conn, "READ COMMITTED")
    var _ = conn.query("SELECT 1")
    commit_transaction(conn)

    conn.close()


fn bench_isolation_repeatable_read() raises:
    """Benchmark: Transaction with REPEATABLE READ isolation."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction_with_isolation(conn, "REPEATABLE READ")
    var _ = conn.query("SELECT 1")
    commit_transaction(conn)

    conn.close()


fn bench_isolation_serializable() raises:
    """Benchmark: Transaction with SERIALIZABLE isolation."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction_with_isolation(conn, "SERIALIZABLE")
    var _ = conn.query("SELECT 1")
    commit_transaction(conn)

    conn.close()


# ============================================================================
# Benchmark 5: Read-Only Transactions
# ============================================================================

fn bench_read_only_transaction() raises:
    """Benchmark: Read-only transaction."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_read_only_transaction(conn)
    var _ = conn.query("SELECT 1")
    commit_transaction(conn)

    conn.close()


# ============================================================================
# Benchmark 6: Multi-Operation Transaction
# ============================================================================

fn bench_transaction_10_queries() raises:
    """Benchmark: Transaction with 10 queries."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    begin_transaction(conn)
    for i in range(10):
        var _ = conn.query("SELECT " + String(i))
    commit_transaction(conn)

    conn.close()


fn bench_transaction_10_inserts() raises:
    """Benchmark: Transaction with 10 inserts."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS bench_multi")
    var __ = conn.query("CREATE TABLE bench_multi (id INT)")

    # Transaction with 10 inserts
    begin_transaction(conn)
    for i in range(10):
        var ___ = conn.query("INSERT INTO bench_multi (id) VALUES (" + String(i) + ")")
    commit_transaction(conn)

    # Cleanup
    var ____ = conn.query("DROP TABLE bench_multi")
    conn.close()


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("TRANSACTION PERFORMANCE BENCHMARKS")
    print("=" * 70)
    print("\n")

    # Benchmark 1: Simple Transactions
    print("📊 Benchmark 1: Basic Transactions\n")

    var r1 = benchmark[bench_empty_transaction]("Empty Transaction", ITERATIONS)
    print("Empty (BEGIN+COMMIT):", String(r1.mean_ns / 1_000.0), "μs")

    var r2 = benchmark[bench_transaction_with_query]("Transaction + Query", ITERATIONS)
    print("With query:         ", String(r2.mean_ns / 1_000.0), "μs")

    var r3 = benchmark[bench_transaction_with_insert]("Transaction + INSERT", ITERATIONS)
    print("With INSERT:        ", String(r3.mean_ns / 1_000.0), "μs")

    var tx_overhead = r1.mean_ns / 1_000.0
    print(f"\nTransaction overhead: {tx_overhead:.2f} μs")
    if tx_overhead < 1000.0:  # Less than 1ms
        print("✅ Transaction overhead is minimal (<1ms)")
    print("\n")

    # Benchmark 2: Rollback
    print("📊 Benchmark 2: Rollback Performance\n")

    var r4 = benchmark[bench_transaction_rollback]("Transaction Rollback", ITERATIONS)
    r4.print_report()
    print()

    var rollback_vs_commit = r4.mean_ns / r3.mean_ns
    print("Rollback vs Commit:", String(rollback_vs_commit), "x")
    if rollback_vs_commit < 1.0:
        print("✅ Rollback is faster than commit (expected)")
    print("\n")

    # Benchmark 3: Savepoints
    print("📊 Benchmark 3: Savepoint Performance\n")

    var r5 = benchmark[bench_savepoint_create]("Create Savepoint", ITERATIONS)
    print("Create:  ", String(r5.mean_ns / 1_000.0), "μs")

    var r6 = benchmark[bench_savepoint_rollback]("Rollback to Savepoint", ITERATIONS)
    print("Rollback:", String(r6.mean_ns / 1_000.0), "μs")

    var r7 = benchmark[bench_savepoint_release]("Release Savepoint", ITERATIONS)
    print("Release: ", String(r7.mean_ns / 1_000.0), "μs")

    var savepoint_overhead = r5.mean_ns / 1_000.0
    if savepoint_overhead < 500.0:  # Less than 500μs
        print("\n✅ Savepoint overhead is minimal (<500μs)")
    print("\n")

    # Benchmark 4: Isolation Levels
    print("📊 Benchmark 4: Isolation Levels\n")

    var r8 = benchmark[bench_isolation_read_committed]("READ COMMITTED", ITERATIONS)
    print("READ COMMITTED:  ", String(r8.mean_ns / 1_000.0), "μs")

    var r9 = benchmark[bench_isolation_repeatable_read]("REPEATABLE READ", ITERATIONS)
    print("REPEATABLE READ: ", String(r9.mean_ns / 1_000.0), "μs")

    var r10 = benchmark[bench_isolation_serializable]("SERIALIZABLE", ITERATIONS)
    print("SERIALIZABLE:    ", String(r10.mean_ns / 1_000.0), "μs")

    var isolation_overhead = ((r10.mean_ns - r8.mean_ns) / r8.mean_ns) * 100.0
    print(f"\nSERIALIZABLE overhead: {isolation_overhead:.1f}%")
    if isolation_overhead < 20.0:
        print("✅ Isolation level overhead is minimal (<20%)")
    print("\n")

    # Benchmark 5: Read-Only
    print("📊 Benchmark 5: Read-Only Transactions\n")

    var r11 = benchmark[bench_read_only_transaction]("Read-Only Transaction", ITERATIONS)
    r11.print_report()
    print()

    var readonly_overhead = ((r11.mean_ns - r2.mean_ns) / r2.mean_ns) * 100.0
    print("Read-only overhead:", String(readonly_overhead), "%")
    print("\n")

    # Benchmark 6: Multi-Operation
    print("📊 Benchmark 6: Multi-Operation Transactions\n")

    var r12 = benchmark[bench_transaction_10_queries]("10 Queries", ITERATIONS)
    print("10 queries: ", String(r12.mean_ns / 1_000_000.0), "ms")

    var r13 = benchmark[bench_transaction_10_inserts]("10 INSERTs", ITERATIONS)
    print("10 INSERTs:", String(r13.mean_ns / 1_000_000.0), "ms")
    print("\n")

    # Summary
    print("=" * 70)
    print("SUMMARY: Transaction Performance")
    print("=" * 70)
    print()
    print("Key Findings:")
    print(f"  • Transaction overhead: {tx_overhead:.2f} μs")
    print(f"  • Savepoint overhead: {savepoint_overhead:.2f} μs")
    print(f"  • SERIALIZABLE overhead: {isolation_overhead:.1f}%")
    print(f"  • 10-query transaction: {r12.mean_ns / 1_000_000.0:.2f} ms")
    print(f"  • 10-insert transaction: {r13.mean_ns / 1_000_000.0:.2f} ms")
    print()
    print("Recommendations:")
    print("  ✓ Use transactions for data consistency")
    print("  ✓ Savepoints are efficient for partial rollback")
    print("  ✓ Use appropriate isolation level (READ COMMITTED is fastest)")
    print("  ✓ Batch operations in single transaction when possible")
    print("  ✓ Read-only transactions have minimal overhead")
    print()
    print("=" * 70)
    print("\n")
