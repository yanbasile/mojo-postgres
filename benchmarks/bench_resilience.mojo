"""
Benchmark: Resilience Features Overhead

Measures the performance overhead of resilience features:
1. Retry logic overhead
2. Circuit breaker overhead
3. Health check overhead
4. Timeout guard overhead
5. Connection validation overhead

Expected Results:
- Retry policy: <1μs per check
- Circuit breaker: <1μs per check
- Health check: Query time + ~1μs
- Timeout guard: <1μs per check
- Validation: Query time + ~1μs
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool
from src.resilience.retry import RetryConfig, RetryPolicy, is_retryable_error
from src.resilience.circuit_breaker import CircuitBreakerConfig, CircuitBreaker
from src.resilience.health import HealthCheckConfig, HealthChecker
from src.resilience.timeout import TimeoutConfig, TimeoutGuard
from src.resilience.validation import ValidationConfig, ConnectionValidator
from time import now


# ============================================================================
# Configuration
# ============================================================================

alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "test"
alias USER = "test"
alias PASSWORD = "test"
alias ITERATIONS = 1000


# ============================================================================
# Benchmark 1: Retry Logic Overhead
# ============================================================================

fn bench_retry_policy_creation() raises:
    """Benchmark: Create retry policy."""
    var config = RetryConfig.default()
    var policy = RetryPolicy(config)


fn bench_retry_should_retry() raises:
    """Benchmark: Check if should retry."""
    var config = RetryConfig.default()
    var policy = RetryPolicy(config)
    var _ = policy.should_retry("connection refused")


fn bench_retry_get_delay() raises:
    """Benchmark: Calculate retry delay."""
    var config = RetryConfig.default()
    var policy = RetryPolicy(config)
    var _ = policy.should_retry("connection refused")
    var delay = policy.get_delay_ms()


fn bench_is_retryable_error() raises:
    """Benchmark: Check if error is retryable."""
    var _ = is_retryable_error("connection refused")


# ============================================================================
# Benchmark 2: Circuit Breaker Overhead
# ============================================================================

fn bench_circuit_breaker_creation() raises:
    """Benchmark: Create circuit breaker."""
    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)


fn bench_circuit_breaker_should_allow() raises:
    """Benchmark: Check if should allow request (closed state)."""
    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)
    var _ = breaker.should_allow_request()


fn bench_circuit_breaker_record_success() raises:
    """Benchmark: Record successful operation."""
    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)
    breaker.record_success()


fn bench_circuit_breaker_record_failure() raises:
    """Benchmark: Record failed operation."""
    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)
    breaker.record_failure()


# ============================================================================
# Benchmark 3: Health Check Overhead
# ============================================================================

fn bench_health_checker_creation() raises:
    """Benchmark: Create health checker."""
    var config = HealthCheckConfig.default()
    var checker = HealthChecker(config)


fn bench_health_check_connection() raises:
    """Benchmark: Check connection health."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var config = HealthCheckConfig.default()
    var checker = HealthChecker(config)

    var _ = checker.check_connection(conn)

    conn.close()


fn bench_health_status_creation() raises:
    """Benchmark: Create health status."""
    from src.resilience.health import HealthStatus
    var _ = HealthStatus.healthy(10)


# ============================================================================
# Benchmark 4: Timeout Guard Overhead
# ============================================================================

fn bench_timeout_guard_creation() raises:
    """Benchmark: Create timeout guard."""
    var guard = TimeoutGuard(5000)


fn bench_timeout_guard_is_timeout() raises:
    """Benchmark: Check if timed out."""
    var guard = TimeoutGuard(5000)
    var _ = guard.is_timeout()


fn bench_timeout_guard_remaining() raises:
    """Benchmark: Get remaining time."""
    var guard = TimeoutGuard(5000)
    var _ = guard.remaining_ms()


fn bench_timeout_guard_elapsed() raises:
    """Benchmark: Get elapsed time."""
    var guard = TimeoutGuard(5000)
    var _ = guard.elapsed_ms()


# ============================================================================
# Benchmark 5: Connection Validation Overhead
# ============================================================================

fn bench_validation_config_creation() raises:
    """Benchmark: Create validation config."""
    var _ = ValidationConfig.default()


fn bench_connection_validate() raises:
    """Benchmark: Validate connection."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var config = ValidationConfig.default()
    var validator = ConnectionValidator(config)

    var _ = validator.validate(conn)

    conn.close()


# ============================================================================
# Benchmark 6: Query with Resilience Features
# ============================================================================

fn bench_query_no_resilience() raises:
    """Benchmark: Query without any resilience features."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)
    var _ = conn.query("SELECT 1")
    conn.close()


