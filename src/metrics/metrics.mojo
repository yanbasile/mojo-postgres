"""
Metrics and Monitoring Infrastructure for mojo-postgres.

Provides metrics collection for observability and monitoring.

Metric Types:
- Counter: Monotonically increasing value (requests, errors)
- Gauge: Value that can increase or decrease (connections, memory)
- Histogram: Distribution of values (query duration, response size)

Features:
- Connection pool metrics
- Query performance metrics
- Error rate tracking
- Prometheus-compatible export
- Custom metrics support
- Real-time monitoring

Usage:
    from src.metrics import MetricsCollector, Counter, Gauge

    var metrics = MetricsCollector.get()
    var requests = metrics.counter("requests_total", "Total requests")
    requests.inc()

    var active_conns = metrics.gauge("connections_active", "Active connections")
    active_conns.set(10)
"""

from collections import List
from time import now


# ============================================================================
# Metric Value Types
# ============================================================================

@value
struct MetricValue:
    """
    Holds a metric value with timestamp.

    Attributes:
        value: The metric value
        timestamp: When the value was recorded (nanoseconds)
    """
    var value: Float64
    var timestamp: Int


# ============================================================================
# Counter Metric
# ============================================================================

struct Counter:
    """
    Counter metric - monotonically increasing value.

    Used for:
    - Request count
    - Error count
    - Query count
    - Bytes transferred

    Example:
        var counter = Counter("requests_total")
        counter.inc()
        counter.add(5)
    """
    var name: String
    var help: String
    var value: Float64
    var labels: List[String]  # Alternating keys and values

    fn __init__(inout self, name: String, help: String = ""):
        """Initialize counter."""
        self.name = name
        self.help = help
        self.value = 0.0
        self.labels = List[String]()

    fn inc(inout self):
        """Increment counter by 1."""
        self.value += 1.0

    fn add(inout self, amount: Float64):
        """Add amount to counter."""
        if amount >= 0:
            self.value += amount

    fn get(self) -> Float64:
        """Get current counter value."""
        return self.value

    fn reset(inout self):
        """Reset counter to zero."""
        self.value = 0.0

    fn with_labels(inout self, *label_pairs: String):
        """Add labels to counter."""
        for i in range(len(label_pairs)):
            self.labels.append(label_pairs[i])

    fn to_prometheus(self) -> String:
        """Export in Prometheus format."""
        var result = ""

        # Help text
        if self.help != "":
            result += "# HELP " + self.name + " " + self.help + "\n"

        # Type
        result += "# TYPE " + self.name + " counter\n"

        # Value with labels
        result += self.name
        if len(self.labels) > 0:
            result += "{"
            var i = 0
            while i < len(self.labels) - 1:
                if i > 0:
                    result += ","
                result += self.labels[i] + "=\"" + self.labels[i + 1] + "\""
                i += 2
            result += "}"
        result += " " + String(self.value) + "\n"

        return result


# ============================================================================
# Gauge Metric
# ============================================================================

struct Gauge:
    """
    Gauge metric - value that can increase or decrease.

    Used for:
    - Active connections
    - Memory usage
    - Queue depth
    - Temperature

    Example:
        var gauge = Gauge("connections_active")
        gauge.set(10)
        gauge.inc()
        gauge.dec()
    """
    var name: String
    var help: String
    var value: Float64
    var labels: List[String]

    fn __init__(inout self, name: String, help: String = ""):
        """Initialize gauge."""
        self.name = name
        self.help = help
        self.value = 0.0
        self.labels = List[String]()

    fn set(inout self, value: Float64):
        """Set gauge to specific value."""
        self.value = value

    fn inc(inout self):
        """Increment gauge by 1."""
        self.value += 1.0

    fn dec(inout self):
        """Decrement gauge by 1."""
        self.value -= 1.0

    fn add(inout self, amount: Float64):
        """Add amount to gauge."""
        self.value += amount

    fn sub(inout self, amount: Float64):
        """Subtract amount from gauge."""
        self.value -= amount

    fn get(self) -> Float64:
        """Get current gauge value."""
        return self.value

    fn with_labels(inout self, *label_pairs: String):
        """Add labels to gauge."""
        for i in range(len(label_pairs)):
            self.labels.append(label_pairs[i])

    fn to_prometheus(self) -> String:
        """Export in Prometheus format."""
        var result = ""

        if self.help != "":
            result += "# HELP " + self.name + " " + self.help + "\n"

        result += "# TYPE " + self.name + " gauge\n"

        result += self.name
        if len(self.labels) > 0:
            result += "{"
            var i = 0
            while i < len(self.labels) - 1:
                if i > 0:
                    result += ","
                result += self.labels[i] + "=\"" + self.labels[i + 1] + "\""
                i += 2
            result += "}"
        result += " " + String(self.value) + "\n"

        return result


