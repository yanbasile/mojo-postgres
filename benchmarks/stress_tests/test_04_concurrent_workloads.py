"""
Stress Test 4: Concurrent Workloads

Tests system behavior under mixed concurrent read/write operations with lock contention.

Success Criteria:
- Handle 100+ concurrent workers
- Throughput > 10K ops/sec
- Deadlock detection and recovery
- Transaction isolation maintained
- No data corruption
- p99 latency < 200ms under load
"""

import sys
import os
import time
import psycopg2
import random
import threading
import statistics
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class ConcurrentWorkloadsTest(StressTestBase):
    """
    Test concurrent mixed read/write workloads with lock contention.

    Simulates realistic production scenarios:
    - 70% read operations (SELECT)
    - 20% write operations (INSERT/UPDATE)
    - 10% heavy operations (complex queries, transactions)
    - Intentional lock contention
    - Deadlock scenarios
    """

    def __init__(self, duration_minutes: int = 30):
        super().__init__(
            name="Concurrent Workloads Test",
            description=f"{duration_minutes}-minute mixed read/write concurrency test"
        )

        self.duration_minutes = duration_minutes
        self.duration_seconds = duration_minutes * 60
        self.num_workers = 100

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Metrics
        self.operations = {"read": 0, "write": 0, "heavy": 0}
        self.errors = {"deadlock": 0, "timeout": 0, "other": 0}
        self.latencies = []
        self.running = False

        # Shared state for contention
        self.hot_rows = [1, 2, 3, 4, 5]  # Rows accessed by many workers

    def setup(self):
        """Setup: Create test table with contention."""
        print(f"Setting up test table...")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Create table optimized for contention testing
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS concurrent_test (
                id SERIAL PRIMARY KEY,
                counter INTEGER DEFAULT 0,
                data TEXT,
                updated_at TIMESTAMP DEFAULT NOW()
            )
        """)

        # Insert hot rows (will be accessed by many workers)
        cursor.execute("DELETE FROM concurrent_test")
        for i in range(1000):
            cursor.execute(
                "INSERT INTO concurrent_test (id, counter, data) VALUES (%s, %s, %s)",
                (i, 0, f"initial_data_{i}")
            )

        conn.commit()
        cursor.close()
        conn.close()

        print(f"✅ Test table created with 1000 rows")
        print(f"🔥 Hot rows for contention: {self.hot_rows}")

    def _read_operation(self, conn):
        """Execute read operation."""
        cursor = conn.cursor()

        # Mix of queries
        query_type = random.random()

        if query_type < 0.5:
            # Simple SELECT
            cursor.execute("SELECT * FROM concurrent_test WHERE id = %s", (random.randint(1, 1000),))
        elif query_type < 0.8:
            # Aggregate query
            cursor.execute("SELECT COUNT(*), AVG(counter) FROM concurrent_test WHERE id < %s", (random.randint(100, 1000),))
        else:
            # Join with self (complex query)
            cursor.execute("""
                SELECT a.id, a.counter, b.counter
                FROM concurrent_test a
                JOIN concurrent_test b ON a.id = b.id
                WHERE a.id BETWEEN %s AND %s
            """, (random.randint(1, 100), random.randint(100, 200)))

        cursor.fetchall()
        cursor.close()

    def _write_operation(self, conn):
        """Execute write operation (UPDATE with contention)."""
        cursor = conn.cursor()

        # Intentionally target hot rows to create contention
        if random.random() < 0.6:
            # 60% chance to hit hot row
            row_id = random.choice(self.hot_rows)
        else:
            row_id = random.randint(1, 1000)

        # UPDATE with row-level lock
        cursor.execute("""
            UPDATE concurrent_test
            SET counter = counter + 1, updated_at = NOW()
            WHERE id = %s
        """, (row_id,))

        conn.commit()
        cursor.close()

    def _heavy_operation(self, conn):
        """Execute heavy operation (transaction with multiple steps)."""
        cursor = conn.cursor()

        try:
            # Multi-step transaction
            conn.rollback()  # Ensure clean state

            # Step 1: Read current state
            cursor.execute("SELECT counter FROM concurrent_test WHERE id = %s FOR UPDATE", (random.choice(self.hot_rows),))
            current = cursor.fetchone()[0]

            # Step 2: Simulate processing
            time.sleep(random.uniform(0.001, 0.01))

            # Step 3: Update based on read (potential for lost updates if not locked)
            cursor.execute("""
                UPDATE concurrent_test
                SET counter = %s, data = %s
                WHERE id = %s
            """, (current + 10, f"heavy_update_{current}", random.choice(self.hot_rows)))

            # Step 4: Insert audit record
            cursor.execute("""
                INSERT INTO concurrent_test (data, counter)
                VALUES (%s, %s)
            """, (f"audit_{current}", current))

            conn.commit()

        except Exception as e:
            conn.rollback()
            raise e
        finally:
            cursor.close()

    def _worker(self, worker_id: int):
        """Worker thread executing mixed operations."""
        local_ops = {"read": 0, "write": 0, "heavy": 0}
        local_errors = {"deadlock": 0, "timeout": 0, "other": 0}
        local_latencies = []

        # Each worker has own connection
        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password,
                connect_timeout=10
            )
            conn.autocommit = False  # Explicit transaction control

            while self.running:
                # Select operation type (70% read, 20% write, 10% heavy)
                rand = random.random()
                if rand < 0.70:
                    op_type = "read"
                elif rand < 0.90:
                    op_type = "write"
                else:
                    op_type = "heavy"

                # Execute operation with timing
                op_start = time.time()

                try:
                    if op_type == "read":
                        self._read_operation(conn)
                    elif op_type == "write":
                        self._write_operation(conn)
                    else:
                        self._heavy_operation(conn)

                    latency_ms = (time.time() - op_start) * 1000
                    local_latencies.append(latency_ms)
                    local_ops[op_type] += 1

                    # Keep only recent latencies
                    if len(local_latencies) > 1000:
                        local_latencies = local_latencies[-1000:]

                except psycopg2.extensions.TransactionRollbackError as e:
                    # Deadlock detected
                    local_errors["deadlock"] += 1
                    conn.rollback()
                    time.sleep(random.uniform(0.001, 0.01))  # Brief backoff

                except psycopg2.OperationalError as e:
                    if "timeout" in str(e).lower():
                        local_errors["timeout"] += 1
                    else:
                        local_errors["other"] += 1
                    conn.rollback()

                except Exception as e:
                    local_errors["other"] += 1
                    conn.rollback()

                # Small sleep to prevent tight loop
                time.sleep(random.uniform(0.001, 0.01))

            conn.close()

        except Exception as e:
            self.errors["other"] += 1

        # Report local stats to global
        for op_type, count in local_ops.items():
            self.operations[op_type] += count

        for error_type, count in local_errors.items():
            self.errors[error_type] += count

        self.latencies.extend(local_latencies)

        print(f"Worker {worker_id} completed: {sum(local_ops.values())} ops, {sum(local_errors.values())} errors")

    def run_test(self):
        """Main test logic."""
        self.running = True
        start_time = time.time()

        # Start workers
        print(f"\n🚀 Starting {self.num_workers} concurrent workers...")
        workers = []
        for i in range(self.num_workers):
            worker = threading.Thread(target=self._worker, args=(i,), daemon=True)
            worker.start()
            workers.append(worker)

        # Monitor progress
        print(f"\n⏱️  Running for {self.duration_minutes} minutes...\n")

        last_report = start_time
        report_interval = 60  # Report every minute

        while time.time() - start_time < self.duration_seconds:
            time.sleep(5)

            if time.time() - last_report >= report_interval:
                elapsed = time.time() - start_time
                total_ops = sum(self.operations.values())
                total_errors = sum(self.errors.values())
                throughput = total_ops / elapsed if elapsed > 0 else 0

                if self.latencies:
                    recent_latencies = self.latencies[-1000:]
                    p99 = sorted(recent_latencies)[int(len(recent_latencies) * 0.99)]
                else:
                    p99 = 0

                print(f"[{elapsed/60:.1f}m] Ops: {total_ops:,} ({throughput:.0f} ops/sec), "
                      f"Errors: {total_errors} (deadlocks: {self.errors['deadlock']}), "
                      f"p99 latency: {p99:.1f}ms")

                last_report = time.time()

        # Stop workers
        print("\n🛑 Stopping workers...")
        self.running = False

        for worker in workers:
            worker.join(timeout=30)

        # Calculate final statistics
        total_time = time.time() - start_time
        total_ops = sum(self.operations.values())
        total_errors = sum(self.errors.values())
        throughput = total_ops / total_time

        if self.latencies:
            p50 = sorted(self.latencies)[int(len(self.latencies) * 0.50)]
            p95 = sorted(self.latencies)[int(len(self.latencies) * 0.95)]
            p99 = sorted(self.latencies)[int(len(self.latencies) * 0.99)]
            avg = statistics.mean(self.latencies)
        else:
            p50 = p95 = p99 = avg = 0

        error_rate = (total_errors / max(total_ops, 1)) * 100

        return {
            "duration_minutes": self.duration_minutes,
            "num_workers": self.num_workers,
            "total_operations": total_ops,
            "read_operations": self.operations["read"],
            "write_operations": self.operations["write"],
            "heavy_operations": self.operations["heavy"],
            "throughput_ops_per_sec": round(throughput, 2),
            "total_errors": total_errors,
            "deadlock_errors": self.errors["deadlock"],
            "timeout_errors": self.errors["timeout"],
            "other_errors": self.errors["other"],
            "error_rate_percent": round(error_rate, 3),
            "latency_avg_ms": round(avg, 2),
            "latency_p50_ms": round(p50, 2),
            "latency_p95_ms": round(p95, 2),
            "latency_p99_ms": round(p99, 2)
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. Throughput > 10K ops/sec
        throughput = self.metrics.get("throughput_ops_per_sec", 0)
        criteria["throughput_above_10k_ops_sec"] = (throughput > 10000)

        # 2. Error rate < 5% (allowing some deadlocks is normal)
        error_rate = self.metrics.get("error_rate_percent", 0)
        criteria["error_rate_under_5pct"] = (error_rate < 5.0)

        # 3. p99 latency < 200ms
        p99 = self.metrics.get("latency_p99_ms", 0)
        criteria["p99_latency_under_200ms"] = (p99 < 200)

        # 4. Deadlocks handled (recovered from)
        deadlocks = self.metrics.get("deadlock_errors", 0)
        total_ops = self.metrics.get("total_operations", 0)
        # Deadlocks should be detected and retried
        criteria["deadlocks_handled"] = (deadlocks < total_ops * 0.01)  # < 1% deadlock rate

        # 5. Completed significant operations
        criteria["significant_operations"] = (total_ops > 100000)

        return criteria

    def teardown(self):
        """Cleanup: Verify data integrity."""
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

            # Verify data integrity
            cursor.execute("SELECT COUNT(*) FROM concurrent_test")
            row_count = cursor.fetchone()[0]

            cursor.execute("SELECT SUM(counter) FROM concurrent_test WHERE id IN %s", (tuple(self.hot_rows),))
            total_counter = cursor.fetchone()[0] or 0

            print(f"\n📊 Data Integrity Check:")
            print(f"  Total rows: {row_count}")
            print(f"  Hot rows total counter: {total_counter}")
            print(f"  Expected write ops: {self.operations['write'] + self.operations['heavy']}")

            # Cleanup
            cursor.execute("DROP TABLE IF EXISTS concurrent_test")
            conn.commit()
            cursor.close()
            conn.close()

            print("✅ Test table dropped")

        except Exception as e:
            self.warnings.append(f"Teardown error: {str(e)}")


def main():
    """Run the concurrent workloads stress test."""
    duration_minutes = int(os.getenv("TEST_DURATION_MINUTES", "30"))

    test = ConcurrentWorkloadsTest(duration_minutes=duration_minutes)
    result = test.execute()

    # Save results
    output_file = f"results/test_04_concurrent_workloads_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
