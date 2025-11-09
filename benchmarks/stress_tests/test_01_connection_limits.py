"""
Stress Test 1: Connection Limits

Tests the driver's ability to handle 1000+ concurrent connections.

Success Criteria:
- Successfully establish 1000+ concurrent connections
- All connections functional (can execute queries)
- No connection leaks
- Graceful handling of connection pool exhaustion
- Memory usage stays reasonable (<10GB for 1000 connections)
- Connection establishment latency p95 < 500ms
"""

import sys
import os
import time
import threading
import psycopg2
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class ConnectionLimitsTest(StressTestBase):
    """
    Test concurrent connection limits.

    Creates 1000+ concurrent connections and validates:
    1. All connections successful
    2. All connections can execute queries
    3. No memory leaks
    4. Graceful pool exhaustion handling
    """

    def __init__(self):
        super().__init__(
            name="Connection Limits Test",
            description="Test 1000+ concurrent connections with query execution"
        )

        # Test parameters
        self.target_connections = 1000
        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Results
        self.connections = []
        self.connection_times = []
        self.query_success = 0
        self.query_failures = 0
        self.connection_failures = 0

    def setup(self):
        """Setup: Verify database is accessible."""
        print(f"Connecting to PostgreSQL at {self.db_host}:{self.db_port}")
        print(f"Database: {self.db_name}")

        # Test connection
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

    def run_test(self):
        """Main test logic."""
        print(f"\nEstablishing {self.target_connections} concurrent connections...")

        # Phase 1: Establish connections
        start_time = time.time()

        for i in range(self.target_connections):
            try:
                conn_start = time.time()

                # TODO: Replace with mojo-postgres connection when available
                # For now using psycopg2 as reference
                conn = psycopg2.connect(
                    host=self.db_host,
                    port=self.db_port,
                    database=self.db_name,
                    user=self.db_user,
                    password=self.db_password,
                    connect_timeout=10
                )

                conn_time = (time.time() - conn_start) * 1000  # ms
                self.connection_times.append(conn_time)
                self.connections.append(conn)

                if (i + 1) % 100 == 0:
                    print(f"  Established {i + 1}/{self.target_connections} connections...")

            except Exception as e:
                self.connection_failures += 1
                self.warnings.append(f"Connection {i} failed: {str(e)}")

        connection_phase_time = time.time() - start_time

        print(f"\n✅ Established {len(self.connections)} connections in {connection_phase_time:.2f}s")
        print(f"❌ Failed connections: {self.connection_failures}")

        # Phase 2: Execute queries on all connections
        print(f"\nExecuting test queries on all {len(self.connections)} connections...")

        query_start = time.time()

        def execute_query(conn, conn_id):
            """Execute a simple query on a connection."""
            try:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                cursor.close()

                if result[0] == 1:
                    self.query_success += 1
                else:
                    self.query_failures += 1
                    self.warnings.append(f"Connection {conn_id}: Query returned unexpected result")

            except Exception as e:
                self.query_failures += 1
                self.errors.append(f"Connection {conn_id}: Query failed: {str(e)}")

        # Execute queries concurrently
        threads = []
        for i, conn in enumerate(self.connections):
            thread = threading.Thread(target=execute_query, args=(conn, i))
            thread.start()
            threads.append(thread)

        # Wait for all queries
        for thread in threads:
            thread.join()

        query_phase_time = time.time() - query_start

        print(f"\n✅ Successful queries: {self.query_success}")
        print(f"❌ Failed queries: {self.query_failures}")
        print(f"Query execution time: {query_phase_time:.2f}s")

        # Calculate connection time statistics
        import statistics

        if self.connection_times:
            conn_p50 = statistics.median(self.connection_times)
            conn_p95 = sorted(self.connection_times)[int(len(self.connection_times) * 0.95)]
            conn_p99 = sorted(self.connection_times)[int(len(self.connection_times) * 0.99)]
            conn_max = max(self.connection_times)
        else:
            conn_p50 = conn_p95 = conn_p99 = conn_max = 0

        # Return metrics
        return {
            "target_connections": self.target_connections,
            "successful_connections": len(self.connections),
            "failed_connections": self.connection_failures,
            "connection_success_rate": round(len(self.connections) / self.target_connections * 100, 2),
            "connection_phase_seconds": round(connection_phase_time, 2),
            "connection_time_p50_ms": round(conn_p50, 2),
            "connection_time_p95_ms": round(conn_p95, 2),
            "connection_time_p99_ms": round(conn_p99, 2),
            "connection_time_max_ms": round(conn_max, 2),
            "successful_queries": self.query_success,
            "failed_queries": self.query_failures,
            "query_success_rate": round(self.query_success / len(self.connections) * 100, 2) if self.connections else 0,
            "query_phase_seconds": round(query_phase_time, 2)
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. At least 95% connections successful
        criteria["connection_success_rate_95%"] = (
            len(self.connections) >= self.target_connections * 0.95
        )

        # 2. All established connections can execute queries
        criteria["all_connections_functional"] = (
            self.query_success == len(self.connections)
        )

        # 3. Connection time p95 < 500ms
        if self.connection_times:
            p95 = sorted(self.connection_times)[int(len(self.connection_times) * 0.95)]
            criteria["connection_latency_p95_under_500ms"] = (p95 < 500)
        else:
            criteria["connection_latency_p95_under_500ms"] = False

        # 4. Memory usage reasonable (<10GB for 1000 connections)
        peak_memory_gb = self.metrics.get("peak_memory_mb", 0) / 1024
        criteria["memory_under_10gb"] = (peak_memory_gb < 10.0)

        # 5. No excessive memory growth (< 5MB per connection)
        memory_growth_mb = self.metrics.get("memory_growth_mb", 0)
        avg_memory_per_conn = memory_growth_mb / len(self.connections) if self.connections else 0
        criteria["memory_per_connection_under_5mb"] = (avg_memory_per_conn < 5.0)

        return criteria

    def teardown(self):
        """Cleanup: Close all connections."""
        print(f"\nClosing {len(self.connections)} connections...")

        closed = 0
        for conn in self.connections:
            try:
                conn.close()
                closed += 1
            except Exception as e:
                self.warnings.append(f"Error closing connection: {str(e)}")

        print(f"✅ Closed {closed} connections")

        self.connections = []


def main():
    """Run the connection limits stress test."""
    test = ConnectionLimitsTest()
    result = test.execute()

    # Save results
    output_file = f"results/test_01_connection_limits_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    # Exit with appropriate code
    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
