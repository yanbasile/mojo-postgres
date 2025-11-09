"""
Unit tests for Metrics infrastructure.

Tests counters, gauges, histograms, and metric export.

Test Categories:
1. Counter metrics tests
2. Gauge metrics tests
3. Histogram metrics tests
4. Connection metrics tests
5. Query metrics tests
6. Prometheus export tests
7. Timer tests
"""

from testing import assert_equal, assert_true, assert_false
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


# ============================================================================
# Test 1: Counter Metrics Tests
# ============================================================================

fn test_counter_creation() raises:
    """Test 1.1: Counter creation."""
    print("  test_counter_creation...", end="")

    var counter = Counter("test_counter", "Test counter")
    assert_equal(counter.name, "test_counter")
    assert_equal(counter.help, "Test counter")
    assert_equal(counter.get(), 0.0)

    print(" ✅")


fn test_counter_inc() raises:
    """Test 1.2: Counter increment."""
    print("  test_counter_inc...", end="")

    var counter = Counter("test_counter")
    assert_equal(counter.get(), 0.0)

    counter.inc()
    assert_equal(counter.get(), 1.0)

    counter.inc()
    assert_equal(counter.get(), 2.0)

    print(" ✅")


fn test_counter_add() raises:
    """Test 1.3: Counter add."""
    print("  test_counter_add...", end="")

    var counter = Counter("test_counter")

    counter.add(5.0)
    assert_equal(counter.get(), 5.0)

    counter.add(3.5)
    assert_equal(counter.get(), 8.5)

    print(" ✅")


fn test_counter_negative_ignored() raises:
    """Test 1.4: Counter ignores negative values."""
    print("  test_counter_negative_ignored...", end="")

    var counter = Counter("test_counter")
    counter.add(10.0)

    # Try to add negative (should be ignored)
    counter.add(-5.0)
    assert_equal(counter.get(), 10.0)

    print(" ✅")


fn test_counter_reset() raises:
    """Test 1.5: Counter reset."""
    print("  test_counter_reset...", end="")

    var counter = Counter("test_counter")
    counter.add(100.0)
    assert_equal(counter.get(), 100.0)

    counter.reset()
    assert_equal(counter.get(), 0.0)

    print(" ✅")


# ============================================================================
# Test 2: Gauge Metrics Tests
# ============================================================================

fn test_gauge_creation() raises:
    """Test 2.1: Gauge creation."""
    print("  test_gauge_creation...", end="")

    var gauge = Gauge("test_gauge", "Test gauge")
    assert_equal(gauge.name, "test_gauge")
    assert_equal(gauge.get(), 0.0)

    print(" ✅")


fn test_gauge_set() raises:
    """Test 2.2: Gauge set."""
    print("  test_gauge_set...", end="")

    var gauge = Gauge("test_gauge")

    gauge.set(10.0)
    assert_equal(gauge.get(), 10.0)

    gauge.set(5.0)
    assert_equal(gauge.get(), 5.0)

    print(" ✅")


fn test_gauge_inc_dec() raises:
    """Test 2.3: Gauge increment and decrement."""
    print("  test_gauge_inc_dec...", end="")

    var gauge = Gauge("test_gauge")

    gauge.inc()
    assert_equal(gauge.get(), 1.0)

    gauge.inc()
    assert_equal(gauge.get(), 2.0)

    gauge.dec()
    assert_equal(gauge.get(), 1.0)

    print(" ✅")


fn test_gauge_add_sub() raises:
    """Test 2.4: Gauge add and subtract."""
    print("  test_gauge_add_sub...", end="")

    var gauge = Gauge("test_gauge")
    gauge.set(10.0)

    gauge.add(5.0)
    assert_equal(gauge.get(), 15.0)

    gauge.sub(3.0)
    assert_equal(gauge.get(), 12.0)

    print(" ✅")


fn test_gauge_negative_values() raises:
    """Test 2.5: Gauge can go negative."""
    print("  test_gauge_negative_values...", end="")

    var gauge = Gauge("test_gauge")

    gauge.sub(5.0)
    assert_equal(gauge.get(), -5.0)

    print(" ✅")


# ============================================================================
# Test 3: Histogram Metrics Tests
# ============================================================================

fn test_histogram_creation() raises:
    """Test 3.1: Histogram creation."""
    print("  test_histogram_creation...", end="")

    var hist = Histogram("test_hist", "Test histogram")
    assert_equal(hist.name, "test_hist")
    assert_equal(hist.get_count(), 0)
    assert_equal(hist.get_sum(), 0.0)

    print(" ✅")


fn test_histogram_observe() raises:
    """Test 3.2: Histogram observe."""
    print("  test_histogram_observe...", end="")

    var hist = Histogram("test_hist")

    hist.observe(10.0)
    assert_equal(hist.get_count(), 1)
    assert_equal(hist.get_sum(), 10.0)

    hist.observe(20.0)
    assert_equal(hist.get_count(), 2)
    assert_equal(hist.get_sum(), 30.0)

    print(" ✅")


fn test_histogram_average() raises:
    """Test 3.3: Histogram average."""
    print("  test_histogram_average...", end="")

    var hist = Histogram("test_hist")

    hist.observe(10.0)
    hist.observe(20.0)
    hist.observe(30.0)

    assert_equal(hist.get_average(), 20.0)

    print(" ✅")


fn test_histogram_empty_average() raises:
    """Test 3.4: Histogram empty average."""
    print("  test_histogram_empty_average...", end="")

    var hist = Histogram("test_hist")
    assert_equal(hist.get_average(), 0.0)

    print(" ✅")


# ============================================================================
# Test 4: Connection Metrics Tests
# ============================================================================

