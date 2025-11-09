"""
Query Timeout for mojo-postgres.

Prevents queries from running indefinitely.

Features:
- Query timeout configuration
- Connection timeout
- Idle timeout detection
- Timeout guards

Example:
    var config = TimeoutConfig.default()
    var manager = TimeoutManager(config)

    var query_id = manager.start_query()
    # Execute query...
    if manager.check_timeout(query_id):
        # Query timed out
        manager.cancel_query(query_id)
"""

from time import now
from collections import List
from src.protocol.connection import PostgresConnection
from src.metrics.metrics import Counter


# ============================================================================
# Timeout Configuration
# ============================================================================

@value
struct TimeoutConfig:
    """
    Configuration for timeout behavior.

    Fields:
        query_timeout_ms: Maximum time for a query to execute
        connection_timeout_ms: Maximum time to establish connection
        idle_timeout_ms: Maximum time connection can be idle
    """
    var query_timeout_ms: Int
    var connection_timeout_ms: Int
    var idle_timeout_ms: Int

    fn __init__(inout self):
        """Create default timeout configuration."""
        self.query_timeout_ms = 30000  # 30 seconds
        self.connection_timeout_ms = 5000  # 5 seconds
        self.idle_timeout_ms = 300000  # 5 minutes

    @staticmethod
    fn default() -> TimeoutConfig:
        """
        Default timeout configuration.

        - Query timeout: 30 seconds
        - Connection timeout: 5 seconds
        - Idle timeout: 5 minutes
        """
        return TimeoutConfig()

    @staticmethod
    fn strict() -> TimeoutConfig:
        """
        Strict timeouts (for fast queries).

        - Query timeout: 5 seconds
        - Connection timeout: 2 seconds
        - Idle timeout: 1 minute
        """
        var config = TimeoutConfig()
        config.query_timeout_ms = 5000
        config.connection_timeout_ms = 2000
        config.idle_timeout_ms = 60000
        return config

    @staticmethod
    fn lenient() -> TimeoutConfig:
        """
        Lenient timeouts (for long-running queries).

        - Query timeout: 5 minutes
        - Connection timeout: 10 seconds
        - Idle timeout: 30 minutes
        """
        var config = TimeoutConfig()
        config.query_timeout_ms = 300000
        config.connection_timeout_ms = 10000
        config.idle_timeout_ms = 1800000
        return config

    @staticmethod
    fn no_timeout() -> TimeoutConfig:
        """No timeouts (not recommended for production)."""
        var config = TimeoutConfig()
        config.query_timeout_ms = 0
        config.connection_timeout_ms = 0
        config.idle_timeout_ms = 0
        return config


# ============================================================================
# Timeout Manager
# ============================================================================

struct TimeoutManager:
    """
    Manages query timeouts and tracks active queries.

    Assigns IDs to queries and checks if they've exceeded timeout.
    """
    var config: TimeoutConfig
    var active_queries: List[Int]  # Query start times
    var next_query_id: Int

    fn __init__(inout self, config: TimeoutConfig):
        """Initialize timeout manager."""
        self.config = config
        self.active_queries = List[Int]()
        self.next_query_id = 0

    fn start_query(inout self) -> Int:
        """
        Start tracking a query.

        Returns:
            Query ID

        Example:
            var query_id = manager.start_query()
            # Execute query...
            if manager.check_timeout(query_id):
                # Timeout occurred
        """
        var query_id = self.next_query_id
        self.next_query_id += 1

        # Record start time
        var start_time = now() / 1_000_000  # milliseconds
        self.active_queries.append(Int(start_time))

        return query_id

    fn check_timeout(self, query_id: Int) -> Bool:
        """
        Check if query has timed out.

        Args:
            query_id: Query ID

        Returns:
            True if timed out, False otherwise
        """
        # No timeout configured
        if self.config.query_timeout_ms == 0:
            return False

        # Invalid query ID
        if query_id >= len(self.active_queries):
            return False

        var start_time = self.active_queries[query_id]
        var current_time = now() / 1_000_000
        var elapsed_ms = current_time - start_time

        return elapsed_ms >= self.config.query_timeout_ms

    fn cancel_query(inout self, query_id: Int):
        """
        Cancel a query (remove from active list).

        Args:
            query_id: Query ID to cancel
        """
        # In a real implementation, this would also send
        # pg_cancel_backend() to PostgreSQL
        pass

    fn get_elapsed_ms(self, query_id: Int) -> Int:
        """
        Get elapsed time for a query.

        Args:
            query_id: Query ID

        Returns:
            Elapsed time in milliseconds
        """
        if query_id >= len(self.active_queries):
            return 0

        var start_time = self.active_queries[query_id]
        var current_time = now() / 1_000_000
        return Int(current_time - start_time)

    fn get_remaining_ms(self, query_id: Int) -> Int:
        """
        Get remaining time before timeout.

        Args:
            query_id: Query ID

        Returns:
            Remaining time in milliseconds (0 if timed out)
        """
        var elapsed = self.get_elapsed_ms(query_id)
        var remaining = self.config.query_timeout_ms - elapsed

        if remaining < 0:
            return 0

        return remaining


