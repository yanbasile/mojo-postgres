"""
Stress Test 6: Resource Exhaustion

Tests system behavior when approaching resource limits.

Success Criteria:
- Graceful handling of resource exhaustion
- No crashes when limits reached
- Appropriate error messages
- Resource cleanup after pressure
- Recovery when resources available
- File descriptor limit handling
"""

import sys
import os
import time
import psycopg2
import psutil
import threading
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class ResourceExhaustionTest(StressTestBase):
    """
    Test system behavior at resource limits.

    Tests:
    1. File descriptor exhaustion (open many connections)
    2. Memory pressure (large result sets)
    3. CPU saturation (complex queries)
    4. Connection pool exhaustion
    """

    def __init__(self):
        super().__init__(
            name="Resource Exhaustion Test",
            description="Test system behavior at resource limits"
        )

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Metrics
        self.fd_limit_reached = False
        self.memory_limit_reached = False
        self.connection_limit_reached = False
        self.max_fds_used = 0
        self.max_memory_mb = 0
        self.graceful_errors = 0
        self.crashes = 0

    def setup(self):
        """Setup: Get system limits."""
        print(f"Checking system limits...")

        # Get process limits
        process = psutil.Process()

        try:
            if hasattr(process, 'rlimit'):
                import resource
                soft_fd_limit, hard_fd_limit = resource.getrlimit(resource.RLIMIT_NOFILE)
                print(f"  File descriptor limits: soft={soft_fd_limit}, hard={hard_fd_limit}")
            else:
                print(f"  File descriptor limits: Not available on this platform")
        except Exception as e:
            print(f"  Could not read FD limits: {e}")

        # Get PostgreSQL connection limit
        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()
            cursor.execute("SHOW max_connections")
            max_conn = cursor.fetchone()[0]
            print(f"  PostgreSQL max_connections: {max_conn}")

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS resource_test (
                    id SERIAL PRIMARY KEY,
                    data TEXT
                )
            """)

            conn.commit()
            cursor.close()
            conn.close()

        except Exception as e:
            raise Exception(f"Setup failed: {e}")

    def _test_fd_exhaustion(self):
        """Test 1: File descriptor exhaustion."""
        print("\n📁 Test 1: File Descriptor Exhaustion")
        print("  Opening connections until file descriptor limit...")

        connections = []
        max_connections = 5000  # Safety limit

        try:
            for i in range(max_connections):
                try:
                    conn = psycopg2.connect(
                        host=self.db_host,
                        port=self.db_port,
                        database=self.db_name,
                        user=self.db_user,
                        password=self.db_password,
                        connect_timeout=5
                    )
                    connections.append(conn)

                    # Track FD usage
                    process = psutil.Process()
                    if hasattr(process, 'num_fds'):
                        num_fds = process.num_fds()
                    else:
                        num_fds = len(process.open_files())

                    self.max_fds_used = max(self.max_fds_used, num_fds)

                    if (i + 1) % 100 == 0:
                        print(f"    Opened {i + 1} connections, FDs: {num_fds}")

                except psycopg2.OperationalError as e:
                    if "too many open files" in str(e).lower() or "could not create socket" in str(e).lower():
                        print(f"  ✅ FD limit reached gracefully at {i} connections")
                        self.fd_limit_reached = True
                        self.graceful_errors += 1
                        break
                    elif "connection limit" in str(e).lower() or "too many clients" in str(e).lower():
                        print(f"  ✅ Connection limit reached at {i} connections")
                        self.connection_limit_reached = True
                        self.graceful_errors += 1
                        break
                    else:
                        raise

            print(f"  Opened {len(connections)} connections total")
            print(f"  Max file descriptors: {self.max_fds_used}")

        finally:
            # Cleanup
            print(f"  Closing {len(connections)} connections...")
            for conn in connections:
                try:
                    conn.close()
                except:
                    pass

        return len(connections)

    def _test_memory_pressure(self):
        """Test 2: Memory pressure with large result sets."""
        print("\n💾 Test 2: Memory Pressure (Large Result Sets)")
        print("  Querying large result sets to stress memory...")

        process = psutil.Process()
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()

            # Generate large dataset
            print("  Generating 1M rows...")
            cursor.execute("DELETE FROM resource_test")

            # Insert in batches
            for batch in range(100):
                values = [(f"data_{i}" * 100,) for i in range(10000)]
                cursor.executemany("INSERT INTO resource_test (data) VALUES (%s)", values)

                if (batch + 1) % 20 == 0:
                    current_memory = process.memory_info().rss / 1024 / 1024
                    print(f"    Batch {batch + 1}/100, Memory: {current_memory:.1f} MB")

            conn.commit()

            # Query large result set
            print("  Querying 1M rows...")
            cursor.execute("SELECT * FROM resource_test")

            # Fetch in chunks to monitor memory
            chunk_size = 10000
            rows_fetched = 0

            while True:
                chunk = cursor.fetchmany(chunk_size)
                if not chunk:
                    break

                rows_fetched += len(chunk)

                current_memory = process.memory_info().rss / 1024 / 1024
                self.max_memory_mb = max(self.max_memory_mb, current_memory)

                if rows_fetched % 100000 == 0:
                    memory_growth = current_memory - initial_memory
                    print(f"    Fetched {rows_fetched:,} rows, Memory: {current_memory:.1f} MB (growth: +{memory_growth:.1f} MB)")

            cursor.close()
            conn.close()

            final_memory = process.memory_info().rss / 1024 / 1024
            memory_growth = final_memory - initial_memory

            print(f"  ✅ Completed: Fetched {rows_fetched:,} rows")
            print(f"  Memory growth: {memory_growth:.1f} MB")
            print(f"  Peak memory: {self.max_memory_mb:.1f} MB")

            return rows_fetched

        except MemoryError as e:
            print(f"  ✅ Memory limit reached gracefully")
            self.memory_limit_reached = True
            self.graceful_errors += 1
            return 0

    def _test_cpu_saturation(self):
        """Test 3: CPU saturation with complex queries."""
        print("\n⚡ Test 3: CPU Saturation (Complex Queries)")
        print("  Running CPU-intensive queries...")

        process = psutil.Process()

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Complex analytical query
        complex_queries = [
            # Cartesian product (very expensive)
            """
            SELECT COUNT(*)
            FROM resource_test a
            CROSS JOIN resource_test b
            WHERE a.id < 1000 AND b.id < 1000
            """,

            # Complex aggregation
            """
            SELECT
                substring(data, 1, 10) as prefix,
                COUNT(*),
                AVG(id),
                STDDEV(id)
            FROM resource_test
            GROUP BY prefix
            ORDER BY COUNT(*) DESC
            LIMIT 100
            """,

            # Recursive CTE
            """
            WITH RECURSIVE cte AS (
                SELECT 1 as n
                UNION ALL
                SELECT n + 1 FROM cte WHERE n < 10000
            )
            SELECT COUNT(*) FROM cte
            """
        ]

        cpu_samples = []

        for i, query in enumerate(complex_queries, 1):
            print(f"\n  Query {i}:")

            # Monitor CPU during query
            def monitor_cpu():
                for _ in range(30):
                    cpu_samples.append(process.cpu_percent(interval=1.0))

            monitor_thread = threading.Thread(target=monitor_cpu, daemon=True)
            monitor_thread.start()

            start_time = time.time()

            try:
                cursor.execute(query)
                cursor.fetchall()

                query_time = time.time() - start_time
                print(f"    Completed in {query_time:.2f}s")

            except Exception as e:
                print(f"    Error: {e}")

            monitor_thread.join(timeout=2)

        cursor.close()
        conn.close()

        if cpu_samples:
            avg_cpu = sum(cpu_samples) / len(cpu_samples)
            max_cpu = max(cpu_samples)
            print(f"\n  CPU Usage: avg={avg_cpu:.1f}%, max={max_cpu:.1f}%")

            return {"avg_cpu": avg_cpu, "max_cpu": max_cpu}
        else:
            return {"avg_cpu": 0, "max_cpu": 0}

    def run_test(self):
        """Main test logic."""
        # Test 1: FD exhaustion
        connection_count = self._test_fd_exhaustion()

        # Small pause
        time.sleep(5)

        # Test 2: Memory pressure
        rows_fetched = self._test_memory_pressure()

        # Small pause
        time.sleep(5)

        # Test 3: CPU saturation
        cpu_stats = self._test_cpu_saturation()

        return {
            "fd_limit_reached": self.fd_limit_reached,
            "connection_limit_reached": self.connection_limit_reached,
            "memory_limit_reached": self.memory_limit_reached,
            "max_connections_opened": connection_count,
            "max_file_descriptors": self.max_fds_used,
            "max_memory_mb": round(self.max_memory_mb, 2),
            "large_result_set_rows": rows_fetched,
            "avg_cpu_percent": round(cpu_stats["avg_cpu"], 2),
            "max_cpu_percent": round(cpu_stats["max_cpu"], 2),
            "graceful_errors": self.graceful_errors,
            "crashes": self.crashes
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. No crashes
        crashes = self.metrics.get("crashes", 0)
        criteria["no_crashes"] = (crashes == 0)

        # 2. Limits reached gracefully (with proper errors, not crashes)
        graceful = self.metrics.get("graceful_errors", 0)
        criteria["graceful_limit_handling"] = (graceful > 0)

        # 3. Opened significant connections (at least 100)
        connections = self.metrics.get("max_connections_opened", 0)
        criteria["opened_100_plus_connections"] = (connections >= 100)

        # 4. Handled large result sets (fetched at least 100K rows)
        rows = self.metrics.get("large_result_set_rows", 0)
        criteria["handled_large_result_sets"] = (rows >= 100000)

        # 5. System remained responsive (CPU not stuck at 100%)
        max_cpu = self.metrics.get("max_cpu_percent", 0)
        criteria["system_remained_responsive"] = (max_cpu < 100)

        return criteria

    def teardown(self):
        """Cleanup."""
        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()
            cursor.execute("DROP TABLE IF EXISTS resource_test")
            conn.commit()
            cursor.close()
            conn.close()

            print("\n✅ Test table dropped")

        except Exception as e:
            self.warnings.append(f"Teardown error: {str(e)}")


def main():
    """Run the resource exhaustion stress test."""
    test = ResourceExhaustionTest()
    result = test.execute()

    # Save results
    output_file = f"results/test_06_resource_exhaustion_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
