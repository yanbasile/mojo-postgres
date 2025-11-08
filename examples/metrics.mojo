"""
Metrics and Monitoring Examples.

Demonstrates metrics collection for observability and monitoring.

Features:
- Counter metrics (monotonically increasing)
- Gauge metrics (can increase or decrease)
- Histogram metrics (distribution tracking)
- Connection pool metrics
- Query performance metrics
- Prometheus export format

Examples:
1. Basic counter metrics
2. Gauge metrics for tracking values
3. Histogram for distributions
4. Connection pool metrics
5. Query performance metrics
6. Prometheus export
7. Custom metrics

Prerequisites:
- None (metrics are standalone)
"""

from src.metrics.metrics import (
    Counter,
    Gauge,
    Histogram,
    MetricsCollector,
    ConnectionMetrics,
    QueryMetrics,
    start_timer,
    stop_timer,
)


fn example1_counter_metrics() raises:
    """Example 1: Counter metrics."""
    print("=" * 70)
    print("Example 1: Counter Metrics")
    print("=" * 70)

    print("\n📊 Counter metrics (monotonically increasing):\n")

    var requests = Counter("http_requests_total", "Total HTTP requests")

    print("Initial value:", requests.get())

    # Increment by 1
    requests.inc()
    print("After inc():", requests.get())

    # Add specific amount
    requests.add(5.0)
    print("After add(5):", requests.get())

    # Multiple increments
    for i in range(10):
        requests.inc()
    print("After 10 more increments:", requests.get())

    print("\n✅ Example 1 complete!\n")


fn example2_gauge_metrics() raises:
    """Example 2: Gauge metrics."""
    print("=" * 70)
    print("Example 2: Gauge Metrics")
    print("=" * 70)

    print("\n📈 Gauge metrics (can increase or decrease):\n")

    var active_connections = Gauge("connections_active", "Active database connections")

    print("Initial value:", active_connections.get())

    # Set to specific value
    active_connections.set(10.0)
    print("Set to 10:", active_connections.get())

    # Increment
    active_connections.inc()
    print("After inc():", active_connections.get())

    # Decrement
    active_connections.dec()
    active_connections.dec()
    print("After 2x dec():", active_connections.get())

    # Add and subtract
    active_connections.add(5.0)
    print("After add(5):", active_connections.get())

    active_connections.sub(3.0)
    print("After sub(3):", active_connections.get())

    print("\n✅ Example 2 complete!\n")


fn example3_histogram_metrics() raises:
    """Example 3: Histogram metrics."""
    print("=" * 70)
    print("Example 3: Histogram Metrics")
    print("=" * 70)

    print("\n📊 Histogram metrics (distribution tracking):\n")

    var query_duration = Histogram("query_duration_ms", "Query execution duration")

    print("Recording observations:")

    # Record various query durations
    var durations = List[Float64]()
    durations.append(5.0)
    durations.append(15.0)
    durations.append(25.0)
    durations.append(50.0)
    durations.append(100.0)
    durations.append(250.0)
    durations.append(500.0)
    durations.append(1500.0)

    for i in range(len(durations)):
        query_duration.observe(durations[i])
        print(f"  Observed: {durations[i]}ms")

    print(f"\nStatistics:")
    print(f"  Count: {query_duration.get_count()}")
    print(f"  Sum: {query_duration.get_sum()}ms")
    print(f"  Average: {query_duration.get_average():.2f}ms")

    print("\n✅ Example 3 complete!\n")


fn example4_connection_pool_metrics() raises:
    """Example 4: Connection pool metrics."""
    print("=" * 70)
    print("Example 4: Connection Pool Metrics")
    print("=" * 70)

    print("\n🔗 Connection pool metrics:\n")

    var metrics = ConnectionMetrics()

    # Simulate connection pool activity
    print("Simulating connection pool activity:")

    # Create connections
    metrics.total_connections.inc()
    metrics.total_connections.inc()
    metrics.total_connections.inc()
    print(f"  Total connections created: {metrics.total_connections.get()}")

    # Set active and idle
    metrics.active_connections.set(2.0)
    metrics.idle_connections.set(1.0)
    print(f"  Active connections: {metrics.active_connections.get()}")
    print(f"  Idle connections: {metrics.idle_connections.get()}")

    # Track checkouts
    metrics.checkout_count.inc()
    metrics.checkout_duration.observe(5.5)
    print(f"  Checkout count: {metrics.checkout_count.get()}")

    # Simulate timeout
    metrics.timeout_count.inc()
    print(f"  Timeout count: {metrics.timeout_count.get()}")

    # Simulate error
    metrics.error_count.inc()
    print(f"  Error count: {metrics.error_count.get()}")

    print("\n✅ Example 4 complete!\n")