# ============================================================================
# Histogram Metric
# ============================================================================

struct Histogram:
    """
    Histogram metric - distribution of values.

    Used for:
    - Request duration
    - Response size
    - Query execution time

    Buckets: 0.001, 0.01, 0.1, 1, 10, 100 (seconds or milliseconds)

    Example:
        var hist = Histogram("query_duration_ms")
        hist.observe(15.5)
        hist.observe(250.0)
    """
    var name: String
    var help: String
    var buckets: List[Float64]
    var bucket_counts: List[Int]
    var sum: Float64
    var count: Int
    var labels: List[String]

    fn __init__(inout self, name: String, help: String = ""):
        """Initialize histogram with default buckets."""
        self.name = name
        self.help = help
        self.buckets = List[Float64]()
        self.bucket_counts = List[Int]()
        self.sum = 0.0
        self.count = 0
        self.labels = List[String]()

        # Default buckets (milliseconds): 1, 10, 50, 100, 500, 1000, 5000
        self.buckets.append(1.0)
        self.buckets.append(10.0)
        self.buckets.append(50.0)
        self.buckets.append(100.0)
        self.buckets.append(500.0)
        self.buckets.append(1000.0)
        self.buckets.append(5000.0)

        # Initialize bucket counts
        for i in range(len(self.buckets)):
            self.bucket_counts.append(0)

    fn observe(inout self, value: Float64):
        """Record an observation."""
        self.sum += value
        self.count += 1

        # Increment bucket counts
        for i in range(len(self.buckets)):
            if value <= self.buckets[i]:
                self.bucket_counts[i] += 1

    fn get_count(self) -> Int:
        """Get total observation count."""
        return self.count

    fn get_sum(self) -> Float64:
        """Get sum of all observations."""
        return self.sum

    fn get_average(self) -> Float64:
        """Get average of observations."""
        if self.count == 0:
            return 0.0
        return self.sum / Float64(self.count)

    fn with_labels(inout self, *label_pairs: String):
        """Add labels to histogram."""
        for i in range(len(label_pairs)):
            self.labels.append(label_pairs[i])

    fn to_prometheus(self) -> String:
        """Export in Prometheus format."""
        var result = ""

        if self.help != "":
            result += "# HELP " + self.name + " " + self.help + "\n"

        result += "# TYPE " + self.name + " histogram\n"

        # Buckets
        for i in range(len(self.buckets)):
            result += self.name + "_bucket{le=\"" + String(self.buckets[i]) + "\"} " + String(self.bucket_counts[i]) + "\n"

        # +Inf bucket
        result += self.name + "_bucket{le=\"+Inf\"} " + String(self.count) + "\n"

        # Sum
        result += self.name + "_sum " + String(self.sum) + "\n"

        # Count
        result += self.name + "_count " + String(self.count) + "\n"

        return result


# ============================================================================
# Metrics Collector
# ============================================================================