fn test_connection_metrics_creation() raises:
    """Test 4.1: Connection metrics creation."""
    print("  test_connection_metrics_creation...", end="")

    var metrics = ConnectionMetrics()

    assert_equal(metrics.active_connections.get(), 0.0)
    assert_equal(metrics.idle_connections.get(), 0.0)
    assert_equal(metrics.total_connections.get(), 0.0)

    print(" ✅")


fn test_connection_metrics_tracking() raises:
    """Test 4.2: Connection metrics tracking."""
    print("  test_connection_metrics_tracking...", end="")

    var metrics = ConnectionMetrics()

    # Create connections
    metrics.total_connections.inc()
    metrics.total_connections.inc()
    assert_equal(metrics.total_connections.get(), 2.0)

    # Set active/idle
    metrics.active_connections.set(1.0)
    metrics.idle_connections.set(1.0)

    assert_equal(metrics.active_connections.get(), 1.0)
    assert_equal(metrics.idle_connections.get(), 1.0)

    print(" ✅")


fn test_connection_metrics_checkouts() raises:
    """Test 4.3: Connection checkout metrics."""
    print("  test_connection_metrics_checkouts...", end="")

    var metrics = ConnectionMetrics()

    metrics.checkout_count.inc()
    metrics.checkout_duration.observe(5.5)

    assert_equal(metrics.checkout_count.get(), 1.0)
    assert_equal(metrics.checkout_duration.get_count(), 1)

    print(" ✅")


# ============================================================================
# Test 5: Query Metrics Tests
# ============================================================================

fn test_query_metrics_creation() raises:
    """Test 5.1: Query metrics creation."""
    print("  test_query_metrics_creation...", end="")

    var metrics = QueryMetrics()

    assert_equal(metrics.query_count.get(), 0.0)
    assert_equal(metrics.error_count.get(), 0.0)

    print(" ✅")


fn test_query_metrics_tracking() raises:
    """Test 5.2: Query metrics tracking."""
    print("  test_query_metrics_tracking...", end="")

    var metrics = QueryMetrics()

    # Execute queries
    metrics.query_count.inc()
    metrics.query_duration.observe(15.5)
    metrics.rows_affected.add(10.0)

    assert_equal(metrics.query_count.get(), 1.0)
    assert_equal(metrics.rows_affected.get(), 10.0)

    print(" ✅")


fn test_query_metrics_slow_queries() raises:
    """Test 5.3: Slow query tracking."""
    print("  test_query_metrics_slow_queries...", end="")

    var metrics = QueryMetrics()

    metrics.slow_query_count.inc()
    assert_equal(metrics.slow_query_count.get(), 1.0)

    print(" ✅")


# ============================================================================
# Test 6: Prometheus Export Tests
# ============================================================================

fn test_counter_prometheus_export() raises:
    """Test 6.1: Counter Prometheus export."""
    print("  test_counter_prometheus_export...", end="")

    var counter = Counter("test_counter", "Test counter")
    counter.add(42.0)

    var prom = counter.to_prometheus()
    assert_true("# HELP test_counter" in prom)
    assert_true("# TYPE test_counter counter" in prom)
    assert_true("test_counter 42" in prom)

    print(" ✅")


fn test_gauge_prometheus_export() raises:
    """Test 6.2: Gauge Prometheus export."""
    print("  test_gauge_prometheus_export...", end="")

    var gauge = Gauge("test_gauge", "Test gauge")
    gauge.set(10.5)

    var prom = gauge.to_prometheus()
    assert_true("# TYPE test_gauge gauge" in prom)
    assert_true("test_gauge 10.5" in prom)

    print(" ✅")


fn test_histogram_prometheus_export() raises:
    """Test 6.3: Histogram Prometheus export."""
    print("  test_histogram_prometheus_export...", end="")

    var hist = Histogram("test_hist", "Test histogram")
    hist.observe(5.0)
    hist.observe(15.0)

    var prom = hist.to_prometheus()
    assert_true("# TYPE test_hist histogram" in prom)
    assert_true("_bucket" in prom)
    assert_true("_sum" in prom)
    assert_true("_count" in prom)

    print(" ✅")


# ============================================================================
# Test 7: Timer Tests
# ============================================================================

fn test_timer_basic() raises:
    """Test 7.1: Basic timer functionality."""
    print("  test_timer_basic...", end="")

    var start = start_timer()

    # Do some work (simulate)
    var sum: Int = 0
    for i in range(1000):
        sum += i

    var duration_ms = stop_timer(start)

    # Duration should be positive
    assert_true(duration_ms >= 0.0)

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Metrics Infrastructure Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: Counter Metrics Tests")
    test_counter_creation()
    test_counter_inc()
    test_counter_add()
    test_counter_negative_ignored()
    test_counter_reset()

    print("\nTest 2: Gauge Metrics Tests")
    test_gauge_creation()
    test_gauge_set()
    test_gauge_inc_dec()
    test_gauge_add_sub()
    test_gauge_negative_values()

    print("\nTest 3: Histogram Metrics Tests")
    test_histogram_creation()
    test_histogram_observe()
    test_histogram_average()
    test_histogram_empty_average()

    print("\nTest 4: Connection Metrics Tests")
    test_connection_metrics_creation()
    test_connection_metrics_tracking()
    test_connection_metrics_checkouts()

    print("\nTest 5: Query Metrics Tests")
    test_query_metrics_creation()
    test_query_metrics_tracking()
    test_query_metrics_slow_queries()

    print("\nTest 6: Prometheus Export Tests")
    test_counter_prometheus_export()
    test_gauge_prometheus_export()
    test_histogram_prometheus_export()

    print("\nTest 7: Timer Tests")
    test_timer_basic()

    print("\n" + "=" * 70)
    print("✅ All 25 tests passed!")
    print("=" * 70 + "\n")
