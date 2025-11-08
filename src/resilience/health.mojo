"""
Health Monitoring for mojo-postgres.

Provides proactive health checks for connections and pools.

Features:
- Connection health checking
- Pool health monitoring
- Unhealthy threshold detection
- Health status reporting

Example:
    var config = HealthCheckConfig.default()
    var checker = HealthChecker(config)

    var status = checker.check_connection(conn)
    if status.is_healthy:
        print("Connection is healthy")
"""

from time import now
from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool
from src.metrics.metrics import Counter, Gauge


# ============================================================================
# Health Status
# ============================================================================

@value
struct HealthStatus:
    """
    Health status of a connection or pool.

    Fields:
        is_healthy: Whether the component is healthy
        last_check: Timestamp of last health check
        error_message: Error message if unhealthy
        response_time_ms: Response time of health check
    """
    var is_healthy: Bool
    var last_check: Int
    var error_message: String
    var response_time_ms: Int

    fn __init__(inout self, is_healthy: Bool, error_message: String, response_time_ms: Int):
        """Create health status."""
        self.is_healthy = is_healthy
        self.last_check = now() / 1_000_000  # Convert to milliseconds
        self.error_message = error_message
        self.response_time_ms = response_time_ms

    @staticmethod
    fn healthy(response_time_ms: Int) -> HealthStatus:
        """
        Create healthy status.

        Args:
            response_time_ms: Response time in milliseconds

        Returns:
            Healthy status
        """
        return HealthStatus(True, "", response_time_ms)

    @staticmethod
    fn unhealthy(error: String) -> HealthStatus:
        """
        Create unhealthy status.

        Args:
            error: Error message

        Returns:
            Unhealthy status
        """
        return HealthStatus(False, error, 0)

    fn to_string(self) -> String:
        """Convert status to string representation."""
        if self.is_healthy:
            return "Healthy (response: " + String(self.response_time_ms) + "ms)"
        else:
            return "Unhealthy: " + self.error_message


# ============================================================================
# Health Check Configuration
# ============================================================================

@value
struct HealthCheckConfig:
    """
    Configuration for health checking.

    Fields:
        interval_ms: Time between health checks
        timeout_ms: Timeout for health check query
        unhealthy_threshold: Consecutive failures before marked unhealthy
        healthy_threshold: Consecutive successes to recover
    """
    var interval_ms: Int
    var timeout_ms: Int
    var unhealthy_threshold: Int
    var healthy_threshold: Int

    fn __init__(inout self):
        """Create default health check configuration."""
        self.interval_ms = 30000  # 30 seconds
        self.timeout_ms = 5000  # 5 seconds
        self.unhealthy_threshold = 3
        self.healthy_threshold = 2

    @staticmethod
    fn default() -> HealthCheckConfig:
        """
        Default health check configuration.

        - Interval: 30 seconds
        - Timeout: 5 seconds
        - Unhealthy threshold: 3 failures
        - Healthy threshold: 2 successes
        """
        return HealthCheckConfig()

    @staticmethod
    fn frequent() -> HealthCheckConfig:
        """
        Frequent health checks (for critical systems).

        - Interval: 5 seconds
        - Timeout: 2 seconds
        - Unhealthy threshold: 2 failures
        - Healthy threshold: 1 success
        """
        var config = HealthCheckConfig()
        config.interval_ms = 5000
        config.timeout_ms = 2000
        config.unhealthy_threshold = 2
        config.healthy_threshold = 1
        return config

    @staticmethod
    fn infrequent() -> HealthCheckConfig:
        """
        Infrequent health checks (for low-priority systems).

        - Interval: 5 minutes
        - Timeout: 10 seconds
        - Unhealthy threshold: 5 failures
        - Healthy threshold: 3 successes
        """
        var config = HealthCheckConfig()
        config.interval_ms = 300000  # 5 minutes
        config.timeout_ms = 10000
        config.unhealthy_threshold = 5
        config.healthy_threshold = 3
        return config


# ============================================================================
# Health Checker
# ============================================================================

