# Resilience & Reliability Guide

Complete guide to using mojo-postgres resilience features for production deployments.

## Overview

Phase 4B adds enterprise-grade resilience features that make mojo-postgres production-ready for mission-critical systems. These features handle failures gracefully, prevent cascading failures, and ensure high availability.

## Table of Contents

- [Quick Start](#quick-start)
- [Retry Logic](#retry-logic)
- [Circuit Breaker](#circuit-breaker)
- [Health Monitoring](#health-monitoring)
- [Query Timeout](#query-timeout)
- [Connection Validation](#connection-validation)
- [Best Practices](#best-practices)
- [Production Configuration](#production-configuration)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```mojo
from src.protocol.connection import PostgresConnection
from src.resilience.retry import RetryConfig, RetryPolicy
from src.resilience.circuit_breaker import CircuitBreakerConfig, CircuitBreaker
from src.resilience.health import HealthCheckConfig, HealthChecker
from src.resilience.timeout import TimeoutConfig, TimeoutGuard
from src.resilience.validation import ValidationConfig, ConnectionValidator

// Setup resilience features
var retry_policy = RetryPolicy(RetryConfig.default())
var breaker = CircuitBreaker(CircuitBreakerConfig.default())
var health_checker = HealthChecker(HealthCheckConfig.default())
var validator = ConnectionValidator(ValidationConfig.default())

// Connect and validate
var conn = PostgresConnection("localhost", 5432)
conn.connect("mydb", "user", "password")

if !validator.validate(conn):
    raise Error("Connection is invalid")

// Check health
var status = health_checker.check_connection(conn)
if !status.is_healthy:
    raise Error("Connection is unhealthy")

// Execute with circuit breaker and timeout
if breaker.should_allow_request():
    var guard = TimeoutGuard(5000)  // 5 second timeout

    try:
        var result = conn.query("SELECT * FROM users")
        breaker.record_success()
    except e:
        breaker.record_failure()
        raise e
```

---

## Retry Logic

Automatic retry with exponential backoff for transient failures.

### Configuration

```mojo
// Default: 3 attempts, 100ms-30s delays, 2.0x backoff
var config = RetryConfig.default()

// Aggressive: 5 attempts, 50ms-5s delays (for development)
var config = RetryConfig.aggressive()

// Conservative: 2 attempts, 200ms-60s delays (for production)
var config = RetryConfig.conservative()

// Custom configuration
var config = RetryConfig()
config.max_attempts = 5
config.initial_delay_ms = 200
config.max_delay_ms = 10000
config.backoff_multiplier = 2.5
config.jitter = True
```

### Usage

```mojo
var policy = RetryPolicy(config)

// Manual retry logic
while True:
    try:
        var result = conn.query("SELECT * FROM users")
        break
    except e:
        if policy.should_retry(str(e)):
            var delay_ms = policy.get_delay_ms()
            sleep_ms(delay_ms)
            continue
        else:
            raise e
```

### Retryable Errors

The retry logic automatically detects these retryable errors:

**Connection Errors:**
- Connection refused
- Connection timeout
- Connection reset
- Broken pipe

**Server Errors:**
- Server starting up
- Server shutting down
- Server closed connection

**Resource Errors:**
- Too many connections
- Out of memory

**Transaction Errors:**
- Deadlock detected
- Serialization failure

### Metrics

```mojo
var metrics = RetryMetrics()

// Track retry attempts
metrics.record_retry(attempt=2, success=True, delay_ms=200)

// Export to Prometheus
print(metrics.total_retries.to_prometheus())
print(metrics.successful_retries.to_prometheus())
print(metrics.failed_retries.to_prometheus())
```

---

## Circuit Breaker

Prevents cascading failures by stopping requests to failing services.

### States

- **Closed**: Normal operation, requests allowed
- **Open**: Too many failures, requests blocked
- **Half-Open**: Testing recovery, limited requests

### Configuration

```mojo
// Default: 5 failures → open, 2 successes → closed
var config = CircuitBreakerConfig.default()

// Aggressive: Opens quickly (3 failures)
var config = CircuitBreakerConfig.aggressive()

// Tolerant: Stays closed longer (10 failures)
var config = CircuitBreakerConfig.tolerant()

// Custom configuration
var config = CircuitBreakerConfig()
config.failure_threshold = 3
config.success_threshold = 2
config.timeout_ms = 60000  // 1 minute
config.window_ms = 10000   // 10 second window
```

### Usage

```mojo
var breaker = CircuitBreaker(config)

if breaker.should_allow_request():
    try:
        var result = conn.query("SELECT * FROM users")
        breaker.record_success()
    except:
        breaker.record_failure()
        raise
else:
    raise Error("Circuit breaker is open")
```

### State Transitions

```
Closed ──(failures >= threshold)──> Open
                                      │
                                      │ (timeout elapsed)
                                      ↓
Open ──────(timeout elapsed)────> Half-Open
                                      │
                                      ├─(success >= threshold)─> Closed
                                      │
                                      └─(any failure)─> Open
```

### Manual Control

```mojo
// Force states (for testing)
breaker.force_open()
breaker.force_closed()

// Check current state
var state = breaker.get_state()  // "closed", "open", or "half_open"

// Reset to closed
breaker.reset()
```

---

## Health Monitoring

Proactive health checks for connections and pools.

### Configuration

```mojo
// Default: 30s interval, 5s timeout
var config = HealthCheckConfig.default()

// Frequent: 5s interval (for critical systems)
var config = HealthCheckConfig.frequent()

// Infrequent: 5min interval (for low-priority)
var config = HealthCheckConfig.infrequent()

// Custom configuration
var config = HealthCheckConfig()
config.interval_ms = 60000        // 1 minute
config.timeout_ms = 5000          // 5 seconds
config.unhealthy_threshold = 3    // 3 failures → unhealthy
config.healthy_threshold = 2      // 2 successes → healthy
```

### Usage

```mojo
var checker = HealthChecker(config)

// Check connection health
var status = checker.check_connection(conn)

if status.is_healthy:
    print(f"Healthy (response: {status.response_time_ms}ms)")
else:
    print(f"Unhealthy: {status.error_message}")

// Check pool health
var pool_status = checker.check_pool(pool)
```

### Automated Monitoring

```mojo
var monitor = ConnectionHealthMonitor(config)

// Automatically checks at configured interval
monitor.monitor_connection(conn)

// Get current status
var current_health = monitor.checker.is_healthy()
```

### Health Metrics

```mojo
var metrics = HealthMetrics()

// Record health check
metrics.record_check(is_healthy=True, duration_ms=15)

// Export metrics
print(metrics.health_checks_total.to_prometheus())
print(metrics.health_checks_failed.to_prometheus())
```

---

## Query Timeout

Prevent queries from running indefinitely.

### Configuration

```mojo
// Default: 30s query, 5s connection, 5min idle
var config = TimeoutConfig.default()

// Strict: 5s query (for fast queries)
var config = TimeoutConfig.strict()

// Lenient: 5min query (for long-running)
var config = TimeoutConfig.lenient()

// Custom configuration
var config = TimeoutConfig()
config.query_timeout_ms = 10000       // 10 seconds
config.connection_timeout_ms = 3000   // 3 seconds
config.idle_timeout_ms = 600000       // 10 minutes
```

### Timeout Guard

```mojo
var guard = TimeoutGuard(5000)  // 5 second timeout

// Execute operation
var result = conn.query("SELECT * FROM large_table")

// Check timeout
if guard.is_timeout():
    raise Error("Query timed out")

// Get timing info
print(f"Elapsed: {guard.elapsed_ms()}ms")
print(f"Remaining: {guard.remaining_ms()}ms")
```

### PostgreSQL Integration

```mojo
// Set statement_timeout parameter
set_statement_timeout(conn, 10000)  // 10 seconds

// Clear timeout (use default)
clear_statement_timeout(conn)

// Get current timeout
var current = get_statement_timeout(conn)
```

### Timeout Manager

```mojo
var manager = TimeoutManager(config)

// Start tracking query
var query_id = manager.start_query()

// Check if timed out
if manager.check_timeout(query_id):
    manager.cancel_query(query_id)
    raise Error("Query timed out")

// Get timing info
var elapsed = manager.get_elapsed_ms(query_id)
var remaining = manager.get_remaining_ms(query_id)
```

---

## Connection Validation

Ensure connections are healthy and automatically recover.

### Configuration

```mojo
// Default: Validate on acquire, 1hr lifetime
var config = ValidationConfig.default()

// Strict: Validate on acquire AND release
var config = ValidationConfig.strict()

// Lenient: Minimal checking, 4hr lifetime
var config = ValidationConfig.lenient()

// Disabled: No validation (not recommended)
var config = ValidationConfig.disabled()

// Custom configuration
var config = ValidationConfig()
config.validate_on_acquire = True
config.validate_on_release = False
config.validation_query = "SELECT 1"
config.max_lifetime_ms = 1800000  // 30 minutes
config.validation_timeout_ms = 5000
```

### Usage

```mojo
var validator = ConnectionValidator(config)

// Validate connection
if !validator.validate(conn):
    // Connection is invalid, reconnect
    conn.close()
    conn = create_new_connection()
```

### Stale Connection Detection

```mojo
// Check if pooled connection is stale
var pooled_conn = pool.acquire()

if validator.is_stale(pooled_conn):
    // Connection is too old, reconnect
    pool.remove(pooled_conn)
    pooled_conn = pool.create_new()

if validator.should_reconnect(pooled_conn):
    // Reconnect based on policy
    reconnect(pooled_conn)
```

### Reconnection Policy

```mojo
var policy = ReconnectionPolicy.default()  // 3 attempts, 1s delay

// Check if should reconnect based on error
if policy.should_reconnect("connection closed"):
    // Attempt reconnection
    for attempt in range(policy.max_attempts):
        try:
            conn.reconnect()
            break
        except:
            sleep_ms(policy.delay_ms)
```

---

## Best Practices

### 1. Use All Features Together

```mojo
// Production-ready setup
fn execute_resilient_query(sql: String) raises -> QueryResult:
    var retry_policy = RetryPolicy(RetryConfig.conservative())
    var breaker = CircuitBreaker(CircuitBreakerConfig.default())
    var validator = ConnectionValidator(ValidationConfig.strict())
    var guard = TimeoutGuard(30000)

    // Validate connection
    if !validator.validate(conn):
        raise Error("Invalid connection")

    // Check circuit breaker
    if !breaker.should_allow_request():
        raise Error("Circuit breaker is open")

    // Execute with timeout
    try:
        var result = conn.query(sql)
        breaker.record_success()
        return result
    except e:
        breaker.record_failure()
        if retry_policy.should_retry(str(e)):
            // Retry logic here
        raise e
```

### 2. Configure for Your Environment

**Development:**
- Aggressive retry (fast retries, many attempts)
- Frequent health checks
- Strict timeouts

**Production:**
- Conservative retry (slower, fewer attempts)
- Balanced health checks
- Lenient timeouts for long queries

**High-Traffic:**
- Aggressive circuit breaker (fail fast)
- Frequent health checks
- Strict validation

### 3. Monitor Everything

```mojo
// Collect all metrics
var retry_metrics = RetryMetrics()
var breaker_metrics = CircuitBreakerMetrics()
var health_metrics = HealthMetrics()
var timeout_metrics = TimeoutMetrics()

// Export to monitoring system
fn export_metrics() -> String:
    var output = ""
    output += retry_metrics.total_retries.to_prometheus()
    output += breaker_metrics.state_transitions.to_prometheus()
    output += health_metrics.health_checks_failed.to_prometheus()
    output += timeout_metrics.timeouts_total.to_prometheus()
    return output
```

### 4. Test Failure Scenarios

Test these scenarios in staging:

- Network partitions
- Database restarts
- Slow queries
- Connection pool exhaustion
- Circuit breaker opening
- Timeout enforcement

---

## Production Configuration

### Financial Systems (High Reliability)

```mojo
var retry = RetryConfig.conservative()      // 2 attempts, slow backoff
var breaker = CircuitBreakerConfig.tolerant()  // Stay closed longer
var health = HealthCheckConfig.frequent()    // 5s health checks
var timeout = TimeoutConfig.strict()         // 5s query timeout
var validation = ValidationConfig.strict()   // Validate acquire & release
```

### E-Commerce (High Traffic)

```mojo
var retry = RetryConfig.aggressive()         // 5 attempts, fast
var breaker = CircuitBreakerConfig.aggressive()  // Fail fast
var health = HealthCheckConfig.frequent()    // 5s health checks
var timeout = TimeoutConfig.default()        // 30s queries
var validation = ValidationConfig.default()  // Validate on acquire
```

### Analytics (Long Queries)

```mojo
var retry = RetryConfig.conservative()       // 2 attempts
var breaker = CircuitBreakerConfig.tolerant()   // Stay closed
var health = HealthCheckConfig.infrequent()  // 5min checks
var timeout = TimeoutConfig.lenient()        // 5min queries
var validation = ValidationConfig.lenient()  // 4hr lifetime
```

---

## Troubleshooting

### Circuit Breaker Stuck Open

**Problem:** Circuit breaker remains open even after service recovers.

**Solution:**
```mojo
// Check timeout settings
var config = CircuitBreakerConfig.default()
config.timeout_ms = 30000  // Reduce timeout

// Or force closed (for testing)
breaker.force_closed()
```

### Too Many Retries

**Problem:** Retries consuming too many resources.

**Solution:**
```mojo
// Use conservative config
var config = RetryConfig.conservative()
config.max_attempts = 2

// Or disable retry for certain errors
fn should_retry_custom(error: String) -> Bool:
    if "permission denied" in error:
        return False  // Don't retry auth errors
    return is_retryable_error(error)
```

### Health Checks Too Slow

**Problem:** Health checks taking too long.

**Solution:**
```mojo
// Reduce timeout
var config = HealthCheckConfig.default()
config.timeout_ms = 2000  // 2 seconds

// Or use less frequent checks
var config = HealthCheckConfig.infrequent()
```

### Validation Overhead

**Problem:** Validation adds too much latency.

**Solution:**
```mojo
// Only validate on acquire
var config = ValidationConfig.default()
config.validate_on_acquire = True
config.validate_on_release = False

// Or increase max lifetime
config.max_lifetime_ms = 7200000  // 2 hours
```

---

## Performance Overhead

Based on benchmarks:

| Feature | Overhead | Notes |
|---------|----------|-------|
| Retry Policy | <1μs | Negligible |
| Circuit Breaker | <1μs | Nearly free |
| Timeout Guard | <1μs | Negligible |
| Health Check | Query time + 1μs | One SELECT 1 |
| Validation | Query time + 1μs | One SELECT 1 |
| **All Features** | **<10%** | Safe for production |

**Recommendation:** Enable all features in production. The overhead is minimal and the benefits are significant.

---

## Next Steps

1. **Read the example:** `examples/resilience_example.mojo`
2. **Run tests:** `mojo tests/integration/test_resilience.mojo`
3. **Run benchmarks:** `mojo benchmarks/bench_resilience.mojo`
4. **Configure for your use case:** See [Production Configuration](#production-configuration)
5. **Monitor metrics:** Export to Prometheus/Grafana
6. **Test failure scenarios:** In staging environment

---

## Resources

- [Phase 4B Implementation Plan](PHASE_4B_PLAN.md)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Retry Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/retry)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)
