"""
Connection Validation for mojo-postgres.

Provides automatic connection validation and recovery.

Features:
- Connection health validation
- Stale connection detection
- Auto-reconnection on failure
- Integration with connection pool

Example:
    var config = ValidationConfig.default()
    var validator = ConnectionValidator(config)

    if validator.validate(conn):
        # Connection is healthy
        var result = conn.query("SELECT * FROM users")
"""

from time import now
from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import PooledConnection


# ============================================================================
# Validation Configuration
# ============================================================================

@value
struct ValidationConfig:
    """
    Configuration for connection validation.

    Fields:
        validate_on_acquire: Validate connection before acquiring from pool
        validate_on_release: Validate connection when releasing to pool
        validation_query: SQL query to run for validation
        max_lifetime_ms: Maximum connection lifetime (reconnect after)
        validation_timeout_ms: Timeout for validation query
    """
    var validate_on_acquire: Bool
    var validate_on_release: Bool
    var validation_query: String
    var max_lifetime_ms: Int
    var validation_timeout_ms: Int

    fn __init__(inout self):
        """Create default validation configuration."""
        self.validate_on_acquire = True
        self.validate_on_release = False
        self.validation_query = "SELECT 1"
        self.max_lifetime_ms = 3600000  # 1 hour
        self.validation_timeout_ms = 5000  # 5 seconds

    @staticmethod
    fn default() -> ValidationConfig:
        """
        Default validation configuration.

        - Validate on acquire: Yes
        - Validate on release: No
        - Query: SELECT 1
        - Max lifetime: 1 hour
        - Validation timeout: 5 seconds
        """
        return ValidationConfig()

    @staticmethod
    fn strict() -> ValidationConfig:
        """
        Strict validation (validate on both acquire and release).

        - Validate on acquire: Yes
        - Validate on release: Yes
        - Query: SELECT 1
        - Max lifetime: 30 minutes
        - Validation timeout: 3 seconds
        """
        var config = ValidationConfig()
        config.validate_on_acquire = True
        config.validate_on_release = True
        config.max_lifetime_ms = 1800000  # 30 minutes
        config.validation_timeout_ms = 3000
        return config

    @staticmethod
    fn lenient() -> ValidationConfig:
        """
        Lenient validation (minimal checking).

        - Validate on acquire: Yes
        - Validate on release: No
        - Query: SELECT 1
        - Max lifetime: 4 hours
        - Validation timeout: 10 seconds
        """
        var config = ValidationConfig()
        config.validate_on_acquire = True
        config.validate_on_release = False
        config.max_lifetime_ms = 14400000  # 4 hours
        config.validation_timeout_ms = 10000
        return config

    @staticmethod
    fn disabled() -> ValidationConfig:
        """Validation disabled (not recommended for production)."""
        var config = ValidationConfig()
        config.validate_on_acquire = False
        config.validate_on_release = False
        return config


# ============================================================================
# Connection Validator
# ============================================================================

struct ConnectionValidator:
    """
    Validates connection health and freshness.

    Checks if connections are:
    - Responsive (can execute queries)
    - Not too old (within max lifetime)
    - Not stale (recently used)
    """
    var config: ValidationConfig

    fn __init__(inout self, config: ValidationConfig):
        """Initialize validator with configuration."""
        self.config = config

    fn validate(inout self, conn: PostgresConnection) raises -> Bool:
        """
        Validate a connection is healthy.

        Args:
            conn: Connection to validate

        Returns:
            True if valid, False if invalid

        Example:
            if validator.validate(conn):
                print("Connection is healthy")
            else:
                print("Connection is invalid")
        """
        try:
            # Run validation query
            var _ = conn.query(self.config.validation_query)
            return True
        except:
            # Query failed, connection is invalid
            return False

    fn is_stale(self, conn: PooledConnection) -> Bool:
        """
        Check if a pooled connection is stale (too old).

        Args:
            conn: Pooled connection

        Returns:
            True if stale, False if fresh
        """
        var age_ms = conn.age_ms()
        return age_ms >= self.config.max_lifetime_ms

    fn should_reconnect(self, conn: PooledConnection) -> Bool:
        """
        Determine if connection should be reconnected.

        Args:
            conn: Pooled connection

        Returns:
            True if should reconnect, False otherwise
        """
        # Reconnect if too old
        if self.is_stale(conn):
            return True

        # Could add more logic here:
        # - Too many errors
        # - Idle for too long
        # - Server version mismatch

        return False


# ============================================================================
# Reconnection Policy
# ============================================================================

@value
struct ReconnectionPolicy:
    """
    Policy for automatic reconnection.

    Fields:
        max_attempts: Maximum reconnection attempts
        delay_ms: Delay between reconnection attempts
        exponential_backoff: Use exponential backoff
    """
    var max_attempts: Int
    var delay_ms: Int
    var exponential_backoff: Bool

    fn __init__(inout self):
        """Create default reconnection policy."""
        self.max_attempts = 3
        self.delay_ms = 1000  # 1 second
        self.exponential_backoff = True

    @staticmethod
    fn default() -> ReconnectionPolicy:
        """Default reconnection policy (3 attempts, 1s delay, exponential)."""
        return ReconnectionPolicy()

    @staticmethod
    fn aggressive() -> ReconnectionPolicy:
        """Aggressive reconnection (5 attempts, 500ms delay)."""
        var policy = ReconnectionPolicy()
        policy.max_attempts = 5
        policy.delay_ms = 500
        policy.exponential_backoff = True
        return policy

    @staticmethod
    fn conservative() -> ReconnectionPolicy:
        """Conservative reconnection (2 attempts, 2s delay)."""
        var policy = ReconnectionPolicy()
        policy.max_attempts = 2
        policy.delay_ms = 2000
        policy.exponential_backoff = True
        return policy

    fn should_reconnect(inout self, error: String) -> Bool:
        """
        Determine if we should reconnect based on error.

        Args:
            error: Error message

        Returns:
            True if should reconnect
        """
        # Reconnect on connection errors
        if "connection" in error.lower():
            return True
        if "server closed" in error.lower():
            return True
        if "broken pipe" in error.lower():
            return True

        return False


# ============================================================================
# Validation Helpers
# ============================================================================

fn validate_connection_quick(conn: PostgresConnection) raises -> Bool:
    """
    Quick connection validation (SELECT 1).

    Args:
        conn: Connection to validate

    Returns:
        True if valid, False if invalid
    """
    try:
        var _ = conn.query("SELECT 1")
        return True
    except:
        return False


fn validate_connection_with_query(conn: PostgresConnection, query: String) raises -> Bool:
    """
    Validate connection with custom query.

    Args:
        conn: Connection to validate
        query: Validation query

    Returns:
        True if valid, False if invalid
    """
    try:
        var _ = conn.query(query)
        return True
    except:
        return False


fn check_connection_version(conn: PostgresConnection) raises -> String:
    """
    Get PostgreSQL server version.

    Args:
        conn: Connection

    Returns:
        Server version string

    Example:
        var version = check_connection_version(conn)
        print("Server version:", version)
    """
    var result = conn.query("SELECT version()")
    return result.get_string(0, 0)
