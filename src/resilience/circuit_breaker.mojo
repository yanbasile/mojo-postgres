"""
Circuit Breaker for mojo-postgres.

Prevents cascading failures by stopping requests to failing service.

Features:
- Three states: Closed, Open, Half-Open
- Configurable failure thresholds
- Automatic state transitions
- Circuit breaker metrics

States:
- Closed: Normal operation, requests pass through
- Open: Too many failures, requests fail immediately
- Half-Open: Testing if service recovered

Example:
    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)

    if breaker.should_allow_request():
        try:
            var result = conn.query("SELECT * FROM users")
            breaker.record_success()
        except e:
            breaker.record_failure()
"""

from time import now
from src.metrics.metrics import Counter, Gauge, Histogram


# ============================================================================
# Circuit Breaker States
# ============================================================================

@value
struct CircuitBreakerState:
    """
    Circuit breaker state.

    States:
    - "closed": Normal operation (requests allowed)
    - "open": Too many failures (requests blocked)
    - "half_open": Testing recovery (limited requests)
    """
    var state: String

    fn __init__(inout self, state: String):
        """Initialize with state string."""
        self.state = state

    @staticmethod
    fn closed() -> CircuitBreakerState:
        """Closed state (normal operation)."""
        return CircuitBreakerState("closed")

    @staticmethod
    fn open() -> CircuitBreakerState:
        """Open state (blocking requests)."""
        return CircuitBreakerState("open")

    @staticmethod
    fn half_open() -> CircuitBreakerState:
        """Half-open state (testing recovery)."""
        return CircuitBreakerState("half_open")

    fn is_closed(self) -> Bool:
        """Check if closed."""
        return self.state == "closed"

    fn is_open(self) -> Bool:
        """Check if open."""
        return self.state == "open"

    fn is_half_open(self) -> Bool:
        """Check if half-open."""
        return self.state == "half_open"

    fn to_string(self) -> String:
        """Get state as string."""
        return self.state


# ============================================================================
# Circuit Breaker Configuration
# ============================================================================

@value
struct CircuitBreakerConfig:
    """
    Configuration for circuit breaker.

    Fields:
        failure_threshold: Number of failures before opening
        success_threshold: Number of successes to close from half-open
        timeout_ms: Time before moving to half-open
        window_ms: Sliding window for failure counting
    """
    var failure_threshold: Int
    var success_threshold: Int
    var timeout_ms: Int
    var window_ms: Int

    fn __init__(inout self):
        """Create default circuit breaker configuration."""
        self.failure_threshold = 5
        self.success_threshold = 2
        self.timeout_ms = 60000  # 1 minute
        self.window_ms = 10000  # 10 seconds

    @staticmethod
    fn default() -> CircuitBreakerConfig:
        """
        Default circuit breaker configuration.

        - Failure threshold: 5 failures
        - Success threshold: 2 successes
        - Timeout: 60 seconds
        - Window: 10 seconds
        """
        return CircuitBreakerConfig()

    @staticmethod
    fn aggressive() -> CircuitBreakerConfig:
        """
        Aggressive circuit breaker (opens quickly).

        - Failure threshold: 3 failures
        - Success threshold: 1 success
        - Timeout: 30 seconds
        - Window: 5 seconds
        """
        var config = CircuitBreakerConfig()
        config.failure_threshold = 3
        config.success_threshold = 1
        config.timeout_ms = 30000
        config.window_ms = 5000
        return config

    @staticmethod
    fn tolerant() -> CircuitBreakerConfig:
        """
        Tolerant circuit breaker (stays closed longer).

        - Failure threshold: 10 failures
        - Success threshold: 3 successes
        - Timeout: 120 seconds
        - Window: 20 seconds
        """
        var config = CircuitBreakerConfig()
        config.failure_threshold = 10
        config.success_threshold = 3
        config.timeout_ms = 120000
        config.window_ms = 20000
        return config


# ============================================================================
# Circuit Breaker
# ============================================================================

