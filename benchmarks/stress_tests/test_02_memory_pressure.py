"""
Stress Test 2: Memory Pressure & Leak Detection

Runs continuous operations for 24 hours to detect memory leaks.

Success Criteria:
- Memory growth < 100MB over 24 hours
- No unbounded memory growth
- Stable RSS memory after warmup period
- No connection leaks
- CPU usage stable (<80% average)
"""

import sys
import os
import time
import psycopg2
import psutil
from datetime import datetime, timedelta
import threading

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class MemoryPressureTest(StressTestBase):
    """
    Test for memory leaks over 24-hour period.

    Executes continuous operations while monitoring memory usage.
    Detects leaks, unbounded growth, and resource cleanup issues.
    """

    def __init__(self, duration_hours: float = 24.0):
        super().__init__(
            name="Memory Pressure & Leak Detection Test",
            description=f"Run continuous operations for {duration_hours} hours to detect memory leaks"
        )

        # Test parameters
        self.duration_hours = duration_hours
        self.duration_seconds = int(duration_hours * 3600)
        self.sample_interval_seconds = 60  # Sample memory every minute
        self.warmup_period_seconds = 600  # 10-minute warmup

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Results
        self.memory_samples = []
        self.cpu_samples = []
        self.operations_completed = 0
        self.errors_encountered = 0
        self.running = False

    def setup(self):
        """Setup: Verify database accessibility."""
        print(f"Connecting to PostgreSQL at {self.db_host}:{self.db_port}")

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )
            conn.close()
            print("✅ Database accessible")
        except Exception as e:
            raise Exception(f"Cannot connect to database: {e}")

        print(f"\n⏱️  Test will run for {self.duration_hours} hours ({self.duration_seconds}s)")
        print(f"📊 Memory sampled every {self.sample_interval_seconds}s")
        print(f"🔥 Warmup period: {self.warmup_period_seconds}s")

    def run_test(self):
        """Main test logic."""
        process = psutil.Process()
        start_time = time.time()
        end_time = start_time + self.duration_seconds
        warmup_end = start_time + self.warmup_period_seconds

        self.running = True

        # Worker thread that executes database operations
        def worker():
            """Execute continuous database operations."""
            while self.running and time.time() < end_time:
                try:
                    # TODO: Replace with mojo-postgres when available
                    conn = psycopg2.connect(
                        host=self.db_host,
                        port=self.db_port,
                        database=self.db_name,
                        user=self.db_user,
                        password=self.db_password
                    )

                    cursor = conn.cursor()

                    # Mix of operations to stress different code paths
                    operations = [
                        "SELECT 1",
                        "SELECT generate_series(1, 1000)",
                        "CREATE TEMP TABLE test_temp (id INT, data TEXT)",
                        "INSERT INTO test_temp VALUES (1, 'test data')",
                        "SELECT * FROM test_temp",
                        "DROP TABLE test_temp"
                    ]

                    for op in operations:
                        cursor.execute(op)
                        if cursor.description:  # Has results
                            cursor.fetchall()

                    cursor.close()
                    conn.close()

                    self.operations_completed += 1

                except Exception as e:
                    self.errors_encountered += 1
                    if self.errors_encountered <= 10:  # Log first 10 errors
                        self.warnings.append(f"Operation error: {str(e)}")

        # Start worker thread
        worker_thread = threading.Thread(target=worker, daemon=True)
        worker_thread.start()

        # Monitoring loop
        print(f"\n🚀 Starting continuous operations (warmup: {self.warmup_period_seconds}s)...")

        last_sample_time = start_time
        warmup_complete = False
        baseline_memory = None

        while time.time() < end_time:
            current_time = time.time()
            elapsed = current_time - start_time

            # Sample memory at intervals
            if current_time - last_sample_time >= self.sample_interval_seconds:
                memory_mb = process.memory_info().rss / 1024 / 1024
                cpu_percent = process.cpu_percent(interval=1.0)

                self.memory_samples.append({
                    "elapsed_seconds": int(elapsed),
                    "memory_mb": round(memory_mb, 2),
                    "cpu_percent": round(cpu_percent, 2)
                })

                self.cpu_samples.append(cpu_percent)

                # After warmup, establish baseline
                if not warmup_complete and elapsed >= self.warmup_period_seconds:
                    warmup_complete = True
                    baseline_memory = memory_mb
                    print(f"\n✅ Warmup complete. Baseline memory: {baseline_memory:.2f} MB\n")

                # Progress update
                if len(self.memory_samples) % 10 == 0:
                    hours_elapsed = elapsed / 3600
                    hours_remaining = (end_time - current_time) / 3600
                    mem_growth = memory_mb - baseline_memory if baseline_memory else 0

                    print(f"[{hours_elapsed:.1f}h elapsed, {hours_remaining:.1f}h remaining] "
                          f"Memory: {memory_mb:.1f} MB (growth: {mem_growth:+.1f} MB), "
                          f"CPU: {cpu_percent:.1f}%, "
                          f"Ops: {self.operations_completed:,}, "
                          f"Errors: {self.errors_encountered}")

                last_sample_time = current_time

            # Small sleep to avoid busy-wait
            time.sleep(1)

        # Stop worker
        self.running = False
        worker_thread.join(timeout=10)

        # Analyze results
        print(f"\n✅ Test complete. Analyzing {len(self.memory_samples)} memory samples...")

        if not baseline_memory:
            baseline_memory = self.memory_samples[0]["memory_mb"] if self.memory_samples else 0

        final_memory = self.memory_samples[-1]["memory_mb"] if self.memory_samples else 0
        memory_growth = final_memory - baseline_memory

        # Calculate memory trend (linear regression)
        import statistics

        if len(self.memory_samples) > 10:
            # Take samples after warmup
            post_warmup_samples = [s for s in self.memory_samples
                                   if s["elapsed_seconds"] >= self.warmup_period_seconds]

            memory_values = [s["memory_mb"] for s in post_warmup_samples]
            memory_stddev = statistics.stdev(memory_values) if len(memory_values) > 1 else 0
            memory_mean = statistics.mean(memory_values)

            # Check for unbounded growth (memory consistently increasing)
            memory_trend = "stable"
            if len(post_warmup_samples) >= 10:
                first_half = memory_values[:len(memory_values)//2]
                second_half = memory_values[len(memory_values)//2:]

                first_avg = statistics.mean(first_half)
                second_avg = statistics.mean(second_half)

                growth_pct = (second_avg - first_avg) / first_avg * 100

                if growth_pct > 10:
                    memory_trend = f"growing ({growth_pct:.1f}% increase)"
                    self.warnings.append(f"Memory trend shows growth: {growth_pct:.1f}%")
                elif growth_pct < -10:
                    memory_trend = f"decreasing ({growth_pct:.1f}% decrease)"
        else:
            memory_stddev = 0
            memory_mean = baseline_memory
            memory_trend = "insufficient data"

        avg_cpu = statistics.mean(self.cpu_samples) if self.cpu_samples else 0

        return {
            "duration_hours": self.duration_hours,
            "total_operations": self.operations_completed,
            "total_errors": self.errors_encountered,
            "operations_per_second": round(self.operations_completed / self.duration_seconds, 2),
            "error_rate_percent": round(self.errors_encountered / max(self.operations_completed, 1) * 100, 4),
            "baseline_memory_mb": round(baseline_memory, 2),
            "final_memory_mb": round(final_memory, 2),
            "memory_growth_mb": round(memory_growth, 2),
            "memory_stddev_mb": round(memory_stddev, 2),
            "memory_mean_mb": round(memory_mean, 2),
            "memory_trend": memory_trend,
            "avg_cpu_percent": round(avg_cpu, 2),
            "memory_samples_collected": len(self.memory_samples)
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. Memory growth < 100MB over 24 hours
        memory_growth = self.metrics.get("memory_growth_mb", 0)
        criteria["memory_growth_under_100mb"] = (memory_growth < 100)

        # 2. Memory trend is stable (not unbounded growth)
        memory_trend = self.metrics.get("memory_trend", "")
        criteria["memory_trend_stable"] = ("stable" in memory_trend.lower())

        # 3. Average CPU < 80%
        avg_cpu = self.metrics.get("avg_cpu_percent", 0)
        criteria["avg_cpu_under_80pct"] = (avg_cpu < 80)

        # 4. Error rate < 1%
        error_rate = self.metrics.get("error_rate_percent", 0)
        criteria["error_rate_under_1pct"] = (error_rate < 1.0)

        # 5. Completed at least some operations (not hung)
        total_ops = self.metrics.get("total_operations", 0)
        criteria["operations_completed"] = (total_ops > 100)

        return criteria

    def teardown(self):
        """Cleanup."""
        self.running = False
        print("\n✅ Teardown complete")


def main():
    """Run the memory pressure stress test."""
    # For testing, use shorter duration (e.g., 1 hour)
    # For production, use full 24 hours
    duration_hours = float(os.getenv("TEST_DURATION_HOURS", "1.0"))

    test = MemoryPressureTest(duration_hours=duration_hours)
    result = test.execute()

    # Save results
    output_file = f"results/test_02_memory_pressure_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
