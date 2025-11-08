"""
Examples of using connection pooling and transactions.

Connection pooling benefits:
- Eliminate 100ms connection overhead (reuse connections)
- Support concurrent queries
- Automatic health checks and recovery
- Resource limits (max connections)

Transaction support:
- ACID guarantees
- Rollback on error
- Savepoints for partial rollback

Run:
  mojo examples/connection_pooling.mojo

Prerequisites:
  PostgreSQL running on localhost:5432
"""

from src.pool.connection_pool import ConnectionPool
from src.protocol.transaction import begin_transaction, commit_transaction, rollback_transaction


# ============================================================================
# Example 1: Basic Connection Pooling
# ============================================================================

fn example_basic_pooling() raises:
    """Example: Basic connection pooling usage."""
    print("\n" + "=" * 70)
    print("Example 1: Basic Connection Pooling")
    print("=" * 70)

    # Create pool
    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(2, 5)  # min=2, max=5
    pool.initialize()

    print("\nInitialized pool with 2-5 connections")

    # Acquire connection from pool
    print("\nAcquiring connection 1...")
    var conn1 = pool.acquire()
    var result1 = conn1.query("SELECT 1 AS value")
    print("  Result: " + result1.get_value(0, 0))

    # Acquire another connection
    print("\nAcquiring connection 2...")
    var conn2 = pool.acquire()
    var result2 = conn2.query("SELECT 2 AS value")
    print("  Result: " + result2.get_value(0, 0))

    # Check pool stats
    var stats = pool.get_stats()
    print("\nPool stats: " + stats.to_string())

    # Release connections back to pool
    print("\nReleasing connections...")
    pool.release(conn1)
    pool.release(conn2)

    # Stats after release
    var stats2 = pool.get_stats()
    print("Pool stats: " + stats2.to_string())

    # Cleanup
    pool.close_all()

    print("\nKey Points:")
    print("  - Connections are reused (no reconnection overhead)")
    print("  - Pool tracks in_use vs idle connections")
    print("  - Automatic resource management")


# ============================================================================
# Example 2: Connection Reuse Performance
# ============================================================================

fn example_reuse_performance() raises:
    """Example: Performance benefit of connection reuse."""
    print("\n" + "=" * 70)
    print("Example 2: Connection Reuse Performance")
    print("=" * 70)

    from src.protocol.connection import PostgresConnection
    from time import now

    var iterations = 50

    # Test 1: No pooling (reconnect each time)
    print("\nTest 1: No pooling (reconnect each time)")
    var start1 = now()

    for i in range(iterations):
        var conn = PostgresConnection("localhost", 5432)
        conn.connect("test", "test", "test")
        var _ = conn.query("SELECT 1")
        conn.close()

    var elapsed1 = Float64(now() - start1) / 1_000_000.0
    print("  Time: " + String(elapsed1) + " ms")
    print("  Avg per query: " + String(elapsed1 / iterations) + " ms")

    # Test 2: With pooling (reuse connections)
    print("\nTest 2: With pooling (reuse connections)")
    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(1, 1)
    pool.initialize()

    var start2 = now()

    for i in range(iterations):
        var conn = pool.acquire()
        var _ = conn.query("SELECT 1")
        pool.release(conn)

    var elapsed2 = Float64(now() - start2) / 1_000_000.0
    print("  Time: " + String(elapsed2) + " ms")
    print("  Avg per query: " + String(elapsed2 / iterations) + " ms")

    pool.close_all()

    # Calculate speedup
    var speedup = elapsed1 / elapsed2
    print("\nSpeedup: " + String(speedup) + "x faster with pooling!")

    print("\nKey Points:")
    print("  - Pooling eliminates 100ms connection overhead")
    print("  - Dramatic speedup for many short queries")
    print("  - Critical for high-throughput applications")


# ============================================================================
# Example 3: Basic Transaction
# ============================================================================