struct CircuitBreaker:
    """
    Circuit breaker implementation.

    Protects against cascading failures by tracking errors
    and opening the circuit after too many failures.
    """
    var config: CircuitBreakerConfig
    var state: CircuitBreakerState
    var failure_count: Int
    var success_count: Int
    var last_failure_time: Int
    var metrics: CircuitBreakerMetrics

    fn __init__(inout self, config: CircuitBreakerConfig):
        """Initialize circuit breaker."""
        self.config = config
        self.state = CircuitBreakerState.closed()
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time = 0
        self.metrics = CircuitBreakerMetrics()

    fn record_success(inout self):
        """
        Record a successful operation.

        Updates state based on current state:
        - Closed: Reset failure count
        - Half-Open: Increment success count, close if threshold met
        - Open: Should not reach here

        Example:
            try:
                var result = conn.query("SELECT 1")
                breaker.record_success()
            except:
                breaker.record_failure()
        """
        self.metrics.successful_requests.inc()

        if self.state.is_closed():
            # Reset failure count on success
            self.failure_count = 0

        elif self.state.is_half_open():
            # Increment success count
            self.success_count += 1

            # Close if threshold met
            if self.success_count >= self.config.success_threshold:
                self._transition_to_closed()

    fn record_failure(inout self):
        """
        Record a failed operation.

        Updates state based on current state:
        - Closed: Increment failure count, open if threshold met
        - Half-Open: Go back to open
        - Open: Update last failure time

        Example:
            try:
                var result = conn.query("SELECT 1")
                breaker.record_success()
            except:
                breaker.record_failure()
        """
        self.metrics.failed_requests.inc()
        self.last_failure_time = now() / 1_000_000

        if self.state.is_closed():
            # Increment failure count
            self.failure_count += 1

            # Open if threshold met
            if self.failure_count >= self.config.failure_threshold:
                self._transition_to_open()

        elif self.state.is_half_open():
            # Failed during testing, go back to open
            self._transition_to_open()

    fn should_allow_request(inout self) -> Bool:
        """
        Check if request should be allowed.

        Returns:
            True if request allowed, False if blocked

        Example:
            if breaker.should_allow_request():
                # Execute request
                pass
            else:
                raise Error("Circuit breaker is open")
        """
        if self.state.is_closed():
            return True

        elif self.state.is_open():
            # Check if timeout has elapsed
            var current_time = now() / 1_000_000
            var elapsed = current_time - self.last_failure_time

            if elapsed >= self.config.timeout_ms:
                # Transition to half-open
                self._transition_to_half_open()
                return True
            else:
                # Still open, reject request
                self.metrics.rejected_requests.inc()
                return False

        elif self.state.is_half_open():
            # Allow limited requests
            return True

        return False

    fn get_state(self) -> String:
        """
        Get current state.

        Returns:
            State string ("closed", "open", "half_open")
        """
        return self.state.to_string()

    fn reset(inout self):
        """Reset circuit breaker to closed state."""
        self._transition_to_closed()

    fn force_open(inout self):
        """Force circuit breaker to open state (for testing)."""
        self._transition_to_open()

    fn force_closed(inout self):
        """Force circuit breaker to closed state."""
        self._transition_to_closed()

    fn _transition_to_closed(inout self):
        """Transition to closed state."""
        self.state = CircuitBreakerState.closed()
        self.failure_count = 0
        self.success_count = 0
        self.metrics.state_transitions.inc()

    fn _transition_to_open(inout self):
        """Transition to open state."""
        self.state = CircuitBreakerState.open()
        self.success_count = 0
        self.metrics.state_transitions.inc()

    fn _transition_to_half_open(inout self):
        """Transition to half-open state."""
        self.state = CircuitBreakerState.half_open()
        self.success_count = 0
        self.failure_count = 0
        self.metrics.state_transitions.inc()


# ============================================================================
# Circuit Breaker Metrics
# ============================================================================

struct CircuitBreakerMetrics:
    """Metrics for circuit breaker."""
    var state_transitions: Counter
    var rejected_requests: Counter
    var successful_requests: Counter
    var failed_requests: Counter

    fn __init__(inout self):
        """Initialize circuit breaker metrics."""
        self.state_transitions = Counter("circuit_breaker_transitions", "State transitions")
        self.rejected_requests = Counter("circuit_breaker_rejected", "Rejected requests")
        self.successful_requests = Counter("circuit_breaker_success", "Successful requests")
        self.failed_requests = Counter("circuit_breaker_failed", "Failed requests")

    fn record_state_change(inout self, from_state: String, to_state: String):
        """Record a state transition."""
        self.state_transitions.inc()