struct HealthChecker:
    """
    Performs health checks on connections and pools.

    Tracks consecutive failures/successes and determines health status.
    """
    var config: HealthCheckConfig
    var status: HealthStatus
    var consecutive_failures: Int
    var consecutive_successes: Int

    fn __init__(inout self, config: HealthCheckConfig):
        """Initialize health checker."""
        self.config = config
        self.status = HealthStatus.healthy(0)
        self.consecutive_failures = 0
        self.consecutive_successes = 0

    fn check_connection(inout self, conn: PostgresConnection) raises -> HealthStatus:
        """
        Check connection health.

        Args:
            conn: Connection to check

        Returns:
            Health status

        Example:
            var status = checker.check_connection(conn)
            if status.is_healthy:
                print("Connection OK")
        """
        var start_time = now()

        try:
            # Run health check query
            var _ = conn.query("SELECT 1")

            # Calculate response time
            var elapsed_ms = (now() - start_time) / 1_000_000

            # Record success
            self.consecutive_successes += 1
            self.consecutive_failures = 0

            # Check if recovered
            if self.consecutive_successes >= self.config.healthy_threshold:
                self.status = HealthStatus.healthy(Int(elapsed_ms))

            return self.status

        except e:
            # Record failure
            self.consecutive_failures += 1
            self.consecutive_successes = 0

            # Check if unhealthy
            if self.consecutive_failures >= self.config.unhealthy_threshold:
                self.status = HealthStatus.unhealthy(str(e))

            return self.status

    fn check_pool(inout self, pool: ConnectionPool) raises -> HealthStatus:
        """
        Check pool health.

        Args:
            pool: Pool to check

        Returns:
            Health status

        Example:
            var status = checker.check_pool(pool)
            print(status.to_string())
        """
        var start_time = now()

        try:
            # Get pool statistics
            var stats = pool.get_stats()

            # Check if pool has connections
            if stats.total_connections == 0:
                self.consecutive_failures += 1
                self.status = HealthStatus.unhealthy("Pool has no connections")
                return self.status

            # Try to acquire connection
            var conn = pool.acquire()

            # Run health check on connection
            var _ = conn.query("SELECT 1")

            # Release connection
            pool.release(conn)

            # Calculate response time
            var elapsed_ms = (now() - start_time) / 1_000_000

            # Record success
            self.consecutive_successes += 1
            self.consecutive_failures = 0

            if self.consecutive_successes >= self.config.healthy_threshold:
                self.status = HealthStatus.healthy(Int(elapsed_ms))

            return self.status

        except e:
            # Record failure
            self.consecutive_failures += 1
            self.consecutive_successes = 0

            if self.consecutive_failures >= self.config.unhealthy_threshold:
                self.status = HealthStatus.unhealthy(str(e))

            return self.status

    fn is_healthy(self) -> Bool:
        """
        Check if currently healthy.

        Returns:
            True if healthy, False otherwise
        """
        return self.status.is_healthy

    fn get_status(self) -> HealthStatus:
        """
        Get current health status.

        Returns:
            Current health status
        """
        return self.status

    fn reset(inout self):
        """Reset health check state."""
        self.consecutive_failures = 0
        self.consecutive_successes = 0
        self.status = HealthStatus.healthy(0)


# ============================================================================
# Health Metrics
# ============================================================================

struct HealthMetrics:
    """Metrics for health monitoring."""
    var health_checks_total: Counter
    var health_checks_failed: Counter
    var health_check_duration_ms: Gauge
    var unhealthy_connections: Gauge

    fn __init__(inout self):
        """Initialize health metrics."""
        self.health_checks_total = Counter("health_checks_total", "Total health checks")
        self.health_checks_failed = Counter("health_checks_failed", "Failed health checks")
        self.health_check_duration_ms = Gauge("health_check_duration_ms", "Health check duration")
        self.unhealthy_connections = Gauge("unhealthy_connections", "Number of unhealthy connections")

    fn record_check(inout self, is_healthy: Bool, duration_ms: Int):
        """
        Record a health check.

        Args:
            is_healthy: Whether check succeeded
            duration_ms: Check duration
        """
        self.health_checks_total.inc()

        if not is_healthy:
            self.health_checks_failed.inc()

        self.health_check_duration_ms.set(Float64(duration_ms))


# ============================================================================
# Connection Health Monitor
# ============================================================================

struct ConnectionHealthMonitor:
    """
    Monitors connection health over time.

    Automatically runs health checks at configured intervals.
    """
    var checker: HealthChecker
    var metrics: HealthMetrics
    var last_check_time: Int

    fn __init__(inout self, config: HealthCheckConfig):
        """Initialize connection health monitor."""
        self.checker = HealthChecker(config)
        self.metrics = HealthMetrics()
        self.last_check_time = 0

    fn monitor_connection(inout self, conn: PostgresConnection) raises:
        """
        Monitor connection health.

        Args:
            conn: Connection to monitor

        Example:
            var monitor = ConnectionHealthMonitor(HealthCheckConfig.default())
            monitor.monitor_connection(conn)
        """
        var current_time = now() / 1_000_000

        # Check if enough time has passed since last check
        if current_time - self.last_check_time < self.checker.config.interval_ms:
            return

        # Perform health check
        var start_time = now()
        var status = self.checker.check_connection(conn)
        var duration_ms = (now() - start_time) / 1_000_000

        # Record metrics
        self.metrics.record_check(status.is_healthy, Int(duration_ms))

        # Update last check time
        self.last_check_time = current_time


# ============================================================================
# Pool Health Monitor
# ============================================================================

struct PoolHealthMonitor:
    """
    Monitors pool health over time.

    Tracks pool statistics and connection health.
    """
    var checker: HealthChecker
    var metrics: HealthMetrics
    var last_check_time: Int

    fn __init__(inout self, config: HealthCheckConfig):
        """Initialize pool health monitor."""
        self.checker = HealthChecker(config)
        self.metrics = HealthMetrics()
        self.last_check_time = 0

    fn monitor_pool(inout self, pool: ConnectionPool) raises:
        """
        Monitor pool health.

        Args:
            pool: Pool to monitor
        """
        var current_time = now() / 1_000_000

        # Check if enough time has passed
        if current_time - self.last_check_time < self.checker.config.interval_ms:
            return

        # Perform health check
        var start_time = now()
        var status = self.checker.check_pool(pool)
        var duration_ms = (now() - start_time) / 1_000_000

        # Record metrics
        self.metrics.record_check(status.is_healthy, Int(duration_ms))

        # Update last check time
        self.last_check_time = current_time

    fn get_pool_health(inout self, pool: ConnectionPool) raises -> HealthStatus:
        """
        Get pool health status.

        Args:
            pool: Pool to check

        Returns:
            Health status
        """
        return self.checker.check_pool(pool)
