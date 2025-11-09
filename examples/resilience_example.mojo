"""
Resilience Features Example.

Demonstrates all Phase 4B resilience features:
1. Retry logic with exponential backoff
2. Circuit breaker pattern
3. Health monitoring
4. Query timeout
5. Connection validation

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
"""

from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool
from src.resilience.retry import RetryConfig, RetryPolicy, RetryMetrics
from src.resilience.circuit_breaker import CircuitBreakerConfig, CircuitBreaker
from src.resilience.health import HealthCheckConfig, HealthChecker, HealthStatus
from src.resilience.timeout import TimeoutConfig, TimeoutGuard, set_statement_timeout
from src.resilience.validation import ValidationConfig, ConnectionValidator


# ============================================================================
# Example 1: Retry Logic
# ============================================================================

fn example1_retry_logic() raises:
    """Example 1: Automatic retry on transient failures."""
    print("=" * 70)
    print("Example 1: Retry Logic")
    print("=" * 70)

    print("\n🔄 Using default retry policy (3 attempts, exponential backoff)")

    var config = RetryConfig.default()
    print(f"   Max attempts: {config.max_attempts}")
    print(f"   Initial delay: {config.initial_delay_ms}ms")
    print(f"   Max delay: {config.max_delay_ms}ms")
    print(f"   Backoff multiplier: {config.backoff_multiplier}x")

    var policy = RetryPolicy(config)

    print("\n   Simulating transient failure scenario:")
    print("   - Attempt 1: Failed (connection refused)")
    print("   - Wait 100ms...")
    print("   - Attempt 2: Failed (connection refused)")
    print("   - Wait 200ms...")
    print("   - Attempt 3: Success!")

    print("\n✅ Retry logic handles transient failures automatically")
    print("\n")


# ============================================================================
# Example 2: Circuit Breaker
# ============================================================================

fn example2_circuit_breaker() raises:
    """Example 2: Circuit breaker pattern."""
    print("=" * 70)
    print("Example 2: Circuit Breaker")
    print("=" * 70)

    print("\n⚡ Circuit breaker protects against cascading failures")

    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)

    print(f"\n   Configuration:")
    print(f"   - Failure threshold: {config.failure_threshold}")
    print(f"   - Success threshold: {config.success_threshold}")
    print(f"   - Timeout: {config.timeout_ms}ms")

    print(f"\n   Initial state: {breaker.get_state()}")

    # Simulate failures
    print("\n   Simulating failures:")
    for i in range(5):
        breaker.record_failure()
        print(f"   - Failure {i+1}, state: {breaker.get_state()}")

    # Try to make request
    if breaker.should_allow_request():
        print("\n   ✅ Request allowed")
    else:
        print("\n   ❌ Request blocked (circuit is OPEN)")

    print("\n✅ Circuit breaker prevents requests to failing service")
    print("\n")


# ============================================================================
# Example 3: Health Monitoring
# ============================================================================

fn example3_health_monitoring() raises:
    """Example 3: Health monitoring."""
    print("=" * 70)
    print("Example 3: Health Monitoring")
    print("=" * 70)

    print("\n🏥 Health monitoring detects unhealthy connections")

    var config = HealthCheckConfig.default()
    var checker = HealthChecker(config)

    print(f"\n   Configuration:")
    print(f"   - Check interval: {config.interval_ms}ms")
    print(f"   - Timeout: {config.timeout_ms}ms")
    print(f"   - Unhealthy threshold: {config.unhealthy_threshold}")
    print(f"   - Healthy threshold: {config.healthy_threshold}")

    # Connect and check health
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var status = checker.check_connection(conn)

    print(f"\n   Health check result: {status.to_string()}")

    if status.is_healthy:
        print(f"   Response time: {status.response_time_ms}ms")
        print("\n   ✅ Connection is healthy")
    else:
        print(f"   Error: {status.error_message}")
        print("\n   ❌ Connection is unhealthy")

    conn.close()

    print("\n✅ Health monitoring provides early warning of issues")
    print("\n")


# ============================================================================
# Example 4: Query Timeout
# ============================================================================

fn example4_query_timeout() raises:
    """Example 4: Query timeout."""
    print("=" * 70)
    print("Example 4: Query Timeout")
    print("=" * 70)

    print("\n⏱️  Query timeout prevents runaway queries")

    var config = TimeoutConfig.default()

    print(f"\n   Configuration:")
    print(f"   - Query timeout: {config.query_timeout_ms}ms")
    print(f"   - Connection timeout: {config.connection_timeout_ms}ms")
    print(f"   - Idle timeout: {config.idle_timeout_ms}ms")

    # Use timeout guard
    print("\n   Using TimeoutGuard for 5 second timeout:")

    var guard = TimeoutGuard(5000)

    print(f"   - Elapsed: {guard.elapsed_ms()}ms")
    print(f"   - Remaining: {guard.remaining_ms()}ms")
    print(f"   - Is timeout: {guard.is_timeout()}")

    # Set statement timeout
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    print("\n   Setting PostgreSQL statement_timeout to 10 seconds...")
    set_statement_timeout(conn, 10000)
    print("   ✅ Timeout configured")

    conn.close()

    print("\n✅ Query timeout prevents resource exhaustion")
    print("\n")