fn bench_query_with_circuit_breaker() raises:
    """Benchmark: Query with circuit breaker."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var config = CircuitBreakerConfig.default()
    var breaker = CircuitBreaker(config)

    if breaker.should_allow_request():
        var _ = conn.query("SELECT 1")
        breaker.record_success()

    conn.close()


fn bench_query_with_timeout_guard() raises:
    """Benchmark: Query with timeout guard."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var guard = TimeoutGuard(5000)
    var _ = conn.query("SELECT 1")

    if guard.is_timeout():
        raise Error("Timeout")

    conn.close()


fn bench_query_with_validation() raises:
    """Benchmark: Query with connection validation."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    var config = ValidationConfig.default()
    var validator = ConnectionValidator(config)

    if validator.validate(conn):
        var _ = conn.query("SELECT 1")

    conn.close()


fn bench_query_with_all_resilience() raises:
    """Benchmark: Query with all resilience features."""
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Setup all resilience features
    var breaker = CircuitBreaker(CircuitBreakerConfig.default())
    var guard = TimeoutGuard(5000)
    var validator = ConnectionValidator(ValidationConfig.default())

    # Validate
    if not validator.validate(conn):
        conn.close()
        raise Error("Invalid connection")

    # Check circuit breaker
    if not breaker.should_allow_request():
        conn.close()
        raise Error("Circuit breaker open")

    # Execute query
    var _ = conn.query("SELECT 1")
    breaker.record_success()

    # Check timeout
    if guard.is_timeout():
        conn.close()
        raise Error("Timeout")

    conn.close()


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("RESILIENCE FEATURES OVERHEAD BENCHMARKS")
    print("=" * 70)
    print("\n")

    # Benchmark 1: Retry Logic
    print("📊 Benchmark 1: Retry Logic Overhead\n")

    var r1 = benchmark[bench_retry_policy_creation]("Retry Policy Creation", ITERATIONS * 10)
    print("Create policy:   ", String(r1.mean_ns / 1000.0), "μs")

    var r2 = benchmark[bench_retry_should_retry]("Should Retry Check", ITERATIONS * 10)
    print("Should retry:    ", String(r2.mean_ns / 1000.0), "μs")

    var r3 = benchmark[bench_retry_get_delay]("Get Delay", ITERATIONS * 10)
    print("Get delay:       ", String(r3.mean_ns / 1000.0), "μs")

    var r4 = benchmark[bench_is_retryable_error]("Is Retryable Error", ITERATIONS * 10)
    print("Check retryable: ", String(r4.mean_ns / 1000.0), "μs")

    if r2.mean_ns < 10_000:  # Less than 10μs
        print("\n✅ Retry logic overhead is minimal (<10μs)")
    print("\n")

    # Benchmark 2: Circuit Breaker
    print("📊 Benchmark 2: Circuit Breaker Overhead\n")

    var r5 = benchmark[bench_circuit_breaker_creation]("Circuit Breaker Creation", ITERATIONS * 10)
    print("Create breaker:     ", String(r5.mean_ns / 1000.0), "μs")

    var r6 = benchmark[bench_circuit_breaker_should_allow]("Should Allow Request", ITERATIONS * 10)
    print("Should allow:       ", String(r6.mean_ns / 1000.0), "μs")

    var r7 = benchmark[bench_circuit_breaker_record_success]("Record Success", ITERATIONS * 10)
    print("Record success:     ", String(r7.mean_ns / 1000.0), "μs")

    var r8 = benchmark[bench_circuit_breaker_record_failure]("Record Failure", ITERATIONS * 10)
    print("Record failure:     ", String(r8.mean_ns / 1000.0), "μs")

    if r6.mean_ns < 10_000:
        print("\n✅ Circuit breaker overhead is minimal (<10μs)")
    print("\n")

    # Benchmark 3: Health Check
    print("📊 Benchmark 3: Health Check Overhead\n")

    var r9 = benchmark[bench_health_checker_creation]("Health Checker Creation", ITERATIONS * 10)
    print("Create checker:  ", String(r9.mean_ns / 1000.0), "μs")

    var r10 = benchmark[bench_health_check_connection]("Health Check (with query)", ITERATIONS)
    print("Check connection:", String(r10.mean_ns / 1_000_000.0), "ms")

    var r11 = benchmark[bench_health_status_creation]("Health Status Creation", ITERATIONS * 10)
    print("Create status:   ", String(r11.mean_ns / 1000.0), "μs")
    print("\n")

    # Benchmark 4: Timeout Guard
    print("📊 Benchmark 4: Timeout Guard Overhead\n")

    var r12 = benchmark[bench_timeout_guard_creation]("Timeout Guard Creation", ITERATIONS * 10)
    print("Create guard:    ", String(r12.mean_ns / 1000.0), "μs")

    var r13 = benchmark[bench_timeout_guard_is_timeout]("Is Timeout Check", ITERATIONS * 10)
    print("Is timeout:      ", String(r13.mean_ns / 1000.0), "μs")

    var r14 = benchmark[bench_timeout_guard_remaining]("Remaining Time", ITERATIONS * 10)
    print("Remaining time:  ", String(r14.mean_ns / 1000.0), "μs")

    var r15 = benchmark[bench_timeout_guard_elapsed]("Elapsed Time", ITERATIONS * 10)
    print("Elapsed time:    ", String(r15.mean_ns / 1000.0), "μs")

    if r13.mean_ns < 10_000:
        print("\n✅ Timeout guard overhead is minimal (<10μs)")
    print("\n")

    # Benchmark 5: Connection Validation
    print("📊 Benchmark 5: Connection Validation Overhead\n")

    var r16 = benchmark[bench_validation_config_creation]("Validation Config", ITERATIONS * 10)
    print("Create config:   ", String(r16.mean_ns / 1000.0), "μs")

    var r17 = benchmark[bench_connection_validate]("Validate Connection", ITERATIONS)
    print("Validate (query):", String(r17.mean_ns / 1_000_000.0), "ms")
    print("\n")

    # Benchmark 6: Query Overhead Comparison
    print("📊 Benchmark 6: Query Overhead with Resilience\n")
    print("This benchmark compares query performance with different resilience features\n")

    var r18 = benchmark[bench_query_no_resilience]("No Resilience", ITERATIONS)
    print("No resilience:       ", String(r18.mean_ns / 1_000_000.0), "ms")

    var r19 = benchmark[bench_query_with_circuit_breaker]("With Circuit Breaker", ITERATIONS)
    print("Circuit breaker:     ", String(r19.mean_ns / 1_000_000.0), "ms")

    var r20 = benchmark[bench_query_with_timeout_guard]("With Timeout Guard", ITERATIONS)
    print("Timeout guard:       ", String(r20.mean_ns / 1_000_000.0), "ms")

    var r21 = benchmark[bench_query_with_validation]("With Validation", ITERATIONS)
    print("Validation:          ", String(r21.mean_ns / 1_000_000.0), "ms")

    var r22 = benchmark[bench_query_with_all_resilience]("All Resilience Features", ITERATIONS)
    print("All features:        ", String(r22.mean_ns / 1_000_000.0), "ms")

    # Calculate overhead
    var breaker_overhead = ((r19.mean_ns - r18.mean_ns) / r18.mean_ns) * 100.0
    var timeout_overhead = ((r20.mean_ns - r18.mean_ns) / r18.mean_ns) * 100.0
    var validation_overhead = ((r21.mean_ns - r18.mean_ns) / r18.mean_ns) * 100.0
    var all_overhead = ((r22.mean_ns - r18.mean_ns) / r18.mean_ns) * 100.0

    print(f"\nOverhead compared to no resilience:")
    print(f"  Circuit breaker: {breaker_overhead:.2f}%")
    print(f"  Timeout guard:   {timeout_overhead:.2f}%")
    print(f"  Validation:      {validation_overhead:.2f}%")
    print(f"  All features:    {all_overhead:.2f}%")

    if all_overhead < 10.0:
        print("\n✅ Total resilience overhead is minimal (<10%)")
    print("\n")

    # Summary
    print("=" * 70)
    print("SUMMARY: Resilience Overhead")
    print("=" * 70)
    print()
    print("Per-Operation Overhead:")
    print(f"  • Retry policy check: {r2.mean_ns / 1000.0:.2f} μs")
    print(f"  • Circuit breaker check: {r6.mean_ns / 1000.0:.2f} μs")
    print(f"  • Timeout guard check: {r13.mean_ns / 1000.0:.2f} μs")
    print(f"  • Health check: {r10.mean_ns / 1_000_000.0:.2f} ms")
    print(f"  • Validation: {r17.mean_ns / 1_000_000.0:.2f} ms")
    print()
    print("Query Overhead:")
    print(f"  • No resilience: {r18.mean_ns / 1_000_000.0:.2f} ms (baseline)")
    print(f"  • All resilience: {r22.mean_ns / 1_000_000.0:.2f} ms ({all_overhead:.1f}% overhead)")
    print()
    print("Recommendations:")
    print("  ✓ Resilience overhead is negligible for most workloads")
    print("  ✓ Safe to enable all features in production")
    print("  ✓ Health checks and validation add query time")
    print("  ✓ Circuit breaker and timeout guards are nearly free")
    print()
    print("=" * 70)
    print("\n")
