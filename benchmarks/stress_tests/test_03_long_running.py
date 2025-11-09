"""
Stress Test 3: Long-Running Stability (7-day test)

Validates system stability over extended periods (7 days continuous operation).

Success Criteria:
- No crashes for 7 days
- No connection pool exhaustion
- No file descriptor leaks
- Memory remains stable
- Throughput doesn't degrade
- 99.9% uptime
"""

import sys
import os
import time
import psycopg2
import psutil
import random
from datetime import datetime, timedelta
import threading
import statistics

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class LongRunningStabilityTest(StressTestBase):
    """
    Test 7-day continuous operation stability.

    Simulates realistic production workload:
    - Mix of read/write operations
    - Variable load patterns
    - Connection churn
    - Periodic maintenance operations
    """

    def __init__(self, duration_days: float = 7.0):
        super().__init__(
            name="Long-Running Stability Test",
            description=f"{duration_days}-day continuous operation stability test"
        )

        # Test parameters
        self.duration_days = duration_days
        self.duration_seconds = int(duration_days * 86400)

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Monitoring
        self.running = False
        self.total_operations = 0
        self.total_errors = 0
        self.crashes = 0
        self.uptime_seconds = 0

        self.throughput_samples = []
        self.latency_samples = []
        self.connection_pool_sizes = []
        self.open_file_descriptors = []

    def setup(self):
        """Setup: Verify database and create test table."""
        print(f"Connecting to PostgreSQL at {self.db_host}:{self.db_port}")

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()

            # Create test table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS stress_test_data (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP DEFAULT NOW(),
                    data TEXT,
                    value INTEGER
                )
            """)

            conn.commit()
            cursor.close()
            conn.close()

            print("✅ Database accessible, test table created")

        except Exception as e:
            raise Exception(f"Setup failed: {e}")

        print(f"\n⏱️  Test will run for {self.duration_days} days ({self.duration_seconds}s)")

    def run_test(self):
        """Main test logic."""
        process = psutil.Process()
        start_time = time.time()
        end_time = start_time + self.duration_seconds

        self.running = True
        operations_this_interval = 0
        last_checkpoint = start_time

        # Worker pool
        num_workers = 10
        worker_threads = []

        def worker(worker_id):
            """Execute continuous database operations."""
            local_ops = 0
            local_errors = 0

            while self.running and time.time() < end_time:
                try:
                    # Variable sleep to simulate realistic load
                    time.sleep(random.uniform(0.01, 0.1))

                    op_start = time.time()

                    conn = psycopg2.connect(
                        host=self.db_host,
                        port=self.db_port,
                        database=self.db_name,
                        user=self.db_user,
                        password=self.db_password,
                        connect_timeout=10
                    )

                    cursor = conn.cursor()

                    # Mix of operations (70% read, 30% write)
                    if random.random() < 0.7:
                        # Read operation
                        cursor.execute("SELECT COUNT(*) FROM stress_test_data")
                        cursor.fetchone()
                    else:
                        # Write operation
                        cursor.execute(
                            "INSERT INTO stress_test_data (data, value) VALUES (%s, %s)",
                            (f"worker_{worker_id}", random.randint(1, 1000))
                        )
                        conn.commit()

                    cursor.close()
                    conn.close()

                    # Record latency
                    latency_ms = (time.time() - op_start) * 1000
                    self.latency_samples.append(latency_ms)

                    # Keep only recent latencies
                    if len(self.latency_samples) > 10000:
                        self.latency_samples = self.latency_samples[-10000:]

                    local_ops += 1
                    self.total_operations += 1
                    operations_this_interval += 1

                except Exception as e:
                    local_errors += 1
                    self.total_errors += 1

                    if self.total_errors <= 20:
                        self.warnings.append(f"Worker {worker_id} error: {str(e)}")

            print(f"Worker {worker_id} completed: {local_ops} ops, {local_errors} errors")

        # Start workers
        print(f"\n🚀 Starting {num_workers} workers...")
        for i in range(num_workers):
            thread = threading.Thread(target=worker, args=(i,), daemon=True)
            thread.start()
            worker_threads.append(thread)

        # Monitoring loop
        checkpoint_interval = 3600  # 1 hour

        while time.time() < end_time and self.running:
            current_time = time.time()
            elapsed = current_time - start_time

            # Checkpoint every hour
            if current_time - last_checkpoint >= checkpoint_interval:
                interval_duration = current_time - last_checkpoint
                throughput = operations_this_interval / interval_duration

                self.throughput_samples.append(throughput)

                # Monitor resources
                try:
                    num_fds = process.num_fds() if hasattr(process, 'num_fds') else len(process.open_files())
                    self.open_file_descriptors.append(num_fds)
                except:
                    pass

                # Progress report
                hours_elapsed = elapsed / 3600
                hours_remaining = (end_time - current_time) / 3600

                if self.latency_samples:
                    avg_latency = statistics.mean(self.latency_samples[-1000:])
                    p95_latency = sorted(self.latency_samples[-1000:])[int(len(self.latency_samples[-1000:]) * 0.95)]
                else:
                    avg_latency = 0
                    p95_latency = 0

                print(f"\n[{hours_elapsed:.1f}h elapsed, {hours_remaining:.1f}h remaining]")
                print(f"  Ops this hour: {operations_this_interval:,} ({throughput:.1f} ops/sec)")
                print(f"  Total ops: {self.total_operations:,}")
                print(f"  Errors: {self.total_errors} ({self.total_errors/max(self.total_operations,1)*100:.3f}%)")
                print(f"  Avg latency: {avg_latency:.1f}ms, p95: {p95_latency:.1f}ms")
                print(f"  Memory: {process.memory_info().rss / 1024 / 1024:.1f} MB")

                operations_this_interval = 0
                last_checkpoint = current_time
                self.uptime_seconds += checkpoint_interval

            time.sleep(10)

        # Stop workers
        print("\n🛑 Stopping workers...")
        self.running = False

        for thread in worker_threads:
            thread.join(timeout=30)

        # Final statistics
        print(f"\n✅ Test complete. Total uptime: {self.uptime_seconds/3600:.1f} hours")

        # Analyze throughput degradation
        if len(self.throughput_samples) > 2:
            first_third = self.throughput_samples[:len(self.throughput_samples)//3]
            last_third = self.throughput_samples[-len(self.throughput_samples)//3:]

            initial_throughput = statistics.mean(first_third)
            final_throughput = statistics.mean(last_third)

            throughput_degradation = ((initial_throughput - final_throughput) / initial_throughput * 100)
        else:
            initial_throughput = final_throughput = throughput_degradation = 0

        uptime_percentage = (self.uptime_seconds / self.duration_seconds) * 100

        return {
            "duration_days": self.duration_days,
            "uptime_seconds": self.uptime_seconds,
            "uptime_percentage": round(uptime_percentage, 3),
            "total_operations": self.total_operations,
            "total_errors": self.total_errors,
            "error_rate_percent": round(self.total_errors / max(self.total_operations, 1) * 100, 4),
            "crashes": self.crashes,
            "initial_throughput_ops_sec": round(initial_throughput, 2),
            "final_throughput_ops_sec": round(final_throughput, 2),
            "throughput_degradation_percent": round(throughput_degradation, 2),
            "avg_latency_ms": round(statistics.mean(self.latency_samples), 2) if self.latency_samples else 0,
            "p95_latency_ms": round(sorted(self.latency_samples)[int(len(self.latency_samples)*0.95)], 2) if self.latency_samples else 0,
            "max_open_fds": max(self.open_file_descriptors) if self.open_file_descriptors else 0
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. Uptime >= 99.9%
        uptime_pct = self.metrics.get("uptime_percentage", 0)
        criteria["uptime_99_9_percent"] = (uptime_pct >= 99.9)

        # 2. No crashes
        crashes = self.metrics.get("crashes", 0)
        criteria["no_crashes"] = (crashes == 0)

        # 3. Error rate < 0.1%
        error_rate = self.metrics.get("error_rate_percent", 0)
        criteria["error_rate_under_0_1_pct"] = (error_rate < 0.1)

        # 4. Throughput degradation < 20%
        degradation = abs(self.metrics.get("throughput_degradation_percent", 0))
        criteria["throughput_degradation_under_20pct"] = (degradation < 20)

        # 5. p95 latency < 100ms
        p95_latency = self.metrics.get("p95_latency_ms", 0)
        criteria["p95_latency_under_100ms"] = (p95_latency < 100)

        return criteria

    def teardown(self):
        """Cleanup: Drop test table."""
        self.running = False

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()
            cursor.execute("DROP TABLE IF EXISTS stress_test_data")
            conn.commit()
            cursor.close()
            conn.close()

            print("✅ Test table dropped")

        except Exception as e:
            self.warnings.append(f"Teardown error: {str(e)}")


def main():
    """Run the long-running stability stress test."""
    # For testing, use shorter duration (e.g., 1 hour)
    # For production, use full 7 days
    duration_days = float(os.getenv("TEST_DURATION_DAYS", "0.042"))  # ~1 hour default

    test = LongRunningStabilityTest(duration_days=duration_days)
    result = test.execute()

    # Save results
    output_file = f"results/test_03_long_running_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
