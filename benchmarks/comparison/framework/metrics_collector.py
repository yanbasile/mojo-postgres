"""
Metrics Collection Utilities

Provides utilities for collecting performance metrics during benchmarks.
"""

import time
import psutil
import numpy as np
from typing import List, Dict, Any
from dataclasses import dataclass


@dataclass
class LatencyStats:
    """Latency statistics."""
    p50: float  # milliseconds
    p95: float
    p99: float
    min: float
    max: float
    mean: float
    std: float


class MetricsCollector:
    """Collects and aggregates performance metrics."""

    def __init__(self):
        self.latencies: List[float] = []  # milliseconds
        self.start_time: float = 0
        self.end_time: float = 0
        self.rows_processed: int = 0
        self.errors: int = 0
        self.process = psutil.Process()
        self.memory_samples: List[float] = []
        self.cpu_samples: List[float] = []

    def start(self):
        """Start metrics collection."""
        self.start_time = time.time()
        self.latencies = []
        self.rows_processed = 0
        self.errors = 0
        self.memory_samples = []
        self.cpu_samples = []

        # Reset CPU measurement
        self.process.cpu_percent()

    def record_operation(self, duration_ms: float, rows: int = 1):
        """Record a single operation."""
        self.latencies.append(duration_ms)
        self.rows_processed += rows

    def record_error(self):
        """Record an error."""
        self.errors += 1

    def sample_resources(self):
        """Sample current resource usage."""
        try:
            # Memory in MB
            memory_mb = self.process.memory_info().rss / 1024 / 1024
            self.memory_samples.append(memory_mb)

            # CPU percent
            cpu = self.process.cpu_percent()
            self.cpu_samples.append(cpu)
        except:
            pass

    def end(self):
        """End metrics collection."""
        self.end_time = time.time()

        # Final resource sample
        self.sample_resources()

    def get_latency_stats(self) -> LatencyStats:
        """Calculate latency statistics."""
        if not self.latencies:
            return LatencyStats(0, 0, 0, 0, 0, 0, 0)

        latencies_array = np.array(self.latencies)

        return LatencyStats(
            p50=float(np.percentile(latencies_array, 50)),
            p95=float(np.percentile(latencies_array, 95)),
            p99=float(np.percentile(latencies_array, 99)),
            min=float(np.min(latencies_array)),
            max=float(np.max(latencies_array)),
            mean=float(np.mean(latencies_array)),
            std=float(np.std(latencies_array))
        )

    def get_duration_seconds(self) -> float:
        """Get total duration in seconds."""
        return self.end_time - self.start_time

    def get_throughput(self) -> float:
        """Calculate throughput (operations per second)."""
        duration = self.get_duration_seconds()
        if duration == 0:
            return 0
        return len(self.latencies) / duration

    def get_row_throughput(self) -> float:
        """Calculate row throughput (rows per second)."""
        duration = self.get_duration_seconds()
        if duration == 0:
            return 0
        return self.rows_processed / duration

    def get_memory_usage(self) -> Dict[str, float]:
        """Get memory usage statistics (MB)."""
        if not self.memory_samples:
            return {"avg": 0, "max": 0, "min": 0}

        return {
            "avg": float(np.mean(self.memory_samples)),
            "max": float(np.max(self.memory_samples)),
            "min": float(np.min(self.memory_samples))
        }

    def get_cpu_usage(self) -> Dict[str, float]:
        """Get CPU usage statistics (percent)."""
        if not self.cpu_samples:
            return {"avg": 0, "max": 0, "min": 0}

        return {
            "avg": float(np.mean(self.cpu_samples)),
            "max": float(np.max(self.cpu_samples)),
            "min": float(np.min(self.cpu_samples))
        }

    def get_results(self) -> Dict[str, Any]:
        """Get complete results."""
        latency_stats = self.get_latency_stats()
        memory_stats = self.get_memory_usage()
        cpu_stats = self.get_cpu_usage()

        return {
            "duration_seconds": self.get_duration_seconds(),
            "throughput_ops_per_sec": self.get_throughput(),
            "throughput_rows_per_sec": self.get_row_throughput(),
            "latency_p50_ms": latency_stats.p50,
            "latency_p95_ms": latency_stats.p95,
            "latency_p99_ms": latency_stats.p99,
            "latency_min_ms": latency_stats.min,
            "latency_max_ms": latency_stats.max,
            "latency_mean_ms": latency_stats.mean,
            "latency_std_ms": latency_stats.std,
            "memory_mb": memory_stats["avg"],
            "memory_max_mb": memory_stats["max"],
            "cpu_percent": cpu_stats["avg"],
            "cpu_max_percent": cpu_stats["max"],
            "rows_processed": self.rows_processed,
            "operations": len(self.latencies),
            "errors": self.errors
        }


class Timer:
    """Context manager for timing operations."""

    def __init__(self, metrics_collector: MetricsCollector, rows: int = 1):
        self.metrics_collector = metrics_collector
        self.rows = rows
        self.start_time = 0

    def __enter__(self):
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        duration_ms = (time.time() - self.start_time) * 1000

        if exc_type is None:
            self.metrics_collector.record_operation(duration_ms, self.rows)
        else:
            self.metrics_collector.record_error()

        # Sample resources periodically (every 10th operation)
        if len(self.metrics_collector.latencies) % 10 == 0:
            self.metrics_collector.sample_resources()


def benchmark_function(func, metrics: MetricsCollector, *args, **kwargs):
    """Decorator to benchmark a function."""
    start = time.time()

    try:
        result = func(*args, **kwargs)
        duration_ms = (time.time() - start) * 1000
        metrics.record_operation(duration_ms)
        return result
    except Exception as e:
        metrics.record_error()
        raise e


# Example usage
if __name__ == "__main__":
    import random

    metrics = MetricsCollector()
    metrics.start()

    # Simulate some operations
    for i in range(1000):
        with Timer(metrics, rows=100):
            # Simulate work
            time.sleep(random.uniform(0.001, 0.01))

    metrics.end()

    results = metrics.get_results()
    print("Benchmark Results:")
    print(f"  Duration: {results['duration_seconds']:.2f}s")
    print(f"  Throughput: {results['throughput_ops_per_sec']:.0f} ops/sec")
    print(f"  Latency p95: {results['latency_p95_ms']:.2f}ms")
    print(f"  Memory: {results['memory_mb']:.1f} MB")
    print(f"  CPU: {results['cpu_percent']:.1f}%")
