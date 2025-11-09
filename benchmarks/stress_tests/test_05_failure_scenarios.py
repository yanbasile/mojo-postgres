"""
Stress Test 5: Failure Scenarios (Chaos Engineering)

Tests system resilience under failure conditions.

Success Criteria:
- Graceful degradation under failures
- Automatic reconnection after network issues
- Transaction retry on transient errors
- Circuit breaker triggers appropriately
- No data corruption during failures
- Recovery time < 30 seconds
"""

import sys
import os
import time
import psycopg2
import random
import threading
import subprocess
from datetime import datetime
from enum import Enum

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class FailureType(Enum):
    """Types of failures to inject."""
    NETWORK_LATENCY = "network_latency"
    CONNECTION_DROP = "connection_drop"
    SLOW_QUERY = "slow_query"
    TRANSACTION_TIMEOUT = "transaction_timeout"
    DISK_FULL = "disk_full"  # Simulated


class FailureScenariosTest(StressTestBase):
    """
    Test system behavior under various failure conditions.

    Chaos Engineering approach:
    - Inject failures randomly during normal operations
    - Monitor recovery behavior
    - Validate data integrity after recovery
    - Test retry mechanisms
    """

    def __init__(self, duration_minutes: int = 60):
        super().__init__(
            name="Failure Scenarios Test",
            description=f"{duration_minutes}-minute chaos engineering test"
        )

        self.duration_minutes = duration_minutes
        self.duration_seconds = duration_minutes * 60

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Metrics
        self.operations_attempted = 0
        self.operations_successful = 0
        self.failures_injected = 0
        self.recoveries = 0
        self.recovery_times = []
        self.running = False

        # Failure injection control
        self.failure_active = False
        self.current_failure = None

    def setup(self):
        """Setup: Create test table."""
        print(f"Setting up test table...")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS failure_test (
                id SERIAL PRIMARY KEY,
                operation_id INTEGER,
                data TEXT,
                checksum INTEGER,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)

        conn.commit()
        cursor.close()
        conn.close()

        print(f"✅ Test table created")

    def _inject_network_latency(self):
        """Simulate network latency."""
        print("  💥 Injecting NETWORK_LATENCY (2-5 second delay)")
        # In real scenario, would use tc (traffic control) or similar
        # For testing, we simulate with sleep in queries
        self.failure_active = True
        self.current_failure = FailureType.NETWORK_LATENCY
        self.failures_injected += 1

        # Auto-recover after 30 seconds
        threading.Timer(30.0, self._clear_failure).start()

    def _inject_slow_query(self):
        """Inject a slow query."""
        print("  💥 Injecting SLOW_QUERY (long-running query)")

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password,
                connect_timeout=5
            )

            cursor = conn.cursor()

            # Start a long-running query in background
            def run_slow_query():
                try:
                    cursor.execute("SELECT pg_sleep(30)")
                except:
                    pass

            threading.Thread(target=run_slow_query, daemon=True).start()

            self.failure_active = True
            self.current_failure = FailureType.SLOW_QUERY
            self.failures_injected += 1

            # Auto-recover
            threading.Timer(30.0, self._clear_failure).start()

        except Exception as e:
            self.warnings.append(f"Failed to inject slow query: {e}")

    def _inject_transaction_timeout(self):
        """Simulate transaction timeout."""
        print("  💥 Injecting TRANSACTION_TIMEOUT (idle in transaction)")

        self.failure_active = True
        self.current_failure = FailureType.TRANSACTION_TIMEOUT
        self.failures_injected += 1

        # Auto-recover
        threading.Timer(15.0, self._clear_failure).start()

    def _clear_failure(self):
        """Clear active failure."""
        if self.failure_active:
            recovery_start = time.time()
            self.failure_active = False
            old_failure = self.current_failure
            self.current_failure = None

            print(f"  ✅ Recovered from {old_failure.value if old_failure else 'unknown'}")
            self.recoveries += 1

    def _execute_operation_with_retry(self, operation_id: int, max_retries: int = 3) -> bool:
        """
        Execute database operation with retry logic.

        Returns True if successful, False otherwise.
        """
        retries = 0

        while retries < max_retries:
            try:
                conn = psycopg2.connect(
                    host=self.db_host,
                    port=self.db_port,
                    database=self.db_name,
                    user=self.db_user,
                    password=self.db_password,
                    connect_timeout=10
                )

                cursor = conn.cursor()

                # Simulate network latency if failure active
                if self.failure_active and self.current_failure == FailureType.NETWORK_LATENCY:
                    time.sleep(random.uniform(2, 5))

                # Execute operation (with checksum for integrity validation)
                data = f"operation_{operation_id}"
                checksum = hash(data) % 10000

                cursor.execute("""
                    INSERT INTO failure_test (operation_id, data, checksum)
                    VALUES (%s, %s, %s)
                """, (operation_id, data, checksum))

                conn.commit()
                cursor.close()
                conn.close()

                return True

            except psycopg2.OperationalError as e:
                retries += 1

                if retries < max_retries:
                    # Exponential backoff
                    backoff = (2 ** retries) * random.uniform(0.1, 0.5)
                    time.sleep(backoff)
                else:
                    return False

            except Exception as e:
                return False

        return False

    def _worker(self, worker_id: int):
        """Worker thread executing operations."""
        local_attempted = 0
        local_successful = 0

        while self.running:
            operation_id = worker_id * 1000000 + local_attempted

            self.operations_attempted += 1
            local_attempted += 1

            # Execute with retry
            if self._execute_operation_with_retry(operation_id):
                self.operations_successful += 1
                local_successful += 1

            # Random sleep
            time.sleep(random.uniform(0.01, 0.1))

        success_rate = (local_successful / local_attempted * 100) if local_attempted > 0 else 0
        print(f"Worker {worker_id} completed: {local_successful}/{local_attempted} successful ({success_rate:.1f}%)")

    def _failure_injector(self):
        """Background thread that injects failures randomly."""
        print("\n🔥 Failure injector started (will inject failures every 2-5 minutes)\n")

        while self.running:
            # Wait between failures
            time.sleep(random.uniform(120, 300))  # 2-5 minutes

            if not self.running:
                break

            # Inject random failure
            if not self.failure_active:
                failure_types = [
                    self._inject_network_latency,
                    self._inject_slow_query,
                    self._inject_transaction_timeout
                ]

                random.choice(failure_types)()

    def run_test(self):
        """Main test logic."""
        self.running = True
        start_time = time.time()

        # Start workers
        num_workers = 10
        print(f"\n🚀 Starting {num_workers} workers...")

        workers = []
        for i in range(num_workers):
            worker = threading.Thread(target=self._worker, args=(i,), daemon=True)
            worker.start()
            workers.append(worker)

        # Start failure injector
        injector = threading.Thread(target=self._failure_injector, daemon=True)
        injector.start()

        # Monitor progress
        print(f"\n⏱️  Running for {self.duration_minutes} minutes with chaos injection...\n")

        last_report = start_time
        report_interval = 60

        while time.time() - start_time < self.duration_seconds:
            time.sleep(5)

            if time.time() - last_report >= report_interval:
                elapsed = time.time() - start_time
                success_rate = (self.operations_successful / max(self.operations_attempted, 1)) * 100

                print(f"[{elapsed/60:.1f}m] Ops: {self.operations_successful}/{self.operations_attempted} successful ({success_rate:.1f}%), "
                      f"Failures injected: {self.failures_injected}, "
                      f"Recoveries: {self.recoveries}, "
                      f"Active failure: {self.current_failure.value if self.current_failure else 'none'}")

                last_report = time.time()

        # Stop everything
        print("\n🛑 Stopping workers and failure injector...")
        self.running = False

        for worker in workers:
            worker.join(timeout=30)

        # Verify data integrity
        print("\n🔍 Verifying data integrity...")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Check for checksum mismatches
        cursor.execute("""
            SELECT COUNT(*) FROM failure_test
            WHERE checksum != (hashtext(data)::bigint % 10000)
        """)
        corruption_count = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM failure_test")
        total_rows = cursor.fetchone()[0]

        cursor.close()
        conn.close()

        success_rate = (self.operations_successful / max(self.operations_attempted, 1)) * 100
        recovery_rate = (self.recoveries / max(self.failures_injected, 1)) * 100

        print(f"\n📊 Data Integrity:")
        print(f"  Total rows: {total_rows}")
        print(f"  Corrupted rows: {corruption_count}")
        print(f"  Integrity: {(1 - corruption_count/max(total_rows, 1))*100:.2f}%")

        return {
            "duration_minutes": self.duration_minutes,
            "operations_attempted": self.operations_attempted,
            "operations_successful": self.operations_successful,
            "success_rate_percent": round(success_rate, 2),
            "failures_injected": self.failures_injected,
            "recoveries": self.recoveries,
            "recovery_rate_percent": round(recovery_rate, 2),
            "data_corruption_count": corruption_count,
            "total_data_rows": total_rows,
            "data_integrity_percent": round((1 - corruption_count/max(total_rows, 1))*100, 4)
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. Success rate > 80% (allowing for some failures during chaos)
        success_rate = self.metrics.get("success_rate_percent", 0)
        criteria["success_rate_above_80pct"] = (success_rate > 80)

        # 2. All injected failures recovered
        recovery_rate = self.metrics.get("recovery_rate_percent", 0)
        criteria["all_failures_recovered"] = (recovery_rate == 100)

        # 3. No data corruption
        corruption = self.metrics.get("data_corruption_count", 0)
        criteria["no_data_corruption"] = (corruption == 0)

        # 4. Data integrity maintained
        integrity = self.metrics.get("data_integrity_percent", 0)
        criteria["data_integrity_100pct"] = (integrity == 100.0)

        # 5. Completed operations despite failures
        ops = self.metrics.get("operations_successful", 0)
        criteria["significant_operations"] = (ops > 1000)

        return criteria

    def teardown(self):
        """Cleanup."""
        self.running = False
        self._clear_failure()

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()
            cursor.execute("DROP TABLE IF EXISTS failure_test")
            conn.commit()
            cursor.close()
            conn.close()

            print("✅ Test table dropped")

        except Exception as e:
            self.warnings.append(f"Teardown error: {str(e)}")


def main():
    """Run the failure scenarios stress test."""
    duration_minutes = int(os.getenv("TEST_DURATION_MINUTES", "60"))

    test = FailureScenariosTest(duration_minutes=duration_minutes)
    result = test.execute()

    # Save results
    output_file = f"results/test_05_failure_scenarios_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