struct MetricsCollector:
    """
    Central metrics collector for all metrics.

    Manages:
    - Counter metrics
    - Gauge metrics
    - Histogram metrics
    - Metric export

    Example:
        var collector = MetricsCollector.get()
        var requests = collector.counter("requests")
        requests.inc()
    """
    var counters: List[Counter]
    var gauges: List[Gauge]
    var histograms: List[Histogram]

    fn __init__(inout self):
        """Initialize metrics collector."""
        self.counters = List[Counter]()
        self.gauges = List[Gauge]()
        self.histograms = List[Histogram]()

    @staticmethod
    fn get() -> MetricsCollector:
        """Get metrics collector instance."""
        return MetricsCollector()

    fn counter(inout self, name: String, help: String = "") -> Counter:
        """Get or create counter metric."""
        # In a real implementation, would check if counter exists
        var counter = Counter(name, help)
        self.counters.append(counter)
        return counter

    fn gauge(inout self, name: String, help: String = "") -> Gauge:
        """Get or create gauge metric."""
        var gauge = Gauge(name, help)
        self.gauges.append(gauge)
        return gauge

    fn histogram(inout self, name: String, help: String = "") -> Histogram:
        """Get or create histogram metric."""
        var hist = Histogram(name, help)
        self.histograms.append(hist)
        return hist

    fn export_prometheus(self) -> String:
        """Export all metrics in Prometheus format."""
        var result = ""

        for i in range(len(self.counters)):
            result += self.counters[i].to_prometheus() + "\n"

        for i in range(len(self.gauges)):
            result += self.gauges[i].to_prometheus() + "\n"

        for i in range(len(self.histograms)):
            result += self.histograms[i].to_prometheus() + "\n"

        return result


# ============================================================================
# PostgreSQL-specific Metrics
# ============================================================================

struct ConnectionMetrics:
    """
    Metrics for connection pooling.

    Tracks:
    - Active connections
    - Idle connections
    - Total connections created
    - Connection checkouts
    - Connection timeouts
    - Connection errors

    Example:
        var metrics = ConnectionMetrics()
        metrics.active_connections.set(10)
        metrics.checkout_count.inc()
    """
    var active_connections: Gauge
    var idle_connections: Gauge
    var total_connections: Counter
    var checkout_count: Counter
    var checkout_duration: Histogram
    var timeout_count: Counter
    var error_count: Counter

    fn __init__(inout self):
        """Initialize connection metrics."""
        self.active_connections = Gauge("postgres_connections_active", "Active connections")
        self.idle_connections = Gauge("postgres_connections_idle", "Idle connections")
        self.total_connections = Counter("postgres_connections_total", "Total connections created")
        self.checkout_count = Counter("postgres_checkouts_total", "Connection checkout count")
        self.checkout_duration = Histogram("postgres_checkout_duration_ms", "Connection checkout duration")
        self.timeout_count = Counter("postgres_checkout_timeouts_total", "Checkout timeout count")
        self.error_count = Counter("postgres_connection_errors_total", "Connection error count")


struct QueryMetrics:
    """
    Metrics for query execution.

    Tracks:
    - Query count by type (SELECT, INSERT, UPDATE, DELETE)
    - Query duration
    - Rows affected
    - Query errors
    - Slow queries

    Example:
        var metrics = QueryMetrics()
        metrics.query_count.inc()
        metrics.query_duration.observe(15.5)
    """
    var query_count: Counter
    var query_duration: Histogram
    var rows_affected: Counter
    var error_count: Counter
    var slow_query_count: Counter

    fn __init__(inout self):
        """Initialize query metrics."""
        self.query_count = Counter("postgres_queries_total", "Total queries executed")
        self.query_duration = Histogram("postgres_query_duration_ms", "Query execution duration")
        self.rows_affected = Counter("postgres_rows_affected_total", "Total rows affected")
        self.error_count = Counter("postgres_query_errors_total", "Query error count")
        self.slow_query_count = Counter("postgres_slow_queries_total", "Slow query count")


# ============================================================================
# Helper Functions
# ============================================================================

fn start_timer() -> Int:
    """
    Start a timer for measuring duration.

    Returns:
        Start timestamp in nanoseconds

    Example:
        var start = start_timer()
        # ... do work ...
        var duration_ms = stop_timer(start)
    """
    return now()


fn stop_timer(start: Int) -> Float64:
    """
    Stop timer and calculate duration in milliseconds.

    Args:
        start: Start timestamp from start_timer()

    Returns:
        Duration in milliseconds

    Example:
        var duration_ms = stop_timer(start)
        histogram.observe(duration_ms)
    """
    var end = now()
    var duration_ns = end - start
    return Float64(duration_ns) / 1_000_000.0  # Convert to milliseconds
