"""
Retry Logic for mojo-postgres.

Provides automatic retry with exponential backoff for transient failures.

Features:
- Configurable retry attempts
- Exponential backoff with jitter
- Retryable error detection
- Retry metrics

Example:
    var config = RetryConfig.default()
    var policy = RetryPolicy(config)

    # Retry a query
    var result = retry_query(policy, conn, "SELECT * FROM users")
"""

from collections import List
from time import now, sleep
from random import random_si64
from src.metrics.metrics import Counter, Histogram


# ============================================================================
# Retry Configuration
# ============================================================================

@value
struct RetryConfig:
    """
    Configuration for retry behavior.

    Fields:
        max_attempts: Maximum number of retry attempts
        initial_delay_ms: Initial delay before first retry
        max_delay_ms: Maximum delay between retries
        backoff_multiplier: Multiplier for exponential backoff
        jitter: Whether to add random jitter to delays
    """
    var max_attempts: Int
    var initial_delay_ms: Int
    var max_delay_ms: Int
    var backoff_multiplier: Float64
    var jitter: Bool

    fn __init__(inout self):
        """Create default retry configuration."""
        self.max_attempts = 3
        self.initial_delay_ms = 100
        self.max_delay_ms = 30000
        self.backoff_multiplier = 2.0
        self.jitter = True

    @staticmethod
    fn default() -> RetryConfig:
        """
        Default retry configuration.

        - 3 attempts
        - 100ms initial delay
        - 30s max delay
        - 2.0x backoff multiplier
        - Jitter enabled
        """
        return RetryConfig()

    @staticmethod
    fn aggressive() -> RetryConfig:
        """
        Aggressive retry configuration (for development).

        - 5 attempts
        - 50ms initial delay
        - 5s max delay
        - 1.5x backoff multiplier
        - Jitter enabled
        """
        var config = RetryConfig()
        config.max_attempts = 5
        config.initial_delay_ms = 50
        config.max_delay_ms = 5000
        config.backoff_multiplier = 1.5
        config.jitter = True
        return config

    @staticmethod
    fn conservative() -> RetryConfig:
        """
        Conservative retry configuration (for production).

        - 2 attempts
        - 200ms initial delay
        - 60s max delay
        - 3.0x backoff multiplier
        - Jitter enabled
        """
        var config = RetryConfig()
        config.max_attempts = 2
        config.initial_delay_ms = 200
        config.max_delay_ms = 60000
        config.backoff_multiplier = 3.0
        config.jitter = True
        return config

    @staticmethod
    fn no_retry() -> RetryConfig:
        """No retry configuration (fail fast)."""
        var config = RetryConfig()
        config.max_attempts = 1
        return config


# ============================================================================
# Retry Policy
# ============================================================================

struct RetryPolicy:
    """
    Retry policy that manages retry state and logic.

    Tracks attempt count and determines if/when to retry.
    """
    var config: RetryConfig
    var attempt_count: Int
    var last_error: String

    fn __init__(inout self, config: RetryConfig):
        """Initialize retry policy with configuration."""
        self.config = config
        self.attempt_count = 0
        self.last_error = ""

    fn should_retry(inout self, error: String) -> Bool:
        """
        Determine if we should retry given an error.

        Args:
            error: Error message

        Returns:
            True if should retry, False otherwise
        """
        self.last_error = error
        self.attempt_count += 1

        # Check if we've exceeded max attempts
        if self.attempt_count >= self.config.max_attempts:
            return False

        # Check if error is retryable
        return is_retryable_error(error)

    fn get_delay_ms(self) -> Int:
        """
        Calculate delay before next retry using exponential backoff.

        Returns:
            Delay in milliseconds
        """
        # Calculate exponential backoff
        var delay = Float64(self.config.initial_delay_ms)
        for i in range(self.attempt_count - 1):
            delay *= self.config.backoff_multiplier

        # Cap at max delay
        if delay > Float64(self.config.max_delay_ms):
            delay = Float64(self.config.max_delay_ms)

        # Add jitter if enabled
        if self.config.jitter:
            # Add random jitter: ±25% of delay
            var jitter_range = delay * 0.25
            var jitter_value = (random_si64(0, 1000) / 1000.0 - 0.5) * 2.0 * jitter_range
            delay += jitter_value

        return Int(delay)

    fn reset(inout self):
        """Reset retry state."""
        self.attempt_count = 0
        self.last_error = ""

    fn get_attempts(self) -> Int:
        """Get number of attempts made."""
        return self.attempt_count