fn example5_query_performance_metrics() raises:
    """Example 5: Query performance metrics."""
    print("=" * 70)
    print("Example 5: Query Performance Metrics")
    print("=" * 70)

    print("\n⚡ Query performance metrics:\n")

    var metrics = QueryMetrics()

    # Simulate query execution
    print("Simulating query execution:")

    # Fast query
    metrics.query_count.inc()
    metrics.query_duration.observe(15.5)
    metrics.rows_affected.add(1.0)
    print("  Fast query: 15.5ms, 1 row")

    # Medium query
    metrics.query_count.inc()
    metrics.query_duration.observe(50.0)
    metrics.rows_affected.add(100.0)
    print("  Medium query: 50ms, 100 rows")

    # Slow query
    metrics.query_count.inc()
    metrics.query_duration.observe(250.0)
    metrics.rows_affected.add(5000.0)
    metrics.slow_query_count.inc()
    print("  Slow query: 250ms, 5000 rows")

    # Query error
    metrics.error_count.inc()
    print("  Query error")

    print(f"\nStatistics:")
    print(f"  Total queries: {metrics.query_count.get()}")
    print(f"  Average duration: {metrics.query_duration.get_average():.2f}ms")
    print(f"  Total rows: {metrics.rows_affected.get()}")
    print(f"  Slow queries: {metrics.slow_query_count.get()}")
    print(f"  Errors: {metrics.error_count.get()}")

    print("\n✅ Example 5 complete!\n")


fn example6_prometheus_export() raises:
    """Example 6: Prometheus export format."""
    print("=" * 70)
    print("Example 6: Prometheus Export")
    print("=" * 70)

    print("\n📤 Exporting metrics in Prometheus format:\n")

    # Create some metrics
    var requests = Counter("http_requests_total", "Total HTTP requests")
    requests.add(100.0)

    var active = Gauge("connections_active", "Active connections")
    active.set(5.0)

    var duration = Histogram("request_duration_ms", "Request duration")
    duration.observe(10.0)
    duration.observe(25.0)
    duration.observe(100.0)

    # Export to Prometheus format
    print("Counter export:")
    print(requests.to_prometheus())

    print("Gauge export:")
    print(active.to_prometheus())

    print("Histogram export:")
    print(duration.to_prometheus())

    print("✅ Example 6 complete!\n")


fn example7_custom_metrics() raises:
    """Example 7: Custom metrics with labels."""
    print("=" * 70)
    print("Example 7: Custom Metrics with Labels")
    print("=" * 70)

    print("\n🏷️  Custom metrics with labels:\n")

    # Counter with labels
    var requests = Counter("api_requests_total", "API requests by method and endpoint")
    requests.with_labels("method", "POST", "endpoint", "/api/users")
    requests.add(50.0)

    print("Counter with labels:")
    print(requests.to_prometheus())

    # Gauge with labels
    var queue_size = Gauge("queue_depth", "Queue depth by queue name")
    queue_size.with_labels("queue", "tasks")
    queue_size.set(125.0)

    print("Gauge with labels:")
    print(queue_size.to_prometheus())

    print("✅ Example 7 complete!\n")


fn example8_timing_operations() raises:
    """Example 8: Timing operations."""
    print("=" * 70)
    print("Example 8: Timing Operations")
    print("=" * 70)

    print("\n⏱️  Timing operations with start_timer/stop_timer:\n")

    var duration_hist = Histogram("operation_duration_ms", "Operation duration")

    # Simulate some operations
    for i in range(5):
        var start = start_timer()

        # Simulate work (in real code, this would be actual work)
        var dummy_sum: Int = 0
        for j in range(1000):
            dummy_sum += j

        var duration_ms = stop_timer(start)
        duration_hist.observe(duration_ms)

        print(f"  Operation {i+1}: {duration_ms:.3f}ms")

    print(f"\nStatistics:")
    print(f"  Count: {duration_hist.get_count()}")
    print(f"  Average: {duration_hist.get_average():.3f}ms")

    print("\n✅ Example 8 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 Metrics and Monitoring Examples")
    print("Observability for Production Applications")
    print("\n")

    # Run examples
    example1_counter_metrics()
    example2_gauge_metrics()
    example3_histogram_metrics()
    example4_connection_pool_metrics()
    example5_query_performance_metrics()
    example6_prometheus_export()
    example7_custom_metrics()
    example8_timing_operations()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - Counter: For monotonically increasing values (requests, errors)")
    print("   - Gauge: For values that go up and down (connections, memory)")
    print("   - Histogram: For distributions (latency, size)")
    print("   - Labels: Add dimensions to metrics (method, endpoint, status)")
    print("   - Prometheus: Standard export format for monitoring")
    print("\n💡 Integration:")
    print("   - Export metrics to Prometheus")
    print("   - Visualize in Grafana")
    print("   - Set up alerts (Alertmanager)")
    print("   - Monitor pool health, query performance, errors")
    print("\n💡 Production Monitoring:")
    print("   - Track connection pool utilization")
    print("   - Monitor query latency percentiles (p50, p95, p99)")
    print("   - Alert on error rate spikes")
    print("   - Track slow query count")
    print("\n")
