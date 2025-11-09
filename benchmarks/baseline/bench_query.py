#!/usr/bin/env python3
"""
Python Baseline: psycopg2 Query Benchmark

Measures query execution time for comparison with mojo-postgres.
"""

import psycopg2
import time
import statistics


# Configuration
HOST = "localhost"
PORT = 5432
DATABASE = "benchdb"
USER = "benchuser"
PASSWORD = "benchpass"
ITERATIONS = 1000


def query_select_1(cursor):
    """Benchmark simple SELECT 1 query."""
    cursor.execute("SELECT 1")
    rows = cursor.fetchall()


def query_select_multiple_cols(cursor):
    """Benchmark query with multiple columns."""
    cursor.execute("SELECT 1, 2, 3, 4, 5")
    rows = cursor.fetchall()


def query_10_rows(cursor):
    """Benchmark query returning 10 rows."""
    cursor.execute("""
        SELECT * FROM (VALUES
            (1), (2), (3), (4), (5),
            (6), (7), (8), (9), (10)
        ) AS t(num)
    """)
    rows = cursor.fetchall()


def query_100_rows(cursor):
    """Benchmark query returning 100 rows."""
    cursor.execute("SELECT generate_series(1, 100) AS num")
    rows = cursor.fetchall()


def query_with_types(cursor):
    """Benchmark query with various types."""
    cursor.execute("""
        SELECT
            42::INT4,
            3.14159::FLOAT8,
            TRUE::BOOL,
            'Hello, World!'::TEXT,
            '2024-01-15'::DATE
    """)
    rows = cursor.fetchall()


def query_with_nulls(cursor):
    """Benchmark query with NULL values."""
    cursor.execute("SELECT 1, NULL, 2, NULL, 3")
    rows = cursor.fetchall()


def benchmark_query_type(cursor, query_func, name, iterations):
    """Benchmark a specific query type."""
    print(f"\n{'=' * 70}")
    print(f"{name}")
    print(f"{'=' * 70}")

    # Warm-up
    for _ in range(10):
        query_func(cursor)

    # Benchmark
    timings = []
    for i in range(iterations):
        start = time.perf_counter_ns()
        query_func(cursor)
        end = time.perf_counter_ns()
        timings.append(end - start)

    # Statistics
    total_ns = sum(timings)
    mean_ns = statistics.mean(timings)
    median_ns = statistics.median(timings)
    min_ns = min(timings)
    max_ns = max(timings)

    # Print results
    mean_ms = mean_ns / 1_000_000.0
    print(f"Iterations:      {iterations}")
    print(f"Total Time:      {total_ns / 1_000_000:.2f} ms")
    print(f"Average time:    {mean_ms:.3f} ms ({mean_ns / 1_000:.1f} μs)")
    print(f"Median:          {median_ns / 1_000_000:.3f} ms")
    print(f"Min:             {min_ns / 1_000_000:.3f} ms")
    print(f"Max:             {max_ns / 1_000_000:.3f} ms")
    print(f"Throughput:      {iterations / (total_ns / 1_000_000_000):.0f} queries/sec")

    return mean_ms


