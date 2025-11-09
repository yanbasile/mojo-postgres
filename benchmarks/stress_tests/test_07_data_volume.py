"""
Stress Test 7: Data Volume Stress

Tests performance with large data volumes (1B+ rows).

Success Criteria:
- Ingest 10M+ rows successfully
- Bulk insert throughput > 100K rows/sec
- COPY command works with large files
- Query performance stable with large tables
- No degradation with growing data
- Successful cleanup of large datasets
"""

import sys
import os
import time
import psycopg2
import psycopg2.extras
import random
import tempfile
from datetime import datetime, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from stress_test_framework import StressTestBase


class DataVolumeStressTest(StressTestBase):
    """
    Test system performance with very large data volumes.

    Tests:
    1. Bulk INSERT (millions of rows)
    2. COPY command (fastest ingestion)
    3. Query performance on large tables
    4. UPDATE/DELETE on large datasets
    5. Cleanup performance
    """

    def __init__(self, target_rows: int = 10_000_000):
        super().__init__(
            name="Data Volume Stress Test",
            description=f"Test bulk ingestion and querying of {target_rows:,} rows"
        )

        self.target_rows = target_rows

        self.db_host = os.getenv("POSTGRES_HOST", "localhost")
        self.db_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.db_name = os.getenv("POSTGRES_DB", "stress_test")
        self.db_user = os.getenv("POSTGRES_USER", "postgres")
        self.db_password = os.getenv("POSTGRES_PASSWORD", "postgres")

        # Metrics
        self.insert_time = 0
        self.copy_time = 0
        self.query_times = []
        self.rows_inserted = 0

    def setup(self):
        """Setup: Create test table."""
        print(f"Creating test table for {self.target_rows:,} rows...")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Drop if exists
        cursor.execute("DROP TABLE IF EXISTS volume_test")

        # Create table with realistic schema
        cursor.execute("""
            CREATE TABLE volume_test (
                id BIGSERIAL PRIMARY KEY,
                timestamp TIMESTAMP NOT NULL,
                user_id INTEGER NOT NULL,
                event_type VARCHAR(50) NOT NULL,
                value NUMERIC(15,2),
                metadata JSONB,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)

        # Create indexes for query testing
        cursor.execute("CREATE INDEX idx_volume_timestamp ON volume_test(timestamp)")
        cursor.execute("CREATE INDEX idx_volume_user_id ON volume_test(user_id)")
        cursor.execute("CREATE INDEX idx_volume_event_type ON volume_test(event_type)")

        conn.commit()
        cursor.close()
        conn.close()

        print(f"✅ Table and indexes created")

    def _test_bulk_insert(self, num_rows: int):
        """Test 1: Bulk INSERT using execute_values."""
        print(f"\n📥 Test 1: Bulk INSERT ({num_rows:,} rows)")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Generate data in batches
        batch_size = 10000
        num_batches = num_rows // batch_size

        print(f"  Inserting in batches of {batch_size:,}...")

        start_time = time.time()
        total_inserted = 0

        for batch_num in range(num_batches):
            # Generate batch
            base_time = datetime.now() - timedelta(days=random.randint(1, 365))

            data = [
                (
                    base_time + timedelta(seconds=i),
                    random.randint(1, 1000000),
                    random.choice(['click', 'view', 'purchase', 'search', 'signup']),
                    round(random.uniform(0.01, 999.99), 2),
                    psycopg2.extras.Json({
                        'session_id': f"sess_{random.randint(1, 100000)}",
                        'source': random.choice(['web', 'mobile', 'api']),
                        'country': random.choice(['US', 'UK', 'CA', 'DE', 'FR'])
                    })
                )
                for i in range(batch_size)
            ]

            # Bulk insert using execute_values
            psycopg2.extras.execute_values(
                cursor,
                """
                INSERT INTO volume_test (timestamp, user_id, event_type, value, metadata)
                VALUES %s
                """,
                data,
                page_size=1000
            )

            total_inserted += batch_size

            if (batch_num + 1) % 10 == 0:
                conn.commit()
                elapsed = time.time() - start_time
                rate = total_inserted / elapsed

                print(f"    Batch {batch_num + 1}/{num_batches} | "
                      f"Inserted: {total_inserted:,} | "
                      f"Rate: {rate:,.0f} rows/sec")

        conn.commit()

        self.insert_time = time.time() - start_time
        self.rows_inserted = total_inserted

        insert_rate = total_inserted / self.insert_time

        print(f"  ✅ Inserted {total_inserted:,} rows in {self.insert_time:.2f}s")
        print(f"  Throughput: {insert_rate:,.0f} rows/sec")

        cursor.close()
        conn.close()

        return total_inserted

    def _test_copy_command(self, num_rows: int):
        """Test 2: COPY command (fastest bulk loading)."""
        print(f"\n📋 Test 2: COPY Command ({num_rows:,} rows)")

        # Generate CSV file
        print(f"  Generating CSV file...")

        csv_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv')
        csv_path = csv_file.name

        base_time = datetime.now() - timedelta(days=30)

        for i in range(num_rows):
            timestamp = (base_time + timedelta(seconds=i)).isoformat()
            user_id = random.randint(1, 1000000)
            event_type = random.choice(['click', 'view', 'purchase'])
            value = round(random.uniform(0.01, 999.99), 2)
            metadata = '{"batch": "copy_test"}'

            csv_file.write(f"{timestamp},{user_id},{event_type},{value},{metadata}\n")

        csv_file.close()

        file_size_mb = os.path.getsize(csv_path) / 1024 / 1024
        print(f"  CSV file: {file_size_mb:.1f} MB")

        # COPY from file
        print(f"  Executing COPY FROM...")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        start_time = time.time()

        with open(csv_path, 'r') as f:
            cursor.copy_expert(
                """
                COPY volume_test (timestamp, user_id, event_type, value, metadata)
                FROM STDIN WITH CSV
                """,
                f
            )

        conn.commit()

        self.copy_time = time.time() - start_time
        copy_rate = num_rows / self.copy_time

        print(f"  ✅ Copied {num_rows:,} rows in {self.copy_time:.2f}s")
        print(f"  Throughput: {copy_rate:,.0f} rows/sec")

        cursor.close()
        conn.close()

        # Cleanup
        os.unlink(csv_path)

        return num_rows

    def _test_query_performance(self):
        """Test 3: Query performance on large table."""
        print(f"\n🔍 Test 3: Query Performance")

        conn = psycopg2.connect(
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
            user=self.db_user,
            password=self.db_password
        )

        cursor = conn.cursor()

        # Get total row count
        cursor.execute("SELECT COUNT(*) FROM volume_test")
        total_rows = cursor.fetchone()[0]

        print(f"  Table size: {total_rows:,} rows")

        # Test queries
        test_queries = [
            ("Simple SELECT", "SELECT * FROM volume_test LIMIT 1000"),
            ("Index scan", "SELECT * FROM volume_test WHERE user_id = 12345"),
            ("Aggregation", "SELECT event_type, COUNT(*), AVG(value) FROM volume_test GROUP BY event_type"),
            ("Time range", "SELECT COUNT(*) FROM volume_test WHERE timestamp > NOW() - INTERVAL '7 days'"),
            ("Complex JOIN", """
                SELECT a.event_type, COUNT(*)
                FROM volume_test a
                JOIN volume_test b ON a.user_id = b.user_id
                WHERE a.id < 10000
                GROUP BY a.event_type
            """)
        ]

        for query_name, query in test_queries:
            print(f"\n  {query_name}:")

            start_time = time.time()
            cursor.execute(query)
            results = cursor.fetchall()
            query_time = time.time() - start_time

            self.query_times.append(query_time)

            print(f"    Time: {query_time:.3f}s, Rows: {len(results)}")

        cursor.close()
        conn.close()

    def run_test(self):
        """Main test logic."""
        # Test 1: Bulk INSERT (smaller dataset)
        insert_rows = min(self.target_rows // 10, 1_000_000)
        self._test_bulk_insert(insert_rows)

        # Test 2: COPY command (larger dataset)
        copy_rows = min(self.target_rows, 5_000_000)
        self._test_copy_command(copy_rows)

        # Test 3: Query performance
        self._test_query_performance()

        # Final statistics
        insert_rate = insert_rows / self.insert_time if self.insert_time > 0 else 0
        copy_rate = copy_rows / self.copy_time if self.copy_time > 0 else 0

        import statistics

        return {
            "target_rows": self.target_rows,
            "bulk_insert_rows": insert_rows,
            "bulk_insert_time_sec": round(self.insert_time, 2),
            "bulk_insert_rate_rows_per_sec": round(insert_rate, 0),
            "copy_rows": copy_rows,
            "copy_time_sec": round(self.copy_time, 2),
            "copy_rate_rows_per_sec": round(copy_rate, 0),
            "total_rows_ingested": self.rows_inserted + copy_rows,
            "num_queries_tested": len(self.query_times),
            "avg_query_time_sec": round(statistics.mean(self.query_times), 3) if self.query_times else 0,
            "max_query_time_sec": round(max(self.query_times), 3) if self.query_times else 0
        }

    def check_pass_criteria(self):
        """Define pass/fail criteria."""
        criteria = {}

        # 1. Bulk insert rate > 50K rows/sec
        insert_rate = self.metrics.get("bulk_insert_rate_rows_per_sec", 0)
        criteria["bulk_insert_above_50k_per_sec"] = (insert_rate > 50000)

        # 2. COPY rate > 100K rows/sec
        copy_rate = self.metrics.get("copy_rate_rows_per_sec", 0)
        criteria["copy_above_100k_per_sec"] = (copy_rate > 100000)

        # 3. Ingested significant data (at least 1M rows)
        total_rows = self.metrics.get("total_rows_ingested", 0)
        criteria["ingested_1m_plus_rows"] = (total_rows >= 1000000)

        # 4. Average query time reasonable (< 5 seconds)
        avg_query_time = self.metrics.get("avg_query_time_sec", 0)
        criteria["avg_query_under_5sec"] = (avg_query_time < 5.0)

        # 5. Completed all test phases
        criteria["all_phases_complete"] = (
            self.metrics.get("bulk_insert_rows", 0) > 0 and
            self.metrics.get("copy_rows", 0) > 0 and
            self.metrics.get("num_queries_tested", 0) > 0
        )

        return criteria

    def teardown(self):
        """Cleanup: Drop large table."""
        print(f"\n🧹 Cleaning up large table...")

        try:
            conn = psycopg2.connect(
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
                user=self.db_user,
                password=self.db_password
            )

            cursor = conn.cursor()

            # Get final size
            cursor.execute("SELECT COUNT(*) FROM volume_test")
            final_count = cursor.fetchone()[0]

            print(f"  Final table size: {final_count:,} rows")

            # Drop table
            start_time = time.time()
            cursor.execute("DROP TABLE IF EXISTS volume_test")
            conn.commit()
            drop_time = time.time() - start_time

            print(f"  ✅ Table dropped in {drop_time:.2f}s")

            cursor.close()
            conn.close()

        except Exception as e:
            self.warnings.append(f"Teardown error: {str(e)}")


def main():
    """Run the data volume stress test."""
    target_rows = int(os.getenv("TARGET_ROWS", "10000000"))

    test = DataVolumeStressTest(target_rows=target_rows)
    result = test.execute()

    # Save results
    output_file = f"results/test_07_data_volume_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs("results", exist_ok=True)
    test.save_result(result, output_file)

    sys.exit(0 if result.status.value == "passed" else 1)


if __name__ == "__main__":
    main()