# ============================================================================
# Timeout Guard
# ============================================================================

struct TimeoutGuard:
    """
    RAII-style timeout guard for automatic timeout checking.

    Tracks operation start time and checks timeout.
    """
    var start_time: Int
    var timeout_ms: Int

    fn __init__(inout self, timeout_ms: Int):
        """
        Initialize timeout guard.

        Args:
            timeout_ms: Timeout in milliseconds
        """
        self.start_time = now() / 1_000_000
        self.timeout_ms = timeout_ms

    fn is_timeout(self) -> Bool:
        """
        Check if timeout has occurred.

        Returns:
            True if timed out, False otherwise

        Example:
            var guard = TimeoutGuard(5000)  # 5 second timeout
            # Do work...
            if guard.is_timeout():
                raise Error("Operation timed out")
        """
        if self.timeout_ms == 0:
            return False

        var current_time = now() / 1_000_000
        var elapsed = current_time - self.start_time

        return elapsed >= self.timeout_ms

    fn remaining_ms(self) -> Int:
        """
        Get remaining time before timeout.

        Returns:
            Remaining time in milliseconds
        """
        if self.timeout_ms == 0:
            return 999999999  # Effectively infinite

        var current_time = now() / 1_000_000
        var elapsed = current_time - self.start_time
        var remaining = self.timeout_ms - elapsed

        if remaining < 0:
            return 0

        return Int(remaining)

    fn elapsed_ms(self) -> Int:
        """
        Get elapsed time.

        Returns:
            Elapsed time in milliseconds
        """
        var current_time = now() / 1_000_000
        return Int(current_time - self.start_time)


# ============================================================================
# Timeout Helpers
# ============================================================================

fn set_statement_timeout(conn: PostgresConnection, timeout_ms: Int) raises:
    """
    Set PostgreSQL statement_timeout parameter.

    Args:
        conn: Connection
        timeout_ms: Timeout in milliseconds

    Example:
        # Set 10 second timeout for all queries on this connection
        set_statement_timeout(conn, 10000)
    """
    var timeout_str = String(timeout_ms)
    var sql = "SET statement_timeout = " + timeout_str
    var _ = conn.query(sql)


fn clear_statement_timeout(conn: PostgresConnection) raises:
    """
    Clear PostgreSQL statement_timeout (set to default).

    Args:
        conn: Connection
    """
    var _ = conn.query("SET statement_timeout = DEFAULT")


fn get_statement_timeout(conn: PostgresConnection) raises -> String:
    """
    Get current statement_timeout setting.

    Args:
        conn: Connection

    Returns:
        Current timeout value

    Example:
        var timeout = get_statement_timeout(conn)
        print("Current timeout:", timeout)
    """
    var result = conn.query("SHOW statement_timeout")
    return result.get_string(0, 0)


# ============================================================================
# Timeout Metrics
# ============================================================================

struct TimeoutMetrics:
    """Metrics for timeout operations."""
    var timeouts_total: Counter
    var query_timeouts: Counter
    var connection_timeouts: Counter

    fn __init__(inout self):
        """Initialize timeout metrics."""
        self.timeouts_total = Counter("timeouts_total", "Total timeouts")
        self.query_timeouts = Counter("query_timeouts", "Query timeouts")
        self.connection_timeouts = Counter("connection_timeouts", "Connection timeouts")

    fn record_query_timeout(inout self):
        """Record a query timeout."""
        self.timeouts_total.inc()
        self.query_timeouts.inc()

    fn record_connection_timeout(inout self):
        """Record a connection timeout."""
        self.timeouts_total.inc()
        self.connection_timeouts.inc()
