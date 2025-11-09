"""
DevOps/SRE Monitoring Data Generator

Generates realistic operational monitoring data:
- Application logs (INFO, WARN, ERROR, CRITICAL)
- System metrics (CPU, memory, disk, network)
- Service health checks
- Error bursts and cascading failures
- Container/pod metrics
- Distributed service monitoring
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class LogLevel(Enum):
    """Log severity levels."""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class ServiceStatus(Enum):
    """Service health status."""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    DOWN = "down"


@dataclass
class LogEntry:
    """Single log entry."""
    time: datetime
    service_name: str
    hostname: str
    pod_id: str
    log_level: str
    message: str
    request_id: Optional[str]
    user_id: Optional[int]
    response_time_ms: Optional[float]
    status_code: Optional[int]
    error_type: Optional[str]


@dataclass
class SystemMetric:
    """Single system metric."""
    time: datetime
    hostname: str
    pod_id: str
    service_name: str
    cpu_percent: float
    memory_percent: float
    memory_used_gb: float
    disk_io_read_mb: float
    disk_io_write_mb: float
    network_in_mb: float
    network_out_mb: float
    open_connections: int
    request_rate: float  # requests/sec


class DevOpsDataGenerator:
    """
    Generates realistic DevOps monitoring data.

    Features:
    - 1000+ microservices
    - Realistic log level distribution (70% INFO, 20% WARN, 8% ERROR, 2% CRITICAL)
    - Error bursts (cascading failures)
    - Correlated logs and metrics
    - Service degradation patterns
    - Container lifecycle (startup, running, restart, crash)
    - Request tracing with request IDs
    - Circadian patterns (higher load during business hours)
    """

    def __init__(self, seed: int = 42, num_services: int = 1000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_services = num_services

        # Service types
        self.service_types = [
            "api-gateway", "auth-service", "user-service", "order-service",
            "payment-service", "inventory-service", "notification-service",
            "search-service", "recommendation-service", "analytics-service"
        ]

        # Generate services
        self.services = self._generate_services()

        # Error burst tracking
        self.error_burst_active = False
        self.error_burst_end_time = None
        self.error_burst_services = []

        # Request ID counter
        self.request_counter = 0

        # Common error messages
        self.error_messages = {
            "connection_timeout": "Database connection timeout after 30s",
            "rate_limit": "Rate limit exceeded: 1000 req/min",
            "auth_failed": "Authentication failed: invalid token",
            "not_found": "Resource not found",
            "internal_error": "Internal server error",
            "circuit_breaker": "Circuit breaker OPEN: downstream service unavailable",
            "memory_error": "Out of memory error",
            "disk_full": "Disk space full: cannot write logs"
        }

        print(f"Initialized DevOpsDataGenerator with {num_services:,} services")

    def _generate_services(self) -> List[Dict]:
        """Generate service metadata."""
        services = []

        for i in range(self.num_services):
            service_type = random.choice(self.service_types)
            service_name = f"{service_type}-{i % 100:03d}"

            # Hostname (multiple replicas per service)
            hostname = f"k8s-node-{random.randint(1, 50):03d}"

            # Pod ID
            pod_id = f"pod-{service_name}-{random.randint(1000, 9999)}"

            services.append({
                "name": service_name,
                "type": service_type,
                "hostname": hostname,
                "pod_id": pod_id
            })

        print(f"Generated {len(services)} service instances")
        return services

    def _get_time_multiplier(self, current_time: datetime) -> float:
        """
        Calculate load multiplier based on time of day.

        Higher during business hours (9am-5pm).
        """
        hour = current_time.hour

        if 9 <= hour < 17:  # Business hours
            return random.uniform(2.0, 3.0)
        elif 0 <= hour < 6:  # Night
            return random.uniform(0.3, 0.5)
        else:
            return random.uniform(0.8, 1.2)

    def _should_start_error_burst(self) -> bool:
        """Determine if error burst should start (1% chance)."""
        return random.random() < 0.01

    def _select_log_level(self, in_error_burst: bool = False) -> str:
        """
        Select log level with realistic distribution.

        Normal distribution:
        - 70% INFO
        - 20% WARN
        - 8% ERROR
        - 2% CRITICAL

        During error burst:
        - 20% INFO
        - 30% WARN
        - 40% ERROR
        - 10% CRITICAL
        """
        if in_error_burst:
            levels = [LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR, LogLevel.CRITICAL]
            weights = [0.20, 0.30, 0.40, 0.10]
        else:
            levels = [LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR, LogLevel.CRITICAL]
            weights = [0.70, 0.20, 0.08, 0.02]

        return random.choices(levels, weights=weights)[0].value

    def _generate_log_message(self, log_level: str, service: Dict) -> Tuple[str, Optional[str]]:
        """
        Generate log message based on level.

        Returns:
            (message, error_type)
        """
        if log_level == LogLevel.INFO.value:
            messages = [
                f"Request processed successfully",
                f"Health check passed",
                f"Cache hit for key",
                f"Connected to database",
                f"User authenticated",
                f"Job completed successfully"
            ]
            return (random.choice(messages), None)

        elif log_level == LogLevel.WARN.value:
            messages = [
                f"High latency detected: >500ms",
                f"Cache miss for key",
                f"Retry attempt 2/3",
                f"Deprecated API endpoint used",
                f"Memory usage above 80%",
                f"Connection pool exhausted"
            ]
            return (random.choice(messages), None)

        elif log_level == LogLevel.ERROR.value:
            error_types = list(self.error_messages.keys())
            error_type = random.choice(error_types)
            message = self.error_messages[error_type]
            return (message, error_type)

        else:  # CRITICAL
            error_types = ["memory_error", "disk_full", "circuit_breaker"]
            error_type = random.choice(error_types)
            message = self.error_messages[error_type]
            return (message, error_type)

    def _generate_request_id(self) -> str:
        """Generate unique request ID."""
        self.request_counter += 1
        return f"req_{self.request_counter:016d}"

    def _generate_response_time(self, log_level: str) -> Optional[float]:
        """
        Generate response time (only for request logs).

        Errors have longer response times (timeouts).
        """
        if log_level in [LogLevel.INFO.value, LogLevel.WARN.value]:
            # Normal response time (log-normal distribution)
            return max(np.random.lognormal(4.5, 0.8), 1.0)  # Mean ~100ms
        elif log_level == LogLevel.ERROR.value:
            # Errors often timeout
            if random.random() < 0.5:
                return random.uniform(5000, 30000)  # 5-30 seconds
            else:
                return max(np.random.lognormal(5.5, 0.8), 1.0)  # Mean ~300ms
        else:
            return None

    def _generate_status_code(self, log_level: str) -> Optional[int]:
        """Generate HTTP status code."""
        if log_level == LogLevel.INFO.value:
            return random.choice([200, 201, 204])
        elif log_level == LogLevel.WARN.value:
            return random.choice([200, 201, 429])  # Some rate limits
        elif log_level == LogLevel.ERROR.value:
            return random.choice([400, 401, 404, 500, 502, 503, 504])
        else:
            return random.choice([500, 502, 503])

    def _generate_system_metrics(self, service: Dict, current_time: datetime,
                                 in_error_burst: bool = False) -> SystemMetric:
        """
        Generate system metrics for service.

        Args:
            service: Service metadata
            current_time: Current timestamp
            in_error_burst: Whether in error burst

        Returns:
            SystemMetric object
        """
        # Base metrics
        cpu_percent = random.uniform(10, 60)
        memory_percent = random.uniform(30, 70)
        memory_used_gb = random.uniform(1.0, 8.0)

        # Disk I/O
        disk_io_read_mb = random.uniform(0.1, 10.0)
        disk_io_write_mb = random.uniform(0.1, 5.0)

        # Network I/O
        network_in_mb = random.uniform(0.5, 20.0)
        network_out_mb = random.uniform(0.5, 15.0)

        # Connections
        open_connections = random.randint(10, 500)

        # Request rate
        time_mult = self._get_time_multiplier(current_time)
        request_rate = random.uniform(10, 100) * time_mult

        # During error burst, increase resource usage
        if in_error_burst:
            cpu_percent *= random.uniform(1.5, 3.0)
            memory_percent *= random.uniform(1.3, 2.0)
            open_connections = int(open_connections * random.uniform(2.0, 5.0))

        # Clamp values
        cpu_percent = min(cpu_percent, 100)
        memory_percent = min(memory_percent, 100)

        return SystemMetric(
            time=current_time,
            hostname=service["hostname"],
            pod_id=service["pod_id"],
            service_name=service["name"],
            cpu_percent=round(cpu_percent, 2),
            memory_percent=round(memory_percent, 2),
            memory_used_gb=round(memory_used_gb, 2),
            disk_io_read_mb=round(disk_io_read_mb, 2),
            disk_io_write_mb=round(disk_io_write_mb, 2),
            network_in_mb=round(network_in_mb, 2),
            network_out_mb=round(network_out_mb, 2),
            open_connections=open_connections,
            request_rate=round(request_rate, 2)
        )

    def generate_logs(self, duration_seconds: int = 3600,
                     logs_per_second: int = 1000) -> Iterator[LogEntry]:
        """
        Generate log stream.

        Args:
            duration_seconds: How long to generate data for
            logs_per_second: Average logs per second

        Yields:
            LogEntry objects
        """
        start_time = datetime.now()
        current_time = start_time

        total_logs = duration_seconds * logs_per_second

        print(f"Generating ~{total_logs:,} log entries...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Rate: {logs_per_second:,} logs/sec")

        logs_generated = 0

        for _ in range(duration_seconds):
            current_time += timedelta(seconds=1)

            # Check for error burst
            if not self.error_burst_active:
                if self._should_start_error_burst():
                    # Start error burst
                    self.error_burst_active = True
                    self.error_burst_end_time = current_time + timedelta(
                        seconds=random.randint(30, 300)  # 30s - 5min
                    )
                    # Select 5-20% of services for error burst
                    num_burst_services = int(len(self.services) * random.uniform(0.05, 0.20))
                    self.error_burst_services = random.sample(self.services, num_burst_services)
            else:
                # Check if error burst ended
                if current_time > self.error_burst_end_time:
                    self.error_burst_active = False
                    self.error_burst_services = []

            # Generate logs for this second
            logs_this_second = int(logs_per_second * random.uniform(0.8, 1.2))

            for _ in range(logs_this_second):
                # Select service
                service = random.choice(self.services)

                # Check if service in error burst
                in_error_burst = self.error_burst_active and service in self.error_burst_services

                # Generate log level
                log_level = self._select_log_level(in_error_burst)

                # Generate message
                message, error_type = self._generate_log_message(log_level, service)

                # Generate request ID (70% of logs have request ID)
                request_id = self._generate_request_id() if random.random() < 0.7 else None

                # Generate user ID (50% of logs have user ID)
                user_id = random.randint(1, 1000000) if random.random() < 0.5 else None

                # Generate response time
                response_time = self._generate_response_time(log_level)

                # Generate status code
                status_code = self._generate_status_code(log_level)

                yield LogEntry(
                    time=current_time,
                    service_name=service["name"],
                    hostname=service["hostname"],
                    pod_id=service["pod_id"],
                    log_level=log_level,
                    message=message,
                    request_id=request_id,
                    user_id=user_id,
                    response_time_ms=response_time,
                    status_code=status_code,
                    error_type=error_type
                )

                logs_generated += 1

            # Progress update
            if logs_generated % 1_000_000 == 0:
                print(f"  Generated {logs_generated:,} logs...")

        print(f"✅ Generated {logs_generated:,} logs")

    def generate_metrics(self, duration_seconds: int = 3600,
                        metric_frequency_sec: int = 60) -> Iterator[SystemMetric]:
        """
        Generate system metrics stream.

        Args:
            duration_seconds: How long to generate data for
            metric_frequency_sec: How often each service reports metrics

        Yields:
            SystemMetric objects
        """
        start_time = datetime.now()
        current_time = start_time

        num_intervals = duration_seconds // metric_frequency_sec
        total_metrics = len(self.services) * num_intervals

        print(f"Generating {total_metrics:,} system metrics...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Services: {len(self.services):,}")
        print(f"  Frequency: {metric_frequency_sec}s")

        metrics_generated = 0

        for _ in range(num_intervals):
            current_time += timedelta(seconds=metric_frequency_sec)

            # Generate metric for each service
            for service in self.services:
                # Check if service in error burst
                in_error_burst = (self.error_burst_active and
                                service in self.error_burst_services)

                metric = self._generate_system_metrics(service, current_time, in_error_burst)

                yield metric
                metrics_generated += 1

            # Progress update
            if metrics_generated % 1_000_000 == 0:
                print(f"  Generated {metrics_generated:,} metrics...")

        print(f"✅ Generated {metrics_generated:,} metrics")

    def generate_dataset(self, size: str = "small", data_type: str = "logs") -> List:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)
            data_type: 'logs' or 'metrics'

        Returns:
            List of LogEntry or SystemMetric objects
        """
        if data_type == "logs":
            # Calculate parameters based on size
            if size == "small":
                duration_seconds = 1000
                logs_per_second = 1000
            elif size == "medium":
                duration_seconds = 100000
                logs_per_second = 1000
            elif size == "large":
                duration_seconds = 1000000
                logs_per_second = 1000
            else:
                raise ValueError(f"Unknown size: {size}")

            data = list(self.generate_logs(
                duration_seconds=duration_seconds,
                logs_per_second=logs_per_second
            ))
        else:  # metrics
            if size == "small":
                duration_seconds = 60000  # 1M metrics with 1K services
                metric_frequency_sec = 60
            elif size == "medium":
                duration_seconds = 6000000
                metric_frequency_sec = 60
            elif size == "large":
                duration_seconds = 60000000
                metric_frequency_sec = 60
            else:
                raise ValueError(f"Unknown size: {size}")

            data = list(self.generate_metrics(
                duration_seconds=duration_seconds,
                metric_frequency_sec=metric_frequency_sec
            ))

        return data