fn example_basic_transaction() raises:
    """Example: Basic transaction usage."""
    print("\n" + "=" * 70)
    print("Example 3: Basic Transaction")
    print("=" * 70)

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(1, 1)
    pool.initialize()

    var conn = pool.acquire()

    # Create test table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE accounts (
            id INT PRIMARY KEY,
            name TEXT,
            balance NUMERIC(10, 2)
        )
    """)

    var __ = conn.query("""
        INSERT INTO accounts VALUES
            (1, 'Alice', 1000.00),
            (2, 'Bob', 500.00)
    """)

    print("\nInitial balances:")
    var result1 = conn.query("SELECT name, balance FROM accounts ORDER BY id")
    for i in range(result1.row_count()):
        print("  " + result1.get_value(i, 0) + ": $" + result1.get_value(i, 1))

    # Transfer money with transaction
    print("\nTransferring $100 from Alice to Bob...")
    begin_transaction(conn)

    try:
        conn.query("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        conn.query("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

        commit_transaction(conn)
        print("  Transaction committed!")
    except:
        rollback_transaction(conn)
        print("  Transaction rolled back!")
        raise

    # Check final balances
    print("\nFinal balances:")
    var result2 = conn.query("SELECT name, balance FROM accounts ORDER BY id")
    for i in range(result2.row_count()):
        print("  " + result2.get_value(i, 0) + ": $" + result2.get_value(i, 1))

    pool.release(conn)
    pool.close_all()

    print("\nKey Points:")
    print("  - Transaction ensures both updates succeed or both fail")
    print("  - ACID guarantees (Atomic, Consistent, Isolated, Durable)")
    print("  - Rollback on error prevents partial updates")


# ============================================================================
# Example 4: Transaction Rollback
# ============================================================================

fn example_transaction_rollback() raises:
    """Example: Transaction rollback on error."""
    print("\n" + "=" * 70)
    print("Example 4: Transaction Rollback on Error")
    print("=" * 70)

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(1, 1)
    pool.initialize()

    var conn = pool.acquire()

    # Create test table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE test_rollback (
            id INT PRIMARY KEY,
            value INT
        )
    """)

    var __ = conn.query("INSERT INTO test_rollback VALUES (1, 100)")

    print("\nInitial value:")
    var result1 = conn.query("SELECT value FROM test_rollback WHERE id = 1")
    print("  Value: " + result1.get_value(0, 0))

    # Try transaction that will fail
    print("\nAttempting transaction with error...")
    begin_transaction(conn)

    var rolled_back = False
    try:
        conn.query("UPDATE test_rollback SET value = 200 WHERE id = 1")
        print("  First UPDATE succeeded")

        # This will fail (duplicate primary key)
        conn.query("INSERT INTO test_rollback VALUES (1, 999)")
        print("  INSERT succeeded")  # Won't reach here

        commit_transaction(conn)
    except e:
        print("  Error occurred: INSERT failed (duplicate key)")
        rollback_transaction(conn)
        rolled_back = True
        print("  Transaction rolled back!")

    # Check value (should still be 100)
    print("\nFinal value:")
    var result2 = conn.query("SELECT value FROM test_rollback WHERE id = 1")
    var final_value = result2.get_value(0, 0)
    print("  Value: " + final_value)

    if final_value == "100":
        print("  ✓ Rollback worked! Value unchanged.")
    else:
        print("  ✗ Rollback failed! Value changed.")

    pool.release(conn)
    pool.close_all()

    print("\nKey Points:")
    print("  - Rollback prevents partial updates")
    print("  - Database state remains consistent")
    print("  - Critical for data integrity")


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Connection Pooling & Transaction Examples")
    print("=" * 70)
    print("")
    print("Demonstrating:")
    print("  - Connection pooling for performance")
    print("  - Transaction management for data integrity")
    print("")

    example_basic_pooling()
    example_reuse_performance()
    example_basic_transaction()
    example_transaction_rollback()

    print("\n" + "=" * 70)
    print("✅ All examples complete!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - Connection pooling: 5-10x faster (eliminate reconnection)")
    print("  - Transactions: ACID guarantees for data integrity")
    print("  - Production-ready connection management")
    print("")