# ============================================================================
# Retryable Error Detection
# ============================================================================

fn is_retryable_error(error: String) -> Bool:
    """
    Check if an error is transient and retryable.

    Retryable errors include:
    - Connection refused
    - Connection timeout
    - Connection reset
    - Server restarting
    - Too many connections
    - Deadlock detected

    Args:
        error: Error message

    Returns:
        True if error is retryable, False otherwise
    """
    # Connection errors (transient)
    if "connection refused" in error.lower():
        return True
    if "connection timeout" in error.lower():
        return True
    if "connection reset" in error.lower():
        return True
    if "broken pipe" in error.lower():
        return True

    # Server errors (transient)
    if "server closed the connection" in error.lower():
        return True
    if "server is starting up" in error.lower():
        return True
    if "server is shutting down" in error.lower():
        return True

    # Resource errors (transient)
    if "too many connections" in error.lower():
        return True
    if "out of memory" in error.lower():
        return True

    # Transaction errors (potentially retryable)
    if "deadlock detected" in error.lower():
        return True
    if "could not serialize" in error.lower():
        return True

    # Not retryable
    return False


# ============================================================================
# Retry Metrics
# ============================================================================

struct RetryMetrics:
    """Metrics for retry operations."""
    var total_retries: Counter
    var successful_retries: Counter
    var failed_retries: Counter
    var retry_delay: Histogram

    fn __init__(inout self):
        """Initialize retry metrics."""
        self.total_retries = Counter("retry_total", "Total retry attempts")
        self.successful_retries = Counter("retry_success", "Successful retries")
        self.failed_retries = Counter("retry_failed", "Failed retries")

        var buckets = List[Float64]()
        buckets.append(0.05)   # 50ms
        buckets.append(0.1)    # 100ms
        buckets.append(0.5)    # 500ms
        buckets.append(1.0)    # 1s
        buckets.append(5.0)    # 5s
        buckets.append(30.0)   # 30s
        self.retry_delay = Histogram("retry_delay_seconds", "Retry delay", buckets)

    fn record_retry(inout self, attempt: Int, success: Bool, delay_ms: Int):
        """
        Record a retry attempt.

        Args:
            attempt: Attempt number
            success: Whether retry succeeded
            delay_ms: Delay before retry
        """
        self.total_retries.inc()

        if success:
            self.successful_retries.inc()
        else:
            self.failed_retries.inc()

        self.retry_delay.observe(Float64(delay_ms) / 1000.0)


# ============================================================================
# Retry Helpers
# ============================================================================

fn sleep_ms(ms: Int):
    """
    Sleep for specified milliseconds.

    Args:
        ms: Milliseconds to sleep
    """
    # Mojo's sleep() takes nanoseconds
    sleep(ms * 1_000_000)


fn calculate_delay_with_jitter(base_delay_ms: Int, jitter_percent: Float64) -> Int:
    """
    Calculate delay with random jitter.

    Args:
        base_delay_ms: Base delay in milliseconds
        jitter_percent: Jitter percentage (e.g., 0.25 for ±25%)

    Returns:
        Delay with jitter applied
    """
    var jitter_range = Float64(base_delay_ms) * jitter_percent
    var jitter_value = (random_si64(0, 1000) / 1000.0 - 0.5) * 2.0 * jitter_range
    var final_delay = Float64(base_delay_ms) + jitter_value

    if final_delay < 0:
        final_delay = 0

    return Int(final_delay)