def main():
    """Example usage and testing."""
    generator = DevOpsDataGenerator(seed=42, num_services=100)

    # Generate 5 minutes of logs
    print("\nGenerating sample DevOps logs...")
    logs = list(generator.generate_logs(duration_seconds=300, logs_per_second=100))

    print(f"\n✅ Generated {len(logs):,} logs")
    print("\nSample logs (first 20):")

    for i, log in enumerate(logs[:20]):
        req_id = log.request_id[:12] if log.request_id else "N/A        "
        resp = f"{log.response_time_ms:6.0f}ms" if log.response_time_ms else "      "
        status = f"{log.status_code}" if log.status_code else "   "

        print(f"  {i+1}. {log.time.strftime('%H:%M:%S')} | {log.log_level:8s} | "
              f"{log.service_name[:20]:20s} | {req_id} | "
              f"{status:3s} {resp} | {log.message[:40]}")

    # Statistics
    from collections import Counter

    print("\nLog Level Distribution:")
    level_counts = Counter(l.log_level for l in logs)
    for level, count in level_counts.most_common():
        print(f"  {level:10s}: {count:6d} ({count/len(logs)*100:5.1f}%)")

    print("\nError Type Distribution:")
    errors = [l for l in logs if l.error_type]
    if errors:
        error_counts = Counter(l.error_type for l in errors)
        for error_type, count in error_counts.most_common():
            print(f"  {error_type:20s}: {count:5d}")

    print("\nResponse Time Statistics:")
    response_times = [l.response_time_ms for l in logs if l.response_time_ms]
    if response_times:
        print(f"  p50: {np.percentile(response_times, 50):.0f}ms")
        print(f"  p95: {np.percentile(response_times, 95):.0f}ms")
        print(f"  p99: {np.percentile(response_times, 99):.0f}ms")
        print(f"  max: {max(response_times):.0f}ms")

    print("\nStatus Code Distribution:")
    status_codes = Counter(l.status_code for l in logs if l.status_code)
    for status, count in sorted(status_codes.items()):
        marker = "✅" if status < 400 else "❌"
        print(f"  {marker} {status}: {count:5d}")

    # Generate system metrics
    print("\n\nGenerating sample system metrics...")
    metrics = list(generator.generate_metrics(duration_seconds=300, metric_frequency_sec=60))

    print(f"\n✅ Generated {len(metrics):,} metrics")
    print("\nSample metrics (first 10):")

    for i, metric in enumerate(metrics[:10]):
        print(f"  {i+1}. {metric.time.strftime('%H:%M:%S')} | "
              f"{metric.service_name[:20]:20s} | "
              f"CPU:{metric.cpu_percent:5.1f}% | MEM:{metric.memory_percent:5.1f}% | "
              f"Conns:{metric.open_connections:4d} | Rate:{metric.request_rate:6.1f} req/s")

    print("\nSystem Metrics Statistics:")
    print(f"  Avg CPU: {np.mean([m.cpu_percent for m in metrics]):.1f}%")
    print(f"  Avg Memory: {np.mean([m.memory_percent for m in metrics]):.1f}%")
    print(f"  Avg Connections: {np.mean([m.open_connections for m in metrics]):.0f}")
    print(f"  Avg Request Rate: {np.mean([m.request_rate for m in metrics]):.1f} req/s")


if __name__ == "__main__":
    main()