def main():
    print("=" * 70)
    print("BENCHMARK: psycopg2 Query Execution")
    print("=" * 70)
    print(f"Configuration:")
    print(f"  Host:       {HOST}")
    print(f"  Port:       {PORT}")
    print(f"  Database:   {DATABASE}")
    print(f"  User:       {USER}")
    print(f"  Iterations: {ITERATIONS}")
    print("=" * 70)

    try:
        # Connect
        conn = psycopg2.connect(
            host=HOST,
            port=PORT,
            database=DATABASE,
            user=USER,
            password=PASSWORD
        )
        cursor = conn.cursor()

        # Benchmark 1: SELECT 1
        avg_ms1 = benchmark_query_type(
            cursor,
            query_select_1,
            "1. Simple Query (SELECT 1)",
            ITERATIONS
        )

        # Benchmark 2: SELECT with 5 columns
        avg_ms2 = benchmark_query_type(
            cursor,
            query_select_multiple_cols,
            "2. Multiple Columns (SELECT 1,2,3,4,5)",
            ITERATIONS
        )

        print(f"Column overhead:   {avg_ms2 - avg_ms1:.3f} ms per 4 columns")

        # Benchmark 3: 10 rows
        small_iterations = 500
        avg_ms3 = benchmark_query_type(
            cursor,
            query_10_rows,
            "3. Small Result Set (10 rows)",
            small_iterations
        )

        row_overhead3 = (avg_ms3 - avg_ms1) / 10.0
        print(f"Row overhead:      {row_overhead3 * 1000.0:.1f} μs per row")
        print(f"Throughput:        {int(small_iterations * 10 / (avg_ms3 * small_iterations / 1000.0))} rows/sec")

        # Benchmark 4: 100 rows
        med_iterations = 200
        avg_ms4 = benchmark_query_type(
            cursor,
            query_100_rows,
            "4. Medium Result Set (100 rows)",
            med_iterations
        )

        row_overhead4 = (avg_ms4 - avg_ms1) / 100.0
        print(f"Row overhead:      {row_overhead4 * 1000.0:.1f} μs per row")
        print(f"Throughput:        {int(med_iterations * 100 / (avg_ms4 * med_iterations / 1000.0))} rows/sec")

        # Benchmark 5: Various types
        avg_ms5 = benchmark_query_type(
            cursor,
            query_with_types,
            "5. Various Data Types",
            ITERATIONS
        )

        print(f"Type parsing:      {avg_ms5 - avg_ms1:.3f} ms overhead")

        # Benchmark 6: NULL values
        avg_ms6 = benchmark_query_type(
            cursor,
            query_with_nulls,
            "6. NULL Value Handling",
            ITERATIONS
        )

        print(f"NULL overhead:     {avg_ms6 - avg_ms1:.3f} ms")

        # Summary
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)
        print(f"Simple query (SELECT 1):        {avg_ms1:.3f} ms")
        print(f"5 columns:                      {avg_ms2:.3f} ms")
        print(f"10 rows:                        {avg_ms3:.3f} ms")
        print(f"100 rows:                       {avg_ms4:.3f} ms")
        print(f"Various types:                  {avg_ms5:.3f} ms")
        print(f"NULL values:                    {avg_ms6:.3f} ms")
        print("")
        print(f"Row parsing overhead:           {row_overhead4 * 1000.0:.1f} μs/row")
        print(f"Column parsing overhead:        {(avg_ms2 - avg_ms1) * 250.0:.1f} μs/column")

        # Save results
        with open("results_query_psycopg2.txt", "w") as f:
            f.write(f"select_1_ms={avg_ms1}\n")
            f.write(f"select_5_cols_ms={avg_ms2}\n")
            f.write(f"select_10_rows_ms={avg_ms3}\n")
            f.write(f"select_100_rows_ms={avg_ms4}\n")
            f.write(f"types_ms={avg_ms5}\n")
            f.write(f"nulls_ms={avg_ms6}\n")
            f.write(f"row_overhead_us={row_overhead4 * 1000.0}\n")

        print("\n" + "=" * 70)
        print("Results saved to: results_query_psycopg2.txt")
        print("Use these values to compare with mojo-postgres benchmark")
        print("=" * 70)

        # Close
        cursor.close()
        conn.close()

    except psycopg2.Error as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure PostgreSQL is running:")
        print("  docker run -d -p 5432:5432 \\")
        print("    -e POSTGRES_PASSWORD=benchpass \\")
        print("    -e POSTGRES_USER=benchuser \\")
        print("    -e POSTGRES_DB=benchdb \\")
        print("    postgres:16")


if __name__ == "__main__":
    main()