# ============================================================================
# Example 5: Connection Validation
# ============================================================================

fn example5_connection_validation() raises:
    """Example 5: Connection validation."""
    print("=" * 70)
    print("Example 5: Connection Validation")
    print("=" * 70)

    print("\n🔍 Connection validation ensures healthy connections")

    var config = ValidationConfig.default()
    var validator = ConnectionValidator(config)

    print(f"\n   Configuration:")
    print(f"   - Validate on acquire: {config.validate_on_acquire}")
    print(f"   - Validate on release: {config.validate_on_release}")
    print(f"   - Validation query: {config.validation_query}")
    print(f"   - Max lifetime: {config.max_lifetime_ms}ms")

    # Connect and validate
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    print("\n   Validating connection...")
    var is_valid = validator.validate(conn)

    if is_valid:
        print("   ✅ Connection is valid")
    else:
        print("   ❌ Connection is invalid")

    conn.close()

    print("\n✅ Validation ensures connections are alive and responsive")
    print("\n")


# ============================================================================
# Example 6: Combining All Features
# ============================================================================

fn example6_combined_resilience() raises:
    """Example 6: All resilience features working together."""
    print("=" * 70)
    print("Example 6: Combined Resilience")
    print("=" * 70)

    print("\n🚀 Production-ready resilience with all features")

    # Setup all resilience features
    var retry_config = RetryConfig.default()
    var breaker_config = CircuitBreakerConfig.default()
    var health_config = HealthCheckConfig.default()
    var timeout_config = TimeoutConfig.default()
    var validation_config = ValidationConfig.default()

    var retry_policy = RetryPolicy(retry_config)
    var breaker = CircuitBreaker(breaker_config)
    var health_checker = HealthChecker(health_config)
    var validator = ConnectionValidator(validation_config)

    print("\n   ✅ Retry logic: Automatic recovery from transient failures")
    print("   ✅ Circuit breaker: Prevent cascading failures")
    print("   ✅ Health monitoring: Proactive issue detection")
    print("   ✅ Query timeout: Bounded resource usage")
    print("   ✅ Connection validation: Self-healing connections")

    # Connect with validation
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Validate connection
    print("\n   Validating connection...")
    var is_valid = validator.validate(conn)
    print(f"   Validation: {'✅ Valid' if is_valid else '❌ Invalid'}")

    # Check health
    var status = health_checker.check_connection(conn)
    print(f"   Health: {status.to_string()}")

    # Set timeout
    set_statement_timeout(conn, timeout_config.query_timeout_ms)
    print(f"   Timeout: {timeout_config.query_timeout_ms}ms")

    # Check circuit breaker
    if breaker.should_allow_request():
        print(f"   Circuit breaker: {breaker.get_state()} (requests allowed)")

        # Execute query with all protections
        try:
            var result = conn.query("SELECT 1 AS healthy")
            breaker.record_success()
            print("\n   ✅ Query executed successfully with all protections")

        except e:
            breaker.record_failure()
            print(f"\n   ❌ Query failed: {str(e)}")
    else:
        print(f"   Circuit breaker: OPEN (requests blocked)")

    conn.close()

    print("\n✅ All resilience features working together!")
    print("\n")


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("🛡️  RESILIENCE FEATURES DEMONSTRATION")
    print("=" * 70)
    print("\n")

    print("This example demonstrates Phase 4B resilience features:")
    print("  1. Retry Logic - Automatic recovery from failures")
    print("  2. Circuit Breaker - Prevent cascading failures")
    print("  3. Health Monitoring - Proactive issue detection")
    print("  4. Query Timeout - Resource usage limits")
    print("  5. Connection Validation - Self-healing connections")
    print("\n")

    example1_retry_logic()
    example2_circuit_breaker()
    example3_health_monitoring()
    example4_query_timeout()
    example5_connection_validation()
    example6_combined_resilience()

    print("=" * 70)
    print("🎉 All resilience examples completed!")
    print("=" * 70)
    print("\n")

    print("💡 Key Takeaways:")
    print("   • Retry logic handles transient failures automatically")
    print("   • Circuit breaker prevents cascade failures")
    print("   • Health monitoring provides early warning")
    print("   • Query timeout prevents resource exhaustion")
    print("   • Connection validation ensures reliability")
    print("\n")

    print("📚 Best Practices:")
    print("   • Use all features together for maximum resilience")
    print("   • Configure for your specific use case")
    print("   • Monitor metrics to understand behavior")
    print("   • Test failure scenarios in staging")
    print("\n")

    print("🚀 mojo-postgres is now enterprise-ready!")
    print("\n")
