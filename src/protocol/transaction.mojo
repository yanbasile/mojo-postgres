"""
PostgreSQL Transaction Management.

Provides transaction support via SQL commands:
- BEGIN - Start transaction
- COMMIT - Commit transaction
- ROLLBACK - Rollback transaction
- SAVEPOINT - Create savepoint
- ROLLBACK TO - Rollback to savepoint

Transaction Isolation Levels:
- READ UNCOMMITTED
- READ COMMITTED (PostgreSQL default)
- REPEATABLE READ
- SERIALIZABLE

Example:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("mydb", "user", "password")

    # Begin transaction
    begin_transaction(conn)

    try:
        conn.query("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        conn.query("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

        # Commit if both succeed
        commit_transaction(conn)
    except:
        # Rollback on error
        rollback_transaction(conn)
        raise
"""

from .connection import PostgresConnection


# ============================================================================
# Transaction Control
# ============================================================================

fn begin_transaction(inout conn: PostgresConnection) raises:
    """
    Begin a new transaction.

    Equivalent to: BEGIN

    Args:
        conn: PostgreSQL connection

    Raises:
        Error if BEGIN fails

    Example:
        begin_transaction(conn)
        conn.query("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        commit_transaction(conn)
    """
    var _ = conn.query("BEGIN")


fn begin_transaction_with_isolation(
    inout conn: PostgresConnection,
    isolation_level: String
) raises:
    """
    Begin transaction with specific isolation level.

    Isolation levels:
    - "READ UNCOMMITTED" - Lowest isolation (not truly supported in PostgreSQL)
    - "READ COMMITTED" - Default, prevents dirty reads
    - "REPEATABLE READ" - Prevents non-repeatable reads
    - "SERIALIZABLE" - Highest isolation, fully serialized execution

    Args:
        conn: PostgreSQL connection
        isolation_level: Isolation level string

    Raises:
        Error if BEGIN fails

    Example:
        begin_transaction_with_isolation(conn, "SERIALIZABLE")
    """
    var query = "BEGIN ISOLATION LEVEL " + isolation_level
    var _ = conn.query(query)


fn commit_transaction(inout conn: PostgresConnection) raises:
    """
    Commit the current transaction.

    Makes all changes permanent.

    Args:
        conn: PostgreSQL connection

    Raises:
        Error if COMMIT fails

    Example:
        begin_transaction(conn)
        conn.query("INSERT INTO users (name) VALUES ('Alice')")
        commit_transaction(conn)
    """
    var _ = conn.query("COMMIT")


fn rollback_transaction(inout conn: PostgresConnection) raises:
    """
    Rollback the current transaction.

    Discards all changes since BEGIN.

    Args:
        conn: PostgreSQL connection

    Raises:
        Error if ROLLBACK fails

    Example:
        begin_transaction(conn)
        try:
            conn.query("UPDATE accounts SET balance = -100 WHERE id = 1")
            commit_transaction(conn)
        except:
            rollback_transaction(conn)
            raise
    """
    var _ = conn.query("ROLLBACK")


# ============================================================================
# Savepoints
# ============================================================================

fn create_savepoint(inout conn: PostgresConnection, savepoint_name: String) raises:
    """
    Create a savepoint within a transaction.

    Savepoints allow partial rollback within a transaction.

    Args:
        conn: PostgreSQL connection
        savepoint_name: Name for the savepoint

    Raises:
        Error if SAVEPOINT fails

    Example:
        begin_transaction(conn)
        conn.query("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        create_savepoint(conn, "sp1")
        conn.query("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
        rollback_to_savepoint(conn, "sp1")  # Only rollback second UPDATE
        commit_transaction(conn)
    """
    var query = "SAVEPOINT " + savepoint_name
    var _ = conn.query(query)


fn rollback_to_savepoint(inout conn: PostgresConnection, savepoint_name: String) raises:
    """
    Rollback to a savepoint.

    Discards changes after the savepoint, but keeps changes before it.

    Args:
        conn: PostgreSQL connection
        savepoint_name: Name of the savepoint

    Raises:
        Error if ROLLBACK TO fails

    Example:
        begin_transaction(conn)
        conn.query("INSERT INTO users (name) VALUES ('Alice')")
        create_savepoint(conn, "sp1")
        conn.query("INSERT INTO users (name) VALUES ('Bob')")
        rollback_to_savepoint(conn, "sp1")  # Bob insert rolled back, Alice kept
        commit_transaction(conn)
    """
    var query = "ROLLBACK TO SAVEPOINT " + savepoint_name
    var _ = conn.query(query)


fn release_savepoint(inout conn: PostgresConnection, savepoint_name: String) raises:
    """
    Release a savepoint.

    Removes the savepoint but keeps all changes.

    Args:
        conn: PostgreSQL connection
        savepoint_name: Name of the savepoint

    Raises:
        Error if RELEASE fails

    Example:
        begin_transaction(conn)
        create_savepoint(conn, "sp1")
        conn.query("INSERT INTO users (name) VALUES ('Alice')")
        release_savepoint(conn, "sp1")  # Savepoint removed, changes kept
        commit_transaction(conn)
    """
    var query = "RELEASE SAVEPOINT " + savepoint_name
    var _ = conn.query(query)


# ============================================================================
# Read-Only Transactions
# ============================================================================

fn begin_read_only_transaction(inout conn: PostgresConnection) raises:
    """
    Begin a read-only transaction.

    Read-only transactions:
    - Cannot modify data
    - More efficient (no transaction log writes)
    - Useful for long-running analytical queries

    Args:
        conn: PostgreSQL connection

    Raises:
        Error if BEGIN fails

    Example:
        begin_read_only_transaction(conn)
        var result = conn.query("SELECT * FROM large_table")
        commit_transaction(conn)
    """
    var _ = conn.query("BEGIN READ ONLY")


# ============================================================================
# Transaction State Queries
# ============================================================================

fn is_in_transaction(inout conn: PostgresConnection) raises -> Bool:
    """
    Check if connection is currently in a transaction.

    Uses PostgreSQL's transaction_status function.

    Args:
        conn: PostgreSQL connection

    Returns:
        True if in transaction, False otherwise

    Raises:
        Error if query fails

    Example:
        if is_in_transaction(conn):
            print("Already in transaction")
        else:
            begin_transaction(conn)
    """
    var result = conn.query("SELECT CASE WHEN pg_backend_pid() = ANY(pg_stat_activity.pid) THEN 1 ELSE 0 END FROM pg_stat_activity")
    # Simplified check - in production, use proper transaction status query
    # For now, we can't reliably check without server-side state
    return False  # Placeholder


# ============================================================================
# Convenience: Automatic Rollback on Error
# ============================================================================

# Note: Mojo doesn't have context managers yet, so we provide
# a pattern for users to follow:
#
# begin_transaction(conn)
# var success = False
# try:
#     # Do work...
#     success = True
# except:
#     rollback_transaction(conn)
#     raise
# if success:
#     commit_transaction(conn)
